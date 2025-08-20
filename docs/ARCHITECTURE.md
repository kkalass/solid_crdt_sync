# A Framework for Local-First, Interoperable Apps on Solid

## 1. Executive Summary

This document outlines an architecture for building **local-first, collaborative, and truly interoperable applications** using Solid Pods as a synchronization backend. The core challenge is twofold: first, to enable robust, conflict-free data merging without sacrificing semantic interoperability; and second, to provide a scalable solution for building performant applications, regardless of dataset size.

The proposed solution addresses both challenges through a declarative, developer-centric framework. Unlike operation-based approaches (such as SU-Set) that synchronize individual change events, our architecture uses a **state-based CRDT model**. This means the entire state of a resource is synchronized, a choice that works seamlessly with passive storage backends like Solid Pods. To ensure data integrity, developers declaratively **link data properties to CRDT merge strategies**. To manage performance, they define a high-level **Sync Strategy** per type (full, groups, or on-demand). This approach allows the library to act as a flexible "add-on" to an existing application, rather than a monolithic database, while ensuring all data at rest on the Solid Pod is clean, standard RDF.

**Implementation Model:** The technical complexity described in this document is intended to be encapsulated within a reusable synchronization library (such as `solid-crdt-sync`). Application developers interact with a simple, declarative API while the library handles all CRDT algorithms, index management, conflict resolution, and Pod communication. The detailed specifications in this document serve as implementation guidance for library authors and reference for understanding the underlying system behavior.

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
   solid:forClass idx:FullIndex;
   solid:instance <../indices/recipes/index> ;
   idx:indexesClass schema:Recipe .

<#shopping-entries-index> a solid:TypeRegistration;
   solid:forClass idx:GroupIndexTemplate;
   solid:instance <../indices/shopping-entries/index> ;
   idx:indexesClass meal:ShoppingListEntry .

<#client-installations> a solid:TypeRegistration;
   solid:forClass crdt:ClientInstallation;
   solid:instanceContainer <../installations/> .
```

4. **Index Type Detection:** Applications query the Type Index for both data types (e.g., `schema:Recipe`) and their corresponding index types (e.g., `idx:FullIndex`), enabling automatic discovery of the complete synchronization setup.

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
        crdt:clientId <https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000>;
        crdt:clockValue "15"^^xsd:integer
    ],
    [
        crdt:clientId <https://bob.podprovider.org/installations/6ba7b810-9dad-11d1-80b4-00c04fd430c8>;
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
   # Links to the meal plan date that requires this ingredient
   meal:requiredForDate "2025-08-15"^^xsd:date .

# -- Pointers to Other Layers --
<> a foaf:Document;
   foaf:primaryTopic :it;
   # Uses a different merge contract for shopping list entries
   sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/shopping-entry-v1> ;
   idx:belongsToIndexShard <../../indices/shopping-entries/groups/2025-08/shard-0> .
```

#### 4.2.1. CRDT Merge Mechanics

The state-based merge process follows standard CRDT algorithms adapted for RDF. The merge contract specifies which CRDT type to use for each property (LWW-Register, OR-Set, etc.), and the library performs property-by-property merging using **document-level vector clocks** for causality determination. Each resource document (e.g., a complete Recipe or Shopping List Entry) has a single vector clock that tracks changes to the entire document, keeping the original resource content clean.

**Vector Clock Example:**
```turtle
<https://alice.podprovider.org/data/recipes/tomato-soup> {
  <https://alice.podprovider.org/data/recipes/tomato-soup>
    a schema:Recipe ;
    schema:name "Tomato Soup" ;
    schema:recipeIngredient "2 cans tomatoes", "1 onion" ;
    schema:recipeInstructions "Sauté onion, add tomatoes, simmer 20 minutes." .
    
  # Document-level vector clock stored separately from resource content
  <> crdt:hasClockEntry [
    crdt:clientId <https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000> ;
    crdt:clockValue "5"^^xsd:integer
  ] ;
  crdt:hasClockEntry [
    crdt:clientId <https://bob.podprovider.org/installations/6ba7b810-9dad-11d1-80b4-00c04fd430c8> ;
    crdt:clockValue "2"^^xsd:integer
  ] ;
  crdt:vectorClockHash "xxh64:abcdef1234567890" .
}
```

