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

**The Mechanism:** Mapping documents can declare that specific properties serve as identifiers for blank nodes using `sync:identifyingPredicate`. This creates stable identity within a known context scope.

**Example - Vector Clock Entries:**
```turtle
# Data: These blank nodes can be identified via crdt:clientId within vector clock context
<> crdt:hasClockEntry [
    crdt:clientId <https://alice.../installation-123> ;  # Identifying property
    crdt:clockValue "15"^^xsd:integer
] .
```

**Mapping Declaration:** The identification pattern is declared in our standard mapping document `https://kkalass.github.io/solid_crdt_sync/mappings/crdt-v1` using predicate-based mapping (since vector clock entries are typically typeless blank nodes):
```turtle
# Standard mapping for vector clock entries (typeless blank nodes)  
<#clock-mappings> a sync:PredicateMapping;
   sync:identifyingPredicate crdt:clientId ;
   sync:rule
     [ sync:predicate crdt:clientId; crdt:mergeWith crdt:LWW_Register ],
     [ sync:predicate crdt:clockValue; crdt:mergeWith crdt:LWW_Register ] .
```

**Compound Keys:** Multiple identifying properties can create compound identification:
```turtle
# Example with compound identification key for nutrition info
mappings:nutrition-mappings-v1 a sync:PredicateMapping;
   sync:identifyingPredicate schema:calories, schema:servingSize ;  # Compound key
   sync:rule
     [ sync:predicate schema:calories; crdt:mergeWith crdt:LWW_Register ],
     [ sync:predicate schema:servingSize; crdt:mergeWith crdt:LWW_Register ],
     [ sync:predicate schema:protein; crdt:mergeWith crdt:LWW_Register ] .
```

**The Pattern:** `(identifying predicate, identifying properties)` creates sufficient identity for safe merging within that scope. With compound keys, the pattern becomes `(identifying predicate, property1=value1, property2=value2, ...)`. For example, vector clock entries are identified by `(crdt:hasClockEntry, crdt:clientId=value)`.

**Multi-Subject References (Aliases):** When the same blank node is referenced by multiple subjects, it creates multiple identification paths - essentially aliases for the same entity:

**Example - Multiple Identification Paths:**
```turtle
# This blank node can be identified through multiple paths
:recipe1 schema:nutrition _:nutritionInfo .
:recipe2 schema:nutrition _:nutritionInfo .
_:nutritionInfo a schema:NutritionInformation ;
    schema:calories 250 ; 
    schema:servingSize "1 cup" .
```

**Identification Aliases:** Using the predicate-based pattern with compound key `schema:calories, schema:servingSize`, this blank node has multiple valid identifications:
- `(schema:nutrition, calories=250, servingSize="1 cup")` (from :recipe1)
- `(schema:nutrition, calories=250, servingSize="1 cup")` (from :recipe2)

In this case, both paths result in the same identification, confirming it's the same entity.

**Matching Across Documents:** For two blank nodes from different documents to be considered the same entity, **at least one of their identification aliases must match**. An identification alias is the unique combination of `(identifying predicate, identifying properties)` derived from a path that references the blank node. If a blank node in Document A and a blank node in Document B share at least one identical identification alias, the framework treats them as the same resource, enabling their properties to be merged. 

### 3.4. Identifiable vs Non-Identifiable Resources

**The Critical Taxonomy:** Now that we understand the solution mechanism, we can categorize resources based on their identifiability:

**Identifiable Resources** (safe for all CRDT operations):
- **IRI-identified resources:** Have globally unique, stable identifiers
- **Context-identified blank nodes:** Blank nodes with identifying properties declared via `sync:identifyingPredicate` in mapping documents within specific subject-predicate contexts

**Non-Identifiable Resources** (limited to atomic operations):
- **Standard blank nodes:** Document-scoped identifiers without declared identification patterns

**Determining Identifiability:** A blank node becomes identifiable when:
1. Its containing property has a mapping contract 
2. That contract includes `sync:identifyingPredicate` declarations
3. The blank node has the declared identifying property(ies)
4. The identification occurs within the specified context scope

### 3.5. When Identity-Dependent CRDTs Fail

**The Technical Problem:** Identity-dependent CRDTs (OR-Set, 2P-Set) require comparing objects across documents to determine if a tombstone matches its target. With non-identifiable objects, this comparison fails.

