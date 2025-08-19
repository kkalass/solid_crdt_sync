# A Framework for Local-First, Interoperable Apps on Solid

## 1. Executive Summary

This document outlines an architecture for building **local-first, collaborative, and truly interoperable applications** using Solid Pods as a synchronization backend. The core challenge is twofold: first, to enable robust, conflict-free data merging without sacrificing semantic interoperability; and second, to provide a scalable solution for building performant applications, regardless of dataset size.

The proposed solution addresses both challenges through a declarative, developer-centric framework. Unlike operation-based approaches (such as SU-Set) that synchronize individual change events, our architecture uses a **state-based CRDT model**. This means the entire state of a resource is synchronized, a choice that works seamlessly with passive storage backends like Solid Pods. To ensure data integrity, developers declaratively **link data properties to CRDT merge strategies**. To manage performance, they define a high-level **Sync Strategy** per type (full, partitioned, or on-demand). This approach allows the library to act as a flexible "add-on" to an existing application, rather than a monolithic database, while ensuring all data at rest on the Solid Pod is clean, standard RDF.

## 2. Core Principles

* **Local-First:** The application must be fully functional offline, working primarily with data cached on the device. To ensure this principle remains practical for large datasets, the architecture supports optional partial sync strategies. This allows an application to work with a local, consistent cache of the *relevant* data, maintaining speed and offline availability without requiring a full data download.

* **True Interoperability:** The data is clean, standard RDF. It becomes fully interoperable by linking to a public "ruleset" that defines how to collaborate on it.

* **Declarative Merge Behavior:** Developers define the merge behavior for each piece of data by declaratively linking its properties to well-defined **state-based** CRDT types (e.g., `LWW-Register`, `OR-Set`). This is done in a **public, discoverable rules file**, abstracting away the complexity of the underlying algorithms. This state-based approach is fundamental to the architecture's design as it works seamlessly with passive storage backends.

* **Discoverability:** The system is designed to be self-describing. Applications can discover the location of data through the user's Solid Type Index. From a single data resource, a client can then discover its merge rules (`sync:isGovernedBy`) and the specific index shard it belongs to (`idx:belongsToIndex`), enabling any application to learn how to correctly and safely collaborate on the data without prior knowledge.

* **Decentralized & Server-Agnostic:** The Solid Pod acts as a simple, passive storage bucket. All synchronization logic resides within the client-side library.

## 3. Architectural Layers

The architecture is composed of four distinct layers, moving from the fundamental structure of the data to the high-level strategies used by an application.

### 3.1. Layer 1: The Data Resource

This layer defines the atomic unit of data: a single, self-contained RDF resource. Its primary purpose is to describe a "thing" (like a recipe) using standard vocabularies.

* **Format:** Data is stored as a single RDF resource. It uses a fragment identifier (e.g., `#it`) to distinguish the "thing" being described from the document that describes it.

* **Vocabulary:** The primary data uses well-known public or custom vocabularies (e.g., `schema.org`).

* **Structure:** The resource is clean and focused on the data's payload. It contains pointers to the other architectural layers. For a clean separation of concerns, it is recommended to store data and indices in separate top-level containers (e.g., `/data/` and `/indices/`). However, a compliant client must always use the Solid Type Index as the definitive source for discovering these locations, as a user may choose to configure different paths.

**Example: A resource at `/data/recipes/123`**
This file lives in the users pod and its main job is to describe the recipe. The crucial `idx:belongsToIndex` now points to a specific shard.

```turtle
@prefix schema: <https://schema.org/> .
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix : <#> .

# -- The "Thing" Itself (The Payload) --
:it a schema:Recipe;
   schema:name "Tomato Soup" ;
   schema:keywords "vegan" .

# -- Pointers to Other Layers --
<> a foaf:Document;
   foaf:primaryTopic :it;
   # Pointer to the Merge Contract (Layer 2)
   sync:isGovernedBy <https://kkalass.github.io/recipe-manager/crdt-mappings/recipe-v1> ;
   # Pointer to the specific index shard this resource belongs to.
   idx:belongsToIndex <../../indices/recipes/shard-0> .
```

### 3.2. Layer 2: The Merge Contract

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
     [ sync:property schema:keywords; crdt:mergeWith crdt:OR_Set ].
```

**Example: The Mechanics embedded in `/data/recipes/123`**
This shows the full data resource with the CRDT mechanics included.

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

### 3.3. Layer 3: The Indexing Layer

This is an optional but powerful performance and discovery layer. It defines a convention for how data can be indexed for fast access.

* **The Convention (`idx:` vocabulary):** The index is a separate set of CRDT resources that contain "header" information and a **lightweight hash of each resource's vector clock**. The vocabulary uses a clear naming hierarchy to distinguish between different types of indices.

* **Structure:** The index is a two-level hierarchy of **Partitions** (logical groups) and **Shards** (technical splits). Each index is self-describing.

**Index Naming Hierarchy:**

* **`idx:Index`:** The abstract base class for any sharded index that directly contains data entries.
* **`idx:RootIndex`:** A concrete, monolithic index for a dataset. It is used when a `PartitionedIndex` is not required. It inherits from `idx:Index`.
* **`idx:PartitionedIndex`:** A "rulebook" resource that defines *how* a data type is partitioned. It does **not** contain data entries itself.
* **`idx:Partition`:** A concrete index representing a single partition (e.g., "August 2025"). It inherits from `idx:Index` and links back to its `PartitionedIndex` rulebook.

**Example 1: A `PartitionedIndex` at `/indices/shopping-entries/index`**
This file is the "rulebook" for all shopping entry partitions.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix schema: <https://schema.org/> .
@prefix mappings: <https://kkalass.github.io/solid_crdt_sync/mappings/> .

<> a idx:PartitionedIndex;
   idx:indexesClass schema:ListItem;
   idx:indexedProperty schema:name;
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
     idx:sourceProperty schema:dateCreated;
     idx:format "YYYY/MM";
     idx:partitionTemplate "partitions/{value}/index"
   ].
```