**Client Installation Documents**

Client IDs are IRIs that reference discoverable `crdt:ClientInstallation` documents. These documents are stored in containers found via the Type Index and provide traceability for vector clock entries.

**Example client installation at `https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000`:**

```turtle
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<> a crdt:ClientInstallation;
   crdt:belongsToWebID <../profile/card#me>;
   crdt:applicationId <https://meal-planning-app.example.org/id>;
   crdt:createdAt "2024-08-19T10:30:00Z"^^xsd:dateTime .
```

##### Client ID Generation

Applications discover the installations container through the Type Index, then generate unique installation IDs using standard UUID v4:

- **Recommended:** Use UUID v4 for guaranteed uniqueness across devices and time
- **Example:** `550e8400-e29b-41d4-a716-446655440000`

**Simple Generation:**
```
1. Generate UUID v4: uuid.v4() → "550e8400-e29b-41d4-a716-446655440000"
2. Client installation IRI: https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000
```

UUIDs provide cryptographically strong uniqueness guarantees without requiring complex generation logic or coordination between clients.

#### 4.2.2. Vocabulary Versioning and Evolution

**Vocabulary URI Strategy:**

The framework vocabularies use versioned URIs to enable backward compatibility and smooth evolution:

```turtle
# Current stable vocabularies
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .

# Future versioned vocabularies (when breaking changes are needed)
@prefix idx2: <https://kkalass.github.io/solid_crdt_sync/vocab/v2/idx#> .
@prefix sync2: <https://kkalass.github.io/solid_crdt_sync/vocab/v2/sync#> .
```

##### Merge Contract Versioning

Merge contracts use explicit versioning in their URIs to handle algorithm evolution:

```turtle
# Stable contract versions
sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v1> .
sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v2> .

# Contract evolution example
# v1: Basic LWW/OR-Set mappings
# v2: Adds new CRDT types, maintains backward compatibility
# v3: Breaking change - different property mappings
```

**When to Create New Versions:**

**DO NOT create new versions for:**
- Adding new optional properties to existing classes
- Adding new CRDT types to the vocabulary  
- Adding new classes that don't conflict with existing ones
- Documentation or comment updates

**DO create new versions ONLY for breaking changes:**
- Changing property semantics (e.g., schema:name becomes multi-valued)
- Removing or renaming existing properties/classes
- Changing CRDT merge behavior in incompatible ways
- Altering required property constraints

**Version Numbering:**
- Use simple integer versioning: `recipe-v1`, `recipe-v2`, `recipe-v3`
- **Never use semantic versioning** like `recipe-v1.1.1` - this creates confusion about compatibility

**Compatibility Strategy:**
- **Backward compatible changes:** Keep same version number, clients ignore unknown properties
- **Breaking changes:** New version number, explicit migration path required
- **Client handling:** Gracefully handle unknown properties and CRDT types within same major version
- **Contract conflicts:** When clients reference different major versions, use most conservative merge approach

**Migration Process:**
1. **Deploy new vocabulary version** alongside existing one
2. **Update reference implementations** to support both versions
3. **Gradual client adoption** of new features
4. **Deprecation notices** for old versions (but never breaking compatibility)

**Detailed Algorithms:** For comprehensive merge algorithms, vector clock mechanics, and edge case handling, see the [CRDT Specification Document](CRDT-SPECIFICATION.md).

### 4.3. Layer 3: The Indexing Layer

This layer is **vital for change detection and synchronization efficiency**. It defines a convention for how data can be indexed for fast access and change monitoring. While the amount of header information stored in indices is optional (some may contain only vector clock hashes), the indexing layer itself is required for the framework to efficiently detect when resources have changed.

* **The Convention (`idx:` vocabulary):** The index is a separate set of CRDT resources that **minimally contain a lightweight hash of each document's vector clock** for change detection. Indices may optionally contain additional "header" information (like titles, dates) to support on-demand synchronization scenarios. The vocabulary uses a clear naming hierarchy to distinguish between different types of indices.

