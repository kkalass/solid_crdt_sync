# A Framework for Local-First, Interoperable Apps on Solid

## 1. Executive Summary

This document outlines an architecture for building **local-first, collaborative, and truly interoperable applications** using Solid Pods as a synchronization backend. The core challenge is twofold: first, to enable robust, conflict-free data merging without sacrificing semantic interoperability; and second, to provide a scalable solution for building performant applications, regardless of dataset size.

The proposed solution addresses both challenges through a declarative, developer-centric framework. Unlike operation-based approaches (such as SU-Set) that synchronize individual change events, our architecture uses a **state-based CRDT model**. This means the entire state of a resource is synchronized, a choice that works seamlessly with passive storage backends like Solid Pods. To ensure data integrity, developers declaratively **link data properties to CRDT merge strategies**. To manage performance, they define a high-level **Sync Strategy** per type (full, partitioned, or on-demand). This approach allows the library to act as a flexible "add-on" to an existing application, rather than a monolithic database, while ensuring all data at rest on the Solid Pod is clean, standard RDF.

## 2. Core Principles

* **Local-First:** The application must be fully functional offline, working primarily with data cached on the device. To ensure this principle remains practical for large datasets, the architecture supports optional partial sync strategies. This allows an application to work with a local, consistent cache of the *relevant* data, maintaining speed and offline availability without requiring a full data download.

* **True Interoperability:** The data is clean, standard RDF. It becomes fully interoperable by linking to a public "ruleset" that defines how to collaborate on it.

* **Declarative Merge Behavior:** Developers define the merge behavior for each piece of data by declaratively linking its properties to well-defined **state-based** CRDT types (e.g., `LWW-Register`, `OR-Set`). This is done in a **public, discoverable rules file**, abstracting away the complexity of the underlying algorithms. This state-based approach is fundamental to the architecture's design as it works seamlessly with passive storage backends.

* **Discoverability:** The system is designed to be self-describing. Applications can discover the location of data through the user's Solid Type Index. From a single data resource, a client can then discover its merge rules (`sync:isGovernedBy`) and the specific index shard it belongs to (`idx:belongsToIndexShard`), enabling any application to learn how to correctly and safely collaborate on the data without prior knowledge.

* **Decentralized & Server-Agnostic:** The Solid Pod acts as a simple, passive storage bucket. All synchronization logic resides within the client-side library.

## 3. Discovery Protocol

Applications discover data locations through the standard Solid discovery mechanism, extended with index-specific resolution:

1. **Standard Discovery:** Follow WebID → Profile Document → Public Type Index:

```turtle
# In Profile Document at https://alice.podprovider.org/profile/card#me
@prefix solid: <http://www.w3.org/ns/solid/terms#> .

<#me> solid:publicTypeIndex </settings/publicTypeIndex.ttl> .
```

2. **Index Resolution:** From the Type Index, resolve data type registrations to data containers:

```turtle
# In Public Type Index at https://alice.podprovider.org/settings/publicTypeIndex.ttl
@prefix solid: <http://www.w3.org/ns/solid/terms#> .
@prefix schema: <https://schema.org/> .
@prefix meal: <https://example.org/vocab/meal#> .

<#recipes> a solid:TypeRegistration;
   solid:forClass schema:Recipe;
   solid:instanceContainer <../data/recipes/> .

<#shopping-entries> a solid:TypeRegistration;
   solid:forClass meal:ShoppingListEntry;
   solid:instanceContainer <../data/shopping-entries/> .
```

3. **Framework Type Resolution:** Applications also register framework-specific types (indices and client installations) in the Type Index using the same mechanism:

```turtle
# Also in Public Type Index at https://alice.podprovider.org/settings/publicTypeIndex.ttl
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .

<#recipe-index> a solid:TypeRegistration;
   solid:forClass idx:RootIndex;
   solid:instance <../indices/recipes/index> ;
   idx:indexesClass schema:Recipe .

<#shopping-entries-index> a solid:TypeRegistration;
   solid:forClass idx:PartitionedIndex;
   solid:instance <../indices/shopping-entries/index> ;
   idx:indexesClass meal:ShoppingListEntry .

<#client-installations> a solid:TypeRegistration;
   solid:forClass crdt:ClientInstallation;
   solid:instanceContainer <../installations/> .
```