**Example 2: A `Partition` document at `/indices/shopping-entries/partitions/2025-08/index`**
This is a concrete index for a single month, containing data entries.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .

<> a idx:Partition;
   # Back-link to the rulebook.
   idx:isPartitionOf <../../index>;
   # It inherits its configuration (indexed properties, etc.) from the rulebook.
   # It has its own list of active shards, which are sibling documents.
   idx:hasShard <shard-0>, <shard-1>, ... .
```

### 3.4. Layer 4: The Sync Strategy

This is the client-side layer where the application developer makes choices about how to synchronize data. The architecture provides flexibility by separating two key decisions: the **Indexing Strategy** (how data is organized on the Pod) and the **Sync Behavior** (what the app syncs by default).

#### 3.4.1. Decision 1: Indexing Strategy

This decision depends on the expected size and structure of the dataset.

*   **Monolithic Index (`idx:RootIndex`):** A single, global index is used for the entire dataset. This is suitable for small to medium-sized datasets where a complete list of all items is needed (e.g., a user's contacts).
*   **Partitioned Index (`idx:PartitionedIndex`):** The index is broken into smaller, logical chunks, or partitions (e.g., by date, by category). This is the right choice for very large or time-series datasets where a full index would be too large and inefficient (e.g., chat messages, sensor data).

#### 3.4.2. Decision 2: Sync Behavior

This decision depends on the application's use case and performance requirements.

*   **Full Data Sync:** The application downloads the relevant index (or index partition) and then immediately fetches the full data for all resources listed in it. This is useful when the application needs the complete data to function.
*   **On-Demand Sync (Index-Only):** The application *only* downloads the index by default. This provides the app with a lightweight list of "headers" (e.g., IRI, title). The full data for a specific resource is only fetched when the application explicitly requests it (e.g., when a user clicks on an item). This is ideal for improving initial load times and reducing bandwidth usage.

#### 3.4.3. Common Strategies

The named sync strategies are simply convenient bundles of these two decisions:

*   **`FullSync`:** A **Full Data Sync** using a **Monolithic Index**.
*   **`PartitionedSync`:** A **Full Data Sync** using a **Partitioned Index**. The application subscribes to specific partitions.
*   **`OnDemandSync`:** An **On-Demand (Index-Only) Sync** using a **Monolithic Index**.

It's also possible to perform an On-Demand sync on a partitioned index, giving the developer fine-grained control over performance for massive, partitioned datasets.

## 4. Synchronization Workflow

The synchronization process is governed by the **Sync Strategy** that the developer chooses.

1.  **Subscription:** The application explicitly tells the library what to sync (e.g., `subscribeToIndex("/indices/shopping-entries/partitions/2025-08")`).
2.  **Efficient Index Discovery:** The library fetches the appropriate root index, reads its `idx:hasShard` list, and then synchronizes only the active shards.
3.  **App Notification (`onIndexUpdate`):** The library notifies the application with the list of headers from the synchronized shards.
4.  **Developer Control:** The developer uses the header list to populate a UI and decide when to fetch full data.
5.  **On-Demand Fetch (`fetchFromRemote`):** When the app needs the full data for an item, it calls `fetchFromRemote(iri)`.
6.  **State-based Merge:** The library downloads the full RDF resource, consults the appropriate **Merge Contract**, performs the property-by-property merge, and returns the final, merged Dart object.
7.  **App Notification (`onUpdate`):** The library notifies the application with the complete, merged object, which the developer can then save to their own local database.

## 5. Benefits of this Architecture

* **True Interoperability:** By publishing the merge rules and linking to them from the data, any application can learn how to correctly and safely collaborate.
* **Developer-Centric Flexibility:** The Sync Strategy model empowers the developer to choose the right performance trade-offs for their specific data.
* **Discoverability and Resilience:** The system is highly discoverable and resilient to changes in the indexing strategy over time.
* **High Performance & Consistency:** The RDF-based sharded index and state-based sync with HTTP caching ensure that synchronization is fast and bandwidth-efficient.

## 6. Alignment with Standardization Efforts

### 6.1. Community Alignment

This architecture aligns with the goals of the **W3C CRDT for RDF Community Group**.

* **Link:** <https://www.w3.org/community/crdt4rdf/>

### 6.2. Architectural Differentiators

* **"Add-on" vs. "Database":** This framework is designed as an "add-on" library. The developer retains control over their local storage and querying logic.
* **Interoperability over Convenience:** The primary rule is that the data at rest in a Solid Pod must be clean, standard, and human-readable RDF.
* **Transparent Logic:** The merge logic is not a "black box." By using the `sync:isGovernedBy` link, the rules for conflict resolution become a public, inspectable part of the data model itself.

## 7. Outlook: Future Enhancements

The core architecture provides a robust foundation for synchronization. The following complementary layers can be built on top of it without altering the core merge logic.

* **Proactive Access Control (WAC/ACP):** A mature version of this library should proactively check Solid's access control rules.
* **Data Validation (SHACL):** By integrating SHACL, the library can validate the merged RDF graph against a predefined "shape" before uploading it.
* **Richer Provenance (PROV-O):** By incorporating PROV-O, the library can create a rich, auditable history of changes.