* **Structure:** The index is a two-level hierarchy of **Groups** (logical groups) and **Shards** (technical splits). Each index is self-describing.

**Index Naming Hierarchy:**

* **`idx:Index`:** The abstract base class for any sharded index that directly contains data entries.
* **`idx:FullIndex`:** A concrete, monolithic index for a dataset. It is used when a `GroupIndexTemplate` is not required. It inherits from `idx:Index`.
* **`idx:GroupIndexTemplate`:** A "rulebook" resource that defines *how* a data type is grouped. It does **not** contain data entries itself.
* **`idx:GroupIndex`:** A concrete index representing a single group (e.g., "August 2025"). It inherits from `idx:Index` and links back to its `GroupIndexTemplate` rulebook.

### 4.3.1. Sharding Algorithm Details

**Resource Assignment to Shards:**

When a new resource is created or an existing resource is updated, the framework determines which shard should contain its index entry using the configured sharding algorithm:

```
1. Extract resource IRI: https://alice.podprovider.org/data/recipes/tomato-soup
2. Apply hash function: xxhash64("https://alice.podprovider.org/data/recipes/tomato-soup") → 0x1A2B3C4D5E6F7890
3. Convert to decimal: 1883669071845588112
4. Calculate modulo: 1883669071845588112 % 2 = 0
5. Assign to shard: shard-0
```

**Consistency Guarantees:**
- The same resource always maps to the same shard (deterministic)
- Resources are distributed roughly evenly across shards  
- Shard count changes use lazy, client-side rebalancing

**Client-Side Shard Evolution:**

In Solid's decentralized context, users are not system administrators and cannot perform traditional "maintenance operations." Instead, shard count changes are handled as application upgrades with lazy migration:

**Automatic and Manual Shard Changes:**
1. **System defaults:** Framework defaults to `v1_0_0` and single shard, library authors should make these explicit in index creation
2. **Developer override (if needed):** Developer can specify major version for breaking changes (e.g., `v2_0_0`)
3. **Automatic scaling:** System increases shard count when any active shard exceeds threshold (e.g., 1000 entries)
4. **Natural progression:** 1 → 2 → 4 → 8 → 16 shards as data grows
5. **Version auto-increment:** System automatically increments middle number: `v1_0_0` → `v1_1_0` → `v1_2_0` for shard scaling
6. **Gradual deployment:** Updated configurations coexist during lazy migration period
7. **Lazy migration:** Existing entries migrate opportunistically during normal operations

**Lazy Migration Process:**
```turtle
# Index configuration shows current sharding algorithm  
<https://alice.podprovider.org/indices/recipes/index>
  idx:shardingAlgorithm [
    a idx:ModuloHashSharding ;
    idx:hashAlgorithm "xxhash64" ;
    idx:numberOfShards 4 ;           # Current configuration (auto-scaled from 1)
    idx:configVersion "1_2_0" ;      # Default v1, auto-scale 2 (1→2→4), conflict 0
    idx:autoScaleThreshold 1000      # Framework default threshold
  ] ;
  idx:hasShard 
    # Evolution: single shard → 2 shards → 4 shards
    # Legacy: <shard-mod-xxhash64-1-0-v1_0_0> (migrated out, tombstoned)
    # Legacy: <shard-mod-xxhash64-2-0-v1_1_0>, <shard-mod-xxhash64-2-1-v1_1_0> (migrated out)
    # Current shards (4-shard configuration) 
    <shard-mod-xxhash64-4-0-v1_2_0>, <shard-mod-xxhash64-4-1-v1_2_0>, 
    <shard-mod-xxhash64-4-2-v1_2_0>, <shard-mod-xxhash64-4-3-v1_2_0> .
```

**Recommended Library Implementation:**
```turtle
# When library creates new index, explicitly write defaults:
<https://alice.podprovider.org/indices/recipes/index>
  idx:shardingAlgorithm [
    a idx:ModuloHashSharding ;
    idx:hashAlgorithm "xxhash64" ;
    idx:numberOfShards 1 ;           # Explicit default
    idx:configVersion "1_0_0" ;      # Explicit default  
    idx:autoScaleThreshold 1000      # Explicit default
  ] ;
  idx:hasShard <shard-mod-xxhash64-1-0-v1_0_0> .
```

