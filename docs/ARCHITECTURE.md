# A Framework for Local-First, Interoperable Apps on Solid

## 1. Executive Summary

This document outlines an architecture for building **local-first, collaborative, and truly interoperable applications** using Solid Pods as a synchronization backend. The core challenge is twofold: first, to enable robust, conflict-free data merging without sacrificing semantic interoperability; and second, to provide a scalable solution for building performant applications, regardless of dataset size.

The proposed solution addresses both challenges through a declarative, developer-centric framework. Unlike operation-based approaches (such as SU-Set) that synchronize individual change events, our architecture uses a **state-based CRDT model**. This means the entire state of a resource is synchronized, a choice that works seamlessly with passive storage backends like Solid Pods. To ensure data integrity, developers declaratively **link data properties to CRDT merge strategies**. To manage performance, they define a high-level **Sync Strategy** per type (full, groups, or on-demand). This approach allows the library to act as a flexible "add-on" to an existing application, rather than a monolithic database, while ensuring all data at rest on the Solid Pod is clean, standard RDF.

**Implementation Model:** The technical complexity described in this document is intended to be encapsulated within a reusable synchronization library (such as `solid-crdt-sync`). Application developers interact with a simple, declarative API while the library handles all CRDT algorithms, index management, conflict resolution, and Pod communication. The detailed specifications in this document serve as implementation guidance for library authors and reference for understanding the underlying system behavior.

## 2. Core Principles

* **Local-First:** The application must be fully functional offline, working primarily with data cached on the device. To ensure this principle remains practical for large datasets, the architecture supports optional partial sync strategies. This allows an application to work with a local, consistent cache of the *relevant* data, maintaining speed and offline availability without requiring a full data download.

* **CRDT Interoperability:** The data is clean, standard RDF within CRDT-managed documents (`sync:ManagedDocument`). CRDT-enabled applications achieve interoperability by discovering managed resources via `sync:managedResourceType` and following the public merge contracts that define collaboration rules.

* **Declarative Merge Behavior:** Developers define the merge behavior for each piece of data by declaratively linking its properties to well-defined **state-based** CRDT types (e.g., `LWW-Register`, `OR-Set`). This is done in a **public, discoverable rules file**, abstracting away the complexity of the underlying algorithms. The framework supports both class-scoped rules (property mappings) and global rules (predicate mappings) to provide flexibility in defining merge semantics. This state-based approach is fundamental to the architecture's design as it works seamlessly with passive storage backends.

* **Managed Resource Discoverability:** The system is designed to be self-describing for CRDT-enabled applications. Compatible applications can discover CRDT-managed resources through `sync:ManagedDocument` Type Index registrations with `sync:managedResourceType` filtering. From a managed resource, clients can discover merge rules (`sync:isGovernedBy`) and index shards (`idx:belongsToIndexShard`), enabling CRDT-enabled applications to collaborate safely while remaining invisible to incompatible applications.

* **Decentralized & Server-Agnostic:** The Solid Pod acts as a simple, passive storage bucket. All synchronization logic resides within the client-side library.

## 3. Fundamental Constraints: Resource Identity and CRDT Compatibility

### 3.1. The Blank Node Challenge

**The Fundamental RDF Constraint:** RDF blank nodes are document-instance-scoped by definition - their identifiers (like `_:b1`) only have meaning within a single document instance. The RDF specification allows different implementations to assign blank node labels arbitrarily, so the same semantic content might be labeled `_:b1` in one instance and `_:genid123` in another. When merging two document instances (e.g., local `recipe-123.ttl` and remote `recipe-123.ttl`), we cannot determine if `_:b1` in the local instance corresponds to `_:b1` in the remote instance - even if the labels match, this must be treated as incidental coincidence rather than semantic equivalence.

**Why This Matters for CRDTs:** Many CRDT operations require stable identity to function correctly:
- **OR-Set and 2P-Set** tombstones must match their target objects across documents
- **Sequence CRDTs** need to maintain consistent element ordering
- **Merge algorithms** must determine which resources represent the same entity

**The Core Problem:** Without stable identity, we cannot reliably merge RDF graphs containing blank nodes, leading to data inconsistency and CRDT convergence failures.

### 3.2. Resource Merging vs Property Merging

**Two Distinct Operations:** The framework performs two conceptually separate but coordinated operations:

1. **Resource Merging:** Combine all properties belonging to the same identified resource across documents. This is resource-scoped processing - each identified resource gets merged independently based on its own properties, regardless of how many other resources reference it.

2. **Property Merging:** Within each identified resource, apply CRDT rules (LWW-Register, OR-Set, etc.) to merge individual property values according to the resource's merge contract.

**Impact on Each Operation:** The blank node identity problem affects both merging operations differently:

**Resource Merging Impact:** When non-identifiable resources appear as subjects, we cannot determine if `_:b1` in document A corresponds to `_:b1` in document B, even if they have identical properties. The blank node labels are arbitrary serialization decisions that only have meaning within a single document instance by RDF definition. Therefore, we cannot merge their properties - each document's version must be treated atomically.

**Property Merging Impact:** When non-identifiable resources appear as object values, we cannot determine equality for CRDT operations that depend on identity. For example, OR-Set tombstones cannot match their target objects across documents because `[rdfs:label "homemade"]` in a tombstone cannot be reliably compared to `[rdfs:label "homemade"]` in the live data.

### 3.3. The Solution: Context-Based Identification

**The Key Insight:** Some blank nodes can become identifiable through the combination of context + properties, enabling safe CRDT operations within specific scopes.

**The Mechanism:** Mapping documents can declare that specific properties serve as identifiers for blank nodes using `sync:isIdentifying true` boolean flags within mapping rules (part of our `sync:` vocabulary for merge contracts). This creates stable identity within a known context scope.

**The Pattern:** `(context, identifying properties)` creates sufficient identity for safe merging within that scope. The context is the identifier of the subject containing the blank node, and identifying properties are the values of predicates with `sync:isIdentifying true` flags in their rules. With compound keys, the pattern becomes `(context, property1=value1, property2=value2, ...)`.

**Recursive Context Building:** Context identifiers can be built recursively - an identified blank node can serve as context for nested blank nodes:
- **Base case:** IRI-identified resource (e.g., `<https://alice.podprovider.org/data/recipes/tomato-soup>`)  
- **Recursive case:** Previously identified blank node (e.g., `(<https://alice.../recipes/tomato-soup>, installationId=<https://alice.../installation-123>)` identifies a clock entry)
- **Nested example:** `((<https://alice.../recipes/tomato-soup>, installationId=<https://alice.../installation-123>), subProperty=value)` could identify a blank node within a clock entry

For example, vector clock entries are identified by `(document_IRI, crdt:installationId=<full_installation_IRI>)`, where `document_IRI` is the full document IRI context and `crdt:installationId=<full_installation_IRI>` are the identifying properties.