4. **Index Type Detection:** Applications query the Type Index for both data types (e.g., `schema:Recipe`) and their corresponding index types (e.g., `idx:RootIndex`), enabling automatic discovery of the complete synchronization setup.

**Advantages:** Using TypeRegistration for indices enables full discoverability - applications can find both data and indices through standard Solid mechanisms, making the architecture truly self-describing.

## 4. Architectural Layers

The architecture is composed of four distinct layers, moving from the fundamental structure of the data to the high-level strategies used by an application.

### 4.1. Layer 1: The Data Resource

This layer defines the atomic unit of data: a single, self-contained RDF resource. Its primary purpose is to describe a "thing" using standard vocabularies.

* **Format:** Data is stored as a single RDF resource. It uses a fragment identifier (e.g., `#it`) to distinguish the "thing" being described from the document that describes it.

* **Vocabulary:** The primary data uses well-known public or custom vocabularies (e.g., `schema.org`).

* **Structure:** The resource is clean and focused on the data's payload. It contains pointers to the other architectural layers. For a clean separation of concerns, it is recommended to store data and indices in separate top-level containers (e.g., `/data/` and `/indices/`). However, a compliant client must always use the Solid Type Index as the definitive source for discovering these locations, as a user may choose to configure different paths.

#### Example Application Context

The following examples demonstrate the architecture using a **meal planning application** that manages recipes, meal plans, and automatically generates shopping lists from planned meals. This integrated workflow shows how different data types can reference each other while maintaining clean separation of concerns.

**Example: A recipe resource at `https://alice.podprovider.org/data/recipes/123`**
This resource lives in Alice's Pod and describes a recipe. It contains metadata that links it to other architectural layers, enabling its use within the synchronization framework.

```turtle
@prefix schema: <https://schema.org/> .
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix : <#> .

# -- The "Thing" Itself (The Payload) --
:it a schema:Recipe;
   schema:name "Tomato Soup" ;
   schema:keywords "vegan", "soup" ;
   schema:recipeIngredient "2 lbs fresh tomatoes", "1 cup fresh basil" ;
   schema:totalTime "PT30M" .

# -- Pointers to Other Layers --
<> a foaf:Document;
   foaf:primaryTopic :it;
   # Pointer to the Merge Contract (Layer 2)
   sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v1> ;
   # Pointer to the specific index shard this resource belongs to.
   idx:belongsToIndexShard <../../indices/recipes/shard-0> .
```

### 4.2. Layer 2: The Merge Contract

This layer defines the "how" of data integrity. It is a public, application-agnostic contract that ensures any two applications can merge the same data and arrive at the same result. It consists of two parts: the high-level rules and the low-level mechanics.

* **The Rules (`sync:` vocabulary):** A separate, published RDF file defines the merge behavior for a class of data by linking its properties to specific CRDT algorithms.

* **The Mechanics (`crdt:` vocabulary):** To execute the rules, low-level metadata is embedded within the data resource itself. This includes **Vector Clocks** for versioning and **RDF-Star Tombstones** for managing deletions.

**Example: The Rules File `recipe-v1`**
This file, published at a public URL, defines how to merge a `schema:Recipe`.

```turtle
@prefix schema: <https://schema.org/> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .

<> a sync:ClassMapping;
   sync:appliesToClass schema:Recipe;
   sync:propertyMapping
     [ sync:property schema:name; crdt:mergeWith crdt:LWW_Register ],
     [ sync:property schema:keywords; crdt:mergeWith crdt:OR_Set ],
     [ sync:property schema:recipeIngredient; crdt:mergeWith crdt:OR_Set ],
     [ sync:property schema:totalTime; crdt:mergeWith crdt:LWW_Register ].
```