**Automatic Scaling Algorithm:**
1. **Monitor shard sizes:** During writes and sync, track entry counts in active shards
2. **Trigger scaling:** When any shard exceeds `idx:autoScaleThreshold` entries (e.g., 1000)
3. **Calculate new shard count:** Double current count (1→2→4→8→16) or use configured algorithm  
4. **Auto-increment version:** Increment scale component: `v2_0_0` → `v2_1_0` → `v2_2_0`
5. **Begin lazy migration:** Start using new shards for new entries, migrate opportunistically

**Self-Describing Shard Names:**
- Format: `shard-{algorithm}-{hash}-{totalShards}-{shardNumber}-v{major}_{scale}_{conflict}`
- Example: `shard-mod-xxhash64-4-0-v2_1_0` = modulo, xxhash64, 4 shards, shard #0, dev version 2, auto-scale 1, conflict resolution 0
- **Version Components:**
  - `major`: Developer-controlled version (increment for breaking changes)
  - `scale`: Auto-increment when system increases shard count due to size thresholds
  - `conflict`: Auto-increment for 2P-Set conflict resolution during cycles
- Benefits: Fully automated scaling with deterministic conflict resolution

**Migration Triggers (Opportunistic):**
- **During writes:** New/updated resources use current shard count, migrate existing entry if found in different shard
- **During sync:** If index entry found in non-current shard, opportunistically migrate to correct shard  
- **During cleanup (optional):** Future versions may implement background migration during idle time

**Migration Process Details:**
- **"Migrate" means:** Add entry to correct shard (using 2P-Set add), remove from incorrect shard (using 2P-Set remove)  
- **Empty shard cleanup:** When a shard becomes empty, remove it from `idx:hasShard` list (using 2P-Set remove with tombstone)
- **New installations:** Only sync shards currently listed in `idx:hasShard` - avoid downloading empty legacy shards
- **Configuration cycles:** 2→4→2 cycles work: `v1_1_0` (2 shards) → `v1_2_0` (4 shards) → `v1_3_0` (2 shards). Each version gets unique shard names avoiding 2P-Set conflicts
- **Version conflict resolution:** If attempting to add a shard name that exists in tombstones, automatically increment to next available version (e.g., v2_0_0 → v2_0_1)

**Client-Side Constraints:**
- **Limited execution time:** Migration happens in small batches to respect mobile background limits
- **Concurrent access:** Multiple clients may migrate simultaneously - use CRDT merge rules for conflicts
- **Never "finished":** Accept that some entries may remain in non-current shards indefinitely  
- **Graceful lookup:** Check all active shards in `idx:hasShard` list (empty shards are automatically tombstoned)

**Example migration:** Resource `tomato-soup` with hash `...1112` starts in legacy `shard-mod-xxhash64-2-0-v1` (1112 % 2 = 0), eventually migrates to new `shard-mod-xxhash64-4-0-v2` (1112 % 4 = 0) when accessed.

**Configuration Version Conflict Handling:**

When a client detects that `idx:configVersion` was not properly incremented, the system automatically resolves conflicts:

**Auto-Resolution Algorithm:**
1. **Detect conflict:** `shard-mod-xxhash64-2-0-v2_0_0` has tombstoned entries blocking new additions
2. **Auto-increment conflict:** Try `shard-mod-xxhash64-2-0-v2_0_1`, then `v2_0_2`, `v2_0_3`, etc.
3. **Find unused version:** Stop at first version without conflicts (no shard or entry tombstones)
4. **Update configuration:** Set `idx:configVersion` to the working version (e.g., `"2_0_1"`)
5. **Continue sync:** Proceed with new shards using the conflict-free version

**Deterministic Resolution:**
- All clients follow identical algorithm, converging on same solution
- Multiple concurrent clients will discover same working version
- Manual developer override (e.g., `v3`) takes precedence over auto-generated versions