**Example - OR-Set with Non-Identifiable Objects:**
```turtle
# Document A: Contains blank node + its tombstone
:recipe schema:keywords [rdfs:label "homemade"; custom:priority 1] .
<#crdt-tombstone-a1b2c3d4> a rdf:Statement;
  rdf:subject :recipe;
  rdf:predicate schema:keywords;
  rdf:object [rdfs:label "homemade"; custom:priority 1];
  crdt:isDeleted true .

# Document B: Contains similar but non-identical blank node  
:recipe schema:keywords [rdfs:label "homemade"; custom:priority 2] .
```

**The Comparison Problem:** The tombstone in document A refers to `[rdfs:label "homemade"; custom:priority 1]` but document B contains `[rdfs:label "homemade"; custom:priority 2]`. Are these the same object that should be tombstoned, or different objects that should coexist?

**Without Identity:** The framework cannot definitively answer this question. Different implementations might:
- Compare structural equality (same properties/values)
- Compare partial equality (ignore some properties)
- Use heuristics based on processing order

**Result:** Inconsistent merge behavior that violates CRDT convergence guarantees.

**Why Not Structural Equality?** A tempting solution would be to declare two blank nodes equal if and only if all their properties are identical. However, this creates a subtle trap: if a blank node has naturally identifying properties (like `rdfs:label`) mixed with mutable properties (like `custom:priority`), then editing the mutable properties silently breaks tombstone matching. The deletion operation fails without error, creating hard-to-debug data inconsistencies. Therefore, this specification explicitly prohibits structural equality comparison and requires explicit identification patterns.

**Solution Path:** This particular example could potentially be made identifiable by declaring `rdfs:label` as an identifying property using `sync:identifyingPredicate` in the mapping contract for `schema:keywords` properties. However, this only works when blank nodes have stable identifying properties that don't conflict across documents.

### 3.6. CRDT Compatibility Rules

**Mapping Validation Requirements:** Now that we understand identifiability, the framework must enforce these compatibility rules for **object values** in RDF triples:

- **OR-Set, 2P-Set:** Can ONLY be used when object values are identifiable (IRIs, literals, or context-identified blank nodes)
- **LWW-Register:** Can work with non-identifiable object values (treats them atomically)

**Error Prevention:** Invalid mappings (e.g., OR-Set on non-identifiable blank nodes) must be detected during merge contract validation. Resources with invalid mappings are rejected at the resource level, allowing other resources of the same type to continue syncing. This provides users with a recovery path to locally edit or delete problematic properties before re-attempting synchronization.

### 3.7. Development Implications

- **Data Modeling:** Prefer IRIs over blank nodes when identity-dependent CRDT operations are needed
- **Mapping Design:** Understand identifiability requirements for each CRDT type and use `sync:identifyingPredicate` appropriately
- **Validation:** Implement mapping validation to prevent invalid configurations
- **Performance:** Flat resource processing enables parallel merging optimizations

This constraint fundamentally shapes merge contract design, mapping validation, and the scope of supported CRDT operations.

## 4. Discovery Protocol

