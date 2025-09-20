# PaCoRS: Passive Storage Collaborative RDF Sync System

**Version:** 0.10.0-draft
**Last Updated:** September 2025
**Status:** Draft Specification
**Authors:** Klas Kalaß
**Target Audience:** Library implementers, application developers, distributed RDF system architects

## Document Status

This is a **draft specification** under active development. The architecture and APIs described here are subject to change based on implementation experience and community feedback.

**Feedback Welcome:** Please report issues, suggestions, or questions at [GitHub Issues](https://github.com/anthropics/claude-code/issues) or contribute via pull requests.

## Document Changelog

### Version 0.10.0-draft (September 2025)
- **DOCUMENT CREATION:** Split from monolithic ARCHITECTURE.md to create backend-agnostic specification
- **BREAKING CHANGE:** Replace xxHash64 with MD5 for cross-platform compatibility
  - Updated hash algorithm from xxHash64 to MD5 throughout specification
  - Modified hash output format: 16 hex chars → 32 hex chars
  - Updated shard naming: `shard-mod-xxhash64-*` → `shard-mod-md5-*`
  - Changed group key safety format: `{length}_{16-char-hash}` → `{length}_{32-char-hash}`
  - Ensures JavaScript/web compatibility while maintaining deterministic hashing
- **Backend Abstraction:** Defined backend interface requirements for resource discovery, storage operations, and authentication
- **Framework Generalization:** Removed Solid-specific implementation details to separate specification
- Complete 4-layer architecture: Data Resource, Merge Contract, Indexing, Sync Strategy layers
- CRDT foundations with Hybrid Logical Clocks and state-based merging
- Backend-agnostic lifecycle management and synchronization algorithms
- Comprehensive error handling and resilience patterns

---

## 1. Executive Summary

### 1.1. System Overview

This document specifies **PaCoRS** (Passive Storage Collaborative RDF Sync System), a CRDT-based system for synchronizing RDF documents across distributed, passive storage backends. PaCoRS enables local-first, collaborative, and truly interoperable applications by solving two fundamental challenges: first, robust conflict-free merging of semantic RDF data; and second, scalable performance regardless of dataset size.

The system uses **property-level, state-based CRDTs** specifically designed for RDF semantics. Unlike operation-based approaches that synchronize individual change events, this architecture synchronizes complete document states using **semantic-aware CRDT algorithms**. Developers declaratively map RDF properties to appropriate CRDT types (LWW-Register, OR-Set, etc.) through public merge contracts. To manage performance, they configure sync strategies (full, grouped, or on-demand) that work with sophisticated indexing and sharding mechanisms. The result is clean, standard RDF that remains fully compatible with existing tools while providing reliable collaborative editing.

**Backend Independence:** PaCoRS is designed to work with any passive storage backend that supports basic file operations (create, read, update, delete). Examples include Solid Pods, Google Drive, Dropbox, AWS S3, or even local filesystems. The core CRDT logic remains identical across all backends, with only the storage interface and resource discovery mechanisms varying.

For comprehensive performance analysis, benchmarks, and mobile considerations, see [PERFORMANCE.md](PERFORMANCE.md).

### 1.2. Implementation Model

The technical complexity described in this document is intended to be encapsulated within a reusable synchronization library (such as `pacors`). Application developers interact with a simple, declarative API while the library handles all CRDT algorithms, index management, conflict resolution, and backend communication. The detailed specifications in this document serve as implementation guidance for library authors and reference for understanding the underlying system behavior.

### 1.3. Scale and Design Constraints

PaCoRS is designed for personal to small-organization scale collaboration, targeting **2-100 installations** with optimal performance at **2-20 installations**. Primary use cases include personal synchronization across multiple devices (2-5 installations), family collaboration (5-15 installations), and small teams or friend groups (10-20 installations). Extended use cases support small organizations up to 100 installations. Beyond this scale, different architectural assumptions around centralized coordination, professional IT support, and enterprise-grade infrastructure might be more appropriate.

### 1.4. Current Scope and Limitations

**Single-Backend Focus:** PaCoRS is designed for CRDT synchronization within a single storage backend. All collaborating installations work with data stored in one backend location, with multiple users able to participate through separate installations.

**Multi-Backend Integration Limitation:** Applications requiring data integration across multiple backends (such as displaying Alice's recipes from Google Drive alongside Bob's recipes from Dropbox) need additional orchestration beyond this specification. While IRIs ensure global uniqueness across backends, the challenges include:
- Discovery and connection management across multiple backends
- Semantic relationship resolution across backend boundaries
- Cross-backend query coordination and performance optimization
- Multi-source synchronization architecture and user experience

**Future Evolution:** Multi-backend application integration represents a significant architectural enhancement planned for future specification versions (v2/v3). See FUTURE-TOPICS.md Section 10 for detailed analysis of the challenges and potential approaches.

## 2. Core Principles

* **Local-First:** The application must be fully functional offline, working primarily with data cached on the device. To ensure this principle remains practical for large datasets, the architecture supports optional partial sync strategies. This allows an application to work with a local, consistent cache of the *relevant* data, maintaining speed and offline availability without requiring a full data download.

* **CRDT Interoperability:** The data is clean, standard RDF within CRDT-managed documents (`sync:ManagedDocument`). CRDT-enabled applications achieve interoperability by discovering managed resources and following the public merge contracts that define collaboration rules.

* **Declarative Merge Behavior:** Developers define the merge behavior for each piece of data by declaratively linking its properties to well-defined **state-based** CRDT types (e.g., `LWW-Register`, `OR-Set`). This is done in a **public, discoverable rules file**, abstracting away the complexity of the underlying algorithms. The framework supports both class-scoped rules (property mappings) and global rules (predicate mappings) to provide flexibility in defining merge semantics. This state-based approach is fundamental to the architecture's design as it works seamlessly with passive storage backends.

* **Managed Resource Discoverability:** The system is designed to be self-describing for CRDT-enabled applications. Compatible applications can discover CRDT-managed resources through backend-specific discovery mechanisms with `sync:managedResourceType` filtering. From a managed resource, clients can discover merge rules (`sync:isGovernedBy`) and index shards (`idx:belongsToIndexShard`), enabling CRDT-enabled applications to collaborate safely while remaining invisible to incompatible applications.

* **Backend-Agnostic & Server-Agnostic:** The storage backend acts as a simple, passive storage bucket. All synchronization logic resides within the client-side library.

## 3. Architecture Overview

This section provides a high-level view of the framework's approach before diving into technical foundations. Understanding these key architectural decisions helps contextualize the detailed mechanisms that follow.

### 3.1. The Problem

Distributed RDF data synchronization faces three fundamental challenges:

**Challenge 1: Conflict-Free Merging**
Multiple applications writing to the same RDF resources create conflicts that must be resolved deterministically without coordination. Traditional "last-write-wins" approaches lose data and break semantic relationships.

**Challenge 2: Semantic Preservation**
RDF's semantic richness must be preserved during synchronization. Merge strategies must understand property semantics (single-value vs multi-value, immutable vs collaborative) rather than treating all data uniformly.

**Challenge 3: Passive Storage Integration**
Storage backends are passive - they cannot execute merge logic or coordinate between clients. All conflict resolution must happen client-side while ensuring convergent results across all installations.

### 3.2. The Solution Approach

**State-Based CRDTs with Semantic Awareness**
Instead of synchronizing individual operations, entire resource states are merged using property-specific CRDT algorithms. This approach works naturally with passive storage and enables rich semantic merge strategies.

**4-Layer Architecture for Separation of Concerns**
1. **Data Resource Layer:** Clean, standard RDF with semantic types
2. **Merge Contract Layer:** Public CRDT rules for conflict resolution
3. **Indexing Layer:** Performance optimization through sharded indices
4. **Sync Strategy Layer:** Application-controlled synchronization patterns

**Hybrid Logical Clocks for Causality**
Combines logical causality tracking with physical timestamps to provide tamper-resistant ordering that works across disconnected clients.

### 3.3. Key Architectural Decisions

**Decision 1: State-Based CRDTs Over Operation-Based**
- Simpler integration with passive storage
- Natural fit for RDF resource model
- Easier rollback and recovery mechanisms
- Compatible with standard HTTP caching

**Decision 2: Property-Level Merge Granularity**
- Preserves RDF semantic relationships
- Enables fine-grained collaboration on complex objects
- Supports mixed merge strategies within single resources

**Decision 3: Public, Discoverable Merge Contracts**
- Enables cross-application interoperability
- Provides clear collaboration semantics
- Allows independent application development

**Decision 4: Sharded Indexing with Lazy Evaluation**
- Scales to large datasets
- Minimizes synchronization overhead
- Supports both full and partial sync strategies

### 3.4. Reading Guide

This document is structured for progressive understanding:

- **Section 4 (Foundations)**: Essential CRDT concepts, RDF identity challenges, and core abstractions
- **Section 5 (Architectural Data Layers)**: The 4-layer model with detailed examples and vocabulary definitions
- **Section 6 (Lifecycle Management)**: Practical backend setup and operational procedures
- **Section 7 (Synchronization Workflow)**: Concrete algorithms and optimization strategies
- **Section 8-9 (Error Handling, Security)**: Resilience patterns and security considerations

**For Backend Implementers**: Focus on Section 4.4 (Backend Integration Requirements) and Section 6 (Lifecycle Management) to understand the storage interface requirements.

**For Application Developers**: Section 5 provides the vocabulary and patterns for defining merge contracts and sync strategies.

**For Library Implementers**: The entire document provides implementation guidance, with Section 7 containing the core synchronization algorithms.

---

## 4. Foundations

Having established the overall architectural approach, this section examines the technical foundations that make reliable CRDT synchronization possible in the RDF ecosystem. We start with CRDT fundamentals (4.1), then address the critical RDF identity challenges that shaped our approach (4.2), followed by integration and lifecycle mechanisms (4.3-4.6).

### 4.1. CRDT Fundamentals

This framework implements **state-based CRDTs** (Convergent Replicated Data Types) to handle conflict resolution in distributed RDF synchronization. Understanding these foundations is essential for both implementers and application developers who need to choose appropriate merge strategies for their data.

#### 4.1.1. Core CRDT Types

The framework provides five core CRDT algorithms, each designed for specific data patterns:

**LWW-Register (Last-Write-Wins Register)**
- **Use Case:** Single-value properties where the most recent change wins
- **Examples:** `schema:name`, `schema:description`, status fields
- **Behavior:** Compares Hybrid Logical Clock timestamps to determine winner
- **Tradeoff:** Simple and intuitive, but loses data in concurrent edits

**FWW-Register (First-Write-Wins Register)**
- **Use Case:** Immutable properties that should never change once set
- **Examples:** `schema:dateCreated`, unique identifiers, audit trails
- **Behavior:** Keeps the value with the earliest timestamp, ignores later changes
- **Tradeoff:** Ensures immutability but may reject legitimate corrections

**OR-Set (Observed-Remove Set)**
- **Use Case:** Multi-value properties with collaborative add/remove semantics
- **Examples:** `schema:keywords`, `schema:author`, tag lists
- **Behavior:** Additions always succeed; removals only succeed if the item was previously observed
- **Tradeoff:** Comprehensive collaboration support with more complex implementation

**2P-Set (Two-Phase Set)**
- **Use Case:** Append-only collections where removals represent permanent deletion
- **Examples:** Access logs, comment streams, audit records
- **Behavior:** Items can be added and removed, but removed items can never be re-added
- **Tradeoff:** Simpler than OR-Set but more restrictive

**Immutable**
- **Use Case:** Properties that must remain exactly as first written
- **Examples:** Digital signatures, checksums, legal timestamps
- **Behavior:** Rejects any change attempts, preserves original value
- **Tradeoff:** Ultimate consistency but no flexibility for corrections

#### 4.1.2. State-Based vs Operation-Based CRDTs

This framework chose **state-based CRDTs** for several reasons:

**Advantages of State-Based Approach:**
- **Simple Storage Integration:** Each sync operation transfers complete resource state
- **Natural HTTP Compatibility:** Works perfectly with GET/PUT semantics
- **Easier Debugging:** Current state is always observable and understandable
- **Rollback Support:** Simple to revert to previous states
- **Compatible with passive storage backends**

**Operation-Based Alternative (Not Used):**
- Would require operation log storage and replay mechanisms
- More complex integration with passive storage
- Harder to recover from corrupted operation histories
- Less suitable for occasional-connection scenarios

#### 4.1.3. Property-Level CRDT Integration

Rather than applying CRDT algorithms to entire documents, this framework operates at the **property level**, allowing different merge strategies for different aspects of the same resource:

```turtle
# A Recipe resource with mixed merge strategies
<#recipe> a schema:Recipe;
    schema:name "Grandmother's Apple Pie"^^crdt:LWW-Register;
    schema:description "Traditional family recipe"^^crdt:LWW-Register;
    schema:dateCreated "2023-10-15"^^crdt:Immutable;
    schema:keywords ("apple", "pie", "dessert")^^crdt:OR-Set;
    schema:author (<#alice>, <#bob>)^^crdt:OR-Set .
```

**Benefits:**
- **Semantic Accuracy:** Recipe name uses LWW (collaborative editing), creation date is immutable, keywords allow collaborative tagging
- **Flexibility:** Different properties can evolve using different collaboration patterns
- **Granular Control:** Fine-grained merge behavior without complex class hierarchies

#### 4.1.4. Multi-Value Property Examples

Multi-value properties require careful CRDT selection based on collaboration semantics:

**Collaborative Keyword Tagging (OR-Set):**
```turtle
# Alice's installation adds keywords
<#recipe> schema:keywords ("apple", "pie")^^crdt:OR-Set .

# Bob's installation adds more keywords
<#recipe> schema:keywords ("apple", "pie", "dessert", "fall")^^crdt:OR-Set .

# Charlie removes "fall", adds "traditional"
<#recipe> schema:keywords ("apple", "pie", "dessert", "traditional")^^crdt:OR-Set .

# Result: All additions preserved, removal respected
<#recipe> schema:keywords ("apple", "pie", "dessert", "traditional")^^crdt:OR-Set .
```

**Append-Only Comment Stream (2P-Set):**
```turtle
# Comments can be added and removed, but never re-added once deleted
<#recipe> schema:comment ("Great recipe!", "Needs more sugar", "Perfect!")^^crdt:2P-Set .

# If "Needs more sugar" is removed, it cannot be re-added later
<#recipe> schema:comment ("Great recipe!", "Perfect!")^^crdt:2P-Set .
```

### 4.2. Core RDF Challenges

Working with CRDTs in RDF presents unique challenges not found in traditional CRDT applications. This section explains these challenges and the design decisions that solve them.

#### 4.2.1. Three-Level Merging Hierarchy

RDF CRDT synchronization operates at three distinct levels, each requiring different merge strategies:

**Level 1: Document Structure**
- Adding/removing top-level resources within documents
- Document-level metadata and relationships
- Framework uses built-in strategies for structural consistency

**Level 2: Resource Properties**
- Adding/removing properties (predicates) to resources
- Uses OR-Set semantics: properties can be added by anyone, removed only if previously observed
- Enables collaborative schema evolution while preventing data loss

**Level 3: Property Values**
- The actual values within properties (objects in RDF triples)
- Uses application-specified CRDT strategies per property type
- Provides semantic-aware merge behavior (LWW-Register, OR-Set, etc.)

**Example:**
```turtle
# Level 1: Document contains resources <#recipe> and <#review>
# Level 2: <#recipe> has properties schema:name, schema:keywords
# Level 3: schema:name uses LWW-Register, schema:keywords uses OR-Set

<#recipe> a schema:Recipe;
    schema:name "Apple Pie"^^crdt:LWW-Register;
    schema:keywords ("apple", "pie")^^crdt:OR-Set .

<#review> a schema:Review;
    schema:reviewBody "Delicious!"^^crdt:LWW-Register .
```

#### 4.2.2. The Blank Node Challenge

Blank nodes in RDF create significant challenges for CRDT identity management:

**The Problem:**
```turtle
# Two installations create similar blank node structures
# Installation A:
<#recipe> schema:nutrition [
    schema:calories 350;
    schema:protein "12g"
] .

# Installation B:
<#recipe> schema:nutrition [
    schema:calories 350;
    schema:fat "8g"
] .
```

**Without proper identity management, merging fails because:**
- Blank nodes have no stable identity across installations
- Cannot determine if blank nodes represent the same entity
- Risk of duplicate entities or lost data

#### 4.2.3. The Solution: Context-Based Identification

The framework solves blank node identity through **context-based identification**:

**Pattern 1: Property Context Identification**
```turtle
# Single blank node per property - identity derived from property context
<#recipe> schema:nutrition [
    schema:calories 350;
    schema:protein "12g";
    schema:fat "8g"
] .
```

**Pattern 2: Explicit Identification**
```turtle
# Multiple blank nodes with explicit identification
<#recipe> schema:ingredient [
    schema:name "Flour";
    schema:amount "2 cups";
    crdt:blankNodeId "ingredient-flour"
], [
    schema:name "Sugar";
    schema:amount "1 cup";
    crdt:blankNodeId "ingredient-sugar"
] .
```

**Pattern 3: Avoid Blank Nodes (Recommended)**
```turtle
# Use fragment identifiers for clean identity
<#recipe> schema:ingredient <#ingredient-flour>, <#ingredient-sugar> .

<#ingredient-flour> a schema:Recipe;
    schema:name "Flour";
    schema:amount "2 cups" .

<#ingredient-sugar> a schema:Recipe;
    schema:name "Sugar";
    schema:amount "1 cup" .
```

#### 4.2.4. Resource Identity Taxonomy

The framework supports three categories of resource identity, each with different CRDT implications:

**Named Resources (IRIs)**
- **Examples:** `<#recipe>`, `<https://example.org/users/alice>`
- **Identity:** Stable across all installations
- **CRDT Behavior:** Full property-level merging supported
- **Best Practice:** Use for all primary entities

**Context-Identified Blank Nodes**
- **Examples:** Nutrition info, addresses, measurements
- **Identity:** Derived from property context or explicit `crdt:blankNodeId`
- **CRDT Behavior:** Property-level merging within identified context
- **Usage:** Complex value objects that don't warrant full IRIs

**Unmanaged Blank Nodes**
- **Examples:** Simple value groupings without identity requirements
- **Identity:** No stable identity across installations
- **CRDT Behavior:** Document-level merging only
- **Limitation:** Cannot use property-level CRDT strategies

#### 4.2.5. CRDT Compatibility Rules

For successful CRDT synchronization, resources must follow these compatibility rules:

**Rule 1: Stable Identity**
- All resources requiring property-level merging must have stable identities (IRIs or context-based identification)
- Identity must be deterministic across all installations

**Rule 2: Consistent CRDT Mappings**
- All installations must use identical property-to-CRDT mappings
- Mappings are defined in public, discoverable merge contracts

**Rule 3: Compatible Vocabulary Usage**
- Applications can extend vocabularies but cannot redefine existing property semantics
- New properties require compatible CRDT strategy definitions

**Rule 4: Framework Metadata Preservation**
- Applications must not modify `crdt:*`, `sync:*`, `idx:*` properties
- Framework handles all synchronization metadata automatically

#### 4.2.6. Development Implications

These RDF challenges create specific development patterns:

**Design Pattern: Fragment-First Modeling**
```turtle
# Preferred: Use fragment identifiers for all entities
<#recipe> a schema:Recipe;
    schema:name "Apple Pie";
    schema:author <#alice>;
    schema:ingredient <#ingredient-1>, <#ingredient-2> .

<#alice> a schema:Person;
    schema:name "Alice Smith" .

<#ingredient-1> a schema:RecipeIngredient;
    schema:name "Apples";
    schema:amount "6 medium" .
```

**Anti-Pattern: Excessive Blank Node Usage**
```turtle
# Problematic: Blank nodes without stable identity
<#recipe> schema:author [
    schema:name "Alice Smith";
    schema:email "alice@example.com"
];
schema:ingredient [
    schema:name "Apples";
    schema:amount "6 medium"
] .
```

#### 4.2.7. Implementation Consistency Checks

Framework implementations should validate these constraints:

**Identity Validation:**
- Verify all resources have stable identity (IRI or context-based)
- Reject resources with unmanaged blank nodes in property-level CRDT contexts
- Provide clear error messages for identity violations

**Mapping Validation:**
- Ensure all installations use identical merge contracts
- Validate that property-to-CRDT mappings are complete and consistent
- Check for vocabulary compatibility across collaborating installations

**Structural Validation:**
- Verify document structure follows framework conventions
- Check that framework metadata is properly maintained
- Validate that semantic types align with CRDT strategies

**Example Validation Logic:**
```
For each resource in document:
  If resource uses property-level CRDT merging:
    Assert: resource has stable identity (IRI or context-based)
    Assert: all properties have defined CRDT mappings
    Assert: CRDT mappings match merge contract specification
```

### 4.3. Resource/Document Abstraction

One of the foundational challenges in RDF CRDT synchronization is bridging the gap between RDF's resource-centric model and the document-based reality of most storage systems. This section explains how the framework resolves this abstraction mismatch.

#### 4.3.1. The Problem: Two Different Mental Models

**RDF Model (Resource-Centric):**
Applications work with individual resources, each with their own identity and properties:
```turtle
<#recipe-123> a schema:Recipe;
    schema:name "Apple Pie";
    schema:author <#alice> .

<#alice> a schema:Person;
    schema:name "Alice Smith" .
```

**Storage Model (Document-Centric):**
Storage systems work with documents containing multiple resources:
```turtle
# Single document containing both resources
@base <https://alice.example.org/data/recipes/apple-pie> .

<#recipe-123> a schema:Recipe;
    schema:name "Apple Pie";
    schema:author <#alice> .

<#alice> a schema:Person;
    schema:name "Alice Smith" .
```

**The Challenge:**
- Applications want to work with individual resources
- Storage and synchronization operate on entire documents
- CRDT merging happens at document level
- Need consistent mapping between resources and storage locations

#### 4.3.2. The Solution: Dual Abstraction Levels

The framework provides two complementary abstractions:

**Application Level: Resource Abstraction**
- Applications retrieve and modify individual resources
- Framework handles document-level storage automatically
- Clean separation between business logic and storage concerns

**Synchronization Level: Document Abstraction**
- CRDT merging operates on complete document state
- Enables atomic consistency across related resources
- Simplifies conflict resolution and storage integration

**Implementation Pattern:**
```dart
// Application works with resources
Recipe recipe = repository.getRecipe('#recipe-123');
recipe.name = 'Grandmother\'s Apple Pie';

// Framework handles document-level operations
await syncSystem.save(recipe); // Saves entire document containing recipe
```

#### 4.3.3. Document-Level Sync with Resource-Level Access

**Synchronization Workflow (Document-Level):**
1. **Fetch:** GET entire document from storage
2. **Merge:** Apply CRDT algorithms to complete document state
3. **Store:** PUT merged document back to storage
4. **Notify:** Inform applications about changed resources

**Application Interface (Resource-Level):**
```dart
// Applications receive resource-level callbacks
repository.onUpdate = (Recipe recipe) {
    // Handle individual recipe changes
    updateUI(recipe);
};

repository.onDelete = (String recipeId) {
    // Handle individual recipe deletion
    removeFromUI(recipeId);
};
```

**Benefits:**
- **Atomic Consistency:** Related resources in the same document are synchronized atomically
- **Simple Conflict Resolution:** CRDT algorithms operate on complete, consistent document state
- **Clean Application Interface:** Applications work with familiar resource abstractions
- **Efficient Storage:** Single HTTP operation per document synchronization

#### 4.3.4. Benefits of This Approach

**For Application Developers:**
- Natural RDF resource programming model
- No need to understand document boundaries or CRDT implementation
- Automatic handling of related resource synchronization

**For Framework Implementation:**
- Clean separation between application logic and synchronization mechanics
- Simplified CRDT implementation (document-level state merging)
- Efficient storage integration (single request per document)

**For Storage Integration:**
- Document-based operations align with most storage APIs
- Simple mapping to filesystem, HTTP, or object storage
- Natural fit for caching and offline capabilities

#### 4.3.5. Implementation Requirements

**Resource-to-Document Mapping:**
- Each resource must have a deterministic mapping to a storage document
- Multiple resources can share a document (for atomicity)
- Framework must handle document-level synchronization transparently

**Change Detection:**
- Applications modify resources through framework APIs
- Framework tracks changes and synchronizes affected documents
- Resource-level change notifications derived from document-level synchronization

**Storage Interface:**
```dart
// Backend implementations provide document-level operations
abstract class BackendStorage {
  Future<Document> getDocument(IriTerm documentIri);
  Future<void> putDocument(IriTerm documentIri, Document document);
  Future<bool> deleteDocument(IriTerm documentIri);
}
```

**Resource Hydration:**
```dart
// Framework provides resource-level access
abstract class Repository<T> {
  Stream<T> hydrateStreaming({
    required GetCurrentCursor getCurrentCursor,
    required OnUpdate<T> onUpdate,
    required OnDelete onDelete,
    required OnCursorUpdate onCursorUpdate,
  });
}
```

This dual abstraction approach ensures that applications can work naturally with RDF resources while the framework handles the complexities of document-based storage and CRDT synchronization.

### 4.4. Backend Integration Requirements

CRDT-enabled applications require specific backend integration patterns to discover managed resources while maintaining compatibility with non-CRDT applications. This section defines the interface requirements for backend implementations.

#### 4.4.1. Backend Interface Definition

All backend implementations must provide three core interfaces:

**Resource Discovery Interface:**
```dart
abstract class ResourceDiscovery {
  /// Discover containers for specific managed resource types
  Future<List<IriTerm>> discoverContainers(IriTerm managedResourceType);

  /// Register a new container for a managed resource type
  Future<void> registerContainer(IriTerm managedResourceType, IriTerm container);
}
```

**Storage Operations Interface:**
```dart
abstract class BackendStorage {
  /// Retrieve document from storage
  Future<Document?> getDocument(IriTerm documentIri);

  /// Store document to storage
  Future<void> putDocument(IriTerm documentIri, Document document);

  /// Delete document from storage
  Future<bool> deleteDocument(IriTerm documentIri);

  /// List documents in container
  Future<List<IriTerm>> listDocuments(IriTerm containerIri);
}
```

**Authentication Interface:**
```dart
abstract class BackendAuth {
  /// Authenticate with backend service
  Future<AuthResult> authenticate();

  /// Get current authentication status
  Future<bool> isAuthenticated();

  /// Sign out from backend service
  Future<void> signOut();
}
```

#### 4.4.2. Discovery Isolation Strategy

**The Challenge:** CRDT-managed resources contain synchronization metadata and follow structural conventions that traditional RDF applications don't understand, creating a risk of data corruption.

**The Solution:** CRDT-managed resources are isolated from traditional discovery mechanisms using backend-specific strategies:

**Backend-Specific Discovery Examples:**

**Solid Pod Backend:**
- Register managed resources under `sync:ManagedDocument` in Type Index
- Traditional apps query for `schema:Recipe` → find nothing (invisible)
- CRDT apps query for `sync:ManagedDocument` where `sync:managedResourceType schema:Recipe` → find managed resources

**Google Drive Backend:**
- Store managed resources in hidden `.rdf-crdt-sync/` folders
- Traditional apps see normal folder structure → unaware of managed data
- CRDT apps look for special folder naming conventions

**S3 Backend:**
- Use object metadata tags to mark CRDT-managed objects
- Traditional apps query without metadata filters → normal objects only
- CRDT apps query with `rdf-crdt-managed=true` filter

#### 4.4.3. Installation Identity Management

Each backend must support stable installation identity for collaborative coordination:

**Installation Document Requirements:**
```turtle
<> a sync:ManagedDocument;
   sync:managedResourceType crdt:ClientInstallation;
   sync:isGovernedBy <https://w3id.org/rdf-crdt-sync/mappings/core-v1> .

<#installation> a crdt:ClientInstallation;
    crdt:installationId "550e8400-e29b-41d4-a716-446655440000";
    crdt:createdAt "2023-10-15T14:30:00Z"^^crdt:Clock;
    crdt:lastSeenAt "2023-10-15T16:45:23Z"^^crdt:Clock .
```

**Lifecycle Requirements:**
1. **Discovery:** Backend provides container location for installations
2. **Registration:** Generate UUID v4, create installation document
3. **Maintenance:** Update `lastSeenAt` during sync operations
4. **Recovery:** Handle tombstoned installations by creating fresh identity

#### 4.4.4. Backend Implementation Examples

**File System Backend:**
```dart
class FileSystemBackend implements Backend {
  @override
  ResourceDiscovery get discovery => FileSystemDiscovery();

  @override
  BackendStorage get storage => FileSystemStorage();

  @override
  BackendAuth get auth => NoAuthRequired();
}
```

**HTTP-Based Backend (Solid, Google Drive, etc.):**
```dart
class HttpBackend implements Backend {
  @override
  ResourceDiscovery get discovery => HttpDiscovery(client);

  @override
  BackendStorage get storage => HttpStorage(client);

  @override
  BackendAuth get auth => OAuthAuthentication();
}
```

This backend abstraction enables the same RDF-CRDT logic to work across radically different storage systems while maintaining discovery isolation and collaborative coordination.

### 4.5. Installation Identity Management

Collaborative CRDT synchronization requires stable client identity management to enable causality tracking, coordinate collaborative operations, and manage installation lifecycles. Each client installation maintains a discoverable identity document that serves as the foundation for all collaborative coordination.

Installation IDs are IRIs that reference discoverable `crdt:ClientInstallation` documents. These provide traceability, identity management for Hybrid Logical Clock entries, and collaborative lifecycle management.

**Discovery and Lifecycle:**
1. **Discovery:** Applications query the backend for `crdt:ClientInstallation` container location
2. **ID Generation:** Generate unique UUID v4 for each application installation
3. **Registration:** Create installation document at discovered container location
4. **Usage:** Reference installation IRI in Hybrid Logical Clock entries for all subsequent operations

**Installation Document Structure:**

```turtle
@base <https://alice.example.org/installations/550e8400-e29b-41d4-a716-446655440000> .

<> a sync:ManagedDocument;
   sync:managedResourceType crdt:ClientInstallation;
   sync:isGovernedBy <https://w3id.org/rdf-crdt-sync/mappings/core-v1> .

<#installation> a crdt:ClientInstallation;
    crdt:installationId "550e8400-e29b-41d4-a716-446655440000";
    crdt:createdAt "2023-10-15T14:30:00Z"^^crdt:HybridClock;
    crdt:lastSeenAt "2023-10-15T16:45:23Z"^^crdt:HybridClock;
    crdt:appName "Meal Planning App";
    crdt:appVersion "1.2.3";
    crdt:deviceInfo "iPhone 12, iOS 17.1" .
```

**Installation Properties:**
- **`crdt:installationId`:** UUID v4 string for stable identity
- **`crdt:createdAt`:** HLC timestamp when installation was first created
- **`crdt:lastSeenAt`:** HLC timestamp of most recent activity (updated during sync)
- **`crdt:appName`:** Human-readable application identifier
- **`crdt:appVersion`:** Application version for debugging and compatibility
- **`crdt:deviceInfo`:** Optional device information for troubleshooting

**Collaborative Benefits:**
- **Causality Tracking:** Installation IRIs appear in all HLC entries for traceability
- **Dormancy Detection:** Other installations can detect inactive collaborators via `lastSeenAt`
- **Conflict Resolution:** Installation identity enables deterministic CRDT merging
- **Debug Support:** Rich metadata helps troubleshoot synchronization issues

### 4.6. Tombstoning and Deletion Semantics

RDF CRDT synchronization requires sophisticated deletion handling that preserves referential integrity while enabling efficient garbage collection. The framework implements a two-tier deletion system: property-level tombstones for fine-grained conflict resolution and document-level tombstones for lifecycle management.

#### 4.6.1. Tombstone Types and Scope

**Property-Level Tombstones (Fine-Grained)**
Used when specific properties are removed from resources while preserving the resource itself:

```turtle
# Original state
<#recipe> schema:name "Apple Pie";
         schema:description "Traditional family recipe";
         schema:keywords ("apple", "pie", "dessert") .

# After removing description property
<#recipe> schema:name "Apple Pie";
         schema:keywords ("apple", "pie", "dessert") .

# Tombstone representation (internal framework state)
<#recipe> schema:name "Apple Pie";
         schema:keywords ("apple", "pie", "dessert") .

# Property deletion represented as reified statement
[] a rdf:Statement;
   rdf:subject <#recipe>;
   rdf:predicate schema:description;
   rdf:object "Traditional family recipe";
   crdt:deletedAt "2023-10-15T14:30:00Z"^^crdt:HybridClock;
   crdt:deletedBy <../installations/550e8400-e29b-41d4-a716-446655440000#installation> .
```

**Document-Level Tombstones (Lifecycle Management)**
Used when entire resources or documents are removed from the system:

```turtle
# Tombstoned recipe document
@base <https://alice.example.org/data/recipes/apple-pie> .

<> a sync:ManagedDocument;
   sync:managedResourceType schema:Recipe;
   sync:isGovernedBy <https://w3id.org/rdf-crdt-sync/mappings/recipe-v1>;
   crdt:deletedAt "2023-10-15T16:00:00Z"^^crdt:HybridClock;
   crdt:deletedBy <../installations/550e8400-e29b-41d4-a716-446655440000#installation> .

# All other content removed to minimize storage and prevent conflicts
```

**Key Design Principles:**
- **Property tombstones:** Enable fine-grained conflict resolution for individual property deletions
- **Document tombstones:** Provide lifecycle management for entire resources
- **Minimal storage:** Tombstoned documents contain only deletion metadata
- **Referential integrity:** Framework ensures dependent resources are handled appropriately
- **Consistent storage usage:** All tombstoned documents have predictable, minimal size

#### 4.6.2. Unified Deletion Semantics

The framework provides clear deletion semantics for different layers:

**Application Layer: Domain-Specific Deletion**
- Applications typically implement soft deletion using domain properties
- Examples: `schema:archived true`, `meal:hidden true`, `status "inactive"`
- Preserves data while controlling visibility
- Supports domain-specific business logic (undelete, audit trails)

**Framework Layer: System-Level Deletion**
- Framework deletion (`crdt:deletedAt`) is for true cleanup
- Use cases: storage optimization, retention compliance, collaborative lifecycle management
- Results in permanent removal from active synchronization
- Cannot be undone through normal application operations

**Example Usage Patterns:**
```turtle
# Domain deletion: Recipe hidden from user interface
<#recipe> schema:name "Secret Family Recipe";
         meal:archived true .  # Application-level soft deletion

# System deletion: Recipe completely removed from synchronization
<> crdt:deletedAt "2023-10-15T16:00:00Z"^^crdt:HybridClock .
# All recipe content removed
```

**Layered Approach Benefits:**
- **Flexibility:** Applications control user-facing deletion behavior
- **Efficiency:** Framework handles backend cleanup and storage optimization
- **Safety:** Clear separation between user actions and system maintenance
- **Compliance:** Supports legal/regulatory deletion requirements

#### 4.6.3. Property Tombstone Implementation

Property-level deletion uses RDF reification to represent deletion events:

**Deletion Event Structure:**
```turtle
# When Alice deletes the description property from a recipe
[] a rdf:Statement;
   rdf:subject <#recipe>;
   rdf:predicate schema:description;
   rdf:object "Traditional family recipe";
   crdt:deletedAt "2023-10-15T14:30:00Z"^^crdt:HybridClock;
   crdt:deletedBy <../installations/alice-phone#installation> .
```

**Conflict Resolution with Property Tombstones:**
```turtle
# Alice deletes description at 14:30
[] a rdf:Statement;
   rdf:subject <#recipe>;
   rdf:predicate schema:description;
   rdf:object "Traditional family recipe";
   crdt:deletedAt "2023-10-15T14:30:00Z"^^crdt:HybridClock .

# Bob updates description at 14:35 (later timestamp)
<#recipe> schema:description "Updated family recipe"^^crdt:HybridClock {
    crdt:clock "2023-10-15T14:35:00Z";
    crdt:installation <../installations/bob-laptop#installation>
} .

# Resolution: Bob's update wins due to later timestamp
<#recipe> schema:description "Updated family recipe" .
```

#### 4.6.4. Design Rationale

**Why Property-Level Tombstones?**
- **Conflict Resolution:** Enables proper CRDT merging when properties are deleted concurrently with updates
- **Semantic Preservation:** Maintains RDF property semantics during collaborative editing
- **Traceability:** Preserves information about what was deleted and when
- **Rollback Support:** Enables recovery of accidentally deleted properties

**Why Document-Level Tombstones?**
- **Storage Efficiency:** Minimizes storage requirements for deleted resources
- **Performance:** Reduces index size and synchronization overhead
- **Lifecycle Clarity:** Provides clear separation between active and deleted resources
- **Garbage Collection:** Enables efficient cleanup of obsolete data

**Integration Benefits:**
- Both tombstone types use identical timestamp and causality mechanisms
- Consistent conflict resolution across property and document levels
- Unified garbage collection and cleanup procedures
- Compatible with standard RDF tooling and semantic web practices

---

## 5. Architectural Data Layers

The framework implements a 4-layer architecture that provides clean separation of concerns while enabling sophisticated collaboration patterns. Each layer builds upon the previous layers, creating a comprehensive solution for distributed RDF data management.

### 5.1. Layer 1: The Data Resource

The Data Resource layer provides clean, standards-based RDF that applications interact with directly. This layer focuses on semantic clarity and interoperability, ensuring that data remains accessible and meaningful regardless of the synchronization infrastructure.

**Core Principles:**
- **Clean RDF:** Standard vocabularies (schema.org, custom vocabularies) without framework pollution
- **Fragment Identifiers:** Clean separation between "things" and "documents" using `#it` pattern
- **Self-Contained Resources:** Each resource contains all necessary semantic information
- **Semantic IRIs:** Resource identifiers that are meaningful and resolvable

**Example Data Resource:**
```turtle
@base <https://alice.example.org/data/recipes/apple-pie> .

<#recipe> a schema:Recipe;
    schema:name "Grandmother's Apple Pie";
    schema:description "Traditional family recipe passed down through generations";
    schema:dateCreated "2023-10-15";
    schema:keywords ("apple", "pie", "dessert", "traditional");
    schema:author <#alice>;
    schema:recipeIngredient <#ingredient-apples>, <#ingredient-flour>, <#ingredient-sugar>;
    schema:recipeInstructions <#instructions> .

<#alice> a schema:Person;
    schema:name "Alice Johnson";
    schema:email "alice@example.org" .

<#ingredient-apples> a schema:RecipeIngredient;
    schema:name "Apples";
    schema:amount "6 medium apples" .

<#ingredient-flour> a schema:RecipeIngredient;
    schema:name "All-purpose flour";
    schema:amount "2 cups" .

<#ingredient-sugar> a schema:RecipeIngredient;
    schema:name "Sugar";
    schema:amount "3/4 cup" .

<#instructions> a schema:HowToSection;
    schema:name "Preparation Instructions";
    schema:text "Peel and slice apples. Mix with sugar and flour. Bake at 350°F for 45 minutes." .
```

**Key Characteristics:**
- **Standard Vocabularies:** Uses schema.org for maximum interoperability
- **Fragment Structure:** Multiple related resources in single document for atomicity
- **Semantic Relationships:** Clear connections between recipe, ingredients, and instructions
- **Human Readable:** Clean, understandable RDF that works with standard tools

**Framework Metadata:**
* **Structure:** The resource is clean and focused on the data's payload. It contains pointers to the other architectural layers. For a clean separation of concerns, it is recommended to store data and indices in separate top-level containers (e.g., `/data/` and `/indices/`). However, a compliant client must always use the backend's resource discovery mechanism as the definitive source for discovering these locations, as a user may choose to configure different paths.

**Application Interface:**
Applications work with this layer through clean, semantic interfaces without exposure to underlying CRDT complexity:

```dart
// Applications see clean domain objects
class Recipe {
  String name;
  String description;
  DateTime dateCreated;
  List<String> keywords;
  Person author;
  List<RecipeIngredient> ingredients;
}

// Framework handles CRDT synchronization transparently
await recipeRepository.save(recipe);
```

### 5.2. Layer 2: The Merge Contract

The Merge Contract layer defines the collaboration rules for each piece of data. This layer contains the public, discoverable CRDT mappings that enable multiple applications to collaborate safely on the same data.

**Fundamental Principle:** All documents stored in user backends by this framework (except for backend-specific discovery metadata) are designed to be merged using the CRDT mechanics described in this layer. This ensures deterministic conflict resolution and maintains data consistency across distributed installations.

#### 5.2.1. Merge Contract Fundamentals

**Core Concepts:**
- **Public Contracts:** Merge rules are published at stable internet URIs, not stored in user backends
- **Property Mappings:** Each property is mapped to a specific CRDT algorithm
- **Stability:** Contracts must remain accessible and stable across application lifecycles
- **Discoverability:** Applications can discover and validate compatible merge behavior

**Critical: Contracts Are Hosted Externally, Not in User Backends**

Merge contracts are **published by application authors or this specification at stable internet URIs** (e.g., `https://kkalass.github.io/meal-planning-app/crdt-mappings/recipe-v1`), not stored in user backends. This separation is essential because:
- **Stability:** Contracts must remain accessible even if individual user backends are offline
- **Consistency:** All installations must reference identical merge rules
- **Versioning:** Contract authors control evolution and backwards compatibility
- **Discoverability:** Applications can validate compatibility before attempting collaboration

**Merge Contract Structure:**
```turtle
# Hosted at: https://w3id.org/rdf-crdt-sync/mappings/recipe-v1
@prefix crdt: <https://w3id.org/rdf-crdt-sync/vocab/crdt-mechanics#> .
@prefix algo: <https://w3id.org/rdf-crdt-sync/vocab/crdt-algorithms#> .
@prefix schema: <https://schema.org/> .

<> a crdt:MergeContract;
   crdt:contractVersion "1.0";
   crdt:importsContract <https://w3id.org/rdf-crdt-sync/mappings/core-v1> .

# Class-scoped property mappings
schema:Recipe crdt:hasPropertyMapping [
    crdt:property schema:name;
    crdt:strategy algo:LWW-Register
], [
    crdt:property schema:description;
    crdt:strategy algo:LWW-Register
], [
    crdt:property schema:dateCreated;
    crdt:strategy algo:Immutable
], [
    crdt:property schema:keywords;
    crdt:strategy algo:OR-Set
], [
    crdt:property schema:author;
    crdt:strategy algo:OR-Set
] .

# Global predicate mappings (applies to all classes)
schema:name crdt:hasGlobalMapping algo:LWW-Register .
schema:dateCreated crdt:hasGlobalMapping algo:Immutable .
```

**Contract Application in Data:**
```turtle
# In the actual data resource
@base <https://alice.example.org/data/recipes/apple-pie> .

<> a sync:ManagedDocument;
   sync:managedResourceType schema:Recipe;
   sync:isGovernedBy <https://w3id.org/rdf-crdt-sync/mappings/recipe-v1> .

<#recipe> a schema:Recipe;
    schema:name "Apple Pie"^^crdt:LWW-Register;
    schema:description "Traditional recipe"^^crdt:LWW-Register;
    schema:dateCreated "2023-10-15"^^crdt:Immutable;
    schema:keywords ("apple", "pie", "dessert")^^crdt:OR-Set .
```

#### 5.2.2. Merge Contract Import Hierarchy and Examples

##### 5.2.2.1. Framework Import Mechanism

Merge contracts support hierarchical imports to enable reuse and ensure consistency across applications:

**Base Framework Contract (Required by All):**
```turtle
# https://w3id.org/rdf-crdt-sync/mappings/core-v1
@prefix crdt: <https://w3id.org/rdf-crdt-sync/vocab/crdt-mechanics#> .
@prefix sync: <https://w3id.org/rdf-crdt-sync/vocab/sync#> .

<> a crdt:MergeContract;
   crdt:contractVersion "1.0";
   rdfs:comment "Core framework mappings required by all RDF-CRDT applications" .

# Framework-required mappings
crdt:ClientInstallation crdt:hasPropertyMapping [
    crdt:property crdt:installationId;
    crdt:strategy algo:Immutable
], [
    crdt:property crdt:createdAt;
    crdt:strategy algo:Immutable
], [
    crdt:property crdt:lastSeenAt;
    crdt:strategy algo:LWW-Register
] .
```

##### 5.2.2.2. Complete Example: Shopping List Entry

**Application-Specific Contract:**
```turtle
# https://example.org/meal-planning/mappings/shopping-v1
@prefix meal: <https://example.org/vocab/meal#> .

<> a crdt:MergeContract;
   crdt:contractVersion "1.0";
   crdt:importsContract <https://w3id.org/rdf-crdt-sync/mappings/core-v1> .

meal:ShoppingListEntry crdt:hasPropertyMapping [
    crdt:property meal:itemName;
    crdt:strategy algo:LWW-Register
], [
    crdt:property meal:quantity;
    crdt:strategy algo:LWW-Register
], [
    crdt:property meal:completed;
    crdt:strategy algo:LWW-Register
], [
    crdt:property meal:addedBy;
    crdt:strategy algo:Immutable
], [
    crdt:property meal:tags;
    crdt:strategy algo:OR-Set
] .
```

**Data Using the Contract:**
```turtle
@base <https://alice.example.org/data/shopping/milk-entry> .

<> a sync:ManagedDocument;
   sync:managedResourceType meal:ShoppingListEntry;
   sync:isGovernedBy <https://example.org/meal-planning/mappings/shopping-v1> .

<#entry> a meal:ShoppingListEntry;
    meal:itemName "Organic Milk"^^crdt:LWW-Register;
    meal:quantity "1 gallon"^^crdt:LWW-Register;
    meal:completed false^^crdt:LWW-Register;
    meal:addedBy <../installations/alice-phone#installation>^^crdt:Immutable;
    meal:tags ("dairy", "organic")^^crdt:OR-Set;
    crdt:createdAt "2023-10-15T14:30:00Z"^^crdt:HybridClock;
    crdt:updatedAt "2023-10-15T15:45:00Z"^^crdt:HybridClock .
```

##### 5.2.2.3. The Contract Hierarchy

**Typical Import Structure:**
```
Core Framework Contract (core-v1)
├── Schema.org Extensions (schema-extensions-v1)
│   ├── Recipe Application Contract (recipe-v1)
│   └── Event Planning Contract (events-v1)
└── Custom Vocabulary Contract (meal-planning-v1)
    └── Shopping List Contract (shopping-v1)
```

**Benefits of Hierarchical Contracts:**
- **Consistency:** Shared base contracts ensure compatible CRDT behavior
- **Reusability:** Common patterns can be defined once and imported
- **Evolution:** Individual contracts can evolve independently
- **Validation:** Framework can verify complete mapping coverage through import chain

#### 5.2.3. Hybrid Logical Clock Mechanics

The framework uses Hybrid Logical Clocks (HLC) to provide tamper-resistant timestamp ordering that combines logical causality with physical time:

**HLC Structure:**
```turtle
"2023-10-15T14:30:00.123Z"^^crdt:HybridClock {
    crdt:logicalTime 1697374200123;      # Physical milliseconds since epoch
    crdt:logicalCounter 5;               # Logical counter for same-millisecond events
    crdt:installation <../installations/alice-phone#installation>
}
```

**HLC Update Algorithm:**
```
When creating a new timestamp:
1. current_physical = current_time_millis()
2. if current_physical > max_logical_time:
     logical_time = current_physical
     logical_counter = 0
   else:
     logical_time = max_logical_time
     logical_counter = max_logical_counter + 1
3. max_logical_time = logical_time
4. max_logical_counter = logical_counter
```

**CRDT Literature Mapping:** The `crdt:installationId` property corresponds to what CRDT literature typically calls "client ID" or "node ID." We use "installation" to distinguish from backend-specific client identifiers, which identify applications rather than specific installation instances.

**Conflict Resolution with HLC:**
```turtle
# Concurrent edits to the same property
# Alice's edit:
<#recipe> schema:name "Apple Pie"^^crdt:HybridClock {
    crdt:logicalTime 1697374200123;
    crdt:logicalCounter 0;
    crdt:installation <../installations/alice-phone#installation>
} .

# Bob's edit (same millisecond):
<#recipe> schema:name "Bob's Apple Pie"^^crdt:HybridClock {
    crdt:logicalTime 1697374200123;
    crdt:logicalCounter 0;
    crdt:installation <../installations/bob-laptop#installation>
} .

# Resolution: Installation IRI comparison (lexicographic)
# Result: Alice's edit wins (alice-phone < bob-laptop)
```

**Benefits:**
- **Tamper Resistance:** Installation identity prevents timestamp manipulation
- **Causality Preservation:** Logical counters maintain event ordering
- **Cross-Platform Compatibility:** Works regardless of clock synchronization
- **Deterministic Ordering:** Identical merge results across all installations

#### 5.2.4. Vocabulary Versioning and Evolution

Contract evolution must balance backwards compatibility with the need for improvements:

**Versioning Strategy:**
```turtle
# Version 1.0 contract
<https://example.org/contracts/recipe-v1> a crdt:MergeContract;
   crdt:contractVersion "1.0" .

# Version 1.1 contract (backwards compatible)
<https://example.org/contracts/recipe-v1.1> a crdt:MergeContract;
   crdt:contractVersion "1.1";
   crdt:backwardsCompatibleWith <https://example.org/contracts/recipe-v1> .

# Version 2.0 contract (breaking changes)
<https://example.org/contracts/recipe-v2> a crdt:MergeContract;
   crdt:contractVersion "2.0";
   crdt:deprecates <https://example.org/contracts/recipe-v1> .
```

**Evolution Rules:**
- **Additive Changes:** New property mappings are backwards compatible
- **Strategy Changes:** Changing CRDT strategies requires new major version
- **Property Removal:** Removing mappings requires migration path
- **Import Changes:** Modifying imports affects all dependent contracts

**Migration Considerations:**
- Applications must handle documents with different contract versions
- Framework should provide migration utilities for contract upgrades
- Mixed-version collaboration requires careful compatibility checking

### 5.3. Layer 3: The Indexing Layer

The Indexing Layer provides performance optimization through sophisticated sharding strategies that enable efficient synchronization even with large datasets. This layer abstracts the complexity of data organization while maintaining semantic clarity.

#### 5.3.1. Index Architecture Overview

**Core Purpose:**
The indexing system serves three critical functions:
1. **Performance Scaling:** Enables synchronization of large datasets without transferring entire collections
2. **Selective Sync:** Supports applications that only need subsets of available data
3. **Collaborative Coordination:** Provides shared structure for multi-installation collaboration

**Two Index Types:**

**FullIndex (Monolithic):**
- Single index containing all items of a specific type
- Best for small to medium datasets (< 1000 items)
- Simple synchronization: sync entire index
- Example use case: Personal recipe collection

**GroupIndex (Partitioned):**
- Items organized into groups using regex-based transformations
- Each group can be synchronized independently
- Supports hierarchical organization (date-based, category-based)
- Example use case: Large photo collections organized by year/month

**Sharding Within Index Types:**
Both index types support sharding for performance:
- 1-16 shards per index based on item count
- O(1) change detection via lightweight shard headers
- Bandwidth optimization through selective shard synchronization

**Index Structure Example:**
```turtle
# FullIndex for recipes
@base <https://alice.example.org/indices/recipes/> .

<index> a idx:FullIndex;
    idx:indexesClass schema:Recipe;
    idx:itemFetchPolicy idx:Prefetch;
    idx:belongsToIndexShard <shard-mod-md5-0>, <shard-mod-md5-1>;
    idx:totalItemCount 157;
    idx:lastModified "2023-10-15T16:30:00Z"^^crdt:HybridClock .

<shard-mod-md5-0> a idx:IndexShard;
    idx:shardId "shard-mod-md5-0";
    idx:itemCount 78;
    idx:stateHash "a1b2c3d4e5f6789012345678901234567890abcd";
    idx:lastModified "2023-10-15T15:20:00Z"^^crdt:HybridClock .
```

#### 5.3.2. Framework Vocabulary

The indexing layer uses the `idx:` vocabulary for all metadata:

**Core Index Types:**
- **`idx:FullIndex`:** Monolithic index containing all items
- **`idx:GroupIndex`:** Partitioned index with group-based organization
- **`idx:IndexShard`:** Individual shard within an index

**Index Configuration:**
- **`idx:indexesClass`:** RDF class that this index manages
- **`idx:itemFetchPolicy`:** Sync strategy (prefetch vs onRequest)
- **`idx:groupingRule`:** Regex transformation for GroupIndex partitioning

**Performance Metadata:**
- **`idx:totalItemCount`:** Total items across all shards
- **`idx:itemCount`:** Items in specific shard
- **`idx:stateHash`:** MD5 hash for O(1) change detection
- **`idx:lastModified`:** HLC timestamp of most recent change

**Item Management:**
- **`idx:belongsToIndexShard`:** Links items to their containing shard
- **`idx:groupKey`:** Group identifier for partitioned indices
- **`idx:itemIri`:** IRI of the actual data resource

#### 5.3.3. GroupingRule Specification

GroupIndex organization uses regex-based transformations to extract group keys from resource IRIs:

**Date-Based Grouping:**
```turtle
<group-index> a idx:GroupIndex;
    idx:indexesClass schema:BlogPost;
    idx:groupingRule [
        idx:regex "https://blog\.example\.org/posts/([0-9]{4})/([0-9]{2})/.*";
        idx:replacement "$1-$2";
        idx:description "Group blog posts by year-month"
    ] .

# Example transformation:
# IRI: https://blog.example.org/posts/2023/10/my-apple-pie-adventure
# Group Key: "2023-10"
```

**Category-Based Grouping:**
```turtle
<group-index> a idx:GroupIndex;
    idx:indexesClass schema:Recipe;
    idx:groupingRule [
        idx:regex "https://recipes\.example\.org/([^/]+)/.*";
        idx:replacement "$1";
        idx:description "Group recipes by category"
    ] .

# Example transformation:
# IRI: https://recipes.example.org/desserts/apple-pie
# Group Key: "desserts"
```

**Hierarchical Grouping:**
```turtle
<photo-index> a idx:GroupIndex;
    idx:indexesClass schema:Photograph;
    idx:groupingRule [
        idx:regex "https://photos\.example\.org/([0-9]{4})/([0-9]{2})/([0-9]{2})/.*";
        idx:replacement "$1/$2";
        idx:description "Group photos by year/month"
    ] .

# Creates hierarchical structure:
# 2023/10/, 2023/11/, 2024/01/, etc.
```

**Group Key Safety:**
Group keys must be filesystem-safe and deterministic:
```turtle
# Unsafe characters transformed to safe equivalents
"My Recipes & Notes" → "My_Recipes___Notes"

# Hash-based safety for very long group keys
"very-long-group-name-that-exceeds-filesystem-limits" → "32_{32-char-md5-hash}"
```

#### 5.3.4. Sharding and Performance

**Shard Distribution Algorithm:**
```
shard_id = md5(item_iri) mod shard_count
shard_name = "shard-mod-md5-{shard_id}"
```

**Shard Count Selection:**
- **1-50 items:** 1 shard
- **51-200 items:** 2 shards
- **201-500 items:** 4 shards
- **501-1000 items:** 8 shards
- **1000+ items:** 16 shards (maximum)

**Shard Structure:**
```turtle
# Lightweight shard header
<shard-mod-md5-0> a idx:IndexShard;
    idx:shardId "shard-mod-md5-0";
    idx:itemCount 78;
    idx:stateHash "a1b2c3d4e5f6789012345678901234567890abcd";
    idx:lastModified "2023-10-15T15:20:00Z"^^crdt:HybridClock .

# Followed by shard items
<item-1> a idx:IndexItem;
    idx:itemIri <../../data/recipes/apple-pie>;
    idx:groupKey "desserts";
    idx:lastModified "2023-10-15T14:30:00Z"^^crdt:HybridClock .

<item-2> a idx:IndexItem;
    idx:itemIri <../../data/recipes/banana-bread>;
    idx:groupKey "desserts";
    idx:lastModified "2023-10-15T13:15:00Z"^^crdt:HybridClock .
```

**Change Detection Workflow:**
1. **Fetch shard headers:** Compare local `stateHash` with remote `stateHash`
2. **Identify changed shards:** Only sync shards with different hashes
3. **Selective synchronization:** Download only modified shard content
4. **Update local state:** Merge received shard data with local changes

#### 5.3.5. Structure-Derived Index Naming

Index locations use deterministic naming based on the managed resource type and index configuration:

**FullIndex Naming:**
```
Base: https://alice.example.org/indices/
Type: schema:Recipe
Structure: FullIndex
Result: https://alice.example.org/indices/recipes/
```

**GroupIndex Naming:**
```
Base: https://alice.example.org/indices/
Type: schema:BlogPost
Structure: GroupIndex with date grouping
Result: https://alice.example.org/indices/blog-posts-by-date/
```

**Shard Naming Within Indices:**
```
Index: https://alice.example.org/indices/recipes/
Shards:
- https://alice.example.org/indices/recipes/shard-mod-md5-0
- https://alice.example.org/indices/recipes/shard-mod-md5-1
- https://alice.example.org/indices/recipes/shard-mod-md5-2
- etc.
```

**Benefits of Deterministic Naming:**
- **Predictable:** Installations can compute index locations without discovery
- **Cacheable:** Standard naming enables effective caching strategies
- **Debuggable:** Clear relationship between resource types and index locations

#### 5.3.6. Index Population Mechanics

**Population Workflow for New Items:**
1. **Item Creation:** Application creates new data resource
2. **Group Assignment:** Framework applies grouping rule to determine group key
3. **Shard Assignment:** MD5 hash determines target shard
4. **Index Update:** Add item metadata to appropriate shard
5. **Header Update:** Update shard and index headers with new counts and hashes

**Example Population:**
```dart
// Application creates recipe
Recipe recipe = Recipe(
  iri: 'https://alice.example.org/data/recipes/chocolate-cake',
  name: 'Chocolate Cake'
);

// Framework processing:
// 1. Extract group key using regex
String groupKey = applyGroupingRule(recipe.iri);  // → "desserts"

// 2. Determine shard assignment
int shardId = md5Hash(recipe.iri) % shardCount;  // → 2

// 3. Update target shard
await updateIndexShard('shard-mod-md5-2', recipe, groupKey);

// 4. Update index headers
await updateIndexHeaders();
```

**Batch Population for Efficiency:**
```dart
// Framework batches multiple updates
List<Recipe> newRecipes = [...];
Map<String, List<Recipe>> shardGroups = groupByTargetShard(newRecipes);

for (String shardId in shardGroups.keys) {
  await updateIndexShard(shardId, shardGroups[shardId]);
}

await updateAllIndexHeaders();
```

#### 5.3.7. Installation Index Management and Scalability

**Installation Index Purpose:**
The installation index enables efficient management operations by tracking all active installations:

```turtle
@base <https://alice.example.org/indices/installations/> .

<index> a idx:FullIndex;
    idx:indexesClass crdt:ClientInstallation;
    idx:itemFetchPolicy idx:Prefetch;
    idx:totalItemCount 5 .

# Installation entries
<installation-1> a idx:IndexItem;
    idx:itemIri <../../installations/alice-phone>;
    crdt:lastSeenAt "2023-10-15T16:45:00Z"^^crdt:HybridClock .

<installation-2> a idx:IndexItem;
    idx:itemIri <../../installations/bob-laptop>;
    crdt:lastSeenAt "2023-10-15T15:30:00Z"^^crdt:HybridClock .
```

**Management Phase Benefits:**
- **Efficient dormancy detection:** Query installation index to find inactive installations
- **Batch validation:** Validate multiple installation states without individual backend requests
- **Coordinated cleanup:** Identify candidates for garbage collection across the system

#### 5.3.8. Index Structure Examples

**Small Dataset: FullIndex with Single Shard**
```turtle
@base <https://alice.example.org/indices/recipes/> .

<index> a idx:FullIndex;
    idx:indexesClass schema:Recipe;
    idx:itemFetchPolicy idx:Prefetch;
    idx:belongsToIndexShard <shard-mod-md5-0>;
    idx:totalItemCount 23 .

<shard-mod-md5-0> a idx:IndexShard;
    idx:itemCount 23;
    idx:stateHash "abc123...";

    # All recipe items in single shard
    idx:contains <item-apple-pie>, <item-banana-bread>, <item-chocolate-cake> .

<item-apple-pie> a idx:IndexItem;
    idx:itemIri <../../data/recipes/apple-pie>;
    idx:lastModified "2023-10-15T14:30:00Z"^^crdt:HybridClock .
```

**Large Dataset: GroupIndex with Multiple Shards**
```turtle
@base <https://alice.example.org/indices/photos-by-date/> .

<index> a idx:GroupIndex;
    idx:indexesClass schema:Photograph;
    idx:itemFetchPolicy idx:OnRequest;
    idx:groupingRule [
        idx:regex "https://photos\.example\.org/([0-9]{4})/([0-9]{2})/.*";
        idx:replacement "$1-$2"
    ];
    idx:belongsToIndexShard <shard-mod-md5-0>, <shard-mod-md5-1>, <shard-mod-md5-2>, <shard-mod-md5-3>;
    idx:totalItemCount 2847 .

# Group shards contain items from different time periods
<shard-mod-md5-0> a idx:IndexShard;
    idx:itemCount 712;
    idx:stateHash "def456...";

    # Items from various months based on hash distribution
    idx:contains <item-2023-01-photo1>, <item-2023-05-photo7>, <item-2023-10-photo12> .

<item-2023-01-photo1> a idx:IndexItem;
    idx:itemIri <../../data/photos/2023/01/vacation-photo-1>;
    idx:groupKey "2023-01";
    idx:lastModified "2023-01-15T10:30:00Z"^^crdt:HybridClock .

<item-2023-10-photo12> a idx:IndexItem;
    idx:itemIri <../../data/photos/2023/10/autumn-leaves>;
    idx:groupKey "2023-10";
    idx:lastModified "2023-10-15T16:00:00Z"^^crdt:HybridClock .
```

**Mixed Index Strategy Example:**
```turtle
# Recipes: Small collection, FullIndex with prefetch
<recipe-index> a idx:FullIndex;
    idx:indexesClass schema:Recipe;
    idx:itemFetchPolicy idx:Prefetch;
    idx:totalItemCount 45 .

# Photos: Large collection, GroupIndex with on-demand loading
<photo-index> a idx:GroupIndex;
    idx:indexesClass schema:Photograph;
    idx:itemFetchPolicy idx:OnRequest;
    idx:totalItemCount 3200 .

# Shopping entries: Medium collection, GroupIndex by week
<shopping-index> a idx:GroupIndex;
    idx:indexesClass meal:ShoppingListEntry;
    idx:itemFetchPolicy idx:Prefetch;
    idx:groupingRule [
        idx:regex ".*/([0-9]{4})-W([0-9]{2})/.*";
        idx:replacement "$1-W$2"
    ];
    idx:totalItemCount 380 .
```

### 5.4. Layer 4: The Sync Strategy

The Sync Strategy layer provides application control over synchronization patterns, enabling developers to optimize performance and user experience based on their specific use cases. This layer combines index structure decisions with timing strategies to create comprehensive synchronization approaches.

#### 5.4.1. Decision 1: Index Structure

**FullIndex Strategy:**
- **Use Case:** Small to medium datasets where users typically work with most items
- **Characteristics:** Single monolithic index, all items discoverable immediately
- **Benefits:** Simple mental model, complete offline availability, fast local queries
- **Tradeoffs:** Higher initial sync time, bandwidth usage grows with dataset size

**GroupIndex Strategy:**
- **Use Case:** Large datasets with natural partitioning (date, category, project)
- **Characteristics:** Items organized into groups, selective group synchronization
- **Benefits:** Scalable to large datasets, selective sync reduces bandwidth
- **Tradeoffs:** More complex setup, partial offline availability

**Selection Criteria:**
```
Dataset Size < 1000 items → Consider FullIndex
Dataset Size > 1000 items → Consider GroupIndex
User works with entire dataset → Prefer FullIndex
User works with subsets → Prefer GroupIndex
Bandwidth is limited → Prefer GroupIndex
Offline availability critical → Prefer FullIndex
```

#### 5.4.2. Decision 2: Sync Timing

**ItemFetchPolicy.Prefetch:**
- **Behavior:** Download all item data during index synchronization
- **Benefits:** Complete offline access, instant application responsiveness
- **Costs:** Higher bandwidth usage, longer initial sync time

**ItemFetchPolicy.OnRequest:**
- **Behavior:** Download item metadata only, fetch full data when needed
- **Benefits:** Fast initial sync, minimal bandwidth for browsing
- **Costs:** Requires network for item details, partial offline availability

**Hybrid Approaches:**
```dart
// Recently viewed items: prefetch for immediate access
recentPhotosRepository.configure(
  indexType: GroupIndex(groupBy: dateWeek),
  fetchPolicy: ItemFetchPolicy.Prefetch,
  groupFilter: lastTwoWeeks
);

// Archive items: on-demand to save bandwidth
archivePhotosRepository.configure(
  indexType: GroupIndex(groupBy: dateYear),
  fetchPolicy: ItemFetchPolicy.OnRequest,
  groupFilter: olderThanTwoWeeks
);
```

#### 5.4.3. Common Strategies

**Strategy 1: Personal Collection (FullSync)**
```dart
// Recipe collection: complete dataset, immediate access
RecipeRepository configure(
  indexType: FullIndex(),
  fetchPolicy: ItemFetchPolicy.Prefetch
);
```
- **Best For:** Personal recipe collections, bookmark lists, contact databases
- **Characteristics:** 10-500 items, frequent access to diverse items
- **User Experience:** Instant search, complete offline access, simple synchronization

**Strategy 2: Timeline Data (GroupedSync)**
```dart
// Photo collection: date-based groups, selective sync
PhotoRepository configure(
  indexType: GroupIndex(
    groupBy: DatePattern("yyyy-MM"),
    autoSyncGroups: currentAndLastMonth
  ),
  fetchPolicy: ItemFetchPolicy.OnRequest
);
```
- **Best For:** Photo libraries, journal entries, activity logs
- **Characteristics:** 1000+ items, temporal access patterns
- **User Experience:** Fast browsing recent items, on-demand access to archives

**Strategy 3: Project-Based (GroupedSync)**
```dart
// Document management: project-based groups
DocumentRepository configure(
  indexType: GroupIndex(
    groupBy: ProjectPattern("/projects/([^/]+)/"),
    autoSyncGroups: activeProjects
  ),
  fetchPolicy: ItemFetchPolicy.Prefetch
);
```
- **Best For:** Project documents, client files, research materials
- **Characteristics:** Clear project boundaries, focus on active work
- **User Experience:** Complete access to active projects, selective archive access

**Strategy 4: Hybrid Collection (Mixed)**
```dart
// Shopping list: recent items prefetched, history on-demand
ShoppingRepository configure([
  // Current week: immediate access
  SubRepository(
    indexType: GroupIndex(groupBy: weekPattern),
    fetchPolicy: ItemFetchPolicy.Prefetch,
    groupFilter: currentWeek
  ),
  // History: browsable but on-demand
  SubRepository(
    indexType: GroupIndex(groupBy: monthPattern),
    fetchPolicy: ItemFetchPolicy.OnRequest,
    groupFilter: previousMonths
  )
]);
```
- **Best For:** Shopping lists, task management, communication logs
- **Characteristics:** Recent items need immediate access, history provides context
- **User Experience:** Fast interaction with current data, searchable historical context

---

## 6. Lifecycle Management

This section covers the practical aspects of setting up and maintaining RDF-CRDT synchronization across the entire system lifecycle, from initial backend configuration to ongoing collaborative coordination.

### 6.1. Backend Setup and Initial Configuration

When an application first encounters a backend, it may need to configure the discovery mechanism and other backend infrastructure. The framework provides standard templates for this initialization process:

**Comprehensive Setup Process:**
1. Check backend for existing resource discovery configuration
2. Query discovery mechanism for required managed resource registrations (sync:ManagedDocument with sync:managedResourceType schema:Recipe, idx:FullIndex, crdt:ClientInstallation, etc.)
3. Collect all missing/required configuration:
   - Missing discovery mechanism entirely
   - Missing registrations for managed data types (sync:ManagedDocument)
   - Missing registrations for indices
   - Missing registrations for installations
4. If any configuration is missing: Display single comprehensive "Backend Setup Dialog"
5. User chooses approach:
   1. **"Automatic Setup"** - Configure backend with standard paths automatically
   2. **"Custom Setup"** - Review and modify proposed backend configuration changes before applying
6. If user cancels: Run with hardcoded default paths, warn about reduced interoperability

**Setup Dialog Design Principles:**
- **Explicit Consent:** Never modify backend configuration without user permission
- **Progressive Disclosure:** Automatic Setup shields users from complexity, Custom Setup provides full control
- **Clear Options:** Two main paths - trust the app or customize the details
- **Graceful Fallback:** Always offer alternative approaches if user declines configuration changes

**Example Setup Flow:**
```
1. Discover missing discovery registrations for sync:ManagedDocument with sync:managedResourceType schema:Recipe
2. Present setup dialog: "This app needs to configure CRDT-managed recipe storage in your backend"
3. User selects "Automatic Setup"
4. App creates discovery entries for managed recipes, recipe index, client installations
5. App proceeds with normal synchronization workflow
```

### 6.2. Installation Document Creation

After successful backend setup, the framework automatically creates an Installation Document (`crdt:ClientInstallation`) to represent this specific client installation in the collaborative system. This document establishes the installation's identity and enables collaborative coordination with other installations.

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
6. **Clean re-sync:** Re-synchronize all data from backend with fresh collaborative state

**Installation Document Template:**
```turtle
@base <https://alice.example.org/installations/550e8400-e29b-41d4-a716-446655440000> .

<> a sync:ManagedDocument;
   sync:managedResourceType crdt:ClientInstallation;
   sync:isGovernedBy <https://w3id.org/rdf-crdt-sync/mappings/core-v1> .

<#installation> a crdt:ClientInstallation;
    crdt:installationId "550e8400-e29b-41d4-a716-446655440000";
    crdt:createdAt "2023-10-15T14:30:00Z"^^crdt:HybridClock;
    crdt:lastSeenAt "2023-10-15T14:30:00Z"^^crdt:HybridClock;
    crdt:appName "Meal Planning App";
    crdt:appVersion "1.2.3";
    crdt:deviceInfo "iPhone 12, iOS 17.1" .
```

### 6.3. System Index Setup

Before any application data can be synchronized, the framework establishes core system indices required for collaborative coordination:

**Installation Index Creation:**
```turtle
@base <https://alice.example.org/indices/installations/> .

<index> a idx:FullIndex;
    idx:indexesClass crdt:ClientInstallation;
    idx:itemFetchPolicy idx:Prefetch;
    idx:belongsToIndexShard <shard-mod-md5-0>;
    idx:totalItemCount 1 .

<shard-mod-md5-0> a idx:IndexShard;
    idx:shardId "shard-mod-md5-0";
    idx:itemCount 1;
    idx:stateHash "a1b2c3d4e5f6789012345678901234567890abcd";
    idx:lastModified "2023-10-15T14:30:00Z"^^crdt:HybridClock .
```

**Framework Garbage Collection Index:**
The system also creates a garbage collection index for managing framework cleanup operations (see Section 6.6 for details).

### 6.4. Application Index Setup

After system indices are established, applications configure indices for their specific data types based on their chosen sync strategies:

**FullIndex Setup Example:**
```turtle
@base <https://alice.example.org/indices/recipes/> .

<index> a idx:FullIndex;
    idx:indexesClass schema:Recipe;
    idx:itemFetchPolicy idx:Prefetch;
    idx:belongsToIndexShard <shard-mod-md5-0>;
    idx:totalItemCount 0 .

<shard-mod-md5-0> a idx:IndexShard;
    idx:shardId "shard-mod-md5-0";
    idx:itemCount 0;
    idx:stateHash "da39a3ee5e6b4b0d3255bfef95601890afd80709";  # Empty content hash
    idx:lastModified "2023-10-15T14:30:00Z"^^crdt:HybridClock .
```

**GroupIndex Setup Example:**
```turtle
@base <https://alice.example.org/indices/shopping-entries-by-week/> .

<index> a idx:GroupIndex;
    idx:indexesClass meal:ShoppingListEntry;
    idx:itemFetchPolicy idx:Prefetch;
    idx:groupingRule [
        idx:regex ".*/([0-9]{4})-W([0-9]{2})/.*";
        idx:replacement "$1-W$2";
        idx:description "Group shopping entries by ISO week"
    ];
    idx:belongsToIndexShard <shard-mod-md5-0>;
    idx:totalItemCount 0 .
```

### 6.5. Resource Creation and Naming

Once backend setup is complete and all required system and application indices are established and synchronized, applications can begin creating data resources. Resource naming is a critical design decision that affects both performance and maintainability, requiring careful consideration of backend filesystem limitations and RDF principles.

**Filesystem Considerations:**
Most backend storage systems (including filesystem-based ones) can experience performance degradation with thousands of files in a single directory. While the framework uses sophisticated sharding for indices, data resources still need thoughtful organization.

**IRI Design Principles:**
Resource IRIs are **identifiers**, not storage locations. Any organizational structure must derive from **invariant properties** of the resource that will never change. Changing IRIs breaks references and violates RDF principles.

**Recommended Patterns:**

**Pattern 1: UUID-Based Naming (Most Robust)**
```turtle
# Generate UUID v4 for each resource
@base <https://alice.example.org/data/recipes/f47ac10b-58cc-4372-a567-0e02b2c3d479> .

<#recipe> a schema:Recipe;
    schema:name "Apple Pie";
    schema:dateCreated "2023-10-15" .
```
- **Benefits:** Guaranteed uniqueness, no filesystem conflicts, stable forever
- **Drawbacks:** Non-human-readable, requires index for discovery

**Pattern 2: Semantic Hierarchies (Human-Friendly)**
```turtle
# Organize by invariant semantic properties
@base <https://alice.example.org/data/recipes/desserts/apple-pie-2023-10-15> .

<#recipe> a schema:Recipe;
    schema:name "Apple Pie";
    schema:recipeCategory "desserts";
    schema:dateCreated "2023-10-15" .
```
- **Benefits:** Human-readable, natural organization, debuggable
- **Drawbacks:** Risk of conflicts, harder to ensure invariant properties

**Pattern 3: Hybrid Approach (Recommended)**
```turtle
# Combine human semantics with guaranteed uniqueness
@base <https://alice.example.org/data/recipes/desserts/apple-pie-f47ac10b> .

<#recipe> a schema:Recipe;
    schema:name "Apple Pie";
    schema:recipeCategory "desserts";
    schema:dateCreated "2023-10-15";
    schema:identifier "f47ac10b-58cc-4372-a567-0e02b2c3d479" .
```
- **Benefits:** Human-readable, guaranteed uniqueness, semantic organization
- **Drawbacks:** Slightly more complex IRI structure

**Directory Structure Recommendations:**
```
/data/
├── recipes/           # By type
│   ├── desserts/      # By category (< 1000 items each)
│   ├── main-dishes/
│   └── appetizers/
├── shopping-entries/  # By type
│   ├── 2023-W41/      # By week (temporal partitioning)
│   ├── 2023-W42/
│   └── 2023-W43/
└── installations/     # System resources
    └── {uuid}/
```

### 6.6. Framework Garbage Collection Index

The framework implements a comprehensive garbage collection system to manage storage efficiency and maintain system health over time. This system requires a dedicated index to coordinate cleanup operations across multiple installations.

#### 6.6.1. Design and Structure

**Garbage Collection Index Purpose:**
The GC index serves as the authoritative record of deletion decisions and coordinates cleanup operations across all installations. It enables efficient discovery of tombstoned resources and provides the foundation for retention policy enforcement.

**GC Index Structure:**
```turtle
@base <https://alice.example.org/indices/framework-gc/> .

<index> a idx:FullIndex;
    idx:indexesClass sync:TombstoneRecord;
    idx:itemFetchPolicy idx:Prefetch;
    idx:belongsToIndexShard <shard-mod-md5-0>;
    idx:totalItemCount 15 .

<shard-mod-md5-0> a idx:IndexShard;
    idx:shardId "shard-mod-md5-0";
    idx:itemCount 15;
    idx:stateHash "e3b0c44298fc1c149afbf4c8996fb92427ae41e4";
    idx:lastModified "2023-10-15T18:00:00Z"^^crdt:HybridClock .

# Tombstone record entries
<record-1> a idx:IndexItem;
    idx:itemIri <gc-record-apple-pie-recipe>;
    idx:lastModified "2023-10-15T16:00:00Z"^^crdt:HybridClock .

<gc-record-apple-pie-recipe> a sync:TombstoneRecord;
    sync:originalResourceIri <../../data/recipes/desserts/apple-pie>;
    sync:originalResourceType schema:Recipe;
    sync:tombstonedAt "2023-10-15T16:00:00Z"^^crdt:HybridClock;
    sync:tombstonedBy <../../installations/alice-phone#installation>;
    sync:retentionEligibleAt "2023-11-15T16:00:00Z"^^crdt:HybridClock;  # 30 days later
    sync:gcStatus sync:PendingGarbageCollection .
```

**Tombstone Record Properties:**
- **`sync:originalResourceIri`:** IRI of the tombstoned data resource
- **`sync:originalResourceType`:** RDF type of the original resource for index cleanup
- **`sync:tombstonedAt`:** HLC timestamp when resource was tombstoned
- **`sync:tombstonedBy`:** Installation that performed the tombstoning
- **`sync:retentionEligibleAt`:** Earliest timestamp when resource becomes eligible for garbage collection
- **`sync:gcStatus`:** Current garbage collection state (PendingGarbageCollection, Collected, etc.)

#### 6.6.2. Cleanup Operations

**Garbage Collection Workflow:**
1. **Tombstone Creation:** When a resource is deleted, create tombstone record in GC index
2. **Retention Period:** Resource remains tombstoned but recoverable during retention period (default: 30 days)
3. **Cleanup Eligibility:** After retention period expires, resource becomes eligible for garbage collection
4. **Coordinated Cleanup:** Management phase identifies eligible resources and removes both data and index entries
5. **Record Update:** Update GC index to reflect successful cleanup

**Multi-Installation Coordination:**
```turtle
# Installation A tombstones a recipe
<gc-record-recipe-123> sync:gcStatus sync:PendingGarbageCollection;
    sync:retentionEligibleAt "2023-11-15T16:00:00Z" .

# During management phase, Installation B checks eligibility
# If current time > retentionEligibleAt, proceed with cleanup:
# 1. Remove data resource from storage
# 2. Remove resource from all relevant indices
# 3. Update GC record status

<gc-record-recipe-123> sync:gcStatus sync:Collected;
    sync:collectedAt "2023-11-16T10:30:00Z"^^crdt:HybridClock;
    sync:collectedBy <../installations/bob-laptop#installation> .
```

**Benefits of Centralized GC Index:**
- **Coordinated Cleanup:** Prevents race conditions between installations
- **Retention Policy Enforcement:** Provides consistent retention periods across all installations
- **Audit Trail:** Maintains record of deletion decisions and cleanup operations
- **Recovery Support:** Enables discovery of recently deleted resources for potential recovery

### 6.7. Retention Policies and Cleanup Configuration

**Default Retention Policy:**
- **Data Resources:** 30 days retention after tombstoning
- **Installation Documents:** 90 days retention after last activity
- **Index Entries:** Cleaned up immediately when associated data is garbage collected

**Configurable Retention Periods:**
```dart
// Application-specific retention configuration
RetentionPolicy configure(
  dataResources: Duration.days(30),
  installationDocuments: Duration.days(90),
  auditRecords: Duration.days(365),  // Longer retention for audit compliance
  temporaryData: Duration.hours(24)   // Short retention for temporary resources
);
```

**Retention Policy Enforcement:**
```turtle
# GC record with custom retention period
<gc-record-audit-log> a sync:TombstoneRecord;
    sync:originalResourceIri <../../audit/login-event-123>;
    sync:originalResourceType audit:LoginEvent;
    sync:tombstonedAt "2023-10-15T16:00:00Z"^^crdt:HybridClock;
    sync:retentionEligibleAt "2024-10-15T16:00:00Z"^^crdt:HybridClock;  # 365 days for audit
    sync:retentionPolicy audit:ComplianceRetention .
```

### 6.8. Collaborative Index Lifecycle Management

#### 6.8.1. Reader Management and Cleanup

**Installation Dormancy Detection:**
The framework tracks installation activity through `lastSeenAt` timestamps in the Installation Index:

```turtle
<alice-phone> crdt:lastSeenAt "2023-10-15T16:45:00Z"^^crdt:HybridClock .
<bob-laptop> crdt:lastSeenAt "2023-10-10T09:30:00Z"^^crdt:HybridClock .  # 5 days inactive
<charlie-tablet> crdt:lastSeenAt "2023-09-15T14:20:00Z"^^crdt:HybridClock .  # 30 days inactive
```

**Dormancy Thresholds:**
- **Active:** Last seen within 7 days
- **Dormant:** Last seen 7-30 days ago
- **Inactive:** Last seen more than 30 days ago (eligible for cleanup)

**Installation Cleanup Process:**
1. **Detection:** Management phase identifies installations inactive for > 30 days
2. **Validation:** Attempt to contact installation (optional ping mechanism)
3. **Tombstoning:** Mark installation document as deleted
4. **Index Cleanup:** Remove installation from all relevant indices
5. **Notification:** Log cleanup action for audit purposes

#### 6.8.2. Index States and Reactivation

**Installation Reactivation:**
If a previously tombstoned installation becomes active again:

1. **Fresh Start Required:** Generate new installation ID and reset local state
2. **Clean Re-sync:** Download current index state and rebuild local caches
3. **No Data Loss:** All collaborative data remains intact, only installation identity resets

**Benefits of Clean Reactivation:**
- **State Consistency:** Eliminates potential synchronization conflicts from old state
- **System Health:** Prevents accumulation of orphaned index entries
- **Simple Recovery:** Straightforward reactivation process without complex conflict resolution

### 6.9. Error Handling and Recovery

#### 6.9.1. Recovery Principles

**Graceful Degradation:** The system continues operating with reduced functionality when components fail
**Progressive Recovery:** Errors are resolved incrementally as connectivity and resources become available
**Data Preservation:** No data loss during error conditions or recovery procedures
**Transparent Healing:** Automatic recovery when possible, clear user feedback when intervention required

#### 6.9.2. Key Recovery Scenarios

**Network Connectivity Issues:**
- **Offline Operation:** Continue with cached data, queue synchronization operations
- **Partial Connectivity:** Sync what's possible, retry failed operations with exponential backoff
- **Reconnection:** Resume synchronization where left off using cursor mechanisms

**Backend Storage Conflicts:**
- **ETag Mismatches:** Re-fetch current state, perform CRDT merge, retry operation
- **Concurrent Modifications:** Use HLC timestamps for deterministic conflict resolution
- **Corruption Detection:** Validate document structure, request re-sync if invalid

**Index Inconsistencies:**
- **Missing Index Entries:** Rebuild index from data resources during management phase
- **Orphaned Index Entries:** Remove entries that reference non-existent data resources
- **Hash Mismatches:** Re-compute index shard hashes and update accordingly

**Installation Recovery:**
- **Lost Installation ID:** Create fresh installation identity and re-sync all data
- **Tombstoned Installation:** Follow clean reactivation process described in Section 6.8.2
- **Corrupted Local State:** Reset to clean state and perform full re-synchronization

---

## 7. Synchronization Workflow

This section provides concrete algorithms and workflows for implementing RDF-CRDT synchronization, covering both the core synchronization operations and the management phase that maintains system health.

### 7.1. Concrete Workflow Example

To illustrate the complete synchronization process, consider Alice's recipe application synchronizing with her backend storage:

**Setup Phase (First Run):**
1. **Backend Discovery:** Check for existing resource discovery configuration
2. **Installation Registration:** Create installation document with UUID `alice-phone-550e8400`
3. **Index Setup:** Create recipe index and installation index
4. **Initial State:** System ready for data synchronization

**Data Creation and Sync:**
```turtle
# Alice creates a new recipe
@base <https://alice.example.org/data/recipes/apple-pie> .

<> a sync:ManagedDocument;
   sync:managedResourceType schema:Recipe;
   sync:isGovernedBy <https://w3id.org/rdf-crdt-sync/mappings/recipe-v1> .

<#recipe> a schema:Recipe;
    schema:name "Apple Pie"^^crdt:LWW-Register;
    schema:description "Traditional family recipe"^^crdt:LWW-Register;
    schema:dateCreated "2023-10-15"^^crdt:Immutable;
    schema:keywords ("apple", "pie", "dessert")^^crdt:OR-Set;
    crdt:createdAt "2023-10-15T14:30:00Z"^^crdt:HybridClock;
    crdt:updatedAt "2023-10-15T14:30:00Z"^^crdt:HybridClock .
```

**Synchronization Workflow:**
1. **Index Update:** Add recipe to recipe index shard
2. **Storage Upload:** PUT recipe document to backend storage
3. **Index Upload:** PUT updated index shard to backend storage
4. **Local Cache:** Update local caches with new recipe data

**Collaborative Editing:**
When Bob edits the same recipe from his installation:
```turtle
# Bob's concurrent edit (different property)
<#recipe> schema:keywords ("apple", "pie", "dessert", "traditional")^^crdt:OR-Set;
    crdt:updatedAt "2023-10-15T14:35:00Z"^^crdt:HybridClock .
```

**Conflict Resolution:**
During next synchronization, CRDT algorithms merge changes:
- Alice's description (LWW-Register): Preserved
- Bob's keywords (OR-Set): Union of both keyword sets
- Result: Clean merge with no data loss

### 7.2. Management Phase Operations

The management phase performs system maintenance operations that ensure long-term health and performance of the collaborative synchronization system.

#### 7.2.1. Lazy Evaluation Principle

**Core Philosophy:** Management operations are expensive and infrequent. The framework uses lazy evaluation to minimize overhead while ensuring system correctness.

**Management Operations Include:**
- **Installation Dormancy Detection:** Identify inactive installations for cleanup
- **Garbage Collection:** Remove tombstoned resources beyond retention period
- **Index Consistency Validation:** Verify index entries match actual data resources
- **Performance Optimization:** Rebalance shards, optimize index structures

**Lazy Triggers:**
Management phase executes when:
1. **Time-based:** Periodic execution (daily/weekly) based on application requirements
2. **Threshold-based:** When system metrics exceed configured limits (index size, dormant installations)
3. **User-triggered:** Manual execution for troubleshooting or maintenance
4. **Error-triggered:** Automatic execution when inconsistencies are detected

**Example Lazy Evaluation:**
```dart
// Management phase triggers
class ManagementPhase {
  DateTime lastExecution = DateTime.fromMillisecondsSinceEpoch(0);

  bool shouldExecute() {
    // Time-based: once per day minimum
    if (DateTime.now().difference(lastExecution) > Duration.days(1)) return true;

    // Threshold-based: too many dormant installations
    if (dormantInstallationCount > 10) return true;

    // Threshold-based: index fragmentation
    if (averageShardUtilization < 0.3) return true;

    return false;
  }
}
```

#### 7.2.2. Management Phase Scope and Frequency

**Operation Categories by Frequency:**

**Daily Operations:**
- Update installation `lastSeenAt` timestamps
- Check for tombstoned resources eligible for garbage collection
- Validate critical index consistency (installation index, GC index)

**Weekly Operations:**
- Detect dormant installations (inactive > 7 days)
- Perform garbage collection of eligible resources
- Optimize index shard distribution if needed

**Monthly Operations:**
- Cleanup inactive installations (inactive > 30 days)
- Comprehensive index consistency validation
- Performance analysis and optimization recommendations

**Adaptive Frequency:**
```dart
// Frequency adapts to system activity
Duration calculateManagementInterval() {
  int activeInstallations = getActiveInstallationCount();
  int dataResourceCount = getTotalResourceCount();

  if (activeInstallations == 1) return Duration.days(7);      // Single user: weekly
  if (activeInstallations <= 5) return Duration.days(3);     // Small group: every 3 days
  if (dataResourceCount > 10000) return Duration.days(1);    // Large dataset: daily

  return Duration.days(2);  // Default: every 2 days
}
```

#### 7.2.3. Installation Index for Efficient Management

**Installation Index Benefits:**
The installation index enables efficient management operations by providing a single location to assess system-wide collaboration health:

```turtle
# Installation index reveals system state at a glance
<alice-phone> crdt:lastSeenAt "2023-10-15T16:45:00Z"^^crdt:HybridClock .     # Active
<bob-laptop> crdt:lastSeenAt "2023-10-10T09:30:00Z"^^crdt:HybridClock .      # Dormant (5 days)
<charlie-tablet> crdt:lastSeenAt "2023-09-15T14:20:00Z"^^crdt:HybridClock .  # Inactive (30 days)
```

**Efficient Management Queries:**
```dart
// Single index query reveals all installation states
List<Installation> installations = await installationIndex.getAllItems();

List<Installation> activeInstallations = installations
    .where((i) => i.lastSeenAt.isAfter(DateTime.now().subtract(Duration.days(7))))
    .toList();

List<Installation> dormantInstallations = installations
    .where((i) => i.lastSeenAt.isBefore(DateTime.now().subtract(Duration.days(7))) &&
                  i.lastSeenAt.isAfter(DateTime.now().subtract(Duration.days(30))))
    .toList();

List<Installation> inactiveInstallations = installations
    .where((i) => i.lastSeenAt.isBefore(DateTime.now().subtract(Duration.days(30))))
    .toList();
```

**Management Decision Matrix:**
- **Active installations (< 7 days):** No action required
- **Dormant installations (7-30 days):** Monitor, no cleanup yet
- **Inactive installations (> 30 days):** Eligible for tombstoning and cleanup

#### 7.2.4. Management Phase Algorithm

**Complete Management Phase Workflow:**

```dart
async function executeManagementPhase() {
  // Phase 1: System Health Assessment
  List<Installation> installations = await loadInstallationIndex();
  GarbageCollectionIndex gcIndex = await loadGCIndex();

  // Phase 2: Installation Lifecycle Management
  for (Installation installation in installations) {
    Duration inactivity = DateTime.now().difference(installation.lastSeenAt);

    if (inactivity > Duration.days(30)) {
      await tombstoneInstallation(installation);
      await removeFromAllIndices(installation);
      logInfo("Tombstoned inactive installation: ${installation.id}");
    }
  }

  // Phase 3: Garbage Collection
  for (TombstoneRecord record in gcIndex.getEligibleRecords()) {
    if (record.retentionEligibleAt.isBefore(DateTime.now())) {
      await deleteDataResource(record.originalResourceIri);
      await removeFromDataIndices(record.originalResourceIri, record.originalResourceType);
      await markAsCollected(record);
      logInfo("Garbage collected resource: ${record.originalResourceIri}");
    }
  }

  // Phase 4: Index Optimization
  for (Index index in getAllDataIndices()) {
    if (index.requiresOptimization()) {
      await optimizeIndexSharding(index);
      logInfo("Optimized index: ${index.iri}");
    }
  }

  // Phase 5: Consistency Validation
  await validateIndexConsistency();
  await validateDataIntegrity();

  // Phase 6: Update Management Metadata
  await updateLastManagementExecution(DateTime.now());
  logInfo("Management phase completed successfully");
}
```

#### 7.2.5. Coordination and Conflict Resolution

**Multi-Installation Management Coordination:**
Since multiple installations may execute management phases concurrently, the framework uses optimistic coordination:

**Coordination Strategy:**
1. **Optimistic Execution:** Each installation performs management operations based on current state
2. **CRDT Conflict Resolution:** Management operations follow same CRDT rules as data operations
3. **Idempotent Operations:** Management actions can be safely repeated across installations
4. **Convergent Results:** All installations converge to same system state regardless of execution order

**Example Coordination:**
```turtle
# Two installations detect the same inactive installation
# Installation A tombstones at 10:30:00
<charlie-tablet> crdt:deletedAt "2023-10-16T10:30:00Z"^^crdt:HybridClock;
    crdt:deletedBy <alice-phone#installation> .

# Installation B attempts tombstoning at 10:35:00
# Framework detects existing tombstone, skips duplicate operation
# Result: Single tombstone with earliest timestamp preserved
```

### 7.3. HTTP-Level Optimizations

**ETag-Based Change Detection:**
```dart
// Efficient synchronization using HTTP ETags
async function syncIndexShard(String shardId) {
  String? localETag = getLocalETag(shardId);

  HttpResponse response = await httpClient.get(
    getShardUri(shardId),
    headers: localETag != null ? {'If-None-Match': localETag} : {}
  );

  if (response.statusCode == 304) {
    // Not Modified - local copy is current
    return;
  }

  // Modified - merge remote changes with local state
  IndexShard remoteShard = parseIndexShard(response.body);
  IndexShard localShard = getLocalShard(shardId);
  IndexShard mergedShard = mergeCRDT(localShard, remoteShard);

  await saveLocalShard(shardId, mergedShard);
  await saveLocalETag(shardId, response.headers['etag']);
}
```

**Conditional Updates with Conflict Resolution:**
```dart
// Atomic updates with conflict detection
async function uploadIndexShard(String shardId, IndexShard shard) {
  String? localETag = getLocalETag(shardId);

  HttpResponse response = await httpClient.put(
    getShardUri(shardId),
    body: serializeIndexShard(shard),
    headers: localETag != null ? {'If-Match': localETag} : {}
  );

  if (response.statusCode == 412) {
    // Precondition Failed - concurrent modification detected
    // Fetch current state, merge, and retry
    await syncIndexShard(shardId);  // Download and merge current state
    return await uploadIndexShard(shardId, getLocalShard(shardId));  // Retry with merged state
  }

  // Success - update local ETag
  await saveLocalETag(shardId, response.headers['etag']);
}
```

**Workflow Integration:**
1. **Fetch current state:** GET populating shard from backend
2. **Check for changes:** Compare ETag with local version
3. **Merge if needed:** Apply CRDT algorithms to resolve conflicts
4. **Apply local changes:** Add/modify local items in merged shard
5. **Compute new state:** Calculate updated shard hash and metadata
6. **Upload:** PUT updated shard and index to backend
   - **ETag optimization:** Store ETags from GET responses, use `If-Match` headers on PUT to detect concurrent modifications
   - **On 412 Precondition Failed:** GET current state, perform CRDT merge with local changes, retry PUT with merged result

**Benefits:**
- **Bandwidth Efficiency:** Only download changed shards
- **Atomic Operations:** Prevent race conditions between installations
- **Automatic Recovery:** Handle concurrent modifications gracefully
- **Standard HTTP:** Works with any HTTP-based storage backend

---

## 8. Error Handling and Resilience

### 8.1. Failure Classification

The framework categorizes failures into distinct types to enable appropriate response strategies:

**Transient Failures (Retry-able):**
- Network connectivity issues
- Temporary backend service unavailability
- Rate limiting and throttling responses
- Temporary authentication token expiration

**Persistent Failures (Require Intervention):**
- Invalid authentication credentials
- Insufficient storage permissions
- Backend storage quota exceeded
- Malformed data that cannot be parsed

**Conflict Failures (Merge-able):**
- Concurrent document modifications (412 Precondition Failed)
- CRDT timestamp conflicts requiring resolution
- Index inconsistencies between installations

### 8.2. Core Resilience Strategies

**Exponential Backoff for Transient Failures:**
```dart
class RetryPolicy {
  static const maxRetries = 5;
  static const baseDelayMs = 1000;

  static Future<T> withRetry<T>(Future<T> Function() operation) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (!isRetryable(e) || attempt == maxRetries - 1) rethrow;

        Duration delay = Duration(milliseconds: baseDelayMs * math.pow(2, attempt));
        await Future.delayed(delay);
      }
    }
    throw StateError('Retry logic failed unexpectedly');
  }
}
```

**Queue-Based Offline Operations:**
```dart
class OfflineQueue {
  final List<SyncOperation> _pendingOperations = [];

  Future<void> enqueue(SyncOperation operation) async {
    _pendingOperations.add(operation);
    await persistQueue();  // Survive app restarts

    // Attempt immediate execution if online
    if (await isOnline()) {
      await processPendingOperations();
    }
  }

  Future<void> processPendingOperations() async {
    while (_pendingOperations.isNotEmpty && await isOnline()) {
      SyncOperation operation = _pendingOperations.removeAt(0);

      try {
        await operation.execute();
        await persistQueue();
      } catch (e) {
        // Re-queue if retryable, otherwise report failure
        if (isRetryable(e)) {
          _pendingOperations.insert(0, operation);
          break;  // Stop processing, will retry later
        } else {
          await reportFailure(operation, e);
        }
      }
    }
  }
}
```

**CRDT-Based Conflict Resolution:**
```dart
Future<void> handleConflictFailure(Document localDoc, String remoteETag) async {
  // Download current remote state
  Document remoteDoc = await backend.getDocument(localDoc.iri);

  // Perform CRDT merge
  Document mergedDoc = mergeCRDTDocuments(localDoc, remoteDoc);

  // Retry upload with merged result
  await backend.putDocument(localDoc.iri, mergedDoc,
      ifMatch: remoteDoc.etag);
}
```

### 8.3. Graceful Degradation

**Offline-First Operation:**
- All read operations work from local cache
- Write operations queue for later synchronization
- UI indicates sync status clearly to users
- Critical operations (like backup) prioritized when connectivity returns

**Partial Sync Recovery:**
- If only some indices sync successfully, continue with available data
- Clearly indicate to user which data may be stale
- Retry failed syncs in background with exponential backoff
- Allow manual retry for user-initiated sync operations

**Index Reconstruction:**
- If index corruption is detected, rebuild from authoritative data sources
- Maintain system availability during reconstruction
- Use management phase operations to coordinate reconstruction across installations

---

## 9. Security Considerations

### 9.1. Threat Model

**In-Scope Threats:**
- **Data Integrity:** Malicious modification of synchronized data
- **Timestamp Manipulation:** Attempts to win conflicts through fake timestamps
- **Backend Authentication:** Unauthorized access to storage backend
- **Privacy Leakage:** Exposure of sensitive data through synchronization metadata

**Out-of-Scope Threats:**
- **Backend Security:** Assumed that backend storage is properly secured
- **Transport Encryption:** Assumed that HTTPS/TLS is used for all communications
- **Client Device Security:** Local storage and application security is application responsibility

### 9.2. Data Integrity and Authenticity

**Hybrid Logical Clock Integrity:**
Installation identity in HLC timestamps provides tamper resistance:
- Installation IRIs reference discoverable installation documents
- Timestamps include installation identity, preventing simple timestamp manipulation
- Cross-installation validation can detect inconsistent timestamps

**Content Hashing:**
Index shards use MD5 hashes for change detection and integrity validation:
```turtle
<shard-mod-md5-0> idx:stateHash "a1b2c3d4e5f6789012345678901234567890abcd" .
```
- Detects accidental corruption during transmission
- Enables efficient change detection
- Provides baseline integrity checking

**Merge Contract Validation:**
Applications must validate that all collaborating installations use compatible merge contracts:
- Contracts hosted at stable, authenticated URIs
- Version compatibility checking before collaboration
- Reject data from installations using incompatible contracts

### 9.3. Privacy and Access Control

**Metadata Exposure:**
Synchronization metadata (HLC timestamps, installation IDs) may reveal information about user activity patterns and device usage. Applications should:
- Consider metadata privacy implications in their threat model
- Implement appropriate access controls for discovery mechanisms
- Document what metadata is exposed through collaboration

**Discovery Isolation:**
The framework isolates CRDT-managed resources from traditional RDF discovery to prevent accidental exposure to incompatible applications.

### 9.4. Authentication and Authorization

**Backend-Specific Security:**
Each backend implementation must handle authentication and authorization according to that backend's security model:
- Solid Pods: Use Solid-OIDC for authentication and ACL/ACP for authorization
- Google Drive: Use OAuth 2.0 for authentication and file permissions for authorization
- AWS S3: Use IAM credentials and bucket policies for access control

**Installation Identity:**
Installation documents should be protected with appropriate access controls to prevent unauthorized modification of collaborative metadata.

---

## 10. Benefits of this Architecture

**For Developers:** Clean separation between business logic and synchronization complexity, enabling focus on application features rather than distributed systems challenges.

**For Users:** Reliable offline-first applications with seamless collaboration, predictable conflict resolution, and transparent multi-device synchronization.

**For the Ecosystem:** Interoperable applications that can collaborate safely on shared data without vendor lock-in, built on open web standards.

**For Scalability:** Efficient bandwidth usage through selective synchronization, sharded indices, and intelligent change detection.

---

## 11. Alignment with Standardization Efforts

### 11.1. Community Alignment

This specification is designed to align with and contribute to broader standardization efforts in the distributed web and semantic technologies space:

**W3C RDF-CRDT Community Group:** This framework provides a concrete implementation model for the theoretical foundations being developed by the RDF-CRDT standardization effort.

**Solid Ecosystem:** While backend-agnostic, this framework provides a sophisticated foundation for Solid-based applications, demonstrating advanced collaborative patterns using Solid infrastructure.

**CRDT Research Community:** The property-level CRDT approach with semantic awareness contributes novel patterns to the broader CRDT research ecosystem.

### 11.2. Architectural Differentiators

**Property-Level Semantic CRDTs:** Unlike generic CRDT approaches, this framework provides semantic awareness of RDF property types and appropriate merge strategies.

**Public, Discoverable Merge Contracts:** Enables cross-application interoperability through shared, versioned collaboration rules.

**4-Layer Separation of Concerns:** Clean architectural boundaries enable independent evolution of data modeling, conflict resolution, performance optimization, and synchronization strategies.

**Backend Abstraction:** While honoring Solid principles, the framework is designed to work with any passive storage backend, increasing practical adoption potential.

---

## 12. Glossary

**Backend:** A storage system that provides basic file operations (create, read, update, delete) and resource discovery mechanisms. Examples include Solid Pods, Google Drive, AWS S3.

**CRDT (Conflict-free Replicated Data Type):** A data structure that can be replicated across multiple installations and merged deterministically without coordination.

**GroupIndex:** An index type that organizes items into groups using regex-based transformations, enabling selective synchronization of data subsets.

**FullIndex:** An index type that contains all items of a specific type in a single, monolithic structure.

**Hybrid Logical Clock (HLC):** A timestamp system that combines logical causality with physical time, providing tamper-resistant ordering across distributed installations.

**Installation:** A specific instance of an application on a particular device, identified by a unique UUID and associated metadata.

**Managed Document:** An RDF document that follows framework conventions and is synchronized using CRDT algorithms.

**Merge Contract:** A publicly hosted specification that defines which CRDT algorithms to use for each property in an RDF vocabulary.

**Property-Level CRDT:** Application of CRDT algorithms to individual RDF properties rather than entire documents, enabling fine-grained semantic merge behavior.

**Resource Locator:** A backend-specific interface that translates between application identifiers and storage IRIs.

**Shard:** A subset of an index, used to improve performance and enable selective synchronization.

**State-Based CRDT:** A CRDT approach where entire object states are synchronized rather than individual operations.

**Sync Strategy:** The combination of index type and fetch policy that determines how an application synchronizes a particular type of data.

**Tombstone:** A marker indicating that a resource or property has been deleted, used for conflict resolution and garbage collection.