**Version Precedence Rules:**
- `v3_0_0` > `v2_999_999` (higher major version wins)  
- `v2_2_0` > `v2_1_0` (higher scale version wins)
- `v2_1_5` > `v2_1_3` (higher conflict resolution wins)
- Lexicographic comparison: `"2_1_0"` vs `"2_0_5"` → `"2_1_0"` wins

**Benefits:**
- **Self-scaling:** System automatically increases shard count as data grows
- **Self-healing:** No manual intervention required for configuration cycles or conflicts
- **Concurrent-safe:** Multiple clients reach same conclusion independently  
- **Zero-config:** Developers need no configuration (system defaults to `v1_0_0` and 1 shard), library makes defaults explicit
- **Performance optimized:** Proactive scaling prevents performance degradation
- **No data loss:** System continues functioning instead of stopping on conflicts

**When Sharding Decisions Are Made:**
- **During writes:** Calculate shard using current numberOfShards, migrate if found in wrong location
- **During reads:** Check all active shards in `idx:hasShard` to locate entries (read-only, no migration)
- **During discovery:** Search all active shards listed in `idx:hasShard` to locate entries
- **During config changes:** Validate new shard names against tombstone list before proceeding

### 4.3.2. Multi-Application Coordination

**Index Sharing and Compatibility:**

When multiple applications work with the same data type, they must coordinate their indexing strategies to maintain interoperability:

**Discovery-First Approach:**
1. **Always discover first:** Applications query the Type Index to find existing indices before creating new ones
2. **Compatibility check:** Evaluate if discovered index meets minimum requirements (FullIndex vs GroupIndexTemplate, required `idx:indexedProperty` fields)
3. **Graceful coexistence:** If existing index is incompatible, create application-specific index without modifying the shared one

**Index Naming Conventions:**
- **Default index:** `/indices/{data-type}/index` (discovered via Type Index)
- **Application-specific:** `/indices/{data-type}/{app-name}/index` (avoid namespace conflicts)

**Example Coordination Scenario:**
```turtle
# Recipe Manager App discovers this default index
<#recipe-index> a solid:TypeRegistration;
   solid:forClass idx:FullIndex; 
   solid:instance <../indices/recipes/index> .

# Meal Planner App needs GroupIndexTemplate, so creates its own:
<#meal-planner-recipe-index> a solid:TypeRegistration;
   solid:forClass idx:GroupIndexTemplate;
   solid:instance <../indices/recipes/meal-planner/index> .
```

**Coordination Guidelines:**
- **Minimize index proliferation:** Consider if existing indices can be extended rather than creating new ones
- **Use minimal default indices:** Keep shared indices lightweight to reduce sync overhead for all applications
- **Document index purposes:** Use `rdfs:comment` to explain index design decisions

### 4.3.3. Index Creation and Bootstrap Process

**Cold Start Problem:**

When an application first encounters a Pod with no existing indices for a data type, it must create the initial indexing structure:

**Bootstrap Decision Flow:**
1. **Discovery first:** Query Type Index for existing indices of the required type
2. **If none found:** Application creates initial index based on its Sync Strategy requirements
3. **Index creation:** Create appropriate index type (FullIndex or GroupIndexTemplate) 
4. **Registration:** Add index to Type Index for future discoverability
5. **Initial population:** Scan existing data containers and populate index with current resources

**Example Bootstrap Scenario:**
```turtle
# Application discovers no recipe index exists
# Creates FullIndex for OnDemand recipe browsing
# Registers in Type Index:
<#recipe-index> a solid:TypeRegistration;
   solid:forClass idx:FullIndex;
   solid:instance <../indices/recipes/index> ;
   idx:indexesClass schema:Recipe .
```

**Who Creates Indices:**
- **First application:** The first app to work with a data type creates the default index
- **Subsequent applications:** Discover existing index and evaluate compatibility
- **Setup process:** Applications can create indices during initial Pod configuration
- **User control:** Setup dialogs allow users to approve index creation

**Bootstrap Timing:**
- **During setup:** Indices created when configuring Pod for first time
- **On first sync:** Indices created when first syncing a data type
- **Lazy creation:** Indices created when first storing a resource of that type