Applications discover data locations through the standard Solid discovery mechanism ([Solid Protocol](https://solidproject.org/TR/protocol)), extended with index-specific resolution:

1. **Standard Discovery:** Follow WebID → Profile Document → Public Type Index ([Type Index](https://github.com/solid/type-indexes)):

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

3. **Specification Type Resolution:** Applications also register specification-defined types (indices and client installations) in the Type Index using the same mechanism:

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

**Advantages:** Using TypeRegistration for indices enables full discoverability - applications can find both data and indices through standard Solid mechanisms ([WebID Profile](https://www.w3.org/TR/webid/), [Type Index](https://github.com/solid/type-indexes)), making the architecture truly self-describing.

## 5. Architectural Layers

The architecture is composed of four distinct layers, moving from the fundamental structure of the data to the high-level strategies used by an application.

### 5.1. Layer 1: The Data Resource

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
<> a foaf:Document;
   foaf:primaryTopic :it;
   # Pointer to the Merge Contract (Layer 2) - imports CRDT library + app mappings
   sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v1> ;
   # Pointer to the specific index shard this resource belongs to
   idx:belongsToIndexShard <../../indices/recipes/shard-mod-xxhash64-2-0-v1_0_0> .
```

### 5.2. Layer 2: The Merge Contract

This layer defines the "how" of data integrity. It is a public, application-agnostic contract that ensures any two applications can merge the same data and arrive at the same result. It consists of two parts: the high-level rules and the low-level mechanics.

* **The Rules (`sync:` vocabulary):** A separate, published RDF file defines the merge behavior for a class of data by linking its properties to specific CRDT algorithms.

* **The Mechanics (`crdt:` vocabulary):** To execute the rules, low-level metadata is embedded within the data resource itself. This includes **Vector Clocks** for versioning and **RDF Reification Tombstones** for managing deletions.

**Example: Standard CRDT Library `crdt-v1`**
This library, published at a public URL by the specification authors, defines standard mappings for CRDT framework components. See [`mappings/crdt-v1.ttl`](../mappings/crdt-v1.ttl) for the complete mapping, which imports the existing [`statement-v1.ttl`](../mappings/statement-v1.ttl) for tombstone handling and defines predicate-based mappings for vector clock entries.

**Example: Application-Specific Rules File `recipe-v1`**
This file, created by application developers, imports the CRDT library and adds application-specific mappings.

```turtle
@prefix schema: <https://schema.org/> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .

<> a sync:DocumentMapping;
   # Import standard CRDT library (gets statement and clock mappings automatically)
   sync:documentMapping <https://kkalass.github.io/solid_crdt_sync/mappings/crdt-v1> ;
   
   # Define local application-specific mappings
   sync:classMapping <#recipe> ;
   sync:predicateMapping <#nutrition> .

<#recipe> a sync:ClassMapping;
   sync:appliesToClass schema:Recipe;
   sync:rule
     [ sync:predicate schema:name; crdt:mergeWith crdt:LWW_Register ],
     [ sync:predicate schema:keywords; crdt:mergeWith crdt:OR_Set ],
     [ sync:predicate schema:recipeIngredient; crdt:mergeWith crdt:OR_Set ],
     [ sync:predicate schema:totalTime; crdt:mergeWith crdt:LWW_Register ] .

<#nutrition> a sync:PredicateMapping;
   sync:identifyingPredicate schema:calories, schema:servingSize ;
   sync:rule
     [ sync:predicate schema:calories; crdt:mergeWith crdt:LWW_Register ],
     [ sync:predicate schema:servingSize; crdt:mergeWith crdt:LWW_Register ],
     [ sync:predicate schema:protein; crdt:mergeWith crdt:LWW_Register ] .
```


**Example: The Mechanics embedded in `https://alice.podprovider.org/data/recipes/tomato-basil-soup`**
This shows the full recipe resource with the CRDT mechanics included.

```turtle
# ... prefixes and primary data from Layer 1 ...

# -- CRDT Mechanics --
<> crdt:hasClockEntry [
    crdt:clientId <https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000> ;
    crdt:clockValue "15"^^xsd:integer
  ] ,
  [
    crdt:clientId <https://bob.podprovider.org/installations/6ba7b810-9dad-11d1-80b4-00c04fd430c8> ;
    crdt:clockValue "8"^^xsd:integer
  ] ;
  # A pre-calculated hash of the clock for efficient index updates
  crdt:vectorClockHash "xxh64:abcdef1234567890" .

# RDF Reification tombstone for a deleted keyword
# Note: RDF Reification is semantically correct for tombstones (vs RDF-Star which would assert the triple)
# Fragment identifier generated deterministically from the deleted triple
<#crdt-tombstone-f8e4d2b1> a rdf:Statement;
  rdf:subject :it;
  rdf:predicate schema:keywords;
  rdf:object "quick";
  crdt:isDeleted true .
```

**Example: A shopping list entry at `https://alice.podprovider.org/data/shopping-entries/created/2024/08/weekly-shopping-001`**
This resource uses semantic date-based organization, reflecting when the shopping list was created (an invariant property). It shows how shopping list entries are derived from recipes in the meal planning workflow.

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
   meal:derivedFrom <../../../../recipes/tomato-basil-soup> ;
   # Links to the meal plan date that requires this ingredient
   meal:requiredForDate "2024-08-15"^^xsd:date .

# -- Pointers to Other Layers --
<> a foaf:Document;
   foaf:primaryTopic :it;
   # Uses a different DocumentMapping for shopping list entries (imports CRDT library + shopping mappings)
   sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/shopping-entry-v1> ;
   # Points to index shard within the appropriate group
   idx:belongsToIndexShard <../../../../../indices/shopping-entries/groups/2024-08/shard-mod-xxhash64-4-0-v1_0_0> .
```

#### 5.2.1. CRDT Merge Mechanics

The state-based merge process follows standard CRDT algorithms adapted for RDF. The merge contract specifies which CRDT type to use for each property (LWW-Register, OR-Set, etc.), and the library performs property-by-property merging using **document-level vector clocks** for causality determination. Each resource document (e.g., a complete Recipe or Shopping List Entry) has a single vector clock that tracks changes to the entire document, keeping the original resource content clean.

**RDF Reification for Tombstones:**

This architecture uses **RDF Reification** to represent tombstones for deleted triples. RDF Reification is the semantically correct approach for this use case because:

- **Tombstone Semantics:** We need to mark statements as deleted without asserting them
- **RDF-Star Incompatibility:** RDF-Star syntax (`<< :it schema:keywords "deleted" >>`) would assert the triple, which is semantically incorrect for deletions
- **Reification Advantages:** RDF Reification allows us to make statements about statements without asserting the original statement
- **Implementation:** We use RDF 1.1 Reification vocabulary (`rdf:Statement`, `rdf:subject`, `rdf:predicate`, `rdf:object`) to represent deleted triples
- **Document-Level Timing:** Tombstones rely on the document-level vector clock rather than storing individual timestamps, simplifying implementation at the cost of preventing compaction

**Vector Clock Example at `https://alice.podprovider.org/data/recipes/tomato-basil-soup`:**
```turtle
@prefix schema: <https://schema.org/> .
@prefix crdt: <https://kkalass.github.io/solid_crdt_sync/vocab/crdt#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix : <#> .

# -- The Recipe Data --
:it a schema:Recipe ;
    schema:name "Tomato Soup" ;
    schema:keywords "vegan", "soup" ;
    schema:recipeIngredient "2 cans tomatoes", "1 onion" ;
    schema:recipeInstructions "Sauté onion, add tomatoes, simmer 20 minutes." ;
    schema:totalTime "PT30M" .
    
# -- Document-level Vector Clock --
<> crdt:hasClockEntry [
    crdt:clientId <https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000> ;
    crdt:clockValue "5"^^xsd:integer
  ] ,
  [
    crdt:clientId <https://bob.podprovider.org/installations/6ba7b810-9dad-11d1-80b4-00c04fd430c8> ;
    crdt:clockValue "2"^^xsd:integer
  ] ;
  crdt:vectorClockHash "xxh64:abcdef1234567890" .
```

**Client Installation Documents**

Client IDs are IRIs that reference discoverable `crdt:ClientInstallation` documents. These provide traceability and identity management for vector clock entries across the distributed system.

**Discovery and Lifecycle:**
1. **Discovery:** Applications query the Type Index for `crdt:ClientInstallation` container location
2. **ID Generation:** Generate unique UUID v4 for each application installation
3. **Registration:** Create installation document at discovered container location
4. **Usage:** Reference installation IRI in vector clock entries for all subsequent operations

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

**Type Index Registration Example:**
```turtle
# In Public Type Index at https://alice.podprovider.org/settings/publicTypeIndex.ttl
<#client-installations> a solid:TypeRegistration;
   solid:forClass crdt:ClientInstallation;
   solid:instanceContainer <../installations/> .
```

##### Client ID Generation Process

**Recommended Approach (UUID v4):**
1. **Discover container:** Query Type Index for `crdt:ClientInstallation` container
2. **Generate UUID:** Use UUID v4 for cryptographically strong uniqueness
3. **Create IRI:** `{container-url}/{uuid}` 
4. **Register installation:** POST installation document to container
5. **Use in vector clocks:** Reference full installation IRI in `crdt:clientId`

**Example Generation:**
```
1. Container: https://alice.podprovider.org/installations/
2. UUID v4: 550e8400-e29b-41d4-a716-446655440000
3. Installation IRI: https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000
4. Vector clock usage: crdt:clientId <https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000>
```

**Benefits of This Approach:**
- **Uniqueness:** UUID v4 provides collision-resistant identifiers
- **Traceability:** Installation documents link clients to WebIDs and applications  
- **Discoverability:** Standard Type Index enables client validation and debugging
- **No Coordination:** Each client generates IDs independently without coordination

#### 5.2.2. Vocabulary Versioning and Evolution

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

**Detailed Algorithms:** For comprehensive merge algorithms, vector clock mechanics, and edge case handling, see [CRDT-SPECIFICATION.md](CRDT-SPECIFICATION.md).

### 5.3. Layer 3: The Indexing Layer

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

### 5.3.1. Sharding Overview

**Resource Assignment:**

Resources are assigned to shards using a deterministic hash algorithm, ensuring even distribution and consistent assignment across clients.

**Key Concepts:**
- **Automatic Scaling:** System increases shard count when size thresholds are exceeded (default: 1000 entries per shard)
- **Lazy Migration:** Existing entries migrate opportunistically during normal operations
- **Self-Describing Names:** Shard names encode algorithm, configuration, and version information
- **Conflict Resolution:** Automatic version increment resolves configuration conflicts

**Migration Process:**
Shard count changes are handled through lazy, client-side migration rather than centralized maintenance operations. This approach respects Solid's decentralized nature where users are not system administrators.

For detailed implementation guidance, including algorithms, version handling, and migration procedures, see [SHARDING.md](SHARDING.md).

### 5.3.2. Multi-Application Coordination

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

### 5.3.3. Index Creation and Bootstrap Process

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

### 5.3.4. Pod Setup and Configuration Process

When an application first encounters a Pod, it may need to configure the Type Index and other Solid infrastructure:

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
1. Discover missing Type Index registrations for recipes
2. Present setup dialog: "This app needs to configure recipe storage in your Pod"
3. User selects "Automatic Setup"
4. App creates Type Index entries for recipes, recipe index, client installations
5. App proceeds with normal synchronization workflow
```

### 5.3.5. Indexing Conventions and Best Practices
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

**Example 2: A `GroupIndex` document at `https://alice.podprovider.org/indices/shopping-entries/groups/2024-08/index`**
This is a concrete index for shopping list entries from August 2024 meal plans.

```turtle
@prefix sync: <https://kkalass.github.io/solid_crdt_sync/vocab/sync#> .
@prefix idx: <https://kkalass.github.io/solid_crdt_sync/vocab/idx#> .

<> a idx:GroupIndex;
   sync:isGovernedBy mappings:group-index-v1;
   # Back-link to the rulebook.
   idx:basedOn <../../index>;
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

**Example: A Shard Document at `https://alice.podprovider.org/indices/shopping-entries/groups/2024-08/shard-mod-xxhash64-4-0-v1_0_0`**
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
   idx:hasShard <shard-mod-xxhash64-2-0-v1_0_0>, <shard-mod-xxhash64-2-1-v1_0_0> .
```

**Example: A Recipe Index Shard for OnDemand Sync at `https://alice.podprovider.org/indices/recipes/shard-mod-xxhash64-2-0-v1_0_0`**
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

### 5.4. Layer 4: The Sync Strategy

This is the client-side layer where the application developer configures how to synchronize data. The framework balances **discovery** (finding existing Pod configuration) with **developer intent** (application requirements). Developers declare their preferred sync approach, and the framework either uses discovered compatible indices or creates new ones as needed.

#### 5.4.1. Decision 1: Index Structure

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

#### 5.4.2. Decision 2: Sync Timing

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

#### 5.4.3. Common Strategies

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

## 6. Synchronization Workflow

The synchronization process is governed by the **Sync Strategy** that the developer chooses.

1.  **Index Selection:** The application chooses which indices to sync based on its needs. For GroupedSync, this means subscribing to specific groups (e.g., "2024-08" for August shopping entries). For FullSync/OnDemandSync, this means syncing the entire FullIndex.
2.  **Index Synchronization:** The library fetches the selected index, reads its `idx:hasShard` list, and synchronizes the active shards.
3.  **App Notification (`onIndexUpdate`):** The library notifies the application with the list of headers from the synchronized index.
4.  **Sync Strategy Application:** Based on the configured strategy:
     - **FullSync:** Immediately fetch all resources listed in the index
     - **OnDemandSync:** Wait for explicit resource requests
5.  **On-Demand Fetch (`fetchFromRemote`):** When needed, the app calls `fetchFromRemote("https://alice.podprovider.org/data/shopping-entries/created/2024/08/weekly-shopping-001")`.
6.  **State-based Merge:** The library downloads the full RDF resource, consults the **Merge Contract**, performs property-by-property merging, and returns the merged object.
7.  **App Notification (`onUpdate`):** The library notifies the application with the complete, merged object for local storage.

### 5.1. Concrete Workflow Example

**Scenario:** OnDemandSync for recipe collection

```javascript
// 1. Index Selection: App requests recipe synchronization
await syncLibrary.syncDataType('schema:Recipe', { strategy: 'OnDemandSync' });

// 2. Index Synchronization: Library fetches recipe index and its shards
// Internal: GET https://alice.podprovider.org/indices/recipes/index
// Internal: GET https://alice.podprovider.org/indices/recipes/shard-mod-xxhash64-2-0-v1_0_0
// Internal: GET https://alice.podprovider.org/indices/recipes/shard-mod-xxhash64-2-1-v1_0_0

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

## 7. Error Handling and Resilience

Real-world synchronization faces numerous failure modes. The architecture provides comprehensive strategies for maintaining consistency and availability despite various error conditions.

### 9.1. Failure Classification

**Error Granularities:**
- **Type-Level:** Entire data type cannot sync (missing merge contracts, authentication failures)
- **Resource-Level:** Individual resource blocked (parse errors, access control changes)  
- **Property-Level:** Specific property cannot sync (unknown CRDT types, schema violations)

### 8.2. Core Resilience Strategies

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

### 8.3. Graceful Degradation

The system provides multiple operational modes based on error conditions:

1. **Full Functionality:** Complete discovery, sync, and merge operations
2. **Limited Discovery:** Manual resource specification, reduced auto-discovery  
3. **Read-Only Mode:** Display data but cannot sync changes
4. **Offline Mode:** Local cache only, queue changes for later sync

For comprehensive implementation guidance including specific error scenarios, recovery procedures, and user interface recommendations, see [ERROR-HANDLING.md](ERROR-HANDLING.md).

## 8. Performance Characteristics

### 9.1. Sync Strategy Performance Trade-offs

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

### 8.2. Index-Based Change Detection

The architecture's index-based approach provides efficient incremental synchronization:

- **Cold Start:** Must download all relevant index shards (O(s) where s = number of shards)
- **Incremental Sync:** Download only changed shards through vector clock hash comparison (O(k) where k = changed shards)
- **Bandwidth Efficiency:** Index headers provide metadata without downloading full resources

### 8.3. Architecture Performance Benefits

- **Parallel Fetching:** Sharded indices enable concurrent synchronization
- **Partial Failure Resilience:** Failed shards don't block others
- **Conflict-Free Merging:** State-based CRDT approach eliminates merge conflicts
- **Offline Capability:** Applications remain functional without network connectivity

For detailed performance analysis, benchmarks, optimization strategies, and mobile considerations, see [PERFORMANCE.md](PERFORMANCE.md).

## 9. Data Organization Principles

### 9.1. Resource IRI Design and Pod Performance

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

## 10. Benefits of this Architecture

* **True Interoperability:** By publishing the merge rules and linking to them from the data, any application can learn how to correctly and safely collaborate.
* **Developer-Centric Flexibility:** The Sync Strategy model empowers the developer to choose the right performance trade-offs for their specific data.
* **Discoverability and Resilience:** The system is highly discoverable and resilient to changes in the indexing strategy over time.
* **High Performance & Consistency:** The RDF-based sharded index and state-based sync with HTTP caching ensure that synchronization is fast and bandwidth-efficient.

## 11. Alignment with Standardization Efforts

### 11.1. Community Alignment

This architecture aligns with the goals of the **W3C CRDT for RDF Community Group**.

* **Link:** <https://www.w3.org/community/crdt4rdf/>

### 11.2. Architectural Differentiators

* **"Add-on" vs. "Database":** This specification is designed for "add-on" libraries. The developer retains control over their local storage and querying logic.
* **Interoperability over Convenience:** The primary rule is that the data at rest in a Solid Pod must be clean, standard, and human-readable RDF.
* **Transparent Logic:** The merge logic is not a "black box." By using the `sync:isGovernedBy` link, the rules for conflict resolution become a public, inspectable part of the data model itself.

## 12. Outlook: Future Enhancements

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