**Implementation Details:** For detailed mapping syntax, complex identification scenarios, and implementation patterns, see [CRDT-SPECIFICATION.md section 4](CRDT-SPECIFICATION.md#4-crdt-mapping-validation). 

### 3.4. Resource Identity Taxonomy

**The Critical Three-Way Distinction:** Resources fall into three categories based on their identity characteristics:

**1. IRI-Identified Resources** (globally unique):
- **Example:** `<https://alice.podprovider.org/data/recipes/tomato-soup>`
- **Identity:** Globally unique, stable identifiers
- **CRDT Compatibility:** Safe for all CRDT operations

**2. Context-Identified Blank Nodes** (unique within context):
- **Example:** `(<https://alice.../recipes/tomato-soup>, installationId=<https://alice.../installation-123>)`
- **Identity:** Unique within specific context through identifying properties
- **CRDT Compatibility:** Safe for all CRDT operations when properly identified

**3. Non-Identifiable Resources** (no stable identity):
- **Example:** `[]` with no identifying properties or non-identifiable parent subject
- **Identity:** Document-scoped identifiers without stable identification patterns
- **CRDT Compatibility:** Limited to atomic operations (LWW-Register only)

**Determining Identifiability:** A blank node becomes identifiable when:
1. A mapping rule declares some predicate as identifying (`sync:isIdentifying true`)  
2. The blank node has that identifying predicate as one of its properties
3. The subject that references the blank node is itself identifiable (IRI or previously identified blank node)

### 3.5. CRDT Compatibility Rules

**The Critical Constraint:** Identity-dependent CRDTs (OR-Set, 2P-Set) require stable object identity to match tombstones with their targets across documents. Non-identifiable blank nodes cause these operations to fail.

**Compatibility Matrix:**
- **OR-Set, 2P-Set:** Can ONLY be used when object values are identifiable (IRIs, literals, or context-identified blank nodes)
- **LWW-Register:** Can work with non-identifiable object values (treats them atomically)

**Error Prevention:** Invalid mappings (e.g., OR-Set on non-identifiable blank nodes) must be detected during merge contract validation. Resources with invalid mappings are rejected at the resource level, allowing other resources of the same type to continue syncing.

**Detailed Examples:** For comprehensive examples of identification failures, structural equality problems, and solution patterns, see [CRDT-SPECIFICATION.md section 4](CRDT-SPECIFICATION.md#4-crdt-mapping-validation).

### 3.6. Development Implications

- **Data Modeling:** Prefer IRIs over blank nodes when identity-dependent CRDT operations are needed
- **Mapping Design:** Understand identifiability requirements for each CRDT type and use `sync:isIdentifying` appropriately
- **Validation:** Implement mapping validation to prevent invalid configurations
- **Performance:** Flat resource processing enables parallel merging optimizations

### 3.7. Implementation Consistency Checks

**Recommended Practice:** Implementing libraries should perform consistency checks during mapping generation or validation, particularly when mappings are derived from code annotations:

- **Blank Node Identification:** Verify that all blank nodes used with identity-dependent CRDTs (OR-Set, 2P-Set) have appropriate `sync:isIdentifying` declarations
- **Mapping Completeness:** Ensure all properties of a class have corresponding merge rules in the mapping contract
- **CRDT Compatibility:** Validate that each property's declared CRDT type is compatible with its object types (see section 4.2 in CRDT-SPECIFICATION.md)
- **Generator Feedback:** When using code generation from annotations, provide clear error messages identifying specific properties or patterns that need correction

**Example Generator Check:**
```dart
// Recipe class annotations
@LWWRegister() // ✅ Valid - works with any object type
String recipeName;

@ORSet() // ✅ Valid because Ingredient class declares identifying properties
List<Ingredient> ingredients; // Generator validates that Ingredient mapping exists

// Ingredient class annotations (separate from Recipe)
class Ingredient {
  @LWWRegister() 
  @IsIdentifying() // ✅ Declares this property as identifying
  String name;
  
  @LWWRegister()
  @IsIdentifying() // ✅ Compound key with name
  String unit;
  
  @LWWRegister() // ✅ Regular property, not identifying
  double amount;
}

// Generator produces mapping:
// sync:rule [ sync:predicate my:name; crdt:mergeWith crdt:LWW_Register; sync:isIdentifying true ],
//           [ sync:predicate my:unit; crdt:mergeWith crdt:LWW_Register; sync:isIdentifying true ],
//           [ sync:predicate my:amount; crdt:mergeWith crdt:LWW_Register ]
```

This constraint fundamentally shapes merge contract design, mapping validation, and the scope of supported CRDT operations.

## 4. Discovery Protocol and Application Isolation

CRDT-managed resources contain synchronization metadata and follow structural conventions that traditional RDF applications don't understand, creating a risk of data corruption. This section describes how the architecture solves this problem through discovery isolation.

CRDT-enabled applications use a modified Solid discovery approach that provides controlled access to managed resources while protecting them from incompatible applications. This isolation strategy prevents data corruption while maintaining standard Solid discoverability principles.

### 4.1. Discovery Isolation Strategy

**The Challenge:** Traditional Solid discovery would expose CRDT-managed data to all applications, risking corruption by applications that don't understand CRDT metadata or vector clocks.

**The Solution:** CRDT-managed resources are registered under `sync:ManagedDocument` in the Type Index rather than their semantic types (e.g., `schema:Recipe`). The semantic type is preserved via `sync:managedResourceType` property.

**Discovery Behavior:**
- **CRDT-enabled apps:** Query for `sync:ManagedDocument` where `sync:managedResourceType schema:Recipe` → Find managed resources
- **Traditional apps:** Query for `schema:Recipe` → Find nothing (managed data invisible)
- **Legacy data:** Remains discoverable through traditional registrations until explicitly migrated

This creates clean separation: compatible applications collaborate safely on managed data, while traditional apps work with unmanaged data, preventing cross-contamination.

### 4.2. Managed Resource Discovery Protocol

1. **Standard Discovery:** Follow WebID → Profile Document → Public Type Index ([Type Index](https://github.com/solid/type-indexes)):

**Note:** This framework currently uses only the **Public Type Index** for discoverability. This design choice enables inter-application collaboration and resource sharing but means all CRDT-managed resources are discoverable by other applications. See [FUTURE-TOPICS.md](FUTURE-TOPICS.md) for planned Private Type Index support.

```turtle
# In Profile Document at https://alice.podprovider.org/profile/card#me
@prefix solid: <http://www.w3.org/ns/solid/terms#> .

<#me> solid:publicTypeIndex </settings/publicTypeIndex.ttl> .
```

2. **Framework Resource Resolution:** From the Type Index, resolve `sync:ManagedDocument` registrations to data containers:

```turtle
# In Public Type Index at https://alice.podprovider.org/settings/publicTypeIndex.ttl
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix solid: <http://www.w3.org/ns/solid/terms#> .
@prefix schema: <https://schema.org/> .
@prefix meal: <https://example.org/vocab/meal#> .

<> a solid:TypeIndex;
   solid:hasRegistration [
      a solid:TypeRegistration;
      solid:forClass sync:ManagedDocument;
      sync:managedResourceType schema:Recipe;
      solid:instanceContainer <../data/recipes/>
   ], [
      a solid:TypeRegistration;
      solid:forClass sync:ManagedDocument;
      sync:managedResourceType meal:ShoppingListEntry;
      solid:instanceContainer <../data/shopping-entries/>
   ] .
```

3. **Specification Type Resolution:** Applications also register specification-defined types (indices and client installations) in the Type Index using the same mechanism:

```turtle
# Also in Public Type Index at https://alice.podprovider.org/settings/publicTypeIndex.ttl
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .

<> solid:hasRegistration [
      a solid:TypeRegistration;
      solid:forClass idx:FullIndex;
      solid:instanceContainer <../indices/recipes/>;
      idx:indexesClass schema:Recipe
   ], [
      a solid:TypeRegistration;
      solid:forClass idx:GroupIndexTemplate;
      solid:instanceContainer <../indices/shopping-entries/>;
      idx:indexesClass meal:ShoppingListEntry
   ], [
      a solid:TypeRegistration;
      solid:forClass crdt:ClientInstallation;
      solid:instanceContainer <../installations/>
   ] .
```

4. **Managed Resource Discovery:** CRDT-enabled applications query the Type Index for `sync:ManagedDocument` registrations with specific `sync:managedResourceType` values (e.g., `schema:Recipe`) and their corresponding index types (e.g., `idx:FullIndex`), enabling automatic discovery of the complete synchronization setup.

**Advantages:** Using TypeRegistration with `sync:ManagedDocument` and `sync:managedResourceType` enables managed resource discovery while protecting managed resources from incompatible applications. CRDT-enabled applications can find both data and indices through standard Solid mechanisms ([WebID Profile](https://www.w3.org/TR/webid/), [Type Index](https://github.com/solid/type-indexes)), while traditional applications remain unaware of CRDT-managed data, preventing accidental corruption.

## 5. Identity and Lifecycle Management

Before examining the architectural layers, we need to establish the fundamental concepts of identity management and resource lifecycle that underpin the entire framework. These concepts are used throughout all architectural layers.

### 5.1. Identity Management (Client Installation Documents)

Installation IDs are IRIs that reference discoverable `crdt:ClientInstallation` documents. These provide traceability, identity management for vector clock entries, and collaborative lifecycle management.

**Discovery and Lifecycle:**
1. **Discovery:** Applications query the Type Index for `crdt:ClientInstallation` container location
2. **ID Generation:** Generate unique UUID v4 for each application installation
3. **Registration:** Create installation document at discovered container location
4. **Usage:** Reference installation IRI in vector clock entries for all subsequent operations

**Installation Document Structure:**

```turtle
<installation-uuid> a crdt:ClientInstallation;
   crdt:belongsToWebID <../profile/card#me>;
   crdt:applicationId <https://meal-planning-app.example.org/id>;
   crdt:createdAt "2024-08-19T10:30:00Z"^^xsd:dateTime;
   crdt:lastActiveAt "2024-09-02T14:30:00Z"^^xsd:dateTime;
   sync:isGovernedBy mappings:client-installation-v1 .
```

**Installation ID Generation Process:**

**Recommended Approach (UUID v4):**
1. **Discover container:** Query Type Index for `crdt:ClientInstallation` container
2. **Generate UUID:** Use UUID v4 for cryptographically strong uniqueness
3. **Create IRI:** `{container-url}/{uuid}` 
4. **Register installation:** POST installation document to container
5. **Use in vector clocks:** Reference full installation IRI in `crdt:installationId`

**Installation Lifecycle Management:**

*Self-Managed Properties (Installation Should Only Update Its Own):*
- **`crdt:lastActiveAt`:** Installation updates its own activity timestamp
  - **Update triggers:** Sync operations
  - **Frequency:** Limited to once per hour to prevent excessive updates
  - **CRDT Algorithm:** `crdt:LWW_Register`
- **`crdt:maxInactivityPeriod`:** Installation's maximum inactivity period before tombstoning (defaults to P6M)

*Identity Properties (Set Once at Creation):*
- **`crdt:belongsToWebID`**, **`crdt:applicationId`**, **`crdt:createdAt`:** Use `crdt:Immutable`

**Installation Cleanup:**
Inactive installations are tombstoned using `crdt:deletedAt` when inactive beyond their `crdt:maxInactivityPeriod`. Other installations monitor `crdt:lastActiveAt` during collaborative operations to make tombstoning decisions.

### 5.2. Tombstoning Fundamentals

The framework uses two distinct tombstone mechanisms for different deletion scopes, both utilizing the same `crdt:deletedAt` predicate with unified OR-Set semantics.

**Two Types of Tombstones:**

**1. Resource Tombstones** (Entire Document Deletion):
- **Purpose:** Mark complete resources as deleted (e.g., deleting an entire recipe)
- **Property:** `crdt:deletedAt` with OR-Set semantics
- **Scope:** Applied to the document itself, affects the entire resource
- **Use Case:** User deletes a recipe, shopping list entry, or other complete resource

**2. Property Tombstones** (Individual Value Deletion):
- **Purpose:** Mark specific values within multi-value properties as deleted (e.g., removing "quick" from recipe keywords)
- **Property:** `crdt:deletedAt` with RDF Reification
- **Scope:** Applied to individual property values within OR-Set or 2P-Set properties
- **Use Case:** User removes a keyword, ingredient, or other individual value from a multi-value property

**Unified `crdt:deletedAt` Semantics:**

The `crdt:deletedAt` predicate is defined globally in the framework's predicate mappings with consistent OR-Set semantics across all contexts:

```turtle
# In crdt-v1.ttl deletion mappings
[ sync:predicate crdt:deletedAt; crdt:mergeWith crdt:OR_Set ]
```

**Key Properties:**
- **Multi-Value Set:** `crdt:deletedAt` is a set of deletion timestamps (OR-Set semantics)
- **State Determination:** A resource/value is considered deleted if `crdt:deletedAt` set is non-empty, undeleted if set is empty
- **Merge Behavior:** OR-Set union across all replicas - timestamps can be added (delete) or removed (undelete)
- **Undeletion Support:** Remove timestamps from the set by tombstoning the deletion timestamps themselves

**Property Tombstone Implementation:**

Individual values within multi-value properties are deleted using RDF Reification tombstones:

```turtle
# Example: Tombstone for deleted keyword "quick"
<#crdt-tombstone-f8e4d2b1> a rdf:Statement;
  rdf:subject :it;
  rdf:predicate schema:keywords;
  rdf:object "quick";
  crdt:deletedAt "2024-09-02T14:30:00Z"^^xsd:dateTime .
```

**Fragment Identifiers:** Deterministic generation using XXH64 hash of canonical N-Triple prevents conflicts while allowing collaborative tombstone creation.

**RDF Reification Choice:** RDF Reification is semantically correct for tombstones because we need to mark statements as deleted without asserting them. RDF-Star syntax would incorrectly assert the triple.

## 6. Architectural Data Layers

Having established the fundamental concepts of identity and lifecycle management, we can now examine how CRDT-managed resources are structured and organized. The architecture is composed of four distinct layers, moving from the fundamental structure of the data to the high-level strategies used by an application.

### 6.1. Layer 1: The Data Resource

This layer defines the atomic unit of data: a single, self-contained RDF resource. Its primary purpose is to describe a "thing" using standard vocabularies.

* **Format:** Data is stored as a single RDF resource. It uses a fragment identifier (e.g., `#it`) to distinguish the "thing" being described from the document that describes it.

* **Vocabulary:** The primary data uses well-known public or custom vocabularies (e.g., `schema.org`).

* **Structure:** The resource is clean and focused on the data's payload. It contains pointers to the other architectural layers. For a clean separation of concerns, it is recommended to store data and indices in separate top-level containers (e.g., `/data/` and `/indices/`). However, a compliant client must always use the Solid Type Index as the definitive source for discovering these locations, as a user may choose to configure different paths.

#### Example Application Context

The following examples demonstrate the architecture using a **meal planning application** that manages recipes, meal plans, and automatically generates shopping lists from planned meals. This integrated workflow shows how different data types can reference each other while maintaining clean separation of concerns.

**Example: A recipe resource at `https://alice.podprovider.org/data/recipes/tomato-basil-soup`**

This resource uses a semantic IRI based on the recipe name. The resource describes a recipe and contains metadata linking it to other architectural layers.

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
<> a sync:ManagedDocument;
   foaf:primaryTopic :it;
   # Pointer to the Merge Contract (Layer 2) - imports CRDT library + app mappings
   sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v1> ;
   # Pointer to the specific index shard this resource belongs to
   idx:belongsToIndexShard <../../indices/recipes/index-full-a1b2c3d4/shard-mod-xxhash64-2-0-v1_0_0> .
```

### 6.2. Layer 2: The Merge Contract

This layer defines the "how" of data integrity. It is a public, application-agnostic contract that ensures any two applications can merge the same data and arrive at the same result. It consists of two parts: the high-level rules and the low-level mechanics.

**Fundamental Principle:** All documents stored in user Pods by this framework are designed to be merged using the CRDT mechanics described in this layer. This ensures deterministic conflict resolution and maintains data consistency across distributed installations.

* **The Rules (`sync:` vocabulary):** A separate, published RDF file defines the merge behavior for a class of data by linking its properties to specific CRDT algorithms.

* **The Mechanics (`crdt:` vocabulary):** To execute the rules, low-level metadata is embedded within the data resource itself. This includes **Vector Clocks** for versioning and **Resource Tombstones** for managing deletions.

#### 6.2.1. Vector Clock Mechanics

The state-based merge process uses **document-level vector clocks** for causality determination. Each resource document has a single vector clock that tracks changes to the entire document.

**Vector Clock Structure:**

```turtle
<> crdt:hasClockEntry [
    crdt:installationId <https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000> ;
    crdt:clockValue "15"^^xsd:integer
  ] ,
  [
    crdt:installationId <https://bob.podprovider.org/installations/6ba7b810-9dad-11d1-80b4-00c04fd430c8> ;
    crdt:clockValue "8"^^xsd:integer
  ] ;
  # Pre-calculated hash for efficient index operations
  crdt:vectorClockHash "xxh64:abcdef1234567890" .
```

**CRDT Literature Mapping:** The `crdt:installationId` property corresponds to what CRDT literature typically calls "client ID" or "node ID." We use "installation" to distinguish from Solid OIDC client identifiers, which identify applications rather than specific installation instances.

**Clock Entry Identification:**

Vector clock entries are context-identified blank nodes using the pattern:
`(document_IRI, crdt:installationId=<installation_IRI>)`

**Merge Process:**
1. **Causality Determination:** Compare vector clocks to determine document causality relationships
2. **Property-by-Property Merging:** Apply CRDT rules (LWW-Register, OR-Set, etc.) to individual properties
3. **Clock Updates:** Merge vector clocks using standard vector clock union algorithms

**Detailed Algorithms:** For comprehensive merge algorithms, vector clock mechanics, and edge case handling, see [CRDT-SPECIFICATION.md](CRDT-SPECIFICATION.md).

#### 6.2.2. Standard CRDT Library Examples

**Example: Standard CRDT Library `crdt-v1`**
This library, published at a public URL by the specification authors, defines standard mappings for CRDT framework components. See [`mappings/crdt-v1.ttl`](../mappings/crdt-v1.ttl) for the complete mapping.

**Key Global Predicate Mappings:**
- **`crdt:installationId`:** Always uses LWW-Register and identifies blank nodes (vector clock entries)
- **`crdt:clockValue`:** Always uses LWW-Register for clock values
- **`crdt:deletedAt`:** Always uses OR-Set semantics for both resource and property tombstones

**Example: Application-Specific Rules File `recipe-v1`**

```turtle
@prefix schema: <https://schema.org/> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .

<> a sync:DocumentMapping;
   # Import standard CRDT library (gets statement and clock mappings automatically)
   sync:imports ( <https://kkalass.github.io/solid_crdt_sync/mappings/crdt-v1> ) ;
   
   # Define local application-specific mappings (ordered lists)
   sync:classMapping ( <#recipe> ) ;
   sync:predicateMapping ( <#nutrition> ) .

<#recipe> a sync:ClassMapping;
   sync:appliesToClass schema:Recipe;
   sync:rule
     [ sync:predicate schema:name; crdt:mergeWith crdt:LWW_Register ],
     [ sync:predicate schema:keywords; crdt:mergeWith crdt:OR_Set ],
     [ sync:predicate schema:recipeIngredient; crdt:mergeWith crdt:OR_Set ],
     [ sync:predicate schema:totalTime; crdt:mergeWith crdt:LWW_Register ] .

<#nutrition> a sync:PredicateMapping;
   sync:rule
     [ sync:predicate schema:calories; crdt:mergeWith crdt:LWW_Register; sync:isIdentifying true ],
     [ sync:predicate schema:servingSize; crdt:mergeWith crdt:LWW_Register; sync:isIdentifying true ],
     [ sync:predicate schema:protein; crdt:mergeWith crdt:LWW_Register ] .
```

**Example: Complete Resource with CRDT Mechanics**

```turtle
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix schema: <https://schema.org/> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix : <#> .

# -- The Recipe Data (Layer 1) --
:it a schema:Recipe;
   schema:name "Tomato Soup" ;
   schema:keywords "vegan", "soup" ;
   schema:recipeIngredient "2 lbs fresh tomatoes", "1 cup fresh basil" ;
   schema:totalTime "PT30M" .

# -- Document Metadata --
<> a sync:ManagedDocument;
   foaf:primaryTopic :it;
   sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v1> ;
   idx:belongsToIndexShard <../../indices/recipes/index-full-a1b2c3d4/shard-mod-xxhash64-2-0-v1_0_0> .

# -- Vector Clock (Layer 2 Mechanics) --
<> crdt:hasClockEntry [
    crdt:installationId <https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000> ;
    crdt:clockValue "15"^^xsd:integer
  ] ,
  [
    crdt:installationId <https://bob.podprovider.org/installations/6ba7b810-9dad-11d1-80b4-00c04fd430c8> ;
    crdt:clockValue "8"^^xsd:integer
  ] ;
  crdt:vectorClockHash "xxh64:abcdef1234567890" .

# -- Property Tombstone Example --
<#crdt-tombstone-f8e4d2b1> a rdf:Statement;
  rdf:subject :it;
  rdf:predicate schema:keywords;
  rdf:object "quick";
  crdt:deletedAt "2024-09-02T14:30:00Z"^^xsd:dateTime .
```

**Example: A shopping list entry at `https://alice.podprovider.org/data/shopping-entries/created/2024/08/weekly-shopping-001`**
This resource uses semantic date-based organization, reflecting when the shopping list was created (an invariant property). It shows how shopping list entries are derived from recipes in the meal planning workflow.

```turtle
@prefix schema: <https://schema.org/> .
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix meal: <https://example.org/vocab/meal#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix : <#> .

# -- The Shopping List Entry (The Payload) --
:it a meal:ShoppingListEntry;
   schema:name "2 lbs fresh tomatoes" ;
   meal:quantity "2" ;
   meal:unit "lbs" ;
   # Links to the source recipe that generated this shopping item
   meal:derivedFrom <../../../../recipes/tomato-basil-soup> ;
   # Links to the meal plan date that requires this ingredient
   meal:requiredForDate "2024-08-15"^^xsd:date ;
   schema:dateCreated "2024-08-10T10:30:00Z"^^xsd:dateTime .

# -- Pointers to Other Layers --
<> a sync:ManagedDocument;
   foaf:primaryTopic :it;
   # Uses a different DocumentMapping for shopping list entries (imports CRDT library + shopping mappings)
   sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/shopping-entry-v1> ;
   # Points to index shard within the appropriate group
   idx:belongsToIndexShard <../../../../../indices/shopping-entries/index-grouped-e5f6g7h8/groups/2024-08/shard-mod-xxhash64-4-0-v1_0_0> .
```

#### 6.2.3. Property Mapping vs. Predicate Mapping Semantics

**Critical Distinction:** The framework supports two fundamentally different scoping approaches for merge rules, each serving different purposes:

**Property Mapping (Class-Scoped Rules):**
- Rules defined within `sync:ClassMapping` apply **only within that specific class context**
- Example: In `mappings:statement-v1`, `rdf:subject` uses LWW-Register **only when within `rdf:Statement` resources**
- **Use case:** Class-specific behavior where the same predicate may have different merge semantics in different contexts

```turtle
# Property mapping: rdf:subject behavior scoped to rdf:Statement context
mappings:statement-v1 a sync:ClassMapping;
   sync:appliesToClass rdf:Statement;
   sync:rule
     [ sync:predicate rdf:subject; crdt:mergeWith crdt:LWW_Register ] .
```

**Predicate Mapping (Global Rules):**
- Rules defined within `sync:PredicateMapping` apply **globally across all contexts**
- Example: In `mappings:crdt-v1`, `crdt:installationId` **always** identifies blank nodes and **always** uses LWW-Register
- Example: In `mappings:crdt-v1`, `crdt:deletedAt` **always** uses OR-Set semantics for both resource and property tombstones
- **Use case:** Framework-level predicates with consistent behavior regardless of context

```turtle
# Predicate mapping: Global behavior across all contexts
<#clock-mappings> a sync:PredicateMapping;
   sync:rule
     [ sync:predicate crdt:installationId; crdt:mergeWith crdt:LWW_Register; sync:isIdentifying true ],
     [ sync:predicate crdt:deletedAt; crdt:mergeWith crdt:OR_Set ] .
```

**Semantic Impact:** This distinction is crucial for understanding merge behavior. A predicate like `schema:name` might use LWW-Register when within `schema:Recipe` resources but could theoretically use OR-Set when within `schema:Organization` resources if different mapping contracts specify different behaviors. However, framework predicates like `crdt:installationId` and `crdt:deletedAt` maintain consistent semantics everywhere through global predicate mappings.

#### 6.2.4. Vocabulary Versioning and Evolution

**Versioning Strategy:**

The specification uses simple integer versioning for merge contracts to handle evolution over time:

```turtle
# Merge contract versioning examples
sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v1> .
sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v2> .
```

**When to Increment Versions:**

**Backward Compatible (same version):**
- Adding new optional properties
- Adding new CRDT types to vocabulary
- Documentation updates

**Breaking Changes (new version required):**
- Changing property semantics or constraints
- Removing/renaming existing properties
- Incompatible CRDT merge behavior changes

**Client Compatibility:**
- Clients gracefully handle unknown properties within same major version
- Different contract versions use conservative merge approach
- Framework vocabularies evolve through major version URI changes when needed

### 6.3. Layer 3: The Indexing Layer

This layer is **vital for change detection and synchronization efficiency**. It defines a convention for how data can be indexed for fast access and change monitoring. While the amount of header information stored in indices is optional (some may contain only vector clock hashes), the indexing layer itself is required for the framework to efficiently detect when resources have changed.

* **The Convention (`idx:` vocabulary):** The index is a separate set of CRDT resources that **minimally contain a lightweight hash of each document's vector clock** for change detection. Indices may optionally contain additional "header" information (like titles, dates) to support on-demand synchronization scenarios. The vocabulary uses a clear naming hierarchy to distinguish between different types of indices.

* **Structure:** The index is a two-level hierarchy of **Groups** (logical groups) and **Shards** (technical splits). Each index is self-describing.

**Framework Vocabulary Hierarchy:**

**Core Index Classes:**
* **`idx:Index`:** The abstract base class for any sharded index that directly contains data entries.
* **`idx:FullIndex`:** A concrete, monolithic index for a dataset. It is used when a `GroupIndexTemplate` is not required. It inherits from `idx:Index`.
* **`idx:GroupIndexTemplate`:** A "rulebook" resource that defines *how* a data type is grouped. It does **not** contain data entries itself.
* **`idx:GroupIndex`:** A concrete index representing a single group (e.g., "August 2024"). It inherits from `idx:Index` and links back to its `GroupIndexTemplate` rulebook.
* **`idx:Shard`:** A technical partition within an index containing actual entry data.

**Framework Properties:**
* **`idx:indexesClass`:** Links index to the RDF class it indexes (e.g., schema:Recipe)
* **`idx:indexedProperty`:** Specifies which properties to include in index headers
* **`idx:hasShard`:** Links index to its component shards
* **`idx:belongsToIndexShard`:** Links data resource to its index shard
* **`idx:basedOn`:** Links GroupIndex back to its GroupIndexTemplate
* **`idx:isShardOf`:** Links shard back to its parent index
* **`idx:containsEntry`:** Contains an index entry with resource IRI and metadata
* **`idx:resource`:** Points to the actual data resource from an index entry
* **`idx:groupedBy`:** Links GroupIndexTemplate to its GroupingRule
* **`idx:sourceProperty`:** Property to extract grouping value from (in GroupingRule)
* **`idx:format`:** Format pattern for date/time values (in GroupingRule)
* **`idx:groupTemplate`:** Template for group index paths (in GroupingRule)
* **`idx:shardingAlgorithm`:** Specifies the sharding algorithm configuration
* **`idx:GroupingRule`:** Class defining how resources are assigned to groups
* **`idx:ModuloHashSharding`:** Class specifying hash-based shard distribution

**Application Vocabulary:**
Applications define their own domain-specific vocabularies (e.g., `meal:ShoppingListEntry`, `meal:requiredForDate`) which are separate from the specification vocabulary but work within the specification's structure.

#### 6.3.1. Sharding Overview

**Resource Assignment:**

Resources are assigned to shards using a deterministic hash algorithm, ensuring even distribution and consistent assignment across installations.

**Key Concepts:**
- **Automatic Scaling:** System increases shard count when size thresholds are exceeded (default: 1000 entries per shard)
- **Lazy Migration:** Existing entries migrate opportunistically during normal operations
- **Self-Describing Names:** Shard names encode algorithm, configuration, and version information
- **Conflict Resolution:** Automatic version increment resolves configuration conflicts

**Migration Process:**
Shard count changes are handled through lazy, client-side migration rather than centralized maintenance operations. This approach respects Solid's decentralized nature where users are not system administrators.

For detailed implementation guidance, including algorithms, version handling, and migration procedures, see [SHARDING.md](SHARDING.md).

#### 6.3.2. Structure-Derived Index Naming

**Coordination-Free Index Convergence:**

Multiple CRDT-enabled applications automatically converge on shared indices through deterministic structure-derived naming, eliminating coordination overhead while ensuring compatibility.

**Deterministic Naming Pattern:**
- **FullIndex:** `index-full-${SHA256(indexedClassIRI|shardingAlgorithmClass|hashAlgorithm)}/index`
- **GroupIndexTemplate:** `index-grouped-${SHA256(sourcePropertyIRI|format|groupTemplate|indexedClassIRI|shardingAlgorithmClass|hashAlgorithm)}/index`
- **Hash computation:** SHA256 with pipe separators (`|`) between all structural inputs
- **Full IRI usage:** Hash computation uses complete IRIs, not prefixed forms
- **Directory structure:** Hash-derived directory name + consistent `index` document

**Hash Computation Examples:**
```turtle
# FullIndex for recipes
# Input: "https://schema.org/Recipe|ModuloHashSharding|xxhash64"
# Directory: /indices/recipes/index-full-a1b2c3d4/
# Document: /indices/recipes/index-full-a1b2c3d4/index

# GroupIndexTemplate for shopping entries  
# Input: "https://example.org/vocab/meal#requiredForDate|YYYY-MM|groups/{value}/index|https://example.org/vocab/meal#ShoppingListEntry|ModuloHashSharding|xxhash64"
# Directory: /indices/shopping-entries/index-grouped-e5f6g7h8/
# Document: /indices/shopping-entries/index-grouped-e5f6g7h8/index
```

**Automatic Convergence Property:**
Applications with identical structural requirements generate identical index names, enabling automatic collaboration without explicit coordination.

**Discovery-First Bootstrap Flow:**
1. **Discovery:** Query Type Index for existing indices of required type and class
2. **Structural analysis:** Evaluate discovered indices for compatibility  
3. **Join or create:** Add self as reader to compatible index OR create new index with structure-derived name
4. **Collaborative population:** All installations participate in distributed population using populating shards and background processing

**Immutable vs Extendable Properties:**

**Immutable (encoded in name, enforced by `crdt:Immutable`):**
- Index type (FullIndex vs GroupIndexTemplate)
- Indexed class (`idx:indexesClass`)
- Grouping configuration (`idx:groupedBy` structure)
- Base sharding algorithm (type and hash function, but not shard count)

**Extendable (CRDT-managed, not in name):**
- `idx:indexedProperty` with per-property `idx:readBy` tracking
- Installation reader lists (`idx:readBy` on index level)
- Shard count (auto-scaling based on volume)

**Conflict Escalation:**
When installations attempt to create indices with conflicting immutable properties, the conflict forces automatic creation of differently-named indices, preventing corruption while maintaining functionality.

**Example Coordination Scenarios:**
```turtle
# App A and App B both need FullIndex for recipes with xxhash64
# → Both generate identical name: index-full-a1b2c3d4
# → Automatic sharing through convergent naming

# App C needs GroupIndexTemplate for recipes with weekly grouping  
# → Different structural hash: index-grouped-f9g0h1i2
# → Separate index to avoid incompatible structural conflicts
```

**Performance Impact Management:**
- **Write overhead awareness:** Every additional index increases write operation overhead for all installations
- **Property-level optimization:** Remove unused `idx:indexedProperty` entries when last reader is tombstoned
- **Reader list maintenance:** Tombstoned installations removed from `idx:readBy` lists, enabling index deprecation when no active readers remain

#### 6.3.3. Collaborative Bootstrap and Index Population

**Coordination-Free Bootstrap Process:**

Multiple installations automatically collaborate on index creation through structure-derived naming and CRDT-based document management.

**Bootstrap Decision Flow:**
1. **Discovery first:** Query Type Index for existing indices with compatible structural requirements
2. **Structural compatibility:** Evaluate discovered indices for exact structural match
3. **Join or create:** Add self as reader to compatible index OR create new index with deterministic name
4. **Opportunistic population:** Installation that creates index populates it from existing data containers

**Structural Compatibility Rules:**
- **Identical immutable properties:** Index type, class, grouping rule, base sharding algorithm must match exactly
- **Extendable properties:** `idx:indexedProperty` can be extended through property-level reader tracking
- **Automatic convergence:** Identical requirements generate identical names, enabling automatic sharing

**Index Population Algorithm:**

The framework uses a distributed population strategy for all index creation, providing collaborative processing and progressive availability:

**Distributed Population Strategy:**

**Universal Populating State:**
When creating any new index, it enters "populating" state with appropriate population strategy based on dataset size:

```turtle
<GroupIndexTemplate>
   idx:populationState "populating";  # LWW-Register managed
   idx:hasPopulatingShard <pop-mod-xxhash64-4-0-v1_0_0>, <pop-mod-xxhash64-4-1-v1_0_0>, 
                          <pop-mod-xxhash64-4-2-v1_0_0>, <pop-mod-xxhash64-4-3-v1_0_0> .
```

**Distributed Processing Algorithm:**
1. **Directory scan:** GET data container → list all resource IRIs
2. **Work distribution:** Each installation computes `hash(installationIRI + shardIRI)` for each populating shard
3. **Priority ordering:** Sort shards by hash value (different order per installation)
4. **Sequential processing:** Process shards in priority order until all complete
5. **Collaborative completion:** Multiple installations work simultaneously, CRDT merge resolves conflicts

**Per-Shard Processing:**
1. **Fetch current state:** GET populating shard from Pod  
2. **CRDT merge:** Merge with local processing state
3. **Check completeness:** Verify if shard needs processing
4. **Population work:** Read resources, populate both temporary + target shards
5. **Completion marking:** Set `crdt:tombstonedAt`, add to garbage collection index
6. **Upload:** PUT updated shard to Pod

**State Transition to Active:**

*LWW-Register State Machine for `idx:populationState`:*
1. **Initial State:** Index created with `idx:populationState "populating"`
2. **Completion Detection:** Installation detects all populating shards have `crdt:tombstonedAt` 
3. **State Update:** Installation attempts `idx:populationState "active"` with current vector clock
4. **Collaborative Resolution:** Multiple installations may attempt transition simultaneously
   - LWW-Register ensures deterministic convergence to "active" state
   - Vector clock comparison resolves concurrent updates
5. **Cleanup Phase:** After state transition, remove `idx:hasPopulatingShard` entries using OR-Set removal

*State Transition Requirements:*
- Only transition to "active" when ALL populating shards are tombstoned
- Use LWW-Register to prevent state regression (active → populating)
- Cleanup populating shard references only after successful state transition

**Background Population Requirements for All Index Types:**

*Universal Requirements (All Index Types):*
- **Non-blocking:** Population happens during background sync cycles, never blocks UI
- **Local-first:** Applications remain functional with partially-populated indices  
- **Mandatory progress:** Every sync cycle continues population until completion
- **Cross-installation:** All installations participate in population until finished
- **State management:** Use `idx:populationState` LWW-Register for collaborative state transitions

*FullIndex Population:*
- **Small datasets (< 1000 resources):** Direct creation and immediate state switch to "active"
  - Create index with `idx:populationState "populating"`
  - Populate target shards directly during creation
  - Switch to `idx:populationState "active"` when complete (no populating shards needed)
- **Large datasets (> 1000 resources):** Use distributed populating shards strategy
  - Create populating shards using `pop-` prefix for collaborative processing
  - Completion criteria: All populating shards tombstoned → state transition to "active"
- **Threshold decision:** Framework automatically chooses strategy based on data container size scan

*GroupIndexTemplate Population:*  
- **Template-only:** GroupIndexTemplate itself never contains data entries
- **State transition:** "populating" → "active" indicates template is ready for group creation
- **No direct population:** Individual GroupIndex instances are populated separately as needed

*GroupIndex Population:*
- **Inherits strategy:** Uses same algorithm as FullIndex but scoped to specific group
- **Group-scoped shards:** Populating shards process only resources belonging to the group
- **Independent completion:** Each group index completes population independently

#### 6.3.4. Installation Index Management and Scalability

**Scalability Challenge:** When thousands of installations exist, validating dormancy and managing reader lists becomes computationally expensive.

**Proposed Solutions:**

*Option A: Sharded Installation Index*
- Create `idx:FullIndex` for `crdt:ClientInstallation` with automatic sharding
- Enable efficient lookup and batch lifecycle validation  
- Index properties: `crdt:lastActiveAt`, `crdt:applicationId`
- Trade-off: Additional index complexity for improved performance

*Option B: Hierarchical Reader Lists*
- Group installations by application ID in reader lists
- Use nested OR-Sets: `idx:readBy` contains application IDs, applications contain installation lists
- Enables app-level dormancy detection without individual installation lookup
- Trade-off: More complex reader list management

*Option C: Lazy Dormancy Detection*
- Only validate installations when they appear in reader lists during normal operation
- Skip global dormancy scans, rely on opportunistic cleanup
- Use TTL-based caching to avoid repeated validation of same installation
- Trade-off: Slower cleanup, potential stale reader list entries

**Recommended Approach:** Start with Option C (lazy detection) for simplicity, migrate to Option A (sharded index) when installation counts exceed ~1000 per Pod.

#### 6.3.5. Pod Setup and Configuration Process

When an application first encounters a Pod, it may need to configure the Type Index and other Solid infrastructure:

**Comprehensive Setup Process:**
1. Check WebID Profile Document for solid:publicTypeIndex
2. If found, query Type Index for required managed resource registrations (sync:ManagedDocument with sync:managedResourceType schema:Recipe, idx:FullIndex, crdt:ClientInstallation, etc.)
3. Collect all missing/required configuration:
   - Missing Type Index entirely
   - Missing Type Registrations for managed data types (sync:ManagedDocument)
   - Missing Type Registrations for indices  
   - Missing Type Registrations for installations
4. If any configuration is missing: Display single comprehensive "Pod Setup Dialog"
5. User chooses approach:
   1. **"Automatic Setup"** - Configure Pod with standard paths automatically
   2. **"Custom Setup"** - Review and modify proposed Profile/Type Index changes before applying
6. If user cancels: Run with hardcoded default paths, warn about reduced interoperability

**Setup Dialog Design Principles:**
- **Explicit Consent:** Never modify Pod configuration without user permission
- **Progressive Disclosure:** Automatic Setup shields users from complexity, Custom Setup provides full control
- **Clear Options:** Two main paths - trust the app or customize the details
- **Graceful Fallback:** Always offer alternative approaches if user declines configuration changes

**Example Setup Flow:**
```
1. Discover missing Type Index registrations for sync:ManagedDocument with sync:managedResourceType schema:Recipe
2. Present setup dialog: "This app needs to configure CRDT-managed recipe storage in your Pod"
3. User selects "Automatic Setup"
4. App creates Type Index entries for managed recipes, recipe index, client installations
5. App proceeds with normal synchronization workflow
```

**Example 1: A `GroupIndexTemplate` at `https://alice.podprovider.org/indices/shopping-entries/index-grouped-e5f6g7h8/index`**
This resource is the "rulebook" for all shopping list entry groups in our meal planning application. The name hash is derived from SHA256(https://example.org/vocab/meal#requiredForDate|YYYY-MM|groups/{value}/index|https://example.org/vocab/meal#ShoppingListEntry|ModuloHashSharding|xxhash64). Note that it has no `idx:indexedProperty` because shopping entries are typically loaded in full groups, requiring only vector clock hashes for change detection.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix schema: <https://schema.org/> .
@prefix mappings: <https://kkalass.github.io/solid_crdt_sync/mappings/> .
@prefix meal: <https://example.org/vocab/meal#> .

# Note: The mappings: namespace contains CRDT merge contracts for specification components
# such as group-index-template-v1, group-index-v1, shard-v1, full-index-v1

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
     idx:sourceProperty meal:requiredForDate;  # Property to extract grouping value from
     idx:format "YYYY-MM";                     # Format pattern for date/time values  
     idx:groupTemplate "groups/{value}/index"  # Template for group index paths
   ].
```

**Example 2: A `GroupIndex` document at `https://alice.podprovider.org/indices/shopping-entries/index-grouped-e5f6g7h8/groups/2024-08/index`**
This is a concrete index for shopping list entries from August 2024 meal plans.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .

<> a idx:GroupIndex;
   sync:isGovernedBy mappings:group-index-v1;
   # Back-link to the rulebook.
   idx:basedOn <../../index-grouped-e5f6g7h8/index>;
   # Inherits configuration from GroupIndexTemplate:
   # - Sharding algorithm (ModuloHashSharding with xxhash64, 4 shards)
   # - Indexed properties (none defined, so minimal entries only)
   # - CRDT merge contract (mappings:group-index-v1)
   # Since the template has no idx:indexedProperty defined, this group's shards
   # will contain only resource IRIs and vector clock hashes (no header data).
   # It has its own list of active shards, which are sibling documents.
   idx:hasShard <shard-mod-xxhash64-4-0-v1_0_0>, <shard-mod-xxhash64-4-1-v1_0_0>, 
                <shard-mod-xxhash64-4-2-v1_0_0>, <shard-mod-xxhash64-4-3-v1_0_0> .
```

**Example: A Shard Document at `https://alice.podprovider.org/indices/shopping-entries/index-grouped-e5f6g7h8/groups/2024-08/shard-mod-xxhash64-4-0-v1_0_0`**
This document contains entries pointing to shopping list data resources from August 2024. Since shopping entries are typically loaded in full groups, this index contains minimal entries (only resource IRI and vector clock hash, no header properties).

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix mappings: <https://kkalass.github.io/solid_crdt_sync/mappings/> .

<> a idx:Shard;
   sync:isGovernedBy mappings:shard-v1;
   idx:isShardOf <index>; # Back-link to its GroupIndex document
   idx:containsEntry [
     idx:resource <../../../../data/shopping-entries/created/2024/08/weekly-shopping-001>;
     crdt:vectorClockHash "xxh64:abcdef1234567890"
   ],
   [
     idx:resource <../../../../data/shopping-entries/created/2024/08/weekly-shopping-002>;
     crdt:vectorClockHash "xxh64:fedcba9876543210"
   ].
```

**Example: A Recipe Index for OnDemand Sync at `https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4/index`**
This is a `FullIndex` for Alice's recipe collection, configured for OnDemand synchronization to enable recipe browsing. The name hash is derived from SHA256(https://schema.org/Recipe|ModuloHashSharding|xxhash64).

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
   idx:hasShard <shard-mod-xxhash64-2-0-v1_0_0>, <shard-mod-xxhash64-2-1-v1_0_0> .
```

**Example: A Recipe Index Shard for OnDemand Sync at `https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4/shard-mod-xxhash64-2-0-v1_0_0`**
This document contains entries for recipe resources. Since recipes are used with OnDemand sync, the index includes header properties (schema:name, schema:keywords, etc.) as specified in the FullIndex's `idx:indexedProperty` list to support browsing without loading full recipe data.

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
     idx:resource <../../data/recipes/tomato-basil-soup>;
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

### 6.4. Layer 4: The Sync Strategy

This is the client-side layer where the application developer configures how to synchronize data. The CRDT implementation balances **discovery** (finding existing Pod configuration) with **developer intent** (application requirements). Developers declare their preferred sync approach, and the implementation either uses discovered compatible indices or creates new ones as needed.

#### 6.4.1. Decision 1: Index Structure

This decision determines how data is organized and indexed in the Pod.

**FullIndex (Monolithic):**
*   Single index covering entire dataset
*   Good for bounded, searchable collections
*   Examples: Personal recipes, document library, contact list

**GroupIndexTemplate (Grouped):**
*   Data split into logical groups via GroupingRule  
*   Good for unbounded or naturally-grouped data
*   Examples: Shopping entries by month, financial transactions by year

**Managed Resource Discovery Process:**
1. **Developer declares data pattern:** "I have recipe data that needs to be searchable"
2. **Implementation discovers:** Checks Type Index for `sync:ManagedDocument` registrations with `sync:managedResourceType schema:Recipe` and corresponding recipe indices  
3. **Compatibility evaluation:** Does discovered index structure meet data pattern needs?
4. **Resolution:** Use compatible index OR create new index with appropriate structure

#### 6.4.2. Decision 2: Sync Timing

This decision determines when and how much data gets loaded from the Pod.

**Full Data Sync:**
*   Downloads index AND immediately fetches all resource data for the selected indices/groups
*   Good for small datasets that are frequently accessed
*   Examples: User settings, small contact lists, preferences

**On-Demand Sync (Index-Only):**
*   Downloads only index initially (provides headers/metadata)
*   Fetches full resource data only when explicitly requested  
*   Good for large datasets or browse-then-load workflows
*   Examples: Large recipe collections, document libraries, photo albums

#### 6.4.3. Common Strategies

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

## 7. Advanced Lifecycle Management

Having established the architectural layers, we now examine advanced topics that span across multiple layers and deal with the complete lifecycle management of resources, indices, and installations.

### 7.1. Framework Garbage Collection Index

**Purpose:** System-level index for tracking tombstoned resources that require proactive cleanup. This includes temporary framework resources (populating shards) and complete user data resources marked for deletion, but **not property tombstones** which are handled during sync-time processing.

**Centralized Resource Cleanup Strategy:** Rather than requiring cleanup processes to scan entire data containers looking for tombstoned resources, complete resources marked with `crdt:deletedAt` are automatically registered in this index, enabling efficient discovery and batch cleanup operations.

**Structure-Derived Naming:**
- **Path:** `/indices/framework/gc-index-${SHA256("tombstoned-resources")}/index`
- **Type:** `idx:FullIndex` with multiple indexed classes
- **Registration:** Automatic Type Index registration by framework (not application-specific)

**Indexed Resource Types:**
- **User Data Resources:** Any `sync:ManagedDocument` with `crdt:deletedAt` timestamps
- **Framework Resources:** `crdt:TombstonedShard` from completed populating operations
- **Client Installations:** `crdt:ClientInstallation` marked for cleanup after inactivity periods

**Index Configuration:**
```turtle
<gc-index-a1b2c3d4> a idx:FullIndex;
   # Index covers all tombstoned resource types
   idx:indexedProperty [
     idx:property crdt:deletedAt;          # Deletion timestamps for all resources
     idx:readBy <installation-1>, <installation-2>, <installation-3>
   ], [
     idx:property rdf:type;                # Resource type for cleanup process routing  
     idx:readBy <installation-1>, <installation-2>, <installation-3>
   ] ;
   idx:shardingAlgorithm [
     a idx:ModuloHashSharding;
     idx:hashAlgorithm "xxhash64";
     idx:numberOfShards 1
   ] ;
   idx:readBy <installation-1>, <installation-2>, <installation-3> .
```

**Resource Garbage Collection Process:**
1. **Automatic Registration:** When complete resources (documents) receive `crdt:deletedAt` timestamp, automatically add entry to GC index
2. **Periodic Cleanup:** Background processes scan GC index for tombstoned resources older than configured retention periods
3. **Type-Specific Cleanup:** Route different resource types to appropriate cleanup logic based on `rdf:type`
4. **Safe Deletion:** Remove entire resource files from Pod after verifying retention period has passed
5. **GC Index Maintenance:** Remove entries for successfully deleted resources from GC index

**Property Tombstone Exclusion:** Property tombstones (RDF Reification statements) are **not** registered in the GC index. They are cleaned during document sync operations when the containing document is processed, providing more efficient and local-first aligned cleanup.

**Cleanup Efficiency Benefits:**
- **No Container Scanning:** Cleanup processes never need to scan entire data containers
- **Batch Operations:** Process multiple tombstoned resources in single operation
- **Type-Aware Routing:** Different cleanup logic for user data vs framework resources
- **Retention Policy Enforcement:** Centralized tracking of deletion timestamps enables proper retention policy compliance

### 7.2. Retention Policies and Cleanup Configuration

The framework provides configurable retention policies for tombstoned resources, recognizing their different cleanup strategies and risk profiles.

**Cleanup Configuration Properties:**

**Resource Tombstone Configuration:**
- **`crdt:resourceTombstoneRetentionPeriod`:** Duration to retain deleted resources (recommended: P2Y)
- **`crdt:enableResourceTombstoneCleanup`:** Whether to automatically clean up resource tombstones
- **Cleanup Strategy:** Proactive cleanup via Framework Garbage Collection Index (see Section 7.1)
- **Risk:** Zombie deletions can affect recreated resources with same IRI

**Property Tombstone Configuration:**
- **`crdt:propertyTombstoneRetentionPeriod`:** Duration to retain deleted property values (recommended: P6M to P1Y)
- **`crdt:enablePropertyTombstoneCleanup`:** Whether to automatically clean up property tombstones
- **Cleanup Strategy:** Sync-time cleanup during document processing (not tracked in GC index)
- **Risk:** Deleted property values may reappear, but resource remains intact

**Configuration Hierarchy:**

**Framework Defaults Hierarchy:**
1. **Type Index defaults:** Cleanup properties on the Type Index document itself
2. **Type-specific overrides:** Individual registrations can override Type Index defaults  
3. **User control:** Framework never overwrites existing user-configured values

**Example Type Index Configuration:**
```turtle
# Type Index with framework-wide defaults
<> a solid:TypeIndex;
   # Framework adds these defaults if missing
   crdt:resourceTombstoneRetentionPeriod "P2Y"^^xsd:duration;
   crdt:enableResourceTombstoneCleanup true;
   crdt:propertyTombstoneRetentionPeriod "P6M"^^xsd:duration;
   crdt:enablePropertyTombstoneCleanup true;
   solid:hasRegistration [
      a solid:TypeRegistration;
      solid:forClass sync:ManagedDocument;
      sync:managedResourceType schema:Recipe;
      solid:instanceContainer <../data/recipes/>;
      # Override: Keep recipe resource tombstones longer
      crdt:resourceTombstoneRetentionPeriod "P3Y"^^xsd:duration;
      crdt:propertyTombstoneRetentionPeriod "P3M"^^xsd:duration
   ] .
```

**Cleanup Strategies:**

**Resource Tombstone Cleanup (Proactive):**
1. **Registration:** Complete tombstoned resources automatically registered in Framework Garbage Collection Index
2. **Discovery:** Cleanup processes scan GC index for resources older than retention period
3. **Processing:** Remove entire resource files from Pod after verifying retention requirements
4. **Efficiency:** No need to scan data containers for tombstoned resources

**Property Tombstone Cleanup (Sync-Time):**
1. **Integration:** Property tombstone cleanup happens during normal document synchronization
2. **Detection:** When syncing a document, check all property tombstones against retention configuration
3. **Local Processing:** Clean expired property tombstones as part of document merge process
4. **Benefits:** Resources not actively synced retain their tombstones (may be beneficial for long-term auditability)
5. **Trade-offs:** Only synchronized documents are cleaned, unused documents accumulate stale tombstones

### 7.3. Collaborative Index Lifecycle Management

**CRDT-Based Index Coordination:**

All index lifecycle decisions are made collaboratively through CRDT-managed installation documents and index properties, eliminating single points of failure and coordination bottlenecks.

**Property-Level Reader Tracking:**
```turtle
<> a idx:FullIndex;
   idx:indexedProperty [
     idx:property schema:name;
     idx:readBy <installation-1>, <installation-2>  # OR-Set of active readers
   ],
   [
     idx:property schema:keywords;
     idx:readBy <installation-1>  # Only one reader remaining
   ];
   idx:readBy <installation-1>, <installation-2>, <installation-3> .  # Index-level readers
```

**Index Reader Management:**

**Property Cleanup Process:**
1. **Reader removal:** When installation is tombstoned, remove from all `idx:readBy` lists
2. **Property removal:** When property has no active readers, remove from `idx:indexedProperty`
3. **Index deprecation:** When index has no active readers, set `idx:deprecatedAt`
4. **Garbage collection:** Deprecated indices stop receiving updates from write operations

**Index States and Transitions:**

*Active State:*
- **Properties:** `idx:populationState "active"`, non-empty `idx:readBy` list
- **Behavior:** Receives write updates, participates in sync operations
- **Reader management:** Installations can join/leave through `idx:readBy` OR-Set

*Deprecated State:*
- **Trigger:** Last active installation removed from `idx:readBy` (OR-Set becomes empty)
- **Properties:** `idx:deprecatedAt` timestamp set, `idx:readBy` empty
- **Behavior:** Stops receiving write updates, no active readers accessing it
- **Persistence:** Index documents and shards remain in Pod but become stale over time

*Tombstoned State (Proposed):*
- **Trigger:** Deprecated for extended period (e.g., 1 year) with no reactivation
- **Properties:** `crdt:tombstonedAt` timestamp set
- **Behavior:** Marked for garbage collection, should not be reactivated
- **Cleanup:** Framework GC index tracks for automated cleanup

**Index Reactivation Policy:**

*Deprecated Index Reactivation (Recommended):*
- **Discovery:** New installation discovers deprecated index through Type Index
- **Validation:** Check structural compatibility with current requirements
- **Reactivation:** Add self to `idx:readBy`, remove `idx:deprecatedAt` timestamp
- **Re-population required:** Index is stale, must re-enter populating state for update
  - Set `idx:populationState "populating"`
  - Create populating shards to scan for new/changed resources since deprecation
  - Detect and handle tombstoned entries that may have been missed during deprecated period
- **Stale data handling:** Deprecated period may have missed resource deletions and updates
- **Tombstone detection algorithm:**
  1. **Vector clock comparison:** Compare index entry vector clocks with actual resource vector clocks
  2. **Resource availability check:** Verify that indexed resources still exist and are accessible
  3. **Tombstone processing:** Apply any missed RDF reification tombstones from deprecation period
  4. **Entry cleanup:** Remove stale entries for deleted or moved resources

*Tombstoned Index Handling (Strict):*
- **Discovery prevention:** Tombstoned indices should be hidden from Type Index
- **Version increment required:** Must create new index with incremented version component
- **Rationale:** Prevents conflicts with cleaned-up shard references

**Configurable CRDT Tie-Breaking Framework:**

*Algorithm-Specific Behaviors:*
- **`crdt:LWW_Register`:** Standard timestamp comparison with lexicographic installation ID tie-breaking
- **`crdt:Immutable`:** No updates allowed after creation

*Framework Benefits:*
- **Explicit semantics:** Each property declares its intended collaboration model
- **Configurable per-property:** Different tie-breaking rules for different use cases
- **Backward compatibility:** Existing `crdt:LWW_Register` maps to `crdt:TimestampLWW`
- **Self-describing:** Merge behavior discoverable through vocabulary definitions

*Installation Document Specific Rules:*
- Installations control their own identity and activity metrics via `SelfOnlyLWW` and `SelfWinsLWW`
- Collaborative dormancy detection enabled through `TimestampLWW` for dormancy properties
- Framework prevents ownership conflicts while enabling collaborative lifecycle management

## 8. Synchronization Workflow

With the architectural layers defined, we can now examine how the synchronization process operates. The synchronization process is governed by the **Sync Strategy** that the developer chooses.

1.  **Index Selection:** The application chooses which indices to sync based on its needs. For GroupedSync, this means subscribing to specific groups (e.g., "2024-08" for August shopping entries). For FullSync/OnDemandSync, this means syncing the entire FullIndex.
2.  **Index Synchronization:** The library fetches the selected index, reads its `idx:hasShard` list, and synchronizes the active shards.
3.  **App Notification (`onIndexUpdate`):** The library notifies the application with the list of headers from the synchronized index.
4.  **Sync Strategy Application:** Based on the configured strategy:
     - **FullSync:** Immediately fetch all resources listed in the index
     - **OnDemandSync:** Wait for explicit resource requests
5.  **On-Demand Fetch (`fetchFromRemote`):** When needed, the app calls `fetchFromRemote("https://alice.podprovider.org/data/shopping-entries/created/2024/08/weekly-shopping-001")`.
6.  **State-based Merge:** The library downloads the full RDF resource, consults the **Merge Contract**, performs property-by-property merging, and returns the merged object.
7.  **App Notification (`onUpdate`):** The library notifies the application with the complete, merged object for local storage.

### 8.1. Concrete Workflow Example

**Scenario:** OnDemandSync for recipe collection

```javascript
// 1. Index Selection: App requests recipe synchronization
await syncLibrary.syncDataType('schema:Recipe', { strategy: 'OnDemandSync' });

// 2. Index Synchronization: Library fetches recipe index and its shards
// Internal: GET https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4
// Internal: GET https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4/shard-mod-xxhash64-2-0-v1_0_0
// Internal: GET https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4/shard-mod-xxhash64-2-1-v1_0_0

// 3. App Notification: Library provides index headers for browsing
syncLibrary.onIndexUpdate((headers) => {
  console.log('Available recipes:', headers);
  // headers = [
  //   { iri: '.../tomato-basil-soup', name: 'Tomato Basil Soup', keywords: ['vegan', 'soup'] },
  //   { iri: '.../pasta-carbonara', name: 'Pasta Carbonara', keywords: ['pasta', 'italian'] }
  // ]
});

// 4. Sync Strategy Application: OnDemandSync waits for explicit requests

// 5. On-Demand Fetch: User clicks on recipe, app requests full data
const recipe = await syncLibrary.fetchFromRemote('https://alice.podprovider.org/data/recipes/tomato-basil-soup');

// 6. State-based Merge: Library downloads resource, applies CRDT merge rules
// Internal: GET https://alice.podprovider.org/data/recipes/tomato-basil-soup
// Internal: Consult merge contract at https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v1
// Internal: Merge with local copy using LWW-Register and OR-Set algorithms

// 7. App Notification: Library provides merged recipe object
syncLibrary.onUpdate((mergedResource) => {
  console.log('Recipe ready for display:', mergedResource);
  // mergedResource = { name: 'Tomato Basil Soup', ingredients: [...], ... }
});
```

## 9. Error Handling and Resilience

While the synchronization workflow provides the ideal path for data consistency, real-world distributed systems face numerous failure modes that can disrupt this process. The architecture provides comprehensive strategies for maintaining consistency and availability despite various error conditions, ensuring the system remains robust across network failures, server outages, access control changes, and data corruption scenarios.

### 9.1. Failure Classification

**Error Granularities:**
- **Type-Level:** Entire data type cannot sync (missing merge contracts, authentication failures)
- **Resource-Level:** Individual resource blocked (parse errors, access control changes)  
- **Property-Level:** Specific property cannot sync (unknown CRDT types, schema violations)

### 9.2. Core Resilience Strategies

**Network Resilience:**
- Distinguish between systemic failures (abort entire sync) vs. resource-specific failures (skip and continue)
- Exponential backoff for systemic issues, immediate retry for individual resources
- Offline operation continues with local vector clock increments

**Discovery and Setup:**
- Comprehensive Pod setup process with user consent for configuration changes
- Graceful fallback to hardcoded paths if discovery fails
- Progressive disclosure: automatic vs. custom setup options

**Data Integrity:**
- Index inconsistency detection and automatic resolution
- CRDT merge conflict resolution at property level
- Vector clock anomaly detection and handling

### 9.3. Graceful Degradation

The system provides multiple operational modes based on error conditions:

1. **Full Functionality:** Complete discovery, sync, and merge operations
2. **Limited Discovery:** Manual resource specification, reduced auto-discovery  
3. **Read-Only Mode:** Display data but cannot sync changes
4. **Offline Mode:** Local cache only, queue changes for later sync

For comprehensive implementation guidance including specific error scenarios, recovery procedures, and user interface recommendations, see [ERROR-HANDLING.md](ERROR-HANDLING.md).

## 10. Performance Characteristics

### 10.1. Sync Strategy Performance Trade-offs

The choice of sync strategy fundamentally determines application performance characteristics:

**FullSync:**
- **Scaling:** Linear with total dataset size
- **Best for:** Small, frequently-accessed datasets (< 100 resources)
- **Limitation:** Becomes impractical beyond ~1000 resources

**GroupedSync:**
- **Scaling:** Linear with subscribed group sizes only (independent of total collection size)
- **Best for:** Time-based or logically-grouped data where users work with specific subsets
- **Key insight:** Performance depends only on groups you subscribe to, not total dataset

**OnDemandSync:**
- **Scaling:** Constant-time sync regardless of dataset size
- **Best for:** Large collections with unpredictable access patterns
- **Trade-off:** Individual resource fetches add latency to data access

### 10.2. Index-Based Change Detection

The architecture's index-based approach provides efficient incremental synchronization:

- **Cold Start:** Must download all relevant index shards (O(s) where s = number of shards)
- **Incremental Sync:** Download only changed shards through vector clock hash comparison (O(k) where k = changed shards)
- **Bandwidth Efficiency:** Index headers provide metadata without downloading full resources

### 10.3. Architecture Performance Benefits

- **Parallel Fetching:** Sharded indices enable concurrent synchronization
- **Partial Failure Resilience:** Failed shards don't block others
- **Conflict-Free Merging:** State-based CRDT approach eliminates merge conflicts
- **Offline Capability:** Applications remain functional without network connectivity

For detailed performance analysis, benchmarks, optimization strategies, and mobile considerations, see [PERFORMANCE.md](PERFORMANCE.md).

## 11. Data Organization Principles

### 11.1. Resource IRI Design and Pod Performance

**The Challenge:**
Most Pod servers (including Community Solid Server) use filesystem backends that can experience performance degradation with thousands of files in a single directory. While the framework uses sophisticated sharding for indices, data resources still need thoughtful organization.

**Fundamental Principle: IRIs Must Be Stable**
Resource IRIs are **identifiers**, not storage locations. Any organizational structure must derive from **invariant properties** of the resource that will never change. Changing IRIs breaks references and violates RDF principles.

**Recommended Approaches:**

**1. Semantic Organization (Preferred)**
Structure paths based on meaningful, invariant properties:
```turtle
# By semantic category (if immutable)
/data/recipes/cuisine/italian/pasta-carbonara
/data/recipes/cuisine/mexican/tacos-al-pastor

# By creation date (if relevant and stable)
/data/shopping-entries/created/2024/08/weekly-shopping-list-001
/data/journal-entries/created/2024/08/15/morning-reflection
```

**2. UUID-Based Distribution (For Large Datasets)**
For UUID-based identifiers, use prefix-based distribution:
```turtle
# UUID: af1e2d43-3ed4-4f5e-9876-1234567890ab
/data/resources/af/1e/af1e2d43-3ed4-4f5e-9876-1234567890ab

# Benefits: Predictable, evenly distributed, derived from invariant UUID
```

**3. Flat Structure (Small Datasets)**
For small collections (< 1000 resources), flat structure is acceptable:
```turtle
/data/recipes/tomato-soup-recipe
/data/recipes/pasta-carbonara-recipe
```

**Critical Guidelines:**
- **Never change IRIs**: Once published, IRIs are permanent identifiers
- **Derive from invariants**: Path structure must be computable from unchanging resource properties
- **Developer awareness**: Library documentations should warn developers about performance implications of flat structures at scale
- **No migration**: If you choose flat structure, accept the performance trade-offs rather than breaking IRI stability

## 12. Benefits of this Architecture

* **CRDT Interoperability:** CRDT-enabled applications achieve safe collaboration by discovering CRDT-managed resources through `sync:ManagedDocument` registrations and following published merge contracts, while remaining protected from interference by incompatible applications.
* **Developer-Centric Flexibility:** The Sync Strategy model empowers the developer to choose the right performance trade-offs for their specific data.
* **Controlled Discoverability:** The system is discoverable by CRDT-enabled applications while protecting CRDT-managed data from accidental modification by incompatible applications.
* **High Performance & Consistency:** The RDF-based sharded index and state-based sync with HTTP caching ensure that synchronization is fast and bandwidth-efficient.

## 13. Alignment with Standardization Efforts

### 13.1. Community Alignment

This architecture aligns with the goals of the **W3C CRDT for RDF Community Group**.

* **Link:** <https://www.w3.org/community/crdt4rdf/>

### 13.2. Architectural Differentiators

* **"Add-on" vs. "Database":** This specification is designed for "add-on" libraries. The developer retains control over their local storage and querying logic.
* **CRDT Interoperability over Convenience:** The primary rule is that CRDT-managed data must be clean, standard RDF within `sync:ManagedDocument` containers, enabling safe collaboration among CRDT-enabled applications while remaining protected from incompatible applications.
* **Transparent Logic:** The merge logic is not a "black box." By using the `sync:isGovernedBy` link, the rules for conflict resolution become a public, inspectable part of the data model itself.

## 14. Outlook: Future Enhancements

The core architecture provides a robust foundation for synchronization. The following complementary layers can be built on top of it without altering the core merge logic.

* **Legacy Data Import (Optional Extension):** A user-controlled import process to bring existing Solid data into framework management. This would be implemented as an optional library feature requiring explicit user consent and would include:
  - Discovery of existing data through traditional Type Index registrations (e.g., `solid:forClass schema:Recipe`)
  - One-time import creation of `sync:ManagedDocument` wrappers with `dct:source` links to preserve originals
  - Import timestamp tracking in index entries to enable incremental re-imports
  - User selection interface for choosing which legacy resources to import
  - Clear separation between imported framework-managed data and original legacy files

* **Proactive Access Control (WAC/ACP):** A mature version of this library should proactively check Solid's access control rules.
* **Data Validation (SHACL):** By integrating SHACL, the library can validate the merged RDF graph against a predefined "shape" before uploading it.
* **Richer Provenance (PROV-O):** By incorporating PROV-O, the library can create a rich, auditable history of changes.
* Usage of "time in millis since unix " in vector clocks for better tie-breaking?