### 4.3.4. Indexing Conventions and Best Practices
To ensure interoperability, performance, and good citizenship within the Solid ecosystem, applications should adhere to the following conventions when working with indices:

 *   **The "Default" Index:** For each class of data (e.g., `schema:Recipe`), there is a convention for a "default" index. Applications should first attempt to discover this default index (e.g., via the user's Solid Type Index). If the discovered default index does not meet an application's specific requirements (e.g., it's a `FullIndex` but the app needs a `GroupIndexTemplate`, or it lacks necessary `indexedProperty` fields), the application **MUST NOT** modify the existing default index. Instead, it should create its own application-specific index. Modifying a shared default index can inadvertently break other applications that rely on its established structure and content.
 
 *   **Minimalism in Default Indices:** Default indices should be kept as minimal as possible. Their primary purpose is to enable basic discovery and synchronization of data resources. They should typically include only essential fields necessary for broad interoperability, such as `foaf:name` or `schema:name` (if at all), and the resource's IRI. Bloating the default index with application-specific or excessive fields increases synchronization overhead for all applications that interact with that data type.

 *   **Application-Specific Indices and "Good Citizenship":** Applications are free to create their own custom indices with additional `indexedProperty` fields to support specific UI needs, advanced search capabilities, or other application-specific functionalities. However, developers must be considerate ("good citizens") when doing so. Every time a data resource is updated, all indices that reference it must also be updated. Therefore, creating numerous application-specific indices, or indices with a large number of `indexedProperty` fields, significantly increases the synchronization burden on *all* applications that interact with that data type. Developers should carefully weigh the benefits of a custom index against the increased overhead for the entire ecosystem. 

**Example 1: A `GroupIndexTemplate` at `https://alice.podprovider.org/indices/shopping-entries/index`**
This resource is the "rulebook" for all shopping list entry groups in our meal planning application. Note that it has no `idx:indexedProperty` because shopping entries are typically loaded in full groups, requiring only vector clock hashes for change detection.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix schema: <https://schema.org/> .
@prefix mappings: <https://kkalass.github.io/solid_crdt_sync/mappings/> .
@prefix meal: <https://example.org/vocab/meal#> .

<> a idx:GroupIndexTemplate;
   idx:indexesClass meal:ShoppingListEntry;
   # No idx:indexedProperty needed - groups are loaded fully
   # A default sharding algorithm for all group indices created under this rule.
   # Resources within each group are assigned to shards using: hash(resourceIRI) % numberOfShards
   idx:shardingAlgorithm [
     a idx:ModuloHashSharding;
     idx:hashAlgorithm "xxhash64";
     idx:numberOfShards 4
   ] ;
   sync:isGovernedBy mappings:group-index-template-v1;

   # The declarative rule for how to assign items to group indices.
   idx:groupedBy [
     a idx:GroupingRule;
     idx:sourceProperty meal:requiredForDate;  # Group by meal plan date
     idx:format "YYYY-MM";
     idx:groupTemplate "groups/{value}/index"
   ].
```

**Example 2: A `GroupIndex` document at `https://alice.podprovider.org/indices/shopping-entries/groups/2025-08/index`**
This is a concrete index for shopping list entries from August 2025 meal plans.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .

<> a idx:GroupIndex;
   sync:isGovernedBy mappings:group-index-v1;
   # Back-link to the rulebook.
   idx:basedOn <../../index>;
   # It inherits its configuration from the GroupIndexTemplate rulebook.
   # Since the template has no idx:indexedProperty defined, this group's shards
   # will contain only resource IRIs and vector clock hashes (no header data).
   # It has its own list of active shards, which are sibling documents.
   idx:hasShard <shard-0>, <shard-1>, ... .
```

**Example: A Shard Document at `https://alice.podprovider.org/indices/shopping-entries/groups/2025-08/shard-0`**
This document contains entries pointing to shopping list data resources from August 2025. Since shopping entries are typically loaded in full groups, this index contains minimal header information.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix mappings: <https://kkalass.github.io/solid_crdt_sync/mappings/> .

<> a idx:Shard;
   sync:isGovernedBy mappings:shard-v1;
   idx:isShardOf <index>; # Back-link to its GroupIndex document
   idx:containsEntry [
     idx:resource <../../../../data/shopping-entries/item-001>;
     crdt:vectorClockHash "xxh64:abcdef1234567890"
   ],
   [
     idx:resource <../../../../data/shopping-entries/item-002>;
     crdt:vectorClockHash "xxh64:fedcba9876543210"
   ].
```

**Example: A Recipe Index for OnDemand Sync at `https://alice.podprovider.org/indices/recipes/index`**
This is a `FullIndex` for Alice's recipe collection, configured for OnDemand synchronization to enable recipe browsing.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix schema: <https://schema.org/> .
@prefix mappings: <https://kkalass.github.io/solid_crdt_sync/mappings/> .

<> a idx:FullIndex;
   idx:indexesClass schema:Recipe;
   # Include properties needed for recipe browsing UI
   idx:indexedProperty schema:name, schema:keywords, schema:totalTime;
   # Default sharding for the recipe collection
   # Resources are assigned to shards using: hash(resourceIRI) % numberOfShards
   idx:shardingAlgorithm [
     a idx:ModuloHashSharding;
     idx:hashAlgorithm "xxhash64";
     idx:numberOfShards 2
   ];
   sync:isGovernedBy mappings:full-index-v1;
   # List of active shards containing recipe entries
   idx:hasShard <shard-0>, <shard-1> .
```

**Example: A Recipe Index Shard for OnDemand Sync at `https://alice.podprovider.org/indices/recipes/shard-0`**
This document contains entries for recipe resources. Since recipes are used with OnDemand sync, the index includes header information to support browsing without loading full recipe data.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix schema: <https://schema.org/> .
@prefix mappings: <https://kkalass.github.io/solid_crdt_sync/mappings/> .

<> a idx:Shard;
   sync:isGovernedBy mappings:shard-v1;
   idx:isShardOf <index>;
   idx:containsEntry [
     idx:resource <../../data/recipes/tomato-soup>;
     schema:name "Tomato Basil Soup";
     schema:keywords "vegan", "soup";
     schema:totalTime "PT30M";
     crdt:vectorClockHash "xxh64:abcdef1234567890"
   ],
   [
     idx:resource <../../data/recipes/pasta-carbonara>;
     schema:name "Pasta Carbonara";
     schema:keywords "pasta", "italian";
     schema:totalTime "PT20M";
     crdt:vectorClockHash "xxh64:fedcba9876543210"
   ].
```

### 4.4. Layer 4: The Sync Strategy

This is the client-side layer where the application developer configures how to synchronize data. The framework balances **discovery** (finding existing Pod configuration) with **developer intent** (application requirements). Developers declare their preferred sync approach, and the framework either uses discovered compatible indices or creates new ones as needed.

#### 4.4.1. Decision 1: Index Structure

This decision determines how data is organized and indexed in the Pod.

**FullIndex (Monolithic):**
*   Single index covering entire dataset
*   Good for bounded, searchable collections
*   Examples: Personal recipes, document library, contact list

**GroupIndexTemplate (Grouped):**
*   Data split into logical groups via GroupingRule  
*   Good for unbounded or naturally-grouped data
*   Examples: Shopping entries by month, financial transactions by year

**Framework Discovery Process:**
1. **Developer declares data pattern:** "I have recipe data that needs to be searchable"
2. **Framework discovers:** Checks Type Index for existing recipe indices  
3. **Compatibility evaluation:** Does discovered index structure meet data pattern needs?
4. **Resolution:** Use compatible index OR create new index with appropriate structure

#### 4.4.2. Decision 2: Sync Timing

This decision determines when and how much data gets loaded from the Pod.

**Full Data Sync:**
*   Downloads index AND immediately fetches all resource data
*   Good for small datasets that are frequently accessed
*   Examples: User settings, small contact lists, preferences

**On-Demand Sync (Index-Only):**
*   Downloads only index initially (provides headers/metadata)
*   Fetches full resource data only when explicitly requested  
*   Good for large datasets or browse-then-load workflows
*   Examples: Large recipe collections, document libraries, photo albums

#### 4.4.3. Common Strategies

The named sync strategies combine the two decisions above:

| Strategy | Index Structure | Sync Timing | Use Case |
|----------|----------------|-------------|----------|
| **`FullSync`** | FullIndex | Full Data Sync | Small, frequently-accessed datasets |
| **`GroupedSync`** | GroupIndexTemplate | Full Data Sync | Time-series data with active groups |
| **`OnDemandSync`** | FullIndex OR GroupIndexTemplate | On-Demand Sync | Large collections, browse-then-load |

**Examples:**
*   **FullSync:** User preferences, small contact lists → FullIndex + immediate data loading
*   **GroupedSync:** Shopping entries, activity logs → GroupIndexTemplate + immediate data for subscribed groups  
*   **OnDemandSync:** Recipe collections, document libraries → Any index + headers-only until requested

## 5. Synchronization Workflow

The synchronization process is governed by the **Sync Strategy** that the developer chooses.

1.  **Index Selection:** The application chooses which indices to sync based on its needs. For GroupedSync, this means subscribing to specific groups (e.g., "2025-08" for August shopping entries). For FullSync/OnDemandSync, this means syncing the entire FullIndex.
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

1. Check WebID Profile Document for solid:publicTypeIndex
2. If found, query Type Index for required data types (schema:Recipe, idx:FullIndex, crdt:ClientInstallation, etc.)
3. Collect all missing/required configuration:
   - Missing Type Index entirely
   - Missing Type Registrations for data types
   - Missing Type Registrations for indices  
   - Missing Type Registrations for client installations
4. If any configuration is missing: Display single comprehensive "Pod Setup Dialog"
5. User chooses approach:
   1. "Automatic Setup" - Configure Pod with standard paths automatically
   2. "Custom Setup" - Review and modify proposed Profile/Type Index changes before applying
6. If user cancels: Run with hardcoded default paths, warn about reduced interoperability


**Setup Dialog Design Principles:**

- **Explicit Consent:** Never modify Pod configuration without user permission
- **Progressive Disclosure:** Automatic Setup shields users from complexity, Custom Setup provides full control
- **Clear Options:** Two main paths - trust the app or customize the details
- **Graceful Fallback:** Always offer alternative approaches if user declines configuration changes
- **Online-Only Operation:** Pod configuration modifications require network connectivity (not CRDT-compatible)

**Example Setup Dialog Flow:**

**Initial Setup Dialog:**
- **Title:** "Pod Setup Required"  
- **Message:** "This app needs to configure data storage in your Solid Pod to enable synchronization."
- **Options:**
  - ○ **Automatic Setup** - Use standard Solid paths (recommended)
  - ○ **Custom Setup** - Review and customize paths
- **Actions:** [Continue] [Cancel]

**Custom Setup Details (if chosen):**
- Type Index Location: `/settings/publicTypeIndex.ttl`
- Recipe Data: `/data/recipes/` [editable]
- Recipe Index: `/indices/recipes/index` [editable]  
- Client Installations: `/installations/` [editable]
- **Actions:** [Apply Changes] [Cancel]

**Fallback Behavior (if user cancels entirely):**
App runs with fallback paths like `/solid-crdt-sync/recipes/` and warns about reduced interoperability with other Solid apps.

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
When group index references non-existent shards:
- **Remove stale shard references** from group index
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
- **Provider Unavailable:** Skip sync operations, continue working with local data and incrementing vector clocks for offline changes

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
- **Error Resolution UI:** Present merge contract failures or data corruption issues requiring user intervention (CRDT merges themselves never fail)

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

## 8. Alignment with Standardization Efforts

### 8.1. Community Alignment

This architecture aligns with the goals of the **W3C CRDT for RDF Community Group**.

* **Link:** <https://www.w3.org/community/crdt4rdf/>

### 8.2. Architectural Differentiators

* **"Add-on" vs. "Database":** This framework is designed as an "add-on" library. The developer retains control over their local storage and querying logic.
* **Interoperability over Convenience:** The primary rule is that the data at rest in a Solid Pod must be clean, standard, and human-readable RDF.
* **Transparent Logic:** The merge logic is not a "black box." By using the `sync:isGovernedBy` link, the rules for conflict resolution become a public, inspectable part of the data model itself.

## 9. Outlook: Future Enhancements

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