**Example: The Mechanics embedded in `https://alice.podprovider.org/data/recipes/123`**
This shows the full recipe resource with the CRDT mechanics included.

```turtle
# ... prefixes and primary data from Layer 1 ...

# -- CRDT Mechanics --
<>
   # The full, structured Vector Clock
   crdt:hasClockEntry
    [
        crdt:clientId <https://example.com/clients/A>;
        crdt:clockValue "15"^^xsd:integer
    ],
    [
        crdt:clientId <https://example.com/clients/B>;
        crdt:clockValue "8"^^xsd:integer
    ];
   # A pre-calculated hash of the clock for efficient index updates
   crdt:vectorClockHash "xxh64:abcdef1234567890" .

# The RDF-Star tombstone for a deleted keyword
<< :it schema:keywords "quick" >> crdt:isDeleted true .
```

**Example: A shopping list entry at `https://alice.podprovider.org/data/shopping-entries/item-001`**
This resource shows how shopping list entries are derived from recipes in the meal planning workflow.

```turtle
@prefix schema: <https://schema.org/> .
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix meal: <https://example.org/vocab/meal#> .
@prefix : <#> .

# -- The Shopping List Entry (The Payload) --
:it a meal:ShoppingListEntry;
   schema:name "2 lbs fresh tomatoes" ;
   meal:quantity "2" ;
   meal:unit "lbs" ;
   # Links to the source recipe that generated this shopping item
   meal:derivedFrom <../recipes/123> ;
   # Links to the meal plan that requires this ingredient
   meal:requiredFor <../meal-plans/2025-08-15> .

# -- Pointers to Other Layers --
<> a foaf:Document;
   foaf:primaryTopic :it;
   # Uses a different merge contract for shopping list entries
   sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/shopping-entry-v1> ;
   idx:belongsToIndexShard <../../indices/shopping-entries/partitions/2025-08/shard-0> .
```

#### 4.2.1. CRDT Merge Mechanics

The state-based merge process follows standard CRDT algorithms adapted for RDF. The merge contract specifies which CRDT type to use for each property (LWW-Register, OR-Set, etc.), and the library performs property-by-property merging using vector clocks for causality determination.

**Client Installation Documents**

Client IDs are IRIs that reference discoverable `crdt:ClientInstallation` documents. These documents are stored in containers found via the Type Index and provide traceability for vector clock entries.

**Example client installation at `https://alice.podprovider.org/installations/mobile-recipe-app-2024-08-19-xyz`:**

```turtle
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<> a crdt:ClientInstallation;
   crdt:belongsToWebID <../profile/card#me>;
   crdt:applicationId <https://meal-planning-app.example.org/id>;
   crdt:createdAt "2024-08-19T10:30:00Z"^^xsd:dateTime .
```

Applications discover the installations container through the Type Index, then generate unique installation IDs using implementation-specific methods (UUIDs, timestamps, etc.).

**Detailed Algorithms:** For comprehensive merge algorithms, vector clock mechanics, and edge case handling, see the [CRDT Specification Document](CRDT-SPECIFICATION.md).

### 4.3. Layer 3: The Indexing Layer

This is an optional but powerful performance and discovery layer. It defines a convention for how data can be indexed for fast access.

* **The Convention (`idx:` vocabulary):** The index is a separate set of CRDT resources that contain "header" information and a **lightweight hash of each resource's vector clock**. The vocabulary uses a clear naming hierarchy to distinguish between different types of indices.

* **Structure:** The index is a two-level hierarchy of **Partitions** (logical groups) and **Shards** (technical splits). Each index is self-describing.

**Index Naming Hierarchy:**

* **`idx:Index`:** The abstract base class for any sharded index that directly contains data entries.
* **`idx:RootIndex`:** A concrete, monolithic index for a dataset. It is used when a `PartitionedIndex` is not required. It inherits from `idx:Index`.
* **`idx:PartitionedIndex`:** A "rulebook" resource that defines *how* a data type is partitioned. It does **not** contain data entries itself.
* **`idx:Partition`:** A concrete index representing a single partition (e.g., "August 2025"). It inherits from `idx:Index` and links back to its `PartitionedIndex` rulebook.

### 4.3.1. Indexing Conventions and Best Practices
To ensure interoperability, performance, and good citizenship within the Solid ecosystem, applications should adhere to the following conventions when working with indices:

 *   **The "Default" Index:** For each class of data (e.g., `schema:Recipe`), there is a convention for a "default" index. Applications should first attempt to discover this default index (e.g., via the user's Solid Type Index). If the discovered default index does not meet an application's specific requirements (e.g., it's a `RootIndex` but the app needs a `PartitionedIndex`, or it lacks necessary `indexedProperty` fields), the application **MUST NOT** modify the existing default index. Instead, it should create its own application-specific index. Modifying a shared default index can inadvertently break other applications that rely on its established structure and content.
 
 *   **Minimalism in Default Indices:** Default indices should be kept as minimal as possible. Their primary purpose is to enable basic discovery and synchronization of data resources. They should typically include only essential fields necessary for broad interoperability, such as `foaf:name` or `schema:name` (if at all), and the resource's IRI. Bloating the default index with application-specific or excessive fields increases synchronization overhead for all applications that interact with that data type.

 *   **Application-Specific Indices and "Good Citizenship":** Applications are free to create their own custom indices with additional `indexedProperty` fields to support specific UI needs, advanced search capabilities, or other application-specific functionalities. However, developers must be considerate ("good citizens") when doing so. Every time a data resource is updated, all indices that reference it must also be updated. Therefore, creating numerous application-specific indices, or indices with a large number of `indexedProperty` fields, significantly increases the synchronization burden on *all* applications that interact with that data type. Developers should carefully weigh the benefits of a custom index against the increased overhead for the entire ecosystem. 

**Example 1: A `PartitionedIndex` at `https://alice.podprovider.org/indices/shopping-entries/index`**
This resource is the "rulebook" for all shopping list entry partitions in our meal planning application.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix schema: <https://schema.org/> .
@prefix mappings: <https://kkalass.github.io/solid_crdt_sync/mappings/> .
@prefix meal: <https://example.org/vocab/meal#> .

<> a idx:PartitionedIndex;
   idx:indexesClass meal:ShoppingListEntry;
   idx:indexedProperty schema:name, meal:requiredFor;
   # A default sharding algorithm for all partitions created under this rule.
   idx:shardingAlgorithm [
     a idx:ModuloHashSharding;
     idx:hashAlgorithm "xxhash64";
     idx:numberOfShards 4
   ] ;
   sync:isGovernedBy mappings:partitioned-index-v1;

   # The declarative rule for how to assign items to partitions.
   idx:partitionedBy [
     a idx:PartitionRule;
     idx:sourceProperty meal:requiredFor;  # Partition by meal plan date
     idx:format "YYYY-MM";
     idx:partitionTemplate "partitions/{value}/index"
   ].
```

**Example 2: A `Partition` document at `https://alice.podprovider.org/indices/shopping-entries/partitions/2025-08/index`**
This is a concrete index for shopping list entries from August 2025 meal plans.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .

<> a idx:Partition;
   sync:isGovernedBy mappings:partition-v1;
   # Back-link to the rulebook.
   idx:isPartitionOf <../../index>;
   # It inherits its configuration (indexed properties, etc.) from the rulebook.
   # It has its own list of active shards, which are sibling documents.
   idx:hasShard <shard-0>, <shard-1>, ... .
```

**Example: A Shard Document at `https://alice.podprovider.org/indices/shopping-entries/partitions/2025-08/shard-0`**
This document contains entries pointing to shopping list data resources from August 2025.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix mappings: <https://kkalass.github.io/solid_crdt_sync/mappings/> .

<> a idx:Shard;
   sync:isGovernedBy mappings:shard-v1;
   idx:isShardOf <index>; # Back-link to its Partition document
   idx:containsEntry [
     idx:resource <../../../../data/shopping-entries/item-001>; # Relative path to shopping list entry
     idx:name "2 lbs tomatoes";
     meal:requiredFor <../../../../data/meal-plans/2025-08-15>;
     crdt:vectorClockHash "xxh64:abcdef1234567890"
   ],
   [
     idx:resource <../../../../data/shopping-entries/item-002>;
     idx:name "Fresh basil";
     meal:requiredFor <../../../../data/meal-plans/2025-08-17>;
     crdt:vectorClockHash "xxh64:fedcba9876543210"
   ].
```

### 4.4. Layer 4: The Sync Strategy

This is the client-side layer where the application developer makes choices about how to synchronize data. The architecture provides flexibility by separating two key decisions: the **Indexing Strategy** (how data is organized on the Pod) and the **Sync Behavior** (what the app syncs by default).

#### 4.4.1. Decision 1: Indexing Strategy

This decision depends on the expected size and structure of the dataset.

*   **Monolithic Index (`idx:RootIndex`):** A single, global index is used for the entire dataset. This is suitable for small to medium-sized datasets where a complete list of all items is needed (e.g., a user's recipe collection).
*   **Partitioned Index (`idx:PartitionedIndex`):** The index is broken into smaller, logical chunks, or partitions (e.g., by date, by category). This is the right choice for very large or time-series datasets where a full index would be too large and inefficient (e.g., shopping list entries partitioned by meal plan date).

#### 4.4.2. Decision 2: Sync Behavior

This decision depends on the application's use case and performance requirements.

*   **Full Data Sync:** The application downloads the relevant index (or index partition) and then immediately fetches the full data for all resources listed in it. This is useful when the application needs the complete data to function.
*   **On-Demand Sync (Index-Only):** The application *only* downloads the index by default. This provides the app with a lightweight list of "headers" (e.g., IRI, title). The full data for a specific resource is only fetched when the application explicitly requests it (e.g., when a user clicks on an item). This is ideal for improving initial load times and reducing bandwidth usage.

#### 4.4.3. Common Strategies

The named sync strategies are simply convenient bundles of these two decisions:

*   **`FullSync`:** A **Full Data Sync** using a **Monolithic Index**.
*   **`PartitionedSync`:** A **Full Data Sync** using a **Partitioned Index**. The application subscribes to specific partitions.
*   **`OnDemandSync`:** An **On-Demand (Index-Only) Sync** using a **Monolithic Index**.

It's also possible to perform an On-Demand sync on a partitioned index, giving the developer fine-grained control over performance for massive, partitioned datasets.

## 5. Synchronization Workflow

The synchronization process is governed by the **Sync Strategy** that the developer chooses.

1.  **Index Selection:** The application chooses which indices to sync based on its needs (e.g., current month's shopping entries, all recipes, etc.).
2.  **Index Synchronization:** The library fetches the selected index, reads its `idx:hasShard` list, and synchronizes the active shards.
3.  **App Notification (`onIndexUpdate`):** The library notifies the application with the list of headers from the synchronized index.
4.  **Sync Strategy Application:** Based on the configured strategy:
     - **FullSync:** Immediately fetch all resources listed in the index
     - **OnDemandSync:** Wait for explicit resource requests
5.  **On-Demand Fetch (`fetchFromRemote`):** When needed, the app calls `fetchFromRemote("https://alice.podprovider.org/data/shopping-entries/item-001")`.
6.  **State-based Merge:** The library downloads the full RDF resource, consults the **Merge Contract**, performs property-by-property merging, and returns the merged object.
7.  **App Notification (`onUpdate`):** The library notifies the application with the complete, merged object for local storage.

## 6. Error Handling and Resilience

Real-world synchronization faces numerous failure modes. This architecture provides specific strategies for maintaining consistency and availability despite various error conditions.

### 6.1. Network and Connectivity Failures

**Sync Failure Classification:**
Distinguish between systemic and resource-specific failures:

- **Systemic Failures (abort entire sync):**
  - Network connectivity issues (DNS, connection timeouts)
  - Server errors (HTTP 500, 502, 503) indicating server overload/maintenance
  - Authentication provider unavailable
  - Pattern detection: >20% resource fetch failures suggests systemic issue

- **Resource-Specific Failures (skip and continue):**
  - Individual HTTP 404 (resource deleted/moved)
  - Individual HTTP 403 (access control changed for specific resource)
  - Individual parse errors (malformed RDF in single resource)

**Sync Recovery Strategies:**
- **Index Sync Interruption:** Always abort and retry from beginning - partial indices create inconsistent views
- **Systemic Failure Detection:** Stop current sync, schedule retry with exponential backoff (5min, 15min, 45min...)
- **Resource-Specific Failures:** Log failure, continue sync with remaining resources, retry failed resources on next sync cycle
- **Upload Failures:** Queue locally, retry with backoff, but preserve vector clock consistency

**Network Partitioning:**
During extended network unavailability:

- **Offline Operation:** Applications continue working with locally cached data and indices
- **Local-Only Updates:** Continue incrementing vector clocks for local changes
- **Sync Resume:** On reconnection, normal CRDT merge processes handle any conflicts from the partition period

### 6.2. Resource Discovery Failures

**Comprehensive Setup Process:**
```
1. Check WebID Profile Document for solid:publicTypeIndex
2. If found, query Type Index for required data types (schema:Recipe, idx:RootIndex, crdt:ClientInstallation, etc.)
3. Collect all missing/required configuration:
   - Missing Type Index entirely
   - Missing Type Registrations for data types
   - Missing Type Registrations for indices  
   - Missing Type Registrations for client installations
4. If any configuration is missing: Display single comprehensive "Pod Setup Dialog"
5. User chooses approach:
   a. "Automatic Setup" - Configure Pod with standard paths automatically
   b. "Custom Setup" - Review and modify proposed Profile/Type Index changes before applying
6. If user cancels: Run with hardcoded default paths, warn about reduced interoperability
```

**Setup Dialog Design Principles:**

- **Explicit Consent:** Never modify Pod configuration without user permission
- **Progressive Disclosure:** Automatic Setup shields users from complexity, Custom Setup provides full control
- **Clear Options:** Two main paths - trust the app or customize the details
- **Graceful Fallback:** Always offer alternative approaches if user declines configuration changes
- **Online-Only Operation:** Pod configuration modifications require network connectivity (not CRDT-compatible)

**Example Setup Dialog Flow:**
```
┌─────── Pod Setup Required ───────┐
│                                  │
│ This app needs to configure      │ 
│ data storage in your Solid Pod   │
│ to enable synchronization.       │
│                                  │
│ ○ Automatic Setup                │
│   Use standard Solid paths       │
│   (recommended)                  │
│                                  │
│ ○ Custom Setup                   │
│   Review and customize paths     │
│                                  │
│ [ Continue ]  [ Cancel ]         │
└──────────────────────────────────┘

Custom Setup shows editable configuration:
- Type Index Location: /settings/publicTypeIndex.ttl
- Recipe Data: /data/recipes/ [editable]
- Recipe Index: /indices/recipes/index [editable]
- Client Installations: /installations/ [editable]
- [Apply Changes] [Cancel]

If user cancels entirely: App runs with /solid-crdt-sync/recipes/ etc., 
warns about reduced interoperability with other Solid apps.
```

**Inaccessible Resources:**
When discovery finds IRIs that can't be fetched:
- **HTTP 404 (Not Found):** Remove stale entries from local cache, mark for re-discovery
- **HTTP 403 (Forbidden):** Log access control issue, continue with available data
- **HTTP 500 (Server Error):** Retry with exponential backoff, don't remove from cache

### 6.3. Merge Contract Failures

**Missing Merge Contracts:**
When `sync:isGovernedBy` references an inaccessible resource:

```
1. Attempt to fetch merge contract with retries
2. Check local cache for previously fetched contract
3. If neither available: Mark resource as non-syncable, work offline only
4. Display error to user about sync unavailability for this data type
5. Periodically retry contract fetching in background
```

**Corrupted Merge Contracts:**
When merge contract parsing fails:
- **Syntax Errors:** Mark resources as non-syncable, work offline, display error to user
- **Unknown CRDT Types:** 
  - If no local changes to property: Accept remote state ("trust remote")
  - If local changes exist: Skip property in merge, keep local value, continue syncing other properties
  - Log warning and recommend app update
- **Missing Property Mappings:** Use LWW-Register fallback based on vector clocks, log warning

**Version Conflicts:**
When different clients reference different contract versions:
- Treat `sync:isGovernedBy` as CRDT-managed property itself (see CRDT Specification for details)
- If contracts fundamentally contradict: Mark resources as non-syncable until resolved

### 6.4. Index Consistency Failures

**Shard Inconsistencies:**
When index shards contain conflicting information:

```
1. Detect inconsistency during index merge (conflicting vectorClockHash values)
2. Fetch all conflicting shards and compare vector clocks
3. Use CRDT merge logic on shard contents themselves
4. Write merged shard back to Pod
5. Log inconsistency for monitoring/debugging
```

**Missing Index Shards:**
When partition index references non-existent shards:
- **Remove stale shard references** from partition index
- **Create empty replacement shards** if write access available
- **Continue with available shards** to maintain partial functionality

**Index-Data Divergence:**
When index entries point to non-existent or modified data:
- **Validate index entries** against actual data resource vector clocks
- **Remove stale entries** during index sync
- **Rebuild index entries** for resources with updated clocks
- **Rate-limit rebuilding** to avoid performance impact

### 6.5. Authentication and Authorization

**Authentication Failures:**
- **Expired Tokens:** Attempt token refresh through authentication provider
- **Invalid Credentials:** Prompt user to re-authenticate
- **Provider Unavailable:** Use cached credentials where possible, degrade to read-only mode

**Access Control Changes:**
When resource permissions change between syncs:
- **HTTP 403 on Previously Accessible Resource:** Keep in local cache, mark as sync-blocked, inform user of access issue
- **Partial Access Loss:** Continue with accessible resources, inform user of limited functionality  
- **Permission Escalation:** Retry previously failed operations, update local capabilities

### 6.6. Data Integrity Failures

**Vector Clock Anomalies:**
- **Clock Regression:** Detect and log impossible clock decreases, reject such updates
- **Unknown Client IDs:** Preserve unknown entries as-is (no need to validate existence)
- **Massive Clock Skew:** Log warning about potential client ID collision or corruption

**RDF Parse Errors:**
When resource content is malformed:
- **Syntax Errors:** Mark resource as non-syncable, work offline only, inform user
- **Schema Violations:** Use available valid properties, log warnings for invalid ones
- **Encoding Issues:** Attempt alternative parsers, character set detection

### 6.7. Performance Degradation Handling

**Large Resource Handling:**
- **Timeout Protection:** Abort operations exceeding configurable time limits
- **Memory Pressure:** Use streaming/partial processing for oversized resources
- **Selective Sync:** Allow applications to skip problematic large resources

**High Conflict Scenarios:**
When merge operations become expensive:
- **Conflict Rate Monitoring:** Track merge complexity and warn on excessive conflicts
- **Back-pressure Mechanisms:** Slow sync rate when merge queue grows large
- **User Notification:** Inform users about sync performance issues

### 6.8. Fallback and Recovery Strategies

**Graceful Degradation:**
1. **Full Functionality:** All discovery, sync, and merge operations working
2. **Limited Discovery:** Manual resource specification, reduced auto-discovery
3. **Read-Only Mode:** Can fetch and display data, cannot sync changes
4. **Offline Mode:** Work with local cache only, queue changes for later sync

**Recovery Procedures:**
- **Sync State Reset:** Clear local cache and re-sync from Pod (last resort)
- **Selective Recovery:** Rebuild specific indices or resource caches
- **Conflict Resolution UI:** Present unresolved conflicts to users when automatic merge fails

### 6.9. Sync Blocking Granularities

Understanding the different levels at which synchronization can be blocked helps implementers design appropriate user interfaces and recovery strategies.

**Type-Level Blocking (Entire Data Type Cannot Sync):**
- **Missing Merge Contracts:** No `sync:isGovernedBy` reference can be resolved
- **Corrupted Merge Contracts:** Syntax errors make contract unparseable  
- **Missing Type Registrations:** Cannot discover where data of this type is stored
- **Authentication Failures:** No access to any resources of this type
- **User Impact:** All recipes, all shopping lists, etc. stop syncing
- **UI Suggestion:** "Recipe sync unavailable - [Details] [Retry]"

**Resource-Level Blocking (Individual Resource Cannot Sync):**
- **RDF Parse Errors:** Resource content is malformed and unparseable
- **Access Control Loss:** HTTP 403 for previously accessible specific resource
- **Network Failures:** Specific resource consistently unreachable (while others work)
- **Vector Clock Corruption:** Clock regression or invalid clock data
- **User Impact:** "Tomato Soup recipe" won't sync, but other recipes work fine
- **UI Suggestion:** "Some recipes cannot sync - [Show Details] [Work Offline]"

**Property-Level Blocking (Specific Property Cannot Sync):**
- **Unknown CRDT Types:** Property uses algorithm not supported by this client
- **Schema Violations:** Property value doesn't match expected format
- **Conflicting Contracts:** Different clients reference incompatible merge rules for same property
- **User Impact:** Recipe name syncs fine, but rating stays local-only
- **UI Suggestion:** "Recipe synced (some features require app update)"

**Implementation Guidance:**
- **Cascade Up:** Property failures don't block resource sync, resource failures don't block type sync
- **User Feedback:** Match error granularity to user mental model (they care about "recipes" more than "properties")
- **Recovery Paths:** Provide different retry/fix options based on blocking level
- **Monitoring:** Track blocking patterns to identify systemic vs. isolated issues

## 7. Benefits of this Architecture

* **True Interoperability:** By publishing the merge rules and linking to them from the data, any application can learn how to correctly and safely collaborate.
* **Developer-Centric Flexibility:** The Sync Strategy model empowers the developer to choose the right performance trade-offs for their specific data.
* **Discoverability and Resilience:** The system is highly discoverable and resilient to changes in the indexing strategy over time.
* **High Performance & Consistency:** The RDF-based sharded index and state-based sync with HTTP caching ensure that synchronization is fast and bandwidth-efficient.

## 7. Alignment with Standardization Efforts

### 7.1. Community Alignment

This architecture aligns with the goals of the **W3C CRDT for RDF Community Group**.

* **Link:** <https://www.w3.org/community/crdt4rdf/>

### 7.2. Architectural Differentiators

* **"Add-on" vs. "Database":** This framework is designed as an "add-on" library. The developer retains control over their local storage and querying logic.
* **Interoperability over Convenience:** The primary rule is that the data at rest in a Solid Pod must be clean, standard, and human-readable RDF.
* **Transparent Logic:** The merge logic is not a "black box." By using the `sync:isGovernedBy` link, the rules for conflict resolution become a public, inspectable part of the data model itself.

## 8. Outlook: Future Enhancements

The core architecture provides a robust foundation for synchronization. The following complementary layers can be built on top of it without altering the core merge logic.

* **Legacy Data Integration:** A background process to integrate existing Solid data that lacks CRDT metadata and index entries. This would:
  - Detect existing data through Type Index that isn't in framework indices
  - Initialize vector clocks for existing resources (using creation dates, file modification times)
  - Migrate data into the indexing structure
  - Add CRDT metadata to enable synchronization
  - Provide user control over which existing data to integrate vs. leave untouched

* **Proactive Access Control (WAC/ACP):** A mature version of this library should proactively check Solid's access control rules.
* **Data Validation (SHACL):** By integrating SHACL, the library can validate the merged RDF graph against a predefined "shape" before uploading it.
* **Richer Provenance (PROV-O):** By incorporating PROV-O, the library can create a rich, auditable history of changes.
