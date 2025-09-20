# A Framework for Local-First, Interoperable Apps on Solid

**Version:** 0.10.0-draft
**Last Updated:** September 2025
**Status:** Draft Specification  
**Authors:** Klas Kalaß  
**Target Audience:** Library implementers, application developers, Solid ecosystem contributors  

## Document Status

This is a **draft specification** under active development. The architecture and APIs described here are subject to change based on implementation experience and community feedback. 

**Feedback Welcome:** Please report issues, suggestions, or questions at [GitHub Issues](https://github.com/anthropics/claude-code/issues) or contribute via pull requests.

## Document Changelog

### Version 0.10.0-draft (September 2025)
- **BREAKING CHANGE:** Replace xxHash64 with MD5 for cross-platform compatibility
  - Updated hash algorithm from xxHash64 to MD5 throughout specification
  - Modified hash output format: 16 hex chars → 32 hex chars
  - Updated shard naming: `shard-mod-xxhash64-*` → `shard-mod-md5-*`
  - Changed group key safety format: `{length}_{16-char-hash}` → `{length}_{32-char-hash}`
  - Ensures JavaScript/web compatibility while maintaining deterministic hashing
- Updated vocabularies, templates, and implementation to use MD5
- All examples and documentation reflect new hash format

### Version 0.9.0-draft (September 2025)
- Initial comprehensive draft specification
- Complete 4-layer architecture: Data Resource, Merge Contract, Indexing, Sync Strategy layers
- CRDT foundations with Hybrid Logical Clocks and state-based merging
- Three sync strategies: FullSync, GroupedSync, OnDemandSync with performance analysis
- Lifecycle management including Pod setup, index population, and maintenance phases
- Management operations with lazy evaluation principles for efficiency
- Comprehensive error handling and graceful degradation patterns
- Security considerations covering threat model, data integrity, and privacy
- Professional glossary of technical terms
- References to complementary documents: [PERFORMANCE.md](PERFORMANCE.md), [ERROR-HANDLING.md](ERROR-HANDLING.md), [FUTURE-TOPICS.md](FUTURE-TOPICS.md)

---

## 1. Executive Summary

### 1.1. Framework Overview

This document outlines an architecture for building **local-first, collaborative, and truly interoperable applications** using Solid Pods as a synchronization backend. The core challenge is twofold: first, to enable robust, conflict-free data merging without sacrificing semantic interoperability; and second, to provide a scalable solution for building performant applications, regardless of dataset size.

The proposed solution addresses both challenges through a declarative, developer-centric framework. Unlike operation-based approaches (such as SU-Set) that synchronize individual change events, our architecture uses a **state-based CRDT model**. This means the entire state of a resource is synchronized, a choice that works seamlessly with passive storage backends like Solid Pods. To ensure data integrity, developers declaratively **link data properties to CRDT merge strategies**. To manage performance, they define a high-level **Sync Strategy** per type (full, groups, or on-demand). This approach allows the library to act as a flexible "add-on" to an existing application, rather than a monolithic database, while ensuring all data at rest on the Solid Pod is clean, standard RDF.

For comprehensive performance analysis, benchmarks, and mobile considerations, see [PERFORMANCE.md](PERFORMANCE.md).

### 1.2. Implementation Model

The technical complexity described in this document is intended to be encapsulated within a reusable synchronization library (such as `solid-crdt-sync`). Application developers interact with a simple, declarative API while the library handles all CRDT algorithms, index management, conflict resolution, and Pod communication. The detailed specifications in this document serve as implementation guidance for library authors and reference for understanding the underlying system behavior.

### 1.3. Scale and Design Constraints

This framework is designed for personal to small-organization scale collaboration, targeting **2-100 installations** with optimal performance at **2-20 installations**. Primary use cases include personal synchronization across multiple devices (2-5 installations), family collaboration (5-15 installations), and small teams or friend groups (10-20 installations). Extended use cases support small organizations up to 100 installations. Beyond this scale, different architectural assumptions around centralized coordination, professional IT support, and enterprise-grade infrastructure might be more appropriate.

### 1.4. Current Scope and Limitations

**Single-Pod Focus:** This framework is designed for CRDT synchronization within a single Solid Pod. All collaborating installations work with data stored in one Pod, with multiple users (WebIDs) able to participate through separate installations.

**Multi-Pod Integration Limitation:** Applications requiring data integration across multiple Pods (such as displaying Alice's recipes from `https://alice.pod/` alongside Bob's recipes from `https://bob.pod/`) need additional orchestration beyond this specification. While IRIs ensure global uniqueness across Pods, the challenges include:
- Discovery and connection management across multiple Pods
- Semantic relationship resolution across Pod boundaries
- Cross-Pod query coordination and performance optimization
- Multi-source synchronization architecture and user experience

**Future Evolution:** Multi-Pod application integration represents a significant architectural enhancement planned for future specification versions (v2/v3). See FUTURE-TOPICS.md Section 10 for detailed analysis of the challenges and potential approaches.

## 2. Core Principles

* **Local-First:** The application must be fully functional offline, working primarily with data cached on the device. To ensure this principle remains practical for large datasets, the architecture supports optional partial sync strategies. This allows an application to work with a local, consistent cache of the *relevant* data, maintaining speed and offline availability without requiring a full data download.

* **CRDT Interoperability:** The data is clean, standard RDF within CRDT-managed documents (`sync:ManagedDocument`). CRDT-enabled applications achieve interoperability by discovering managed resources via `sync:managedResourceType` and following the public merge contracts that define collaboration rules.

* **Declarative Merge Behavior:** Developers define the merge behavior for each piece of data by declaratively linking its properties to well-defined **state-based** CRDT types (e.g., `LWW-Register`, `OR-Set`). This is done in a **public, discoverable rules file**, abstracting away the complexity of the underlying algorithms. The framework supports both class-scoped rules (property mappings) and global rules (predicate mappings) to provide flexibility in defining merge semantics. This state-based approach is fundamental to the architecture's design as it works seamlessly with passive storage backends.

* **Managed Resource Discoverability:** The system is designed to be self-describing for CRDT-enabled applications. Compatible applications can discover CRDT-managed resources through `sync:ManagedDocument` Type Index registrations with `sync:managedResourceType` filtering. From a managed resource, clients can discover merge rules (`sync:isGovernedBy`) and index shards (`idx:belongsToIndexShard`), enabling CRDT-enabled applications to collaborate safely while remaining invisible to incompatible applications.

* **Decentralized & Server-Agnostic:** The Solid Pod acts as a simple, passive storage bucket. All synchronization logic resides within the client-side library.

## 3. Architecture Overview

This section provides a high-level view of the framework's approach before diving into technical foundations. Understanding these key architectural decisions helps contextualize the detailed mechanisms that follow.

### 3.1. The Problem

Distributed RDF data synchronization faces three fundamental challenges:

**Challenge 1: Conflict-Free Merging**  
Multiple applications writing to the same RDF resources create conflicts that must be resolved deterministically without coordination. Traditional "last-write-wins" approaches lose data and break semantic relationships.

**Challenge 2: Semantic Preservation**  
RDF's semantic richness must be preserved during synchronization. Merge strategies must understand property semantics (single-value vs multi-value, immutable vs collaborative) rather than treating all data uniformly.

**Challenge 3: Passive Storage Integration**  
Solid Pods are passive storage - they cannot execute merge logic or coordinate between clients. All conflict resolution must happen client-side while ensuring convergent results across all installations.

### 3.2. The Solution Approach

The framework addresses these challenges through a **state-based CRDT architecture** with three key innovations:

**State-Based CRDT Model:**  
Instead of synchronizing individual operations, entire resource states are merged using property-specific CRDT algorithms. This approach works naturally with passive storage and enables rich semantic merge strategies.

**Declarative Merge Contracts:**  
Developers define merge behavior by linking each property to appropriate CRDT types (LWW-Register for names, OR-Set for keywords, Immutable for structural data). These contracts are public and discoverable, enabling cross-application interoperability.

**Four-Layer Architecture:**  
1. **Data Resource Layer**: Clean RDF using standard vocabularies
2. **Merge Contract Layer**: Public CRDT rules for conflict resolution  
3. **Indexing Layer**: Performance optimization through sharded indices
4. **Sync Strategy Layer**: Application-controlled synchronization patterns

### 3.3. Key Architectural Decisions

Several critical design decisions shape the framework's behavior:

**Hybrid Logical Clocks for Causality:**  
Combines logical causality tracking (tamper-proof) with physical timestamps (intuitive tie-breaking). This provides both theoretical soundness and user-friendly "most recent wins" behavior for concurrent operations.

**Blank Node Context Identification:**  
RDF blank nodes gain stable identity through context + identifying properties, enabling CRDT operations that require object identity (OR-Set tombstones, etc.) while preserving RDF semantics.

**Discovery Isolation Strategy:**  
CRDT-managed resources register as `sync:ManagedDocument` rather than semantic types, protecting them from incompatible applications while enabling framework-aware collaboration.

**Document-Level Sync with Resource-Level Semantics:**  
Synchronization operates on complete documents for atomic consistency, while indexing and APIs work with individual resources for developer intuition.

### 3.4. Reading Guide

The remainder of this document provides detailed technical foundations and implementation guidance:

- **Section 4 (Foundations)**: Technical mechanisms that enable the architecture
- **Section 5 (Four-Layer Architecture)**: Detailed explanation of each architectural layer  
- **Section 6 (Lifecycle Management)**: Practical Pod setup and operational procedures
- **Appendices**: Implementation specifications and error handling patterns (see [ERROR-HANDLING.md](ERROR-HANDLING.md) for comprehensive resilience strategies)

**For Different Audiences:**
- **Architects/Decision Makers**: Sections 1-3 provide sufficient overview for technology decisions
- **Application Developers**: Add Section 5 for understanding the development model
- **Library Implementers**: Full document provides complete technical specification

**Transitioning to Implementation Details**: While the previous sections established the conceptual framework and architectural decisions, the following sections dive into the specific technical mechanisms that make this architecture work. Understanding these foundations is essential for implementing the framework correctly, particularly the CRDT algorithms, RDF identity resolution, and synchronization protocols that enable conflict-free collaboration.

## 4. Foundations

Having established the overall architectural approach, this section examines the technical foundations that make reliable CRDT synchronization possible in the RDF/Solid ecosystem. We start with CRDT fundamentals (4.1), then address the critical RDF identity challenges that shaped our approach (4.2), followed by integration and lifecycle mechanisms (4.3-4.6).

### 4.1. CRDT Fundamentals

Before examining RDF-specific challenges, it's essential to understand the core CRDT concepts that underpin this architecture. These data structures enable conflict-free merging of distributed data without requiring coordination between clients.

#### 4.1.1. Core CRDT Types

**LWW-Register (Last-Writer-Wins Register):**
- Used for single-value properties where the most recent write should win
- Examples: Recipe name, creation timestamp, status field
- Conflict resolution: Compare timestamps, newer value wins
- **Multi-value behavior:** Treats complete value set atomically - most recent set wins, replaces all previous values
- Compatible with any object type (IRIs, literals, blank nodes)

**FWW-Register (First-Writer-Wins Register):**
- Used for immutable properties where "first to set wins" semantics are desired
- Examples: Resource identifiers, permanent classifications, initial configurations
- Conflict resolution: Compare timestamps, first write wins, subsequent writes ignored
- **Multi-value behavior:** Preserves the first complete value set, ignores subsequent modifications
- Provides graceful degradation alternative to Immutable's strict merge failure

**OR-Set (Observed-Remove Set):**
- Used for multi-value properties where additions and removals must be tracked separately
- Examples: Recipe keywords, ingredient lists, tag collections
- Conflict resolution: Union of all additions, minus explicitly removed items
- Requires stable object identity for tombstone matching across documents

**2P-Set (Two-Phase Set):**
- Add-only sets with tombstone-based removal (elements can be added and removed, but not re-added)
- Used for properties where re-addition after removal should be prevented
- Requires stable object identity for tombstone operations

**Immutable:**
- Framework-specific constraint (not a traditional CRDT algorithm)
- Used for properties that must never change after creation with strict enforcement
- Examples: Resource creation timestamps, installation identifiers, structural configurations
- **Multi-value behavior:** Complete value set treated as immutable - any modification causes merge failure
- Conflict resolution: Merge fails if different values encountered, forces resource versioning
- **Key distinction from FWW-Register:** Immutable causes sync failure for conflicts, FWW-Register silently ignores them

**Hybrid Logical Clock (HLC):**
- Combines logical causality tracking with physical wall-clock timestamps
- Provides tamper-resistant causality determination and intuitive tie-breaking
- Each document maintains a clock that advances with each change
- Enables "newer wins" semantics while protecting against clock manipulation

**Framework Extensibility:** The architecture is designed to support additional CRDT algorithms beyond this initial set. The core infrastructure (Hybrid Logical Clocks, blank node identification, merge contracts) provides the foundation for extending to counters, sequences, and other algorithm families, though complex algorithms may require enhancements to the identification or merge rule systems.

#### 4.1.2. State-Based vs Operation-Based CRDTs

This framework uses **state-based CRDTs** rather than operation-based approaches:

**State-Based Approach (This Framework):**
- Synchronizes complete document state between replicas
- Compatible with passive storage backends like Solid Pods
- Merge function operates on entire document states
- Higher bandwidth but simpler implementation

**Operation-Based Approach (Alternative):**
- Synchronizes individual operations/changes between replicas
- Requires active coordination and reliable message delivery
- Lower bandwidth but requires more complex infrastructure
- Examples: Yjs, Automerge operation streams

#### 4.1.3. Property-Level CRDT Integration

The framework applies these CRDT types at the **property level** within RDF resources:
- Each property in a resource is governed by a specific CRDT type
- Merge contracts (`sync:` vocabulary) declaratively link properties to CRDT algorithms
- Document-level Hybrid Logical Clocks coordinate the overall merge process
- The result is deterministic, conflict-free merging of arbitrary RDF data

#### 4.1.4. Multi-Value Property Examples

Understanding how different CRDT types handle multi-value properties is crucial for correct usage:

**Immutable Multi-Value Example (Garbage Collection Index):**
```turtle
# Template defines multiple document types - this complete set is immutable
idx:indexesClass sync:ManagedDocument, idx:FullIndex, idx:GroupIndex, idx:GroupIndexTemplate, idx:Shard;
```
- **Merge behavior:** If any installation attempts to change this set (add/remove types), merge fails
- **Use case:** Structural configurations that must remain consistent across all installations
- **Error handling:** Forces resource versioning or manual intervention

**FWW-Register Multi-Value Example (Installation Configuration):**
```turtle
# First installation to set supported features wins
app:supportedFeatures "recipes", "meal-planning", "shopping-lists";
```
- **Merge behavior:** First complete set wins, subsequent modifications ignored
- **Use case:** Initial configurations where "first to configure wins" behavior is desired  
- **Error handling:** Graceful degradation, no sync failure

**LWW-Register Multi-Value Example (Accidental Usage):**
```turtle
# If mistakenly used for multi-value property
recipe:keywords "quick", "easy", "vegetarian";  # Alice's version
recipe:keywords "healthy", "dinner";           # Bob's later version  
# Result: Bob's complete set wins - Alice's keywords completely replaced
```
- **Merge behavior:** Most recent complete set wins, all previous values discarded
- **Use case:** Generally incorrect for multi-value properties - should use OR-Set instead
- **Error handling:** No sync failure, but likely unintended data loss

**Key Decision Points:** 
- Choose **Immutable** when strict consistency is critical and conflicts indicate serious configuration errors
- Choose **FWW-Register** when graceful degradation and "first wins" semantics are desired  
- Choose **LWW-Register** only for truly single-value properties - avoid for multi-value to prevent data loss
- Choose **OR-Set** for collaborative multi-value properties where individual additions/removals matter

### 4.2. Core RDF Challenges

CRDTs require stable object identity for operations like OR-Set tombstone matching and 2P-Set removal tracking. This creates a fundamental challenge with RDF blank nodes, whose document-scoped identifiers cannot be reliably matched across different document instances. For RDF-knowledgeable readers, this section addresses the "obvious" question: how can CRDT operations work reliably with RDF's semantic model? The following sections explain the framework's context-based identification solution and its implications for merge contract design.


#### 4.2.1. Three-Level Merging Hierarchy

**Three Distinct Operations:** The framework performs merging operations at three different levels, with document-level decisions handling special cases and tombstoning:

1. **Document-Level Merging:** Handles special cases where document-level decisions override resource-level merging:
   - **Tombstoning decisions:** `max(crdt:deletedAt) > max(crdt:createdAt)` empties all semantic content
   - **Fallback behavior:** When merge contracts are incompatible/unknown, entire document wins via `crdt:LWW_Register`

2. **Resource Merging:** For normal cases, combine all properties belonging to the same identified resource across documents. This is resource-scoped processing - each identified resource gets merged independently based on its own properties, regardless of how many other resources reference it.

3. **Property Merging:** Within each identified resource, apply CRDT rules (LWW-Register, OR-Set, etc.) to merge individual property values according to the resource's merge contract.

**Processing Flow:** 
- **First check document-level conditions** (tombstoning, compatibility, identifiability)
- **If document-level merging applies:** Use atomic document handling
- **Otherwise:** Proceed with normal resource-level and property-level merging

**Impact on Each Operation:** The blank node identity problem affects the resource and property merging operations differently:

**Resource Merging Impact:** When non-identifiable resources appear as subjects, we cannot determine if `_:b1` in document A corresponds to `_:b1` in document B, even if they have identical properties. The blank node labels are arbitrary serialization decisions that only have meaning within a single document instance by RDF definition. Therefore, we cannot merge their properties - each document's version must be treated atomically.

**Property Merging Impact:** When non-identifiable resources appear as object values, we cannot determine equality for CRDT operations that depend on identity. For example, OR-Set tombstones cannot match their target objects across documents because `[rdfs:label "homemade"]` in a tombstone cannot be reliably compared to `[rdfs:label "homemade"]` in the live data.

#### 4.2.2. The Blank Node Challenge

**The Fundamental RDF Constraint:** RDF blank nodes are document-instance-scoped by definition - their identifiers (like `_:b1`) only have meaning within a single document instance. The RDF specification allows different implementations to assign blank node labels arbitrarily, so the same semantic content might be labeled `_:b1` in one instance and `_:genid123` in another. When merging two document instances (e.g., local `recipe-123.ttl` and remote `recipe-123.ttl`), we cannot determine if `_:b1` in the local instance corresponds to `_:b1` in the remote instance - even if the labels match, this must be treated as incidental coincidence rather than semantic equivalence.

**Why This Matters for CRDTs:** Many CRDT operations require stable identity to function correctly:
- **OR-Set and 2P-Set** tombstones must match their target objects across documents
- **Sequence CRDTs** need to maintain consistent element ordering
- **Merge algorithms** must determine which resources represent the same entity

**The Core Problem:** Without stable identity, we cannot reliably merge RDF graphs containing blank nodes, leading to data inconsistency and CRDT convergence failures.

#### 4.2.3. The Solution: Context-Based Identification

**The Key Insight:** Some blank nodes can become identifiable through the combination of context + properties, enabling safe CRDT operations within specific scopes.

**The Mechanism:** Mapping documents can declare that specific properties serve as identifiers for blank nodes using `mc:isIdentifying true` boolean flags within mapping rules (part of our `mc:` vocabulary for merge contracts). This creates stable identity within a known context scope.

**The Pattern:** `(context, identifying properties)` creates sufficient identity for safe merging within that scope. The context is the identifier of the subject containing the blank node, and identifying properties are the values of predicates with `mc:isIdentifying true` flags in their rules. With compound keys, the pattern becomes `(context, property1=value1, property2=value2, ...)`.

**Recursive Context Building:** Context identifiers can be built recursively - an identified blank node can serve as context for nested blank nodes:
- **Base case:** IRI-identified resource (e.g., `<https://alice.podprovider.org/data/recipes/tomato-soup#it>`)  
- **Recursive case:** Previously identified blank node (e.g., `(<https://alice.../recipes/tomato-soup#it>, installationId=<https://alice.../installation-123>)` identifies a clock entry)
- **Nested example:** `((<https://alice.../recipes/tomato-soup#it>, installationId=<https://alice.../installation-123>), subProperty=value)` could identify a blank node within a clock entry

For example, Hybrid Logical Clock entries are identified by `(document_IRI, crdt:installationId=<full_installation_IRI>)`, where `document_IRI` is the full document IRI context and `crdt:installationId=<full_installation_IRI>` are the identifying properties.

**Implementation Details:** For detailed mapping syntax, complex identification scenarios, and implementation patterns, see [CRDT-SPECIFICATION.md section 4](CRDT-SPECIFICATION.md#4-crdt-mapping-validation). 

#### 4.2.4. Resource Identity Taxonomy

**The Critical Three-Way Distinction:** Resources fall into three categories based on their identity characteristics:

**1. IRI-Identified Resources** (globally unique):
- **Example:** `<https://alice.podprovider.org/data/recipes/tomato-soup#it>`
- **Identity:** Globally unique, stable identifiers
- **CRDT Compatibility:** Safe for all CRDT operations

**2. Context-Identified Blank Nodes** (unique within context):
- **Example:** `(<https://alice.../recipes/tomato-soup#it>, installationId=<https://alice.../installation-123>)`
- **Identity:** Unique within specific context through identifying properties
- **CRDT Compatibility:** Safe for all CRDT operations when properly identified

**3. Non-Identifiable Resources** (no stable identity):
- **Example:** `[]` with no identifying properties or non-identifiable parent subject
- **Identity:** Document-scoped identifiers without stable identification patterns
- **CRDT Compatibility:** Limited to atomic operations (LWW-Register only)

**Determining Identifiability:** A blank node becomes identifiable when:
1. A mapping rule declares some predicate as identifying (`mc:isIdentifying true`)  
2. The blank node has that identifying predicate as one of its properties
3. The subject that references the blank node is itself identifiable (IRI or previously identified blank node)

#### 4.2.5. CRDT Compatibility Rules

**The Critical Constraint:** Identity-dependent CRDTs (OR-Set, 2P-Set) require stable object identity to match tombstones with their targets across documents. Non-identifiable blank nodes cause these operations to fail.

**Compatibility Matrix:**
- **OR-Set, 2P-Set:** Can ONLY be used when object values are identifiable (IRIs, literals, or context-identified blank nodes)
- **LWW-Register:** Can work with non-identifiable object values (treats them atomically)

**Error Prevention:** Invalid mappings (e.g., OR-Set on non-identifiable blank nodes) must be detected during merge contract validation. Resources with invalid mappings are rejected at the resource level, allowing other resources of the same type to continue syncing.

**Detailed Examples:** For comprehensive examples of identification failures, structural equality problems, and solution patterns, see [CRDT-SPECIFICATION.md section 4](CRDT-SPECIFICATION.md#4-crdt-mapping-validation).

#### 4.2.6. Development Implications

- **Data Modeling:** Prefer IRIs over blank nodes when identity-dependent CRDT operations are needed
- **Mapping Design:** Understand identifiability requirements for each CRDT type and use `mc:isIdentifying` appropriately
- **Validation:** Implement mapping validation to prevent invalid configurations
- **Performance:** Flat resource processing enables parallel merging optimizations

#### 4.2.7. Implementation Consistency Checks

**Recommended Practice:** Implementing libraries should perform consistency checks during mapping generation or validation, particularly when mappings are derived from code annotations:

- **Blank Node Identification:** Verify that all blank nodes used with identity-dependent CRDTs (OR-Set, 2P-Set) have appropriate `mc:isIdentifying` declarations
- **Mapping Completeness:** Ensure all properties of a class have corresponding merge rules in the mapping contract
- **CRDT Compatibility:** Validate that each property's declared CRDT type is compatible with its object types (see section 4.2 in CRDT-SPECIFICATION.md)
- **Multi-Value Semantics:** Verify understanding of how each CRDT type handles multi-value properties (LWW-Register = atomic set replacement, Immutable = complete set immutable, FWW-Register = first complete set wins, OR-Set = collaborative set operations)
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
// mc:rule [ mc:predicate recipe:name; algo:mergeWith algo:LWW_Register; mc:isIdentifying true ],
//           [ mc:predicate recipe:unit; algo:mergeWith algo:LWW_Register; mc:isIdentifying true ],
//           [ mc:predicate recipe:amount; algo:mergeWith algo:LWW_Register ]
```

This constraint fundamentally shapes merge contract design, mapping validation, and the scope of supported CRDT operations.

### 4.3. Resource/Document Abstraction

Developers want to work with individual recipe properties like `schema:name` and `schema:ingredients`, but efficient sync requires handling entire documents as atomic units. This section explains how the framework solves both needs through coordinated abstraction levels.

#### 4.3.1. The Problem: Two Different Mental Models

**What Developers Want to Work With:**
```turtle
# Individual recipe properties - feels natural for app development
<https://alice.podprovider.org/data/recipes/tomato-soup#it> 
    schema:name "Tomato Soup" ;
    schema:ingredients "tomatoes, basil" ;
    schema:prepTime "PT30M" .
```

**What Efficient Sync Requires:**

*Document: `/data/recipes/tomato-soup`*
```turtle
# Complete document with sync metadata - efficient for protocol operations
<https://alice.podprovider.org/data/recipes/tomato-soup> 
    a sync:ManagedDocument ;
    sync:managedResourceType schema:Recipe ;  # Enables resource-type-specific retention policies
    crdt:hasClockEntry [
        crdt:installationId <https://alice.podprovider.org/installations/mobile-recipe-app-2024-08-19-xyz> ;
        crdt:logicalTime "15"^^xsd:long ;
        crdt:physicalTime "1693824600000"^^xsd:long
    ] ;
    sync:isGovernedBy <https://alice.podprovider.org/mappings/recipes-v1> ;
    crdt:clockHash "abc123def456" .

<https://alice.podprovider.org/data/recipes/tomato-soup#it> 
    schema:name "Tomato Soup" ;
    schema:ingredients "tomatoes, basil" ;
    schema:prepTime "PT30M" .
```

The framework needs to support both perspectives simultaneously.

#### 4.3.2. The Solution: Dual Abstraction Levels

**Core Rule:** *When a resource uses a fragment identifier (like `#it`), sync/merge control operates on the entire document, while resource content and indexing operate on the specific resource.*

This creates two coordinated abstraction levels:

**Developer/Application Perspective (Resource-Oriented):**
- Work with resource identities: `https://alice.podprovider.org/data/recipes/tomato-soup#it`
- Receive resource properties for local storage and application logic
- Update individual properties: change just the `schema:prepTime`
- APIs handle resource-level operations and individual property values

**Framework/Sync Perspective (Document-Oriented):**
- Track changes at document level using Hybrid Logical Clock hashes
- Merge conflicts by comparing entire document states, then resolving property-by-property
- Synchronize complete documents as atomic units for consistency
- Handle deletion as all-or-nothing document cleanup

#### 4.3.3. Document-Level Sync with Resource-Level Access

The framework maintains the dual abstraction by tracking changes at the document level while providing access to individual resources:

*Document: `/data/recipes/tomato-soup`*
```turtle
# Document-level change tracking enables efficient sync
<https://alice.podprovider.org/data/recipes/tomato-soup> 
    a sync:ManagedDocument ;
    sync:managedResourceType schema:Recipe ;
    crdt:clockHash "abc123def456" ;  # Single hash covers entire document
    crdt:hasClockEntry [...] ;
    sync:isGovernedBy <mappings> .

# Resource-level content for application use
<https://alice.podprovider.org/data/recipes/tomato-soup#it> 
    schema:name "Tomato Soup" ;
    schema:ingredients "tomatoes, basil" ;
    schema:prepTime "PT30M" .
```

**Conflict Resolution:**
When Alice and Bob edit the same recipe simultaneously, the framework merges at the document level while preserving individual resource properties:

*Merged Document: `/data/recipes/tomato-soup`*
```turtle
# Result: Both changes preserved through property-level conflict resolution
<https://alice.podprovider.org/data/recipes/tomato-soup> 
    a sync:ManagedDocument ;
    sync:managedResourceType schema:Recipe ;
    crdt:clockHash "def789ghi012" ;      # Updated hash reflects merged state
    crdt:hasClockEntry [
        crdt:installationId <https://alice.podprovider.org/installations/mobile-recipe-app-2024-08-19-xyz> ;
        crdt:logicalTime "16"^^xsd:long
    ], [
        crdt:installationId <https://bob.podprovider.org/installations/desktop-recipe-app-2024-08-15-abc> ;
        crdt:logicalTime "15"^^xsd:long
    ] ;
    sync:isGovernedBy <https://alice.podprovider.org/mappings/recipes-v1> .

<https://alice.podprovider.org/data/recipes/tomato-soup#it> 
    schema:name "Spicy Tomato Soup" ;    # Alice's change (higher logical time)
    schema:ingredients "tomatoes, basil" ; # Unchanged property preserved
    schema:prepTime "PT45M" .            # Bob's change (preserved)
```

#### 4.3.4. Benefits of This Approach

**For Developers:**
- Work with standard resource-oriented RDF concepts
- Receive individual resource data for local storage and application logic
- Type registrations use familiar semantic types (`schema:Recipe`)

**For Sync Efficiency:**
- Document-level change detection minimizes network overhead
- Atomic document synchronization prevents partial update inconsistencies
- Single document merge resolves all property conflicts together

**For System Consistency:**
- All changes to resources within a document are synchronized together
- Deletion operates cleanly on complete documents with retention policies
- Fragment resources automatically inherit document-level sync behavior

#### 4.3.5. Implementation Requirements

**Mandatory Document Properties:**
Framework libraries **MUST** include the following properties when creating `sync:ManagedDocument` instances:

- **`foaf:primaryTopic`**: MUST identify the primary resource within the document (typically `<#it>`)
- **`crdt:createdAt`**: MUST be set to document creation timestamp to enable zombie deletion protection
- **`sync:managedResourceType`**: MUST be set to the `rdf:type` of the `foaf:primaryTopic` resource
  - **Purpose**: Enables efficient garbage collection, retention policy lookup, and prevents zombie deletion problems during document recreation
  - **Requirement**: The `sync:managedResourceType` value MUST equal the primary resource type (e.g., `schema:Recipe` for recipe documents)

```turtle
# REQUIRED: All mandatory properties must be present
<https://alice.podprovider.org/data/recipes/tomato-soup> 
    a sync:ManagedDocument ;
    sync:managedResourceType schema:Recipe ;  # MUST match #it rdf:type
    crdt:createdAt "2024-08-15T10:30:00Z"^^xsd:dateTime ;  # MUST be present
    foaf:primaryTopic <#it> .

<https://alice.podprovider.org/data/recipes/tomato-soup#it>
    a schema:Recipe ;  # Must match sync:managedResourceType above
    schema:name "Tomato Soup" .
```

This requirement ensures consistent resource type tracking across Type Index registrations, document metadata, and garbage collection operations.

### 4.4. Solid Discovery Integration

CRDT-managed resources contain synchronization metadata and follow structural conventions that traditional RDF applications don't understand, creating a risk of data corruption. This section describes how the architecture solves this problem through discovery isolation.

CRDT-enabled applications use a modified Solid discovery approach that provides controlled access to managed resources while protecting them from incompatible applications. This isolation strategy prevents data corruption while maintaining standard Solid discoverability principles.

#### 4.4.1. Discovery Isolation Strategy

**The Challenge:** Traditional Solid discovery would expose CRDT-managed data to all applications, risking corruption by applications that don't understand CRDT metadata or Hybrid Logical Clocks.

**The Solution:** CRDT-managed resources are registered under `sync:ManagedDocument` in the Type Index rather than their semantic types (e.g., `schema:Recipe`). The semantic type is preserved via `sync:managedResourceType` property.

**Discovery Behavior:**
- **CRDT-enabled apps:** Query for `sync:ManagedDocument` where `sync:managedResourceType schema:Recipe` → Find managed resources
- **Traditional apps:** Query for `schema:Recipe` → Find nothing (managed data invisible)
- **Legacy data:** Remains discoverable through traditional registrations until explicitly migrated

This creates clean separation: compatible applications collaborate safely on managed data, while traditional apps work with unmanaged data, preventing cross-contamination.

#### 4.4.2. Managed Resource Discovery Protocol

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
@prefix sync: <https://w3id.org/solid-crdt-sync/vocab/sync#> .
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
@prefix idx: <https://w3id.org/solid-crdt-sync/vocab/idx#> .
@prefix crdt: <https://w3id.org/solid-crdt-sync/vocab/crdt-mechanics#> .

<> solid:hasRegistration [
      a solid:TypeRegistration;
      solid:forClass idx:FullIndex;
      idx:indexesClass schema:Recipe
      solid:instanceContainer <../indices/recipes/>;
   ], [
      a solid:TypeRegistration;
      solid:forClass idx:GroupIndexTemplate;
      idx:indexesClass meal:ShoppingListEntry
      solid:instanceContainer <../indices/shopping-entries/>;
   ], [
      a solid:TypeRegistration;
      solid:forClass sync:ManagedDocument;
      sync:managedResourceType crdt:ClientInstallation;
      solid:instanceContainer <../installations/>
   ] .
```

4. **Managed Resource Discovery:** CRDT-enabled applications query the Type Index for `sync:ManagedDocument` registrations with specific `sync:managedResourceType` values (e.g., `schema:Recipe`) and their corresponding index types (e.g., `idx:FullIndex`), enabling automatic discovery of the complete synchronization setup.

**Advantages:** Using TypeRegistration with `sync:ManagedDocument` and `sync:managedResourceType` enables managed resource discovery while protecting managed resources from incompatible applications. CRDT-enabled applications can find both data and indices through standard Solid mechanisms ([WebID Profile](https://www.w3.org/TR/webid/), [Type Index](https://github.com/solid/type-indexes)), while traditional applications remain unaware of CRDT-managed data, preventing accidental corruption.

### 4.5. Installation Identity Management

Collaborative CRDT synchronization requires stable client identity management to enable causality tracking, coordinate collaborative operations, and manage installation lifecycles. Each client installation maintains a discoverable identity document that serves as the foundation for all collaborative coordination.

Installation IDs are IRIs that reference discoverable `crdt:ClientInstallation` documents. These provide traceability, identity management for Hybrid Logical Clock entries, and collaborative lifecycle management.

**Discovery and Lifecycle:**
1. **Discovery:** Applications query the Type Index for `crdt:ClientInstallation` container location
2. **ID Generation:** Generate unique UUID v4 for each application installation
3. **Registration:** Create installation document at discovered container location
4. **Usage:** Reference installation IRI in Hybrid Logical Clock entries for all subsequent operations

**Installation Document Structure:**

```turtle
<> a sync:ManagedDocument;
   foaf:primaryTopic <#installation>;
   sync:isGovernedBy mappings:client-installation-v1 .

<#installation> a crdt:ClientInstallation;
   crdt:belongsToWebID <../profile/card#me>;
   crdt:applicationId <https://meal-planning-app.example.org/id>;
   crdt:createdAt "2024-08-19T10:30:00Z"^^xsd:dateTime;
   crdt:lastActiveAt "2024-09-02T14:30:00Z"^^xsd:dateTime .
```

**Installation ID Generation Process:**

**Recommended Approach (UUID v4):**
1. **Discover container:** Query Type Index for `crdt:ClientInstallation` container
2. **Generate UUID:** Use UUID v4 for cryptographically strong uniqueness
3. **Create IRI:** `{container-url}/{uuid}` 
4. **Register installation:** POST installation document to container
5. **Use in Hybrid Logical Clocks:** Reference full installation IRI in `crdt:installationId`

**Installation Lifecycle Management:**

*Self-Managed Properties (Installation Should Only Update Its Own):*
- **`crdt:lastActiveAt`:** Installation updates its own activity timestamp
  - **Update triggers:** First sync operation of each day
  - **Frequency:** Daily maximum to align with Management Phase operations and reduce write overhead
  - **CRDT Algorithm:** `crdt:LWW_Register`
- **`crdt:maxInactivityPeriod`:** Installation's maximum inactivity period before tombstoning (defaults to P6M)

*Identity Properties (Set Once at Creation):*
- **`crdt:belongsToWebID`**, **`crdt:applicationId`**, **`crdt:createdAt`:** Use `crdt:Immutable` or `crdt:FWW_Register` based on error handling preference

**Installation Cleanup:**
Inactive installations are tombstoned using `crdt:deletedAt` when inactive beyond their `crdt:maxInactivityPeriod`. Other installations monitor `crdt:lastActiveAt` during collaborative operations and make dormant installation tombstoning decisions as part of their sync management phase. For general tombstone mechanics, see Section 3.6 below.

### 4.6. Tombstoning and Deletion Semantics

Distributed systems require explicit deletion handling to ensure consistent data removal across all clients. The framework implements a comprehensive tombstoning approach that supports both complete resource deletion and granular property value removal while maintaining CRDT convergence properties.

#### 4.6.1. Tombstone Types and Scope

The framework uses two distinct tombstone mechanisms for different deletion scopes, both utilizing the same `crdt:deletedAt` predicate but with different merge semantics appropriate to their scope.

**Two Types of Tombstones:**

**1. Document Tombstones** (Entire Document Deletion):
- **Purpose:** Mark complete documents as deleted, affecting all resources contained within
- **Property:** `crdt:deletedAt` with OR-Set semantics applied to the document
- **Scope:** Applied to the document identifier `<doc>`, marking the entire document for cleanup
- **Use Cases:** 
  - **Application-controlled cleanup:** User-deleted documents (recipes, shopping lists, etc.)
  - **Installation management:** Inactive client installations beyond their `crdt:maxInactivityPeriod`
  - **Index lifecycle management:** Obsolete index shards during index reorganization
  - **Garbage collection:** Framework-managed cleanup of stale metadata documents

```turtle
# Document tombstone example - applied at document level
<https://alice.podprovider.org/data/shopping-entries/entry-123> 
    crdt:deletedAt "2024-09-02T14:30:00Z"^^xsd:dateTime .
```

**Document-Level Deletion Semantics (Universal Emptying):**
When applying document tombstones, implementations must perform universal emptying: remove all semantic content while preserving essential framework metadata. This applies when setting `crdt:deletedAt` such that `max(crdt:deletedAt) > max(crdt:createdAt)`. This "radical emptying" approach provides:

- **Consistent storage usage:** All tombstoned documents have predictable, minimal size
- **Conflict avoidance:** No stale content to conflict with during reactivation scenarios  
- **Simple cleanup logic:** One deletion marker controls entire document lifecycle
- **Optimal performance:** Minimal data to sync for tombstoned documents

**Universal Emptying Rule:**
```turtle
# Before tombstoning (example recipe):
<> a sync:ManagedDocument;
   sync:isGovernedBy mappings:recipe-v1;
   foaf:primaryTopic <#recipe>;
   idx:belongsToIndexShard <../indices/recipes/shard-0>,
                           <../indices/gc/2024/shard-0>;
   crdt:createdAt "2024-08-01T10:00:00Z"^^xsd:dateTime;
   crdt:clockEntry [...] .

<#recipe> a schema:Recipe;
   schema:name "Tomato Soup";
   schema:ingredients [...] .

# After tombstoning (universal emptying applied):
<> a sync:ManagedDocument;
   sync:isGovernedBy mappings:recipe-v1;
   idx:belongsToIndexShard <../indices/gc/2024/shard-0>;  # Only GC shard remains
   crdt:createdAt "2024-08-01T10:00:00Z"^^xsd:dateTime;
   crdt:deletedAt "2024-08-15T14:30:00Z"^^xsd:dateTime;
   crdt:clockEntry [...] .

# Removed during tombstoning:
# - foaf:primaryTopic and all semantic content  
# - All idx:belongsToIndexShard except GC index references
# - All application-specific properties
```

**Selective Property Retention:**
- **Framework metadata:** `rdf:type`, `sync:isGovernedBy`, `crdt:*` properties preserved
- **GC index tracking:** `idx:belongsToIndexShard` retained only for garbage collection shards
- **All other content:** Removed to minimize storage and prevent conflicts

**2. Property Tombstones** (Individual Value Deletion):
- **Purpose:** Mark specific values within multi-value properties as deleted (e.g., removing "quick" from recipe keywords)
- **Property:** `crdt:deletedAt` with RDF Reification
- **Scope:** Applied to individual property values within OR-Set or 2P-Set properties
- **Use Case:** User removes a keyword, ingredient, or other individual value from a multi-value property

#### 4.6.2. Unified Deletion Semantics

The `crdt:deletedAt` predicate is defined globally in the framework's predicate mappings with consistent OR-Set semantics across all contexts:

```turtle
# In core-v1.ttl deletion mappings
[ mc:predicate crdt:deletedAt; algo:mergeWith algo:OR_Set ]
```

**Key Properties:**

**Document-Level Deletion:**
- **Temporal Lifecycle:** Both `crdt:createdAt` and `crdt:deletedAt` are sets of timestamps (OR-Set semantics)
- **State Determination:** A document is considered deleted if `max(crdt:deletedAt) > max(crdt:createdAt)`
- **Merge Behavior:** OR-Set union across all replicas for both creation and deletion timestamps
- **Undeletion Support:** Add new `crdt:createdAt` timestamp and tombstone old `crdt:deletedAt` timestamps that are being "undone"

**Property-Level Deletion (RDF Reification):**
- **Simple Tombstone:** Property values are deleted if a corresponding RDF reification tombstone with `crdt:deletedAt` exists
- **No Creation Tracking:** Property tombstones only have `crdt:deletedAt` (no `crdt:createdAt` at value level)
- **Standard RDF Semantics:** Uses RDF reification to mark specific triples as deleted without asserting them

**Undeletion Example:**
```turtle
# Before undeletion - document is deleted (max deletion > max creation)
<doc> crdt:createdAt ["2024-01-01T10:00:00Z"] ;
      crdt:deletedAt ["2024-06-01T15:30:00Z"] .  # Document deleted

# After undeletion - add new creation, tombstone old deletion
<doc> crdt:createdAt ["2024-01-01T10:00:00Z", "2024-08-15T09:00:00Z"] ;
      crdt:deletedAt [] .  # Deletion timestamp tombstoned

# The deletion tombstone (as RDF reification):
[rdf:subject <doc> ; 
 rdf:predicate crdt:deletedAt ; 
 rdf:object "2024-06-01T15:30:00Z"^^xsd:dateTime] 
    crdt:deletedAt "2024-08-15T09:01:00Z"^^xsd:dateTime .
```

**Deletion API Design Philosophy:**

Framework deletion operates at the document level, providing a clean separation between application-controlled soft deletion and system-level cleanup:

```dart
// Document-level deletion - marks entire document for cleanup
syncLibrary.deleteDocument(documentUri);
// ↑ Framework handles document-level tombstone, affects all resources within

// Note: Direct manipulation of document metadata is NOT supported:
// syncLibrary.addTriple(documentUri, 'crdt:deletedAt', timestamp); // ILLEGAL
// ↑ Document metadata belongs to framework, not application control
```

**Key Principles:**
- **Document-Level Scope:** Deletion affects entire documents, not individual resources
- **Developer Choice:** Use framework deletion only when business-level soft deletion isn't sufficient
- **Explicit Cleanup:** Framework deletion provides eventual cleanup with retention policies

**Application vs System Deletion:**

The framework distinguishes between application-level "deletion" semantics and system-level cleanup operations:

- **Application Layer:** Developers typically implement domain-specific soft deletion (`status: "archived"`, `visibility: "hidden"`) using their own vocabulary and business logic
- **System Layer:** Framework deletion (`crdt:deletedAt`) is for true cleanup - storage optimization, retention compliance, and document lifecycle management
- **Layered Approach:** Applications may use both - soft deletion for user-facing features, framework deletion for backend cleanup policies

This separation allows developers to maintain full control over user-visible deletion semantics while leveraging the framework's sophisticated distributed cleanup infrastructure when genuine resource removal is required.

#### 4.6.3. Property Tombstone Implementation

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

#### 4.6.4. Design Rationale

This framework deliberately uses fragment identifiers for reification statements rather than the more common blank nodes, reflecting the distributed coordination requirements of CRDT synchronization:

**Traditional RDF Reification:** Typically uses blank nodes since statements are considered "local to document" without inherent web identity:
```turtle
# Traditional approach (NOT used in this framework)
_:tombstone a rdf:Statement;
  rdf:subject :it;
  rdf:predicate schema:keywords;
  rdf:object "quick";
  crdt:deletedAt "2024-09-02T14:30:00Z"^^xsd:dateTime .
```

**Distributed CRDT Requirements:** The collaborative nature of CRDT synchronization requires deterministic identification of the same logical deletion across installations:

1. **Cross-Installation Coordination:** Multiple client installations must identify the same logical deletion when merging tombstone states
2. **Merge Efficiency:** Fragment identifiers are more efficient during merge operations than blank node identity resolution

**Technical Alternative:** Blank nodes with canonical form identification (Section 3.2) would also work, but fragment identifiers provide simpler merge processing and better debuggability.

**Key Insight:** While traditional RDF treats reification as document-local metadata, CRDT frameworks require deterministic identification of deletion markers across the collaborative system.

**RDF Reification Choice:** RDF Reification is semantically correct for tombstones because we need to mark statements as deleted without asserting them. RDF-Star syntax would incorrectly assert the triple.

## 5. Architectural Data Layers

Having established the fundamental concepts of identity and lifecycle management, we can now examine how CRDT-managed resources are structured and organized. The architecture is composed of four distinct layers, moving from the fundamental structure of the data to the high-level strategies used by an application.

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
@prefix sync: <https://w3id.org/solid-crdt-sync/vocab/sync#> .
@prefix idx: <https://w3id.org/solid-crdt-sync/vocab/idx#> .
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
   idx:belongsToIndexShard <../../indices/recipes/index-full-a1b2c3d4/shard-mod-md5-2-0-v1_0_0> .
```

### 5.2. Layer 2: The Merge Contract

This layer defines the "how" of data integrity. It is a public, application-agnostic contract that ensures any two applications can merge the same data and arrive at the same result. It consists of two parts: the high-level rules and the low-level mechanics.

**Fundamental Principle:** All documents stored in user Pods by this framework (except for the standard solid type index which cannot be fully managed by us) are designed to be merged using the CRDT mechanics described in this layer. This ensures deterministic conflict resolution and maintains data consistency across distributed installations.

* **The Rules (`sync:` vocabulary):** A separate, published RDF file defines the merge behavior for a class of data by linking its properties to specific CRDT algorithms.

* **The Mechanics (`crdt:` vocabulary):** To execute the rules, low-level metadata is embedded within the data resource itself. This includes **Hybrid Logical Clocks** for versioning and **Document Tombstones** for managing deletions.

#### 5.2.1. Merge Contract Fundamentals

**What Are Merge Contracts?**

Merge contracts are public RDF documents that define how to resolve conflicts when merging data from multiple sources. They act as "rule books" that ensure any two CRDT-enabled applications can merge the same data and arrive at identical results.

**Critical: Contracts Are Hosted Externally, Not in User Pods**

Merge contracts are **published by application authors or this specification at stable internet URIs** (e.g., `https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v1`), not stored in user Pods. This separation is essential because:
- **Stability:** Contracts must remain accessible even if individual user Pods are offline
- **Interoperability:** Multiple applications can reference the same contract without coordination
- **Version control:** Application authors manage contract evolution independently of user data
- **Trust:** Users can inspect the merge rules their data follows by examining public contracts

**How Merge Contracts Work:**

1. **Property-to-CRDT Mapping:** Each RDF property is linked to a specific CRDT algorithm (LWW-Register, OR-Set, etc.)
2. **External Reference:** Resources point to their merge contract via `sync:isGovernedBy` using stable internet URIs
3. **Deterministic Merging:** Applications follow the published rules to merge conflicting changes
4. **Interoperability:** Different applications using the same contracts can safely collaborate

**The Two Scoping Approaches:**

The framework supports two different ways to define merge rules, each serving different purposes:

**Property Mapping (Class-Scoped Rules):**
- Rules defined within `mc:ClassMapping` apply **only within that specific class context**
- Example: `rdf:subject` might use LWW-Register when within `rdf:Statement` resources, but different rules elsewhere
- **Use case:** When the same predicate needs different merge behavior in different contexts

```turtle
# Property mapping: rdf:subject behavior scoped to rdf:Statement context
mappings:statement-v1 a mc:ClassMapping;
   mc:appliesToClass rdf:Statement;
   mc:rule
     [ mc:predicate rdf:subject; algo:mergeWith algo:LWW_Register ] .
```

**Predicate Mapping (Global Rules):**
- Rules defined within `mc:PredicateMapping` apply **globally across all contexts**
- Example: `crdt:installationId` **always** uses LWW-Register regardless of which resource contains it
- **Use case:** Framework-level predicates that need consistent behavior everywhere

```turtle
# Predicate mapping: Global behavior across all contexts
<#clock-mappings> a mc:PredicateMapping;
   mc:rule
     [ mc:predicate crdt:installationId; algo:mergeWith algo:LWW_Register; mc:isIdentifying true ],
     [ mc:predicate crdt:logicalTime; algo:mergeWith algo:LWW_Register ],
     [ mc:predicate crdt:physicalTime; algo:mergeWith algo:LWW_Register ],
     [ mc:predicate crdt:deletedAt; algo:mergeWith algo:OR_Set ] .
```

**Why Both Are Needed:**

- **Framework predicates** (like `crdt:installationId`, `crdt:deletedAt`) need consistent behavior across all resources → Global predicate mappings
- **Application data** (like `schema:name`, `schema:keywords`) may need context-specific behavior → Class-scoped property mappings
- **Hybrid approach** allows framework consistency while enabling application flexibility

**Semantic Impact:** This distinction is crucial for understanding merge behavior. A predicate like `schema:name` might use LWW-Register when within `schema:Recipe` resources but could theoretically use OR-Set when within `schema:Organization` resources if different mapping contracts specify different behaviors. However, framework predicates like `crdt:installationId` and `crdt:deletedAt` maintain consistent semantics everywhere through global predicate mappings.

#### 5.2.2. Merge Contract Import Hierarchy and Examples

This section demonstrates how the hierarchical import system works in practice, showing how framework-provided mappings are reused across different application domains.

##### 5.2.2.1. Framework Import Mechanism

The framework provides a reusable mapping library (`mappings:core-v1`) that defines standard behavior for all CRDT infrastructure predicates. Applications import this library and add their domain-specific rules on top.

##### 5.2.2.2. Complete Example: Shopping List Entry

**Data Resource:** `https://alice.podprovider.org/data/shopping-entries/created/2024/08/weekly-shopping-001`

This resource demonstrates semantic date-based organization and shows how shopping list entries integrate with the meal planning workflow.

```turtle
@prefix schema: <https://schema.org/> .
@prefix sync: <https://w3id.org/solid-crdt-sync/vocab/sync#> .
@prefix idx: <https://w3id.org/solid-crdt-sync/vocab/idx#> .
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
   meal:derivedFrom <../../../../recipes/tomato-basil-soup#it> ;
   # Links to the meal plan date that requires this ingredient
   meal:requiredForDate "2024-08-15"^^xsd:date ;
   schema:dateCreated "2024-08-10T10:30:00Z"^^xsd:dateTime .

# -- Pointers to Other Layers --
<> a sync:ManagedDocument;
   foaf:primaryTopic :it;
   # Uses a different DocumentMapping for shopping list entries (imports CRDT library + shopping mappings)
   sync:isGovernedBy <https://kkalass.github.io/meal-planning-app/crdt-mappings/shopping-entry-v1> ;
   # Points to index shard within the appropriate group
   idx:belongsToIndexShard <../../../../../indices/shopping-entries/index-grouped-e5f6g7h8/groups/2024-08/shard-mod-md5-4-0-v1_0_0> .
```

**Following the Merge Contract Link: shopping-entry-v1**

Now let's examine what the `shopping-entry-v1` merge contract actually contains. This shows how the framework imports standard CRDT mappings and defines application-specific rules:

```turtle
# At https://kkalass.github.io/meal-planning-app/crdt-mappings/shopping-entry-v1
@prefix sync: <https://w3id.org/solid-crdt-sync/vocab/sync#> .
@prefix mc: <https://w3id.org/solid-crdt-sync/vocab/merge-contract#> .
@prefix algo: <https://w3id.org/solid-crdt-sync/vocab/crdt-algorithms#> .
@prefix crdt: <https://w3id.org/solid-crdt-sync/vocab/crdt-mechanics#> .
@prefix mappings: <https://w3id.org/solid-crdt-sync/mappings/> .
@prefix schema: <https://schema.org/> .
@prefix meal: <https://example.org/vocab/meal#> .

<> a mc:DocumentMapping;
   # Import the standard CRDT vocabulary mappings (framework-provided)
   mc:imports ( mappings:core-v1 );
   
   # Define shopping-specific property mappings
   mc:classMapping ( [
     a mc:ClassMapping;
     mc:appliesToClass meal:ShoppingListEntry;
     mc:rule
       [ mc:predicate schema:name; algo:mergeWith algo:LWW_Register ],
       [ mc:predicate meal:quantity; algo:mergeWith algo:LWW_Register ],
       [ mc:predicate meal:unit; algo:mergeWith algo:LWW_Register ],
       [ mc:predicate meal:derivedFrom; algo:mergeWith algo:LWW_Register ],
       [ mc:predicate meal:requiredForDate; algo:mergeWith algo:LWW_Register ],
       [ mc:predicate schema:dateCreated; algo:mergeWith algo:LWW_Register ]
   ] ) .
```

##### 5.2.2.3. The Contract Hierarchy

**How Import Resolution Works:**

1. **Framework Import:** `mc:imports ( mappings:core-v1 )` brings in standard CRDT framework mappings for infrastructure predicates like `crdt:installationId`, `crdt:deletedAt`, `crdt:logicalTime`. These use global predicate mappings for consistent behavior across all contexts.

2. **Application Rules:** The local `mc:classMapping` defines domain-specific merge behavior for `meal:ShoppingListEntry` properties. All properties use `algo:LWW_Register` since shopping items are typically single-user managed.

3. **Precedence Resolution:** Conflicts are resolved using deterministic precedence order following the specificity principle (why `rdf:List` is used instead of multi-valued properties):
   1. **Local Class Mappings** (highest priority) - `mc:classMapping` 
   2. **Imported Class Mappings** - from `mc:imports` libraries
   3. **Local Predicate Mappings** - `mc:predicateMapping`
   4. **Imported Predicate Mappings** (lowest priority) - from `mc:imports` libraries
   
   **Key Principle:** Context-specific rules (class mappings) win over global rules (predicate mappings), regardless of local vs imported source. This ensures that specific behaviors defined for particular contexts aren't accidentally overridden by general global rules.


#### 5.2.3. Hybrid Logical Clock Mechanics

The state-based merge process uses **document-level Hybrid Logical Clocks (HLC)** for causality determination and intuitive tie-breaking. Each resource document has a single HLC that tracks changes to the entire document using both logical time (causality) and physical time (wall-clock).

**Hybrid Logical Clock Structure:**

```turtle
<> crdt:hasClockEntry [
    crdt:installationId <https://alice.podprovider.org/installations/550e8400-e29b-41d4-a716-446655440000> ;
    crdt:logicalTime "15"^^xsd:long ;  # Causality counter (tamper-proof)
    crdt:physicalTime "1693824600000"^^xsd:long  # Wall-clock timestamp (intuitive tie-breaking)
  ] ,
  [
    crdt:installationId <https://bob.podprovider.org/installations/6ba7b810-9dad-11d1-80b4-00c04fd430c8> ;
    crdt:logicalTime "8"^^xsd:long ;
    crdt:physicalTime "1693824550000"^^xsd:long
  ] ;
  # Pre-calculated hash for efficient index operations (includes both logical and physical times)
  crdt:clockHash "xxh64:abcdef1234567890" .  # Framework standard: xxh64 algorithm
```

**CRDT Literature Mapping:** The `crdt:installationId` property corresponds to what CRDT literature typically calls "client ID" or "node ID." We use "installation" to distinguish from Solid OIDC client identifiers, which identify applications rather than specific installation instances.

**Clock Entry Identification:**

Hybrid Logical Clock entries are context-identified blank nodes using the pattern:
`(document_IRI, crdt:installationId=<installation_IRI>)`

**Merge Process:**
1. **Causality Determination:** Compare logical clocks to determine document causality relationships
2. **Physical Time Tie-Breaking:** For concurrent logical operations, use physical time for "most recent wins" semantics
3. **Property-by-Property Merging:** Apply CRDT rules (LWW-Register, OR-Set, etc.) to individual properties
4. **Clock Updates:** Merge Hybrid Logical Clocks using standard union algorithms (max logical times, max physical times)

**Benefits of Hybrid Logical Clocks:**
- **Tamper-Resistant Causality:** Logical time protects against clock manipulation
- **Intuitive Tie-Breaking:** Physical time provides "newer wins" semantics
- **Related Change Coherence:** Operations done together tend to win/lose together across properties and documents
- **Clock Skew Tolerance:** Physical time bias doesn't affect convergence, only fairness

**Detailed Algorithms:** For comprehensive merge algorithms, Hybrid Logical Clock mechanics, and edge case handling, see [CRDT-SPECIFICATION.md](CRDT-SPECIFICATION.md).

#### 5.2.4. Vocabulary Versioning and Evolution

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
- Clients handle unknown properties by defaulting to `crdt:LWW_Register` merge behavior when using known contracts
- Different or unknown contracts trigger fallback to document-level `crdt:LWW_Register` (entire resource wins based on Hybrid Logical Clock)
- Framework vocabularies evolve through major version URI changes when needed

### 5.3. Layer 3: The Indexing Layer

This layer is **vital for change detection and synchronization efficiency**. It defines a convention for how data can be indexed for fast access and change monitoring. While the amount of header information stored in indices is optional (some may contain only Hybrid Logical Clock hashes), the indexing layer itself is required for the framework to efficiently detect when resources have changed. For detailed sharding algorithms and performance optimization strategies, see [SHARDING.md](SHARDING.md) and [PERFORMANCE.md](PERFORMANCE.md).

#### 5.3.1. Index Architecture Overview

The framework provides two fundamental indexing approaches to handle different data organization patterns:

**FullIndex (Monolithic Approach):**
- **Purpose:** Single index covering an entire dataset
- **Use cases:** Bounded, searchable collections where you want global access
- **Examples:** Personal recipe collection, document library, contact list
- **Structure:** One index with multiple shards for performance (technical partitioning)
- **Benefits:** Simple discovery, global search capabilities, unified management

**GroupIndexTemplate + GroupIndex (Grouped Approach):**
- **Purpose:** Data split into logical groups, each with its own index
- **Use cases:** Unbounded or naturally-grouped data where you work with specific subsets
- **Examples:** Shopping entries by month, financial transactions by year, email by folder
- **Structure:** Template defines grouping rules, individual GroupIndex instances for each group
- **Benefits:** Scales to unlimited data size, efficient partial sync, natural organization

**Key Architectural Distinction:**
- **Groups** = Logical organization (August 2024 shopping entries, Italian recipes, Q3 transactions)
- **Shards** = Technical performance optimization (split large indices for parallel processing)

**When to Choose Each Pattern:**

| Pattern | Best For | Examples | Scaling |
|---------|----------|----------|---------|
| **FullIndex** | Bounded datasets you browse/search globally | Recipes (≤1000s), Contacts, Documents | Limited by total size |
| **GroupIndexTemplate** | Unbounded datasets with natural groupings | Shopping by month, Transactions by year | Unlimited (groups stay small) |

**Index Convention:** Indices are separate CRDT resources that **minimally contain a lightweight hash of each document's Hybrid Logical Clock** for change detection. They may optionally contain additional "header" information extracted from **resource properties** (like `schema:name`, `schema:dateCreated`) to support on-demand synchronization scenarios.

**Important Distinction:** While the Hybrid Logical Clock hash tracks document-level changes, the header properties come from specific resources within those documents. For example, a recipe's `schema:name` property belongs to the `recipe#it` resource, not the document itself, but gets included in index headers for efficient discovery.

**Index Entry CRDT Behavior:** All index entry properties use **LWW-Register (Last Writer Wins)** merge semantics, regardless of the CRDT algorithms used in the original indexed resources. This design choice:
- **Simplifies architecture**: Avoids complex mapping file inheritance and type registry mechanisms  
- **Recognizes index entries as cached data**: Index entries are performance optimizations, not authoritative sources
- **Provides acceptable trade-offs**: Slight inconsistencies between index and source data are less critical than system simplicity
- **Enables self-healing**: Index entries can be regenerated from authoritative sources if inconsistencies become problematic
- **Maintains predictable semantics**: "Last installation to update this index entry wins" is simple and deterministic

**Bidirectional Index Maintenance:** All index operations require updating both the index shard entries and the corresponding `idx:belongsToIndexShard` references in the indexed documents. Removing a document from an index means removing both its shard entry and updating the document to remove its `idx:belongsToIndexShard` reference to that shard. This principle applies to all indexing operations: population, cleanup, document updates, and maintenance tasks.

#### 5.3.2. Framework Vocabulary

The `idx:` vocabulary provides the building blocks for both indexing approaches:

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

**Indexing Flexibility:** While most indices focus on primary resources (like `recipe#it`), the framework supports indexing any resource within a document. For example, a recipe document could have both a recipe index (indexing `recipe#it` for name, prep time) and a nutrition index (indexing `recipe#nutrition` for calories, protein). Both resources sync together via the same document-level Hybrid Logical Clock but serve different discovery purposes.
* **`idx:groupedBy`:** Links GroupIndexTemplate to its GroupingRule
* **`idx:property`:** Multi-value property linking to GroupingRuleProperty instances (in GroupingRule)
* **`idx:shardingAlgorithm`:** Specifies the sharding algorithm configuration
* **`idx:GroupingRule`:** Class defining how resources are assigned to groups
* **`idx:GroupingRuleProperty`:** Individual property specification within a GroupingRule
* **`idx:sourceProperty`:** Property to extract grouping value from (in GroupingRuleProperty)
* **`idx:transform`:** Optional regex transform for value normalization (in GroupingRuleProperty) - see [Group Indexing Specification](GROUP-INDEXING.md)  
* **`idx:hierarchyLevel`:** Optional hierarchy level for multi-property grouping (in GroupingRuleProperty)
* **`idx:missingValue`:** Default value when property is absent (in GroupingRuleProperty)
* **`idx:ModuloHashSharding`:** Class specifying hash-based shard distribution

#### 5.3.3. GroupingRule Specification

GroupIndexTemplate uses a GroupingRule to determine which group(s) a resource belongs to. This system supports conditional indexing (resources only indexed when certain properties are present) and multi-dimensional grouping.

For detailed information on regex transforms and group key formatting, see [Group Indexing Specification](GROUP-INDEXING.md).

**GroupingRule Algorithm:**

The GroupingRule determines group membership using the following process:

1. **Property Extraction:** For each `idx:GroupingRuleProperty`, extract all values for `idx:sourceProperty` from the resource
2. **Missing Value Handling:** If a property has no values:
   - **With `idx:missingValue`:** Use the specified default value
   - **Without `idx:missingValue`:** Return empty set (resource joins no groups)
3. **Permutation Generation:** Compute Cartesian product of all property value sets
4. **Transform Application:** Apply `idx:transform` to each value if specified
5. **Path Generation:** Generate deterministic group paths using hierarchy levels:
   - **With `idx:hierarchyLevel`:** Sort properties by level, create nested path structure
   - **Without hierarchy levels:** Sort properties by source IRI lexicographically, join with '-' separator
6. **Set Deduplication:** Convert the list of group identifiers to a set, removing duplicates that arise from different source values formatting to the same string
7. **Group Creation:** Create GroupIndex instances for all unique group identifiers

**Configuration Structure:**
```turtle
idx:groupedBy [
  a idx:GroupingRule;
  idx:property [
    a idx:GroupingRuleProperty;
    idx:sourceProperty <predicate>;     # RDF property to extract from
    idx:transform (                     # Optional value transformation list
      [
        a idx:RegexTransform;
        idx:pattern "^([0-9]{4})-([0-9]{2})-([0-9]{2})$";
        idx:replacement "${1}-${2}"
      ]
    ) ;
    idx:hierarchyLevel 1;               # Optional hierarchy level (default: 1)
    idx:missingValue "default"          # Optional default if property absent
  ];
  # No groupTemplate - paths generated deterministically
];
```

**Common Patterns:**

*Simple Time-Based Grouping:*
```turtle
idx:property [
  idx:sourceProperty schema:dateCreated;
  idx:transform (
    [
      a idx:RegexTransform;
      idx:pattern "^([0-9]{4})-([0-9]{2})-([0-9]{2})$";
      idx:replacement "${1}-${2}"
    ]
  ) .
];
# Result: groups/2024-08/index, groups/2024-09/index, etc.
```

*Hierarchical Time-Based Grouping:*
```turtle
idx:property [
  idx:sourceProperty schema:dateCreated;
  idx:transform (
    [
      a idx:RegexTransform;
      idx:pattern "^([0-9]{4})-[0-9]{2}-[0-9]{2}$";
      idx:replacement "${1}"
    ]
  ) ;
  idx:hierarchyLevel 1
], [
  idx:sourceProperty schema:dateCreated;
  idx:transform (
    [
      a idx:RegexTransform;
      idx:pattern "^[0-9]{4}-([0-9]{2})-[0-9]{2}$";
      idx:replacement "${1}"
    ]
  ) ;
  idx:hierarchyLevel 2
];
# Result: groups/2024/08/index, groups/2024/09/index, etc.
```

*Conditional Registration:*
```turtle
idx:property [
  idx:sourceProperty crdt:deletedAt;
  idx:transform (
    [
      a idx:RegexTransform;
      idx:pattern "^([0-9]{4})-[0-9]{2}-[0-9]{2}$";
      idx:replacement "${1}"
    ]
  ) .
  # No missingValue = no group if property absent
];
# Only documents WITH crdt:deletedAt get indexed
# Result: groups/2024/index, groups/2025/index, etc.
```

*Multi-Property Flat Grouping:*
```turtle
idx:property [
  idx:sourceProperty schema:dateCreated;
  idx:transform (
    [
      a idx:RegexTransform;
      idx:pattern "^([0-9]{4})-([0-9]{2})-([0-9]{2})$";
      idx:replacement "${1}-${2}"
    ]
  ) .
], [
  idx:sourceProperty schema:category
  # No transform = use property value directly
];
# Resource with dateCreated="2024-08-15", category="work"
# Result: groups/2024-08-work/index (lexicographic IRI ordering)
```

#### 5.3.4. Sharding and Performance

Both FullIndex and GroupIndex instances use **sharding** for performance optimization. This is a technical implementation detail that splits large indices into smaller, parallel-processable chunks.

**Key Principles:**
- **Deterministic assignment:** Each resource always maps to the same shard
- **Automatic scaling:** System increases shard count when size thresholds are exceeded (default: 1000 entries per shard)
- **Lazy migration:** Shard rebalancing happens opportunistically during normal operations
- **Self-describing names:** Shard names encode their configuration for automatic coordination

**Example Shard Structure:**
```turtle
<index> idx:hasShard <shard-mod-md5-4-0-v1_2_0>, <shard-mod-md5-4-1-v1_2_0>,
                     <shard-mod-md5-4-2-v1_2_0>, <shard-mod-md5-4-3-v1_2_0> .
```

**Implementation Details:** For comprehensive sharding algorithms, migration procedures, and version handling, see [SHARDING.md](SHARDING.md).

#### 5.3.5. Structure-Derived Index Naming

**Coordination-Free Index Convergence:**

Multiple CRDT-enabled applications automatically converge on shared indices through deterministic structure-derived naming, eliminating coordination overhead while ensuring compatibility.

**Deterministic Naming Pattern:**
- **FullIndex:** `index-full-${SHA256(indexedClassIRI|shardingAlgorithmClass|hashAlgorithm)}/index`
- **GroupIndexTemplate:** `index-grouped-${SHA256(groupingRuleProperties|indexedClassIRI|shardingAlgorithmClass|hashAlgorithm)}/index`
- **Hash computation:** SHA256 with pipe separators (`|`) between all structural inputs
- **Full IRI usage:** Hash computation uses complete IRIs, not prefixed forms
- **Directory structure:** Hash-derived directory name + consistent `index` document
- **GroupingRuleProperties serialization:** Each GroupingRuleProperty serialized as `sourceProperty|transformList|hierarchyLevel|missingValue`, where transformList uses canonical transform format (see below), multiple properties sorted using the same ordering rules as path generation (hierarchy level first, then lexicographic IRI ordering for properties without explicit levels) and concatenated with `&` separator
- **Transform List Canonical Format:** Each RegexTransform serialized as `<https://w3id.org/solid-crdt-sync/vocab/idx#RegexTransform>{"pattern":"escaped_pattern","replacement":"escaped_replacement"}` where strings are JSON-escaped, multiple transforms separated by `|`, empty list represented as empty string

**Hash Computation Examples:**
```turtle
# FullIndex for recipes
# Input: "https://schema.org/Recipe|ModuloHashSharding|md5"
# Directory: /indices/recipes/index-full-a1b2c3d4/
# Document: /indices/recipes/index-full-a1b2c3d4/index

# GroupIndexTemplate for shopping entries with single property
# groupingRuleProperties: "https://example.org/vocab/meal#requiredForDate|<https://w3id.org/solid-crdt-sync/vocab/idx#RegexTransform>{\"pattern\":\"^([0-9]{4})-([0-9]{2})-([0-9]{2})$\",\"replacement\":\"${1}-${2}\"}||"
# (format: sourceProperty|transformList_canonical|hierarchyLevel|missingValue - empty missingValue at end)
# Input: "https://example.org/vocab/meal#requiredForDate|<https://w3id.org/solid-crdt-sync/vocab/idx#RegexTransform>{\"pattern\":\"^([0-9]{4})-([0-9]{2})-([0-9]{2})$\",\"replacement\":\"${1}-${2}\"}|||groups/{monthYear}/index|https://example.org/vocab/meal#ShoppingListEntry|ModuloHashSharding|md5"
# Directory: /indices/shopping-entries/index-grouped-e5f6g7h8/
# Document: /indices/shopping-entries/index-grouped-e5f6g7h8/index

# GroupIndexTemplate with single property (GC index example)
# groupingRuleProperties: "https://w3id.org/solid-crdt-sync/vocab/crdt#deletedAt|<https://w3id.org/solid-crdt-sync/vocab/idx#RegexTransform>{\"pattern\":\"^([0-9]{4})-[0-9]{2}-[0-9]{2}$\",\"replacement\":\"${1}\"}||"
# Input: "https://w3id.org/solid-crdt-sync/vocab/crdt#deletedAt|<https://w3id.org/solid-crdt-sync/vocab/idx#RegexTransform>{\"pattern\":\"^([0-9]{4})-[0-9]{2}-[0-9]{2}$\",\"replacement\":\"${1}\"}|||gc/{deletionYear}/index|https://w3id.org/solid-crdt-sync/vocab/sync#ManagedDocument|ModuloHashSharding|md5"
# Directory: /indices/gc/index-grouped-f9g8h7i6/
# Document: /indices/gc/index-grouped-f9g8h7i6/index

# GroupIndexTemplate with multiple properties
# Two properties: rdf:type and schema:keywords
# groupingRuleProperties: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type|||&https://schema.org/keywords|||default"
# (sorted by sourceProperty IRI, joined with &, empty transform lists represented as empty string)
# Input: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type|||&https://schema.org/keywords|||default|groups/{type}-{keyword}/index|https://schema.org/Recipe|ModuloHashSharding|md5"
```

**Automatic Convergence Property:**
Applications with identical structural requirements generate identical index names, enabling automatic collaboration without explicit coordination.

**Discovery-First Bootstrap Flow:**
1. **Discovery:** Query Type Index for existing indices of required type and class
2. **Structural analysis:** Evaluate discovered indices for compatibility  
3. **Join or create:** Add self as reader to compatible index OR create new index with structure-derived name
4. **Collaborative population:** All installations participate in distributed population using populating shards and background processing

**Immutable vs Extendable Properties:**

**Immutable (encoded in name, enforced by `crdt:Immutable` or `crdt:FWW_Register`):**
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
# App A and App B both need FullIndex for recipes with md5
# → Both generate identical name: index-full-a1b2c3d4
# → Automatic sharing through convergent naming

# App C needs GroupIndexTemplate for recipes with weekly grouping  
# → Different structural hash: index-grouped-f9g0h1i2
# → Separate index to avoid incompatible structural conflicts
```

**Performance Impact Management:**
- **Write overhead awareness:** Every additional index increases write operation overhead for all installations
- **Property-level optimization:** Framework automatically removes unused `idx:indexedProperty` entries when last reader is tombstoned (see Section 5.8 for index lifecycle management)
- **Reader list maintenance:** Framework automatically removes tombstoned installations from `idx:readBy` lists, enabling index tombstoning when no active readers remain (see Section 5.8)

#### 5.3.6. Index Population Mechanics

Index population occurs in two scenarios: when creating a new index, or when syncing an existing index that is still in populating state.

**Population Variants Overview:**

The framework uses two different approaches for population based on the index type:

**FullIndex Population:** Works directly on target shards that will be used for normal operations. The `idx:hasPopulatingShard` list contains the same shard names as `idx:hasShard`, enabling unified progress tracking.

**GroupIndexTemplate Population:** Uses temporary coordination shards (`pop-` prefix) to distribute work across installations. These temporary shards coordinate creation of actual GroupIndex instances and are tombstoned when complete.

**Unified Population Process:**

**Index Creation Process:**
1. **Directory scan:** Creating installation recursively lists all resource IRIs from data container and subfolders
2. **Initial structure:** 
   - **For FullIndex:** Create index and target shards with minimal entries (resource IRIs only), list target shards in both `idx:hasShard` and `idx:hasPopulatingShard`
   - **For GroupIndexTemplate:** Create index and temporary populating shards for coordination work
   (See [SHARDING.md](SHARDING.md) for shard count determination details)

**Distributed Processing Algorithm:**
When any installation encounters a populating index during sync:
1. **Work distribution:** Each installation computes `hash(installationIRI + shardIRI)` for each shard in `idx:hasPopulatingShard`
2. **Priority ordering:** Sort shards by hash value (different order per installation)
3. **Sequential processing:** Process shards in priority order until all complete
4. **Collaborative completion:** Multiple installations work simultaneously, CRDT merge resolves conflicts

**Per-Shard Processing:**
1. **Fetch current state:** GET populating shard from Pod
2. **CRDT merge:** Merge with local processing state
3. **Check completeness:** Verify if shard needs processing
4. **Population work:** 
   - **For FullIndex:** Read resources, add `idx:belongsToIndexShard` back-pointers, calculate HLC hashes, populate shard entries
   - **For GroupIndexTemplate:** Read resources, determine group assignments, add `idx:belongsToIndexShard` back-pointers to GroupIndex shards, create GroupIndex instances, populate both populating shard and target group shards
5. **Completion marking:** 
   - **For FullIndex:** Remove shard from `idx:hasPopulatingShard` OR-Set
   - **For GroupIndexTemplate:** Tombstone populating shard with `crdt:deletedAt` AND remove from `idx:hasPopulatingShard` OR-Set
6. **Upload:** PUT updated shard and index to Pod
   - **ETag optimization:** Store ETags from GET responses, use `If-Match` headers on PUT to detect concurrent modifications
   - **On 412 Precondition Failed:** GET current state, perform CRDT merge with local changes, retry PUT with merged result

**State Transition to Active:**

*LWW-Register State Machine for `idx:populationState`:*
1. **Initial State:** Index created with `idx:populationState "populating"`
2. **Completion Detection:** Installation detects `idx:hasPopulatingShard` is empty (all shards completed)
3. **State Update:** Installation attempts `idx:populationState "active"` with current Hybrid Logical Clock
4. **Collaborative Resolution:** Multiple installations may attempt transition simultaneously
   - LWW-Register ensures deterministic convergence to "active" state
   - Hybrid Logical Clock comparison resolves concurrent updates

**Concrete Examples:**

**FullIndex during population:**
```turtle
<FullIndex>
   idx:populationState "populating";
   idx:hasPopulatingShard <shard-mod-md5-2-0-v1_0_0>, <shard-mod-md5-2-1-v1_0_0>;
   # Target shards created with minimal entries (resource IRIs only)
   idx:hasShard <shard-mod-md5-2-0-v1_0_0>, <shard-mod-md5-2-1-v1_0_0> .
```

**GroupIndexTemplate during population:**
```turtle
<GroupIndexTemplate>
   idx:populationState "populating";
   # Temporary coordination shards for distributed work
   idx:hasPopulatingShard <pop-mod-md5-4-0-v1_0_0>, <pop-mod-md5-4-1-v1_0_0>, 
                          <pop-mod-md5-4-2-v1_0_0>, <pop-mod-md5-4-3-v1_0_0> .
```

#### 5.3.7. Installation Index Management and Scalability

**Installation Management Strategy:** Within the framework's design constraints of 2-100 installations, installation management uses a dedicated **Framework Installation Index** combined with periodic **Management Phase** operations (detailed in Section 6.2).

**Framework Installation Index:**
Rather than expensive Type Index container scanning, the framework maintains a dedicated installation index that provides efficient batch access to installation states:

```turtle
# At /indices/framework/installations-index-${hash}/index  
<> a idx:FullIndex;
   sync:isGovernedBy mappings:index-v1;
   idx:indexesClass crdt:ClientInstallation;
   idx:indexedProperty [
     idx:trackedProperty crdt:lastActiveAt;        # For dormancy detection
     idx:readBy <installation-1>, <installation-2>
   ], [
     idx:trackedProperty crdt:maxInactivityPeriod; # For cleanup thresholds
     idx:readBy <installation-1>, <installation-2>  
   ] .
```

**Operational Benefits:**
- **Efficient reader list management**: Management phase can batch-validate installation states without individual Pod requests
- **Collaborative dormancy detection**: Multiple installations can safely coordinate cleanup through CRDT operations
- **Scalable at target range**: Direct OR-Set management of `idx:readBy` lists works efficiently for 2-100 installations
- **Framework consistency**: Uses same indexing patterns as user data

**Management Phase Integration:** Installation lifecycle operations (dormancy detection, reader list cleanup, tombstone processing) are handled through periodic Management Phase operations rather than during every sync. See Section 6.2 for detailed algorithms and coordination mechanisms.

**Beyond Design Scale:** For scenarios exceeding 100 installations, different architectural patterns might be more appropriate than extending this framework.

#### 5.3.8. Index Structure Examples

The following examples demonstrate concrete RDF structures for different types of indices, showing how the indexing architecture works in practice with real data.

**Example 1: A `GroupIndexTemplate` at `https://alice.podprovider.org/indices/shopping-entries/index-grouped-e5f6g7h8/index`**
This resource is the "rulebook" for all shopping list entry groups in our meal planning application. The name hash is derived from SHA256 of the canonical transform format shown in section 5.3.5. Note that it has no `idx:indexedProperty` because shopping entries are typically loaded in full groups, requiring only Hybrid Logical Clock hashes for change detection.

```turtle
@prefix sync: <https://w3id.org/solid-crdt-sync/vocab/sync#> .
@prefix idx: <https://w3id.org/solid-crdt-sync/vocab/idx#> .
@prefix schema: <https://schema.org/> .
@prefix mappings: <https://w3id.org/solid-crdt-sync/mappings/> .
@prefix meal: <https://example.org/vocab/meal#> .

# Note: The mappings: namespace contains CRDT merge contracts for specification components
# such as group-index-template-v1, group-index-v1, shard-v1, full-index-v1

<> a idx:GroupIndexTemplate;
   sync:isGovernedBy mappings:index-v1;
   idx:indexesClass meal:ShoppingListEntry;
   # No idx:indexedProperty needed - groups are loaded fully
   # A default sharding algorithm for all group indices created under this rule.
   # Resources within each group are assigned to shards using: hash(resourceIRI) % numberOfShards
   idx:shardingAlgorithm [
     a idx:ModuloHashSharding;
     idx:hashAlgorithm "md5";  # Framework standard: md5 provides fast, consistent hashing
     idx:numberOfShards 4
   ] ;
   sync:isGovernedBy mappings:group-index-template-v1;

   # The declarative rule for how to assign items to group indices.
   idx:groupedBy [
     a idx:GroupingRule;
     idx:property [
       a idx:GroupingRuleProperty;
       idx:sourceProperty meal:requiredForDate;
       idx:transform (
         [
           a idx:RegexTransform;
           idx:pattern "^([0-9]{4})-([0-9]{2})-([0-9]{2})$";
           idx:replacement "${1}-${2}"
         ]
       ) .
     ];
     # No groupTemplate - paths generated deterministically as: groups/{yyyy-MM}/index
   ].
```

**Example 2: A `GroupIndex` document at `https://alice.podprovider.org/indices/shopping-entries/index-grouped-e5f6g7h8/groups/2024-08/index`**
This is a concrete index for shopping list entries from August 2024 meal plans.

```turtle
@prefix sync: <https://w3id.org/solid-crdt-sync/vocab/sync#> .
@prefix idx: <https://w3id.org/solid-crdt-sync/vocab/idx#> .

<> a idx:GroupIndex;
   sync:isGovernedBy mappings:index-v1;
   # Back-link to the rulebook.
   idx:basedOn <../../index-grouped-e5f6g7h8/index>;
   # Inherits configuration from GroupIndexTemplate:
   # - Sharding algorithm (ModuloHashSharding with md5, 4 shards)
   # - Indexed properties (none defined, so minimal entries only)
   # - CRDT merge contract (mappings:index-v1)
   # Since the template has no idx:indexedProperty defined, this group's shards
   # will contain only resource IRIs and Hybrid Logical Clock hashes (no header data).
   # It has its own list of active shards, which are sibling documents.
   idx:hasShard <shard-mod-md5-4-0-v1_0_0>, <shard-mod-md5-4-1-v1_0_0>, 
                <shard-mod-md5-4-2-v1_0_0>, <shard-mod-md5-4-3-v1_0_0> .
```

**Example 3: A Shard Document at `https://alice.podprovider.org/indices/shopping-entries/index-grouped-e5f6g7h8/groups/2024-08/shard-mod-md5-4-0-v1_0_0`**
This document contains entries pointing to shopping list data resources from August 2024. Since shopping entries are typically loaded in full groups, this index contains minimal entries (only resource IRI and Hybrid Logical Clock hash, no header properties).

```turtle
@prefix sync: <https://w3id.org/solid-crdt-sync/vocab/sync#> .
@prefix idx: <https://w3id.org/solid-crdt-sync/vocab/idx#> .
@prefix crdt: <https://w3id.org/solid-crdt-sync/vocab/crdt-mechanics#> .
@prefix mappings: <https://w3id.org/solid-crdt-sync/mappings/> .

<> a idx:Shard;
   sync:isGovernedBy mappings:shard-v1;
   idx:isShardOf <index>; # Back-link to its GroupIndex document
   # Note: Shard entries do not require explicit typing (a idx:ShardEntry) for space efficiency.
   # Instead, idx:resource is marked as identifying at the predicate level in mappings:shard-v1.
   idx:containsEntry [
     idx:resource <../../../../data/shopping-entries/created/2024/08/weekly-shopping-001>;
     crdt:clockHash "xxh64:abcdef1234567890"
   ],
   [
     idx:resource <../../../../data/shopping-entries/created/2024/08/weekly-shopping-002>;
     crdt:clockHash "xxh64:fedcba9876543210"
   ].
```

**Example 4: A Recipe Index for OnDemand Sync at `https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4/index`**
This is a `FullIndex` for Alice's recipe collection, configured for OnDemand synchronization to enable recipe browsing. The name hash is derived from SHA256(https://schema.org/Recipe|ModuloHashSharding|md5).

```turtle
@prefix sync: <https://w3id.org/solid-crdt-sync/vocab/sync#> .
@prefix idx: <https://w3id.org/solid-crdt-sync/vocab/idx#> .
@prefix schema: <https://schema.org/> .
@prefix mappings: <https://w3id.org/solid-crdt-sync/mappings/> .

<> a idx:FullIndex;
   sync:isGovernedBy mappings:index-v1;
   idx:indexesClass schema:Recipe;
   # Include properties needed for recipe browsing UI
   idx:indexedProperty [
     a idx:IndexedProperty;
     idx:trackedProperty schema:name;
     idx:readBy <installation-1>, <installation-2>
   ], [
     a idx:IndexedProperty;
     idx:trackedProperty schema:keywords;
     idx:readBy <installation-1>, <installation-2>
   ], [
     a idx:IndexedProperty;
     idx:trackedProperty schema:totalTime;
     idx:readBy <installation-1>, <installation-2>
   ];
   # Default sharding for the recipe collection
   # Resources are assigned to shards using: hash(resourceIRI) % numberOfShards
   idx:shardingAlgorithm [
     a idx:ModuloHashSharding;
     idx:hashAlgorithm "md5";
     idx:numberOfShards 2
   ];
   sync:isGovernedBy mappings:full-index-v1;
   # List of active shards containing recipe entries
   idx:hasShard <shard-mod-md5-2-0-v1_0_0>, <shard-mod-md5-2-1-v1_0_0> .
```

**Example 5: A Recipe Index Shard for OnDemand Sync at `https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4/shard-mod-md5-2-0-v1_0_0`**
This document contains entries for recipe resources. Since recipes are used with OnDemand sync, the index includes header properties (schema:name, schema:keywords, etc.) as specified in the FullIndex's `idx:indexedProperty` list to support browsing without loading full recipe data.

```turtle
@prefix sync: <https://w3id.org/solid-crdt-sync/vocab/sync#> .
@prefix idx: <https://w3id.org/solid-crdt-sync/vocab/idx#> .
@prefix crdt: <https://w3id.org/solid-crdt-sync/vocab/crdt-mechanics#> .
@prefix schema: <https://schema.org/> .
@prefix mappings: <https://w3id.org/solid-crdt-sync/mappings/> .

<> a idx:Shard;
   sync:isGovernedBy mappings:shard-v1;
   idx:isShardOf <index>;
   idx:containsEntry [
     idx:resource <../../data/recipes/tomato-basil-soup>;
     schema:name "Tomato Basil Soup";
     schema:keywords "vegan", "soup";
     schema:totalTime "PT30M";
     crdt:clockHash "xxh64:abcdef1234567890"
   ],
   [
     idx:resource <../../data/recipes/pasta-carbonara>;
     schema:name "Pasta Carbonara";
     schema:keywords "pasta", "italian";
     schema:totalTime "PT20M";
     crdt:clockHash "xxh64:fedcba9876543210"
   ].
```

### 5.4. Layer 4: The Sync Strategy

This is the client-side layer where the application developer configures how to synchronize data. The CRDT implementation balances **discovery** (finding existing Pod configuration) with **developer intent** (application requirements). Developers declare their preferred sync approach, and the implementation either uses discovered compatible indices or creates new ones as needed.

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

**Implementation Note:** The framework automatically handles index discovery and creation through structure-derived naming (see Section 4.3.4 for technical details). Developers simply declare their data organization needs, and the implementation manages the underlying index infrastructure.

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

For detailed performance analysis, benchmarks, and optimization guidance for each sync strategy, see [PERFORMANCE.md](PERFORMANCE.md).

## 6. Lifecycle Management

Having established the architectural layers, we now examine the complete lifecycle of resources, indices, and installations - from initial Pod setup through daily operations to long-term maintenance and cleanup.

### 6.1. Pod Setup and Initial Configuration

When an application first encounters a Pod, it may need to configure the Type Index and other Solid infrastructure. The framework provides standard templates for this initialization process (see [templates/README.md](../templates/README.md) for complete placeholder substitution documentation):

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

### 6.2. Installation Document Creation

After successful Pod setup, the framework automatically creates an Installation Document (`crdt:ClientInstallation`) to represent this specific client installation in the collaborative system. This document establishes the installation's identity and enables collaborative coordination with other installations.

**Lifecycle Role:**
The Installation Document serves as the foundation for all collaborative operations - index management, dormancy detection, and CRDT conflict resolution. It is registered in the system Installation Index and remains active until the installation is tombstoned.

**Tombstoned Installation Recovery:**
If an installation discovers its own document has been tombstoned (`max(crdt:deletedAt) > max(crdt:createdAt)`) **or cannot find its installation document remotely** (indicating it was tombstoned and later garbage collected), it must **not** attempt undeletion or continue using the stored installation ID. Instead, it creates a fresh installation identity and resets all internal state.

**Recovery Process:**
1. **Detection during startup:** Framework checks if its locally stored installation ID exists in the remote Installation Index
2. **Scenario A - Document found but tombstoned:** Proceed with fresh start
3. **Scenario B - Document not found:** Assume it was tombstoned and garbage collected, proceed with fresh start
4. **User notification:** Inform user that "this installation was deactivated due to inactivity and will be reset"
5. **Fresh start:** Generate new installation ID and reset all local caches/state
6. **Clean re-sync:** Re-synchronize all data from Pod with fresh collaborative state

**Critical Policy:**
An installation that has a locally stored installation ID but cannot find that specific ID in the remote Installation Index must assume it was tombstoned and subsequently garbage collected. It must **not** continue using the stored ID or attempt to recreate a document with that same ID - it must generate a completely new installation ID.

This approach ensures system integrity and prevents "zombie" installations from creating CRDT conflicts.

**Details:** See Section 4.2 for complete Installation Document specification, properties, and CRDT behavior.

### 6.3. System Index Setup

Before application-specific functionality can begin, the framework establishes essential system indices required for collaborative coordination and maintenance operations.

**Required System Indices:**
- **Installation Index:** For tracking all client installations (Section 4.2.2)
- **Framework Garbage Collection Index:** For tracking tombstoned documents (Section 6.6)

**Lifecycle Role:**
These indices follow standard creation and discovery rules (Chapter 4) but are established automatically during framework initialization. The Installation Index receives the installation document created in Section 5.2, enabling collaborative operations for subsequent application indices.

**Creation Timing:**
System indices are created before application indices to ensure the collaborative infrastructure is ready when applications begin data synchronization.

### 6.4. Application Index Setup

With system indices established, the framework creates application-specific indices based on the data types the application needs to synchronize. Applications declare their requirements and the framework establishes the appropriate index patterns (FullIndex or GroupIndexTemplate) following the rules in Chapter 4.

**Lifecycle Role:**
Application indices are created during startup or when first accessing new data types. The framework coordinates creation collaboratively - discovering existing compatible indices before creating new ones, and ensuring all installations can participate in the collaborative indexing.

**Synchronization Priority:**
All **required** application indices must be synchronized and merged before exposing functionality to users, ensuring consistent application state across installations. However, applications that can handle incomplete data may choose to use indices still in populating state, with the understanding that results will be incrementally complete as population progresses.

**Details:** See Chapter 4 for complete indexing patterns, creation rules, and collaborative coordination mechanisms.

### 6.5. Resource Creation and Naming

Once Pod setup is complete and all required system and application indices are established and synchronized, applications can begin creating data resources. Resource naming is a critical design decision that affects both performance and maintainability, requiring careful consideration of Pod filesystem limitations and RDF principles.

**The Performance Challenge:**
Most Pod servers (including Community Solid Server) use filesystem backends that can experience performance degradation with thousands of files in a single directory. While the framework uses sophisticated sharding for indices, data resources still need thoughtful organization.

**Fundamental Principle: IRIs Must Be Stable**
Resource IRIs are **identifiers**, not storage locations. Any organizational structure must derive from **invariant properties** of the resource that will never change. Changing IRIs breaks references and violates RDF principles.

**Recommended Naming Approaches:**

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

**Strategy Comparison:**

| Strategy | Best For | Performance | Discoverability | Trade-offs |
|----------|----------|-------------|-----------------|------------|
| **Semantic** | Human browsing, meaningful categories | Complex path computation, potential hotspots | High - paths are human-readable | Reorganization complexity if categories change |
| **UUID** | High throughput, even distribution | Optimal - predictable, evenly distributed | Low - requires index for discovery | Loss of human-readable structure |
| **Flat** | Small datasets, simple apps | Good for <1000 resources | Medium - browsable but no structure | Degrades with scale, directory limits |

**Resource Creation Workflow:**
1. **Generate stable IRI** using chosen naming strategy
2. **Determine target indices** - Identify all matching index shards based on:
   - Resource type
   - Group membership for GroupIndexTemplate patterns (resources may belong to multiple groups)  
   - Active shard status (exclude tombstoned or deleted shards)
3. **Prepare resource document** with semantic data, CRDT metadata, and `idx:belongsToIndexShard` links to target shards
4. **Upload resource document** to Pod storage
5. **Update index shards** - Add index entries to all target shards and upload updated shards to Pod (may be batched when creating multiple resources together)
6. **Resumption mechanism** - Implementations should track workflow state to resume interrupted operations at any step

**Fault Tolerance:**
Resource creation must be resumable after interruptions (network failures, app termination, etc.). The workflow is designed so each step can be retried independently, with the resource document serving as the source of truth for which shards need updating.

**Critical Guidelines:**
- **Never change IRIs**: Once published, IRIs are permanent identifiers - even if underlying properties change
- **Derive from invariants**: Path structure should be based on properties unlikely to change, but IRI stability takes precedence over semantic accuracy
- **Plan for scale**: Consider performance implications of naming choices early
- **Accept semantic drift**: If "invariant" properties do change, maintain the existing IRI and let CRDT merge behavior handle the data updates


### 6.6. Framework Garbage Collection Index

System-level index for tracking documents with deletion timestamps that require proactive cleanup. This includes temporary framework documents (populating shards) and complete user data documents marked for deletion, but **not property tombstones** which are handled during sync-time processing.

#### 6.6.1. Design and Structure

**Centralized Cleanup Strategy:**
Rather than scanning entire data containers, framework-managed documents with ANY `crdt:deletedAt` timestamp are automatically registered in this index. The cleanup process evaluates `max(crdt:deletedAt) > max(crdt:createdAt)` using indexed temporal data to determine actual deletion state.

**GroupIndexTemplate Configuration:**
```turtle
<gc-index-template> a idx:GroupIndexTemplate;
   sync:isGovernedBy mappings:index-v1;
   idx:indexesClass sync:ManagedDocument, idx:FullIndex, idx:GroupIndex, 
                    idx:GroupIndexTemplate, idx:Shard;  # Framework types only
   idx:indexedProperty [
     idx:trackedProperty crdt:deletedAt, crdt:createdAt;  # Temporal evaluation
     idx:readBy <installation-uri>
   ], [
     idx:trackedProperty rdf:type, sync:managedResourceType, idx:indexesClass;  # Retention policies
     idx:readBy <installation-uri>
   ];
   idx:groupedBy [
     a idx:GroupingRule;
     idx:property [
       idx:sourceProperty crdt:deletedAt;
       idx:transform (
         [
           a idx:RegexTransform;
           idx:pattern "^([0-9]{4})-[0-9]{2}-[0-9]{2}$";
           idx:replacement "${1}"
         ]
       ) .
       # No idx:missingValue = only documents with deletedAt get indexed
     ];
     # No groupTemplate - paths generated deterministically as: gc/{yyyy}/index
   ];
   idx:shardingAlgorithm [
     a idx:ModuloHashSharding;
     idx:hashAlgorithm "md5";
     idx:numberOfShards 1
   ];
   idx:populationState "active";
   idx:readBy <installation-uri> .
```

**Registration Behavior:**
- **Active documents** (no `crdt:deletedAt`): Not indexed
- **Documents with deletion timestamps**: Registered in yearly groups (`gc/2024/index`, etc.)
- **Undeletion handling**: Documents removed from GC index when `crdt:deletedAt` property tombstones are cleaned up

#### 6.6.2. Cleanup Operations

**Document Garbage Collection Process:**
1. **Periodic scans**: Background processes scan GC index groups older than retention periods
2. **Temporal validation**: Verify `max(crdt:deletedAt) > max(crdt:createdAt)` using indexed data
3. **Retention verification**: Apply type-specific retention periods using (`rdf:type`, `sync:managedResourceType`) or (`rdf:type`, `idx:indexesClass`) tuples
4. **Document deletion**: Remove document files from Pod (fragment resources already removed during tombstoning)
5. **Index maintenance**: Remove entries for successfully deleted documents from GC index

**Implementation Guidelines:**
- **Batch processing**: 50-100 documents per cycle, 2-5 minutes max execution time
- **Frequency**: Every 24-48 hours during low-activity periods
- **Concurrent safety**: Multiple installations coordinate through CRDT merge rules
- **Universal emptying benefits**: Tombstoned documents already have minimal size and no application index references

**Efficiency Benefits:**
- No container scanning required
- Type-aware retention policies
- Centralized deletion timestamp tracking
- Batch operations optimize Pod performance

### 6.7. Retention Policies and Cleanup Configuration

The framework provides configurable retention policies for tombstoned documents, recognizing their different cleanup strategies and risk profiles.

**Cleanup Configuration Properties:**

**Document Tombstone Configuration:**
- **`crdt:documentTombstoneRetentionPeriod`:** Duration to retain deleted documents (recommended: P2Y)
- **`crdt:enableDocumentTombstoneCleanup`:** Whether to automatically clean up document tombstones
- **Cleanup Strategy:** Proactive cleanup via Framework Garbage Collection Index (see Section 6.6)
- **Risk:** Zombie deletions can affect recreated documents with same IRI

**Property Tombstone Configuration:**
- **`crdt:propertyTombstoneRetentionPeriod`:** Duration to retain deleted property values (recommended: P6M to P1Y)
- **`crdt:enablePropertyTombstoneCleanup`:** Whether to automatically clean up property tombstones
- **Cleanup Strategy:** Sync-time cleanup during document processing (not tracked in GC index)
- **Risk:** Deleted property values may reappear, but document remains intact

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
   crdt:documentTombstoneRetentionPeriod "P2Y"^^xsd:duration;
   crdt:enableDocumentTombstoneCleanup true;
   crdt:propertyTombstoneRetentionPeriod "P6M"^^xsd:duration;
   crdt:enablePropertyTombstoneCleanup true;
   solid:hasRegistration [
      a solid:TypeRegistration;
      solid:forClass sync:ManagedDocument;
      sync:managedResourceType schema:Recipe;
      solid:instanceContainer <../data/recipes/>;
      # Override: Keep recipe document tombstones longer
      crdt:documentTombstoneRetentionPeriod "P3Y"^^xsd:duration;
      crdt:propertyTombstoneRetentionPeriod "P3M"^^xsd:duration
   ] .
```

**Cleanup Strategies:**

**Document Tombstone Cleanup (Proactive):**
1. **Registration:** Complete tombstoned documents automatically registered in Framework Garbage Collection Index
2. **Discovery:** Cleanup processes scan GC index for documents older than retention period
3. **Processing:** Remove entire document files from Pod after verifying retention requirements
4. **Efficiency:** No need to scan data containers for tombstoned documents

**Property Tombstone Cleanup (Sync-Time):**
1. **Integration:** Property tombstone cleanup happens during normal document synchronization
2. **Detection:** When syncing a document, check all property tombstones against retention configuration
3. **Local Processing:** Clean expired property tombstones as part of document merge process
4. **Benefits:** Documents not actively synced retain their tombstones (may be beneficial for long-term auditability)
5. **Trade-offs:** Only synchronized documents are cleaned, unused documents accumulate stale tombstones

### 6.8. Collaborative Index Lifecycle Management

All index lifecycle decisions are made collaboratively through CRDT-managed installation documents and index properties, eliminating single points of failure and coordination bottlenecks.

#### 6.8.1. Reader Management and Cleanup

**Reader Tracking:**
```turtle
<> a idx:FullIndex;
   sync:isGovernedBy mappings:index-v1;
   idx:indexedProperty [
     idx:trackedProperty schema:name;
     idx:readBy <installation-1>, <installation-2>  # OR-Set of active readers
   ];
   idx:readBy <installation-1>, <installation-2>, <installation-3> .  # Index-level readers
```

**Collaborative Cleanup Process:**
1. **Installation tombstoning**: Remove tombstoned installations from all `idx:readBy` OR-Sets
2. **Property cleanup**: Remove properties with empty `idx:readBy` lists from `idx:indexedProperty`
3. **Index tombstoning**: Tombstone indices when `idx:readBy` becomes empty
4. **Garbage collection**: Tombstoned indices enter GC index for cleanup after retention period

#### 6.8.2. Index States and Reactivation

**Index States:**
- **Active**: `idx:populationState "active"`, non-empty `idx:readBy` list, receives updates
- **Tombstoned**: When `idx:readBy` becomes empty, index is tombstoned by setting `crdt:deletedAt`, then registered in GC index for cleanup

**Reactivation Process:**
When discovering compatible tombstoned indices:
1. **Undelete**: Add new `crdt:createdAt` timestamp, tombstone existing `crdt:deletedAt` entries
2. **Fresh initialization**: Recreate index structure from scratch as if it never existed before
3. **Join as reader**: Add installation to `idx:readBy` OR-Set
4. **Fresh population**: Set `idx:populationState "populating"` and perform complete index population like a new index


### 6.9. Error Handling and Recovery

The framework provides robust error handling for lifecycle management failures, ensuring system integrity and recovery from various failure scenarios. For comprehensive error handling patterns and implementation guidance, see [ERROR-HANDLING.md](ERROR-HANDLING.md).

#### 6.9.1. Recovery Principles

**Fundamental Approaches:**
- **Fail-safe defaults**: When in doubt, choose options that preserve data integrity
- **Incremental recovery**: Break operations into small, resumable steps to handle interruptions
- **Fresh start preference**: For complex failures, rebuild from scratch rather than attempting partial repairs
- **CRDT-based coordination**: Use existing CRDT merge rules to resolve conflicts during recovery

#### 6.9.2. Key Recovery Scenarios

**Pod Setup Recovery:**
- **Incomplete setup**: Re-present setup dialog for missing Type Index entries
- **Permission failures**: Offer alternative approaches (local-only operation, manual configuration)
- **Network interruptions**: Resume from last completed step, avoid duplicate operations

**Index Lifecycle Recovery:**
- **Reactivation failures**: Restart with clean tombstoned state and perform fresh population
- **Population interruptions**: Resume index population from last successfully processed resource
- **Concurrent conflicts**: Use CRDT merge rules when multiple installations perform recovery simultaneously

**Garbage Collection Recovery:**
- **Cleanup interruptions**: Queue failed operations for retry with exponential backoff
- **GC index corruption**: Accept orphaned tombstoned documents as manageable trade-off (universal emptying keeps them minimal)
- **Cross-validation**: Validate GC index entries against document states only during normal processing, avoid expensive container scans

**Property Tombstone Recovery:**
- **Malformed tombstones**: Detect and repair tombstones with invalid RDF structure

## 7. Synchronization Workflow

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

### 7.1. Concrete Workflow Example

**Scenario:** OnDemandSync for recipe collection

```javascript
// 1. Index Selection: App requests recipe synchronization
await syncLibrary.syncDataType('schema:Recipe', { strategy: 'OnDemandSync' });

// 2. Index Synchronization: Library fetches recipe index and its shards
// Internal: GET https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4
// Internal: GET https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4/shard-mod-md5-2-0-v1_0_0
// Internal: GET https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4/shard-mod-md5-2-1-v1_0_0

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

### 7.2. Management Phase Operations

Beyond regular data synchronization, the framework requires periodic **management operations** to maintain system health and clean up stale metadata. These operations are separate from normal sync workflows and run on a different schedule.

#### 7.2.1. Lazy Evaluation Principle

**Core Design Principle:** Management operations are performance-critical and must be implemented with high efficiency:

**Cheap Operations (Always Acceptable):**
- Cached index lookups (reading installation states from locally cached Framework Installation Index)
- Processing cached Framework Garbage Collection Index entries

**Critical Implementation Notes:** 
- **Caching Required:** "Cheap" operations rely on **local caching with ETag validation**. The framework maintains local copies of frequently-accessed indices (Installation Index, GC Index) and uses HTTP `If-None-Match` headers to get efficient `304 Not Modified` responses when data hasn't changed. Fresh HTTP requests for every management operation would violate the efficiency principle.
- **Frequency Management:** Management operations should **not run on every sync**. Recommended approach: run management operations only on the first sync of each day, or after extended periods of inactivity. This prevents unnecessary overhead during normal application usage.

**Lazy Operations (Only During Normal Access):**
- Reader list cleanup happens **only** when already syncing an index for other purposes
- Index deprecation happens **only** when accessing indices that are already being synchronized
- No dedicated scanning or fetching of resources solely for cleanup purposes

**Operations to Avoid:**
- Scanning Pod containers to discover resources for cleanup
- Fetching documents solely to check their cleanup eligibility  
- Any operations requiring O(total resources) or O(total indices) traversal
- Proactive "find and fix" patterns that traverse data structures

This principle ensures management operations remain efficient regardless of Pod data volume.

#### 7.2.2. Management Phase Scope and Frequency

**When Management Phase Runs:**
- **Scheduled**: Daily or weekly (configurable, default: daily)
- **No Coordination Required**: Each installation runs management operations independently without coordinating with other installations - CRDT merge semantics handle any concurrent operations safely

**Management Operations:**
1. **Installation Dormancy Detection**: Check installation activity and tombstone inactive ones (cheap: uses Framework Installation Index)
2. **Opportunistic Reader List Cleanup**: Remove tombstoned installations from `idx:readBy` lists during normal index sync operations (lazy: only for indices being synchronized)
3. **Opportunistic Index Deprecation**: Mark indices with no active readers as deprecated during normal access (lazy: only for indices being synchronized)
4. **Garbage Collection**: Process framework GC index for cleanup-ready resources (cheap: uses GC index, processes bounded batch sizes)

#### 7.2.3. Installation Index for Efficient Management

**Framework Installation Index:**
To avoid expensive Type Index container scanning, the framework maintains a dedicated installation index at `/indices/framework/installations-index-${hash}/index`.

**Index Properties:**
```turtle
<installations-index> a idx:FullIndex;
   sync:isGovernedBy mappings:index-v1;
   idx:indexesClass crdt:ClientInstallation;
   idx:indexedProperty [
     idx:trackedProperty crdt:lastActiveAt;        # For dormancy detection
     idx:readBy <installation-1>, <installation-2>
   ], [
     idx:trackedProperty crdt:maxInactivityPeriod; # For cleanup thresholds  
     idx:readBy <installation-1>, <installation-2>
   ];
   idx:shardingAlgorithm [
     a idx:ModuloHashSharding;
     idx:hashAlgorithm "md5";
     idx:numberOfShards 1
   ] .
```

**Benefits:**
- **Efficient batch validation**: Check all installation states in single index sync
- **No container scanning**: Avoid expensive Pod filesystem operations
- **Framework consistency**: Use same index patterns as user data

#### 7.2.4. Management Phase Algorithm

**Phase 1: Sync Installation Index (Cheap)**
1. Sync framework installation index (same as any other index)
2. Identify potentially dormant installations from `crdt:lastActiveAt` headers
3. Build priority list for validation (oldest first)

**Phase 2: Validate Dormant Installations (Cheap - Bounded by Installation Count)**
1. **Initial screening**: Use cached Installation Index to identify installations that appear dormant based on `crdt:lastActiveAt` headers
2. **Document validation**: For each potentially dormant installation:
   - GET installation document from Pod
   - Re-check dormancy using actual `crdt:lastActiveAt` vs `crdt:maxInactivityPeriod` from document
3. **Tombstone dormant installations**: If still dormant based on actual document data:
   - Apply document tombstone by adding `crdt:deletedAt` timestamp and performing universal emptying (remove all semantic content, keeping only framework metadata)
   - PUT updated installation document
4. **Automatic index registration**: Framework automatically registers tombstoned installation documents in Garbage Collection Index for eventual cleanup

**Phase 3: Framework Garbage Collection (Cheap - Uses GC Index)**
1. Process framework GC index for cleanup-ready documents
2. Remove documents beyond retention periods (bounded batch sizes)
3. Update GC index to reflect completed cleanups

**Phase 4: Opportunistic Cleanup (Lazy - Only During Normal Operations)**
1. **During subsequent normal sync operations**, not as part of management phase:
   - When syncing any index, opportunistically remove tombstoned installations from `idx:readBy` lists
   - When syncing any data document, opportunistically remove tombstoned installations from Hybrid Logical Clock entries
   - When syncing any index with empty reader lists, mark as deprecated
   - When syncing deprecated indices, apply tombstoning if appropriate

**Key Implementation Note:** Phase 4 operations are **not performed during management phase** - they happen lazily as part of normal data synchronization workflows.

#### 7.2.5. Coordination and Conflict Resolution

**Collaborative Execution**: Multiple installations may run management phases simultaneously. CRDT merge semantics ensure safe coordination:

- **Installation tombstoning**: OR-Set semantics on `crdt:deletedAt` allow multiple installations to safely mark dormant installations
- **Reader list updates**: OR-Set removal operations are commutative and convergent  
- **Index tombstoning**: OR-Set semantics on `crdt:deletedAt` ensure deterministic deletion state transitions

**Efficiency Optimization**: Management phase skips work already completed by other installations by checking index states before performing updates.

### 7.3. HTTP-Level Optimizations

**ETag-Based Conflict Detection:**

Solid Pods support standard HTTP ETags for optimistic concurrency control:
- **GET responses:** Include `ETag` header with resource version identifier
- **PUT requests:** Include `If-Match` header with stored ETag to detect concurrent modifications  
- **412 Precondition Failed:** Server rejects if ETag doesn't match current version

**CRDT Integration Strategy:**
Unlike traditional REST APIs that fail on conflicts, this framework leverages ETags as a performance optimization:
1. **Optimistic path:** Most PUTs succeed immediately when no concurrent modifications occurred
2. **Conflict resolution:** On 412 response, GET current state, perform CRDT merge with local changes, retry PUT
3. **Eventual consistency:** CRDT merge semantics ensure convergence regardless of update order

This approach provides both immediate conflict detection (via ETags) and robust conflict resolution (via CRDT merging), offering better performance than pure CRDT approaches while maintaining stronger consistency than traditional optimistic locking.

## 8. Error Handling and Resilience

While the synchronization workflow provides the ideal path for data consistency, real-world distributed systems face numerous failure modes that can disrupt this process. The architecture provides comprehensive strategies for maintaining consistency and availability despite various error conditions, ensuring the system remains robust across network failures, server outages, access control changes, and data corruption scenarios.

### 8.1. Failure Classification

**Error Granularities:**
- **Type-Level:** Entire data type cannot sync (missing merge contracts, authentication failures)
- **Resource-Level:** Individual resource blocked (parse errors, access control changes)  
- **Property-Level:** Specific property cannot sync (unknown CRDT types, schema violations)

### 8.2. Core Resilience Strategies

**Network Resilience:**
- Distinguish between systemic failures (abort entire sync) vs. resource-specific failures (skip and continue)
- Exponential backoff for systemic issues, immediate retry for individual resources
- Offline operation continues with local Hybrid Logical Clock increments

**Discovery and Setup:**
- Comprehensive Pod setup process with user consent for configuration changes
- Graceful fallback to hardcoded paths if discovery fails
- Progressive disclosure: automatic vs. custom setup options

**Data Integrity:**
- Index inconsistency detection and automatic resolution
- CRDT merge conflict resolution at property level
- Hybrid Logical Clock anomaly detection and handling

### 8.3. Graceful Degradation

The system provides two operational modes based on sync availability:

1. **Full Functionality:** Complete discovery, sync, and merge operations
2. **Sync Disabled:** Full local functionality with sync operations disabled until connectivity/permissions restored

For comprehensive implementation guidance including specific error scenarios, recovery procedures, and user interface recommendations, see [ERROR-HANDLING.md](ERROR-HANDLING.md).

## 9. Security Considerations

### 9.1. Threat Model

This framework operates within the **Solid security model** where:
- **Pod access control** (WAC/ACP) provides primary security boundaries
- **WebID-based authentication** establishes user identity
- **Pods are trusted storage** - no protection against malicious Pod providers
- **Network communication** relies on HTTPS for transport security

### 9.2. Data Integrity and Authenticity

**Tamper Resistance:**
- **Hybrid Logical Clocks** provide tamper-resistant causality tracking through logical time counters
- **Cryptographic hash verification** of index shard states detects data corruption
- **CRDT merge semantics** ensure convergent outcomes regardless of operation order

**Limitations:**
- No cryptographic signatures on data - integrity depends on Pod provider trustworthiness
- Malicious Pod providers could manipulate stored data
- Hybrid Logical Clock physical timestamps are user-controlled (trusted for tie-breaking only)

### 9.3. Privacy and Access Control

**Access Patterns:**
- Framework **respects Pod access control** but does not enforce additional restrictions
- **Index structures may leak metadata** about data organization and access patterns
- **Installation documents** contain user device/application metadata visible to collaborators

**Privacy Considerations:**
- **Collaborative visibility**: All installations in a Pod can see framework metadata and index structures
- **Temporal information**: Hybrid Logical Clocks reveal rough timing and causality of changes
- **No end-to-end encryption** - data protection relies entirely on Pod provider security

### 9.4. Authentication and Authorization

**Current Scope:**
- Framework **assumes valid WebID authentication** handled by external mechanisms
- **Permission failures** trigger graceful degradation to local-only operation
- **No proactive permission checking** - operations may fail due to access control changes

**OAuth/OIDC Security:**
For critical security considerations regarding redirect URI configuration in Solid OIDC authentication, see [SECURITY.md](SECURITY.md). This covers platform-specific best practices for preventing authorization code interception and client impersonation attacks.

**Future Enhancements:**
For proactive access control integration and advanced security features, see [FUTURE-TOPICS.md](FUTURE-TOPICS.md) sections 13-15.

## 10. Benefits of this Architecture

* **CRDT Interoperability:** CRDT-enabled applications achieve safe collaboration by discovering CRDT-managed resources through `sync:ManagedDocument` registrations and following published merge contracts, while remaining protected from interference by incompatible applications.
* **Developer-Centric Flexibility:** The Sync Strategy model empowers the developer to choose the right performance trade-offs for their specific data.
* **Controlled Discoverability:** The system is discoverable by CRDT-enabled applications while protecting CRDT-managed data from accidental modification by incompatible applications.
* **High Performance & Consistency:** The RDF-based sharded index and state-based sync with HTTP caching ensure that synchronization is fast and bandwidth-efficient.

## 11. Alignment with Standardization Efforts

### 11.1. Community Alignment

This architecture aligns with the goals of the **W3C CRDT for RDF Community Group**.

* **Link:** <https://www.w3.org/community/crdt4rdf/>

### 11.2. Architectural Differentiators

* **"Add-on" vs. "Database":** This specification is designed for "add-on" libraries. The developer retains control over their local storage and querying logic.
* **CRDT Interoperability over Convenience:** The primary rule is that CRDT-managed data must be clean, standard RDF within `sync:ManagedDocument` containers, enabling safe collaboration among CRDT-enabled applications while remaining protected from incompatible applications.
* **Transparent Logic:** The merge logic is not a "black box." By using the `sync:isGovernedBy` link, the rules for conflict resolution become a public, inspectable part of the data model itself.

## 12. Glossary

**CRDT (Conflict-free Replicated Data Type)**: Data structure that can be safely replicated and merged without coordination, guaranteeing convergent outcomes.

**FullIndex**: Monolithic index covering an entire dataset, suitable for small collections (< 1000 resources).

**GroupIndexTemplate**: Template defining how data is grouped into separate indices, enabling scalable organization of large datasets.

**Hybrid Logical Clock (HLC)**: Causality tracking mechanism combining logical time (tamper-resistant) with physical timestamps (intuitive tie-breaking).

**Installation**: Single instance of an application on a specific device, identified by a unique IRI and serving as the CRDT "actor" or "node ID".

**LWW-Register (Last-Writer-Wins Register)**: CRDT type where the most recent value (based on Hybrid Logical Clock) wins during conflicts.

**Merge Contract**: Public RDF document defining how to merge conflicting changes for specific data properties, referenced via `sync:isGovernedBy`.

**OR-Set (Observed-Remove Set)**: CRDT set type supporting additions and explicit removals, commonly used for multi-value properties.

**Pod**: Solid personal data storage space providing web-based access control and RDF data storage.

**sync:ManagedDocument**: Framework wrapper around RDF resources that enables CRDT synchronization and conflict resolution.

**Sync Strategy**: High-level performance pattern (FullSync, GroupedSync, OnDemandSync) determining when and how data is synchronized.

**Tombstone**: Deletion marker in CRDT systems, either at document level (`crdt:deletedAt`) or property level (RDF reification).

**Type Index**: Solid discovery mechanism registering data types and their storage locations within a Pod.

**Universal Emptying**: Process of removing all semantic content from tombstoned documents while preserving framework metadata.

**WebID**: Unique identifier for users in the Solid ecosystem, serving as both identity and profile location.