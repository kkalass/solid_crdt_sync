# CRDT Specification for RDF Synchronization

This document provides the detailed algorithms and mechanics for implementing state-based CRDTs with RDF data in the Solid ecosystem.

## 1. Overview

This specification defines how to implement conflict-free replicated data types (CRDTs) for RDF resources, enabling automatic synchronization without coordination between replicas.

**Core Principles:**
- **State-based**: Entire resource state is synchronized, not operations
- **RDF-native**: Uses RDF vocabularies and structures throughout
- **Property-level**: Different CRDT types can be applied to different properties
- **Vector clock causality**: Determines merge order and conflict resolution
- **RDF Reification for tombstones**: Uses RDF Reification to represent deleted statements, which is semantically correct since it describes statements without asserting them (unlike RDF-Star which would assert the triple being "deleted")

## 2. Vector Clock Mechanics

### 2.1. Vector Clock Structure

Vector clocks track causality between client operations using structured entries:

```turtle
<> crdt:hasClockEntry [
     crdt:clientId <https://alice.podprovider.org/installations/mobile-recipe-app-2024-08-19-xyz>;
     crdt:clockValue "3"^^xsd:integer
   ], [
     crdt:clientId <https://bob.podprovider.org/installations/desktop-recipe-app-2024-08-15-abc>;
     crdt:clockValue "1"^^xsd:integer
   ];
   crdt:vectorClockHash "xxh64:abc123" .
```

### 2.2. Causality Determination

**Clock Comparison Rules:**
- Clock A **dominates** Clock B if A[i] ≥ B[i] for all clients i, and A[j] > B[j] for at least one client j
- If A[i] == B[i] for all clients i, the clocks are **identical** (no merge needed)
- If neither dominates, the changes are **concurrent** and require property-level merge resolution

### 2.3. Vector Clock Operations

**On Local Update:**
1. Increment own clock entry: `clockValue++`
2. Update `crdt:vectorClockHash` with new hash
3. Apply changes to resource

**On Merge:**
1. Create result clock: `result[i] = max(A[i], B[i])` for each client i
2. Increment merging client's entry: `result[mergingClient]++`
3. Update hash: `crdt:vectorClockHash = hash(result)`

## 3. CRDT Types and Algorithms

### 3.1. LWW-Register (Last Writer Wins Register)

Used for properties where only the most recent value matters.

**Merge Algorithm:**
When merging two versions of a resource, A and B:
```
merge(A, B):
  if A.clock dominates B.clock:
    return A.value
  elif B.clock dominates A.clock:
    return B.value
  else: // Concurrent change
    // Deterministic tie-breaking is required for concurrent updates.
    // The value from the client with the lexicographically greater client ID wins.
    if A.clientId > B.clientId:
        return A.value
    else:
        return B.value
```

**Example:**
```turtle
# Alice's version (clock dominates)
schema:name "Tomato Basil Soup"

# Bob's version (clock dominated)  
schema:name "Tomato Soup"

# Result: "Tomato Basil Soup" (Alice's clock wins)
```

### 3.2. 2P-Set (Two-Phase Set)

A 2P-Set is used for multi-value properties where removal is permanent. Once an element is removed, it cannot be re-added.

**RDF Representation:**
- **Additions:** The presence of a triple in the resource (e.g., `:it schema:keywords "vegan"`) signifies that the value is in the set.
- **Removals:** A removal is marked with a simple, un-timestamped tombstone using RDF Reification, which is semantically correct for representing deleted statements without asserting them.

```turtle
# The tombstone marks the triple as deleted using RDF Reification
# Fragment identifier generated deterministically from the deleted triple
<#crdt-tombstone-8f2a1c7d> a rdf:Statement;
  rdf:subject :it;
  rdf:predicate schema:keywords;
  rdf:object "vegan";
  crdt:isDeleted true .
```

**Merge Algorithm:**
The merge of two replicas, A and B, is the union of their elements minus the union of their tombstones.
1.  `merged_elements = elements(A) ∪ elements(B)`
2.  `merged_tombstones = tombstones(A) ∪ tombstones(B)`
3.  `result = { e | e ∈ merged_elements and e ∉ merged_tombstones }`

**Limitation:** Because tombstones are simple truthy values without causality information, they are permanent. If a value is removed, it can never be re-added, as the tombstone will always cause it to be removed during a merge.

### 3.3. OR-Set (Observed-Remove Set) with Add-Wins

A true OR-Set allows elements to be added and removed multiple times. The recommended implementation for this framework uses an "Add-Wins" semantic, which is efficient and avoids the metadata overhead of traditional tagged OR-Sets.

An element's presence is determined by comparing the causality information of its addition (the document-level vector clock) and its removal (using the document-level vector clock at removal time).

**RDF Representation:**
- **Additions:** The presence of a triple in a version of a resource implies an "add" operation whose timestamp is the document-level vector clock.
- **Removals:** A removal is marked with a **simple tombstone** using RDF Reification. The tombstone itself does NOT store its own vector clock - instead, it relies on the document-level vector clock of the resource version where the tombstone was created.

**Tombstone Structure:**
```turtle
# Simple tombstone using RDF Reification (semantically correct for deletions)
# Fragment identifier generated deterministically from the deleted triple
<#crdt-tombstone-a1b2c3d4> a rdf:Statement;
  rdf:subject :it;
  rdf:predicate schema:keywords;
  rdf:object "spicy";
  crdt:isDeleted true .

# The timing of this tombstone is determined by the document-level vector clock:
<> crdt:hasClockEntry [
    crdt:clientId <client-that-deleted>;
    crdt:clockValue "5"^^xsd:integer
  ], [
    crdt:clientId <other-client>;
    crdt:clockValue "8"^^xsd:integer
  ] .
```

**Merge Algorithm (Add-Wins):**
When merging two replicas, A and B, every potential element `e` is decided by comparing the document-level clocks of the conflicting states (add vs. remove).

For each element `e`:
- If `e` exists in A and not in B (and no tombstone for `e` exists in B), it is kept.
- If `e` exists in A and is tombstoned in B:
    1. Get the document-level vector clock from document A: `add_clock`.
    2. Get the document-level vector clock from document B (where the tombstone was created): `remove_clock`.
    3. If `add_clock` dominates `remove_clock`, the add is newer. The element is kept and the tombstone is discarded.
    4. If `remove_clock` dominates `add_clock`, the remove is newer. The element is removed.
    5. If the clocks are concurrent, the conflict must be resolved deterministically. **The recommended policy is Add-Wins**, meaning the element is kept. This ensures that if two users concurrently add and remove the same item, it is preserved.
- The final document-level vector clock of the merged document is the standard clock merge (max of each client's counter).

This Add-Wins approach provides the desired OR-Set semantics (elements can be re-added) without requiring complex tags on every set element, thus preserving the clean, interoperable nature of the RDF data.

**Deterministic Tombstone Fragment Identifier Algorithm:**

Since tombstones use RDF Reification, they integrate seamlessly with our standard CRDT merge algorithms via the `statement-v1` merge contract. To prevent fragment identifier collisions when multiple clients independently create tombstones for the same triple, we use deterministic identifier generation.

**Algorithm Specification:**

1. **Resolve Relative IRIs:** Convert all relative IRIs to absolute form using the document's base URI
2. **Canonicalize as N-Triple:** Serialize the triple using strict N-Triples format with absolute IRIs
3. **Generate Hash:** Apply XXH64 hash function to the canonical N-Triple string
4. **Format Identifier:** Use format `#crdt-tombstone-{8-char-hex-hash}`

**Example:**
```
Triple: <#it> schema:keywords "spicy"
Base URI: https://alice.podprovider.org/data/recipes/tomato-soup
Canonical: <https://alice.podprovider.org/data/recipes/tomato-soup#it> <https://schema.org/keywords> "spicy" .
Hash: XXH64("...") = a1b2c3d4e5f67890
Result: #crdt-tombstone-a1b2c3d4
```

**Implementation Notes:**
- **Pod Migration Limitation:** When documents are copied between pods, base URIs change, resulting in different tombstone identifiers for semantically equivalent tombstones. This is acceptable as equivalent tombstones merge correctly.
- **Blank Node Support:** Identifiable blank nodes (those with `sync:identifyingPredicate` declarations) can serve as tombstone subjects using their stable identity pattern. Non-identifiable blank nodes cannot be tombstoned as they lack stable identity across documents. See ARCHITECTURE.md section 3.3-3.4 for identification patterns.
- **Collision Resistance:** XXH64 provides sufficient collision resistance for practical use cases while maintaining compact identifiers.

**Implementation Guidance:**
- **Library Support:** RDF libraries should provide helper functions for generating deterministic tombstone identifiers to ensure consistency across implementations.
- **Base URI Resolution:** Use the document's base URI (typically the document URL without fragment) for resolving relative IRIs in the canonical N-Triple.
- **N-Triples Canonicalization:** Follow RFC 7932 N-Triples specification strictly, ensuring proper IRI bracketing, literal escaping, and terminating period.
- **Hash Truncation:** Use only the first 8 characters of the XXH64 hex output to keep fragment identifiers compact while maintaining sufficient collision resistance.

#### 3.3.1. Tombstone Garbage Collection (Compaction Limitation)

**Important Limitation:** With the document-level vector clock approach, tombstone compaction (cleanup) is **not possible** in the general case.

**Why Compaction is Not Safe:**
Since tombstones rely on the document-level vector clock rather than storing their own creation timestamp, we cannot determine if a tombstone is truly redundant without full causal history. A tombstone can only be safely removed if we can prove that the "add" operation definitively happened after the "remove" operation across all possible merge scenarios.

**Trade-off Decision:**
- **Document-level clocks**: Simpler implementation, less storage overhead, but permanent tombstones
- **Per-tombstone clocks**: More complex, higher storage cost, but allows compaction

**Alternative Approaches for Large-Scale Use:**
For applications where tombstone accumulation becomes problematic:
1. **Resource Splitting**: Partition large multi-value properties into separate documents with independent clocks
2. **Periodic Rebuilding**: Occasionally recreate documents with clean state (requires coordination)
3. **Hybrid Approach**: Use per-tombstone clocks only for properties expected to have high churn

**Current Recommendation:**
Accept the storage trade-off in favor of implementation simplicity. The document-level approach aligns with the passive storage philosophy and reduces the metadata burden on RDF data.

### 3.4. RDF Reification Tombstone Design Summary

The final tombstone design addresses two key requirements:

1. **Mergeable RDF Data**: All tombstone statements are governed by the document-level merge contract (imported via `sync:includes mappings:statement-v1`), ensuring they can be properly merged as RDF data.

2. **Document-Level Vector Clocks**: Tombstones rely on the document-level vector clock rather than storing individual timestamps, which:
   - **Simplifies implementation** by avoiding per-tombstone clock management
   - **Reduces storage overhead** for RDF data
   - **Prevents compaction** as a trade-off, but enables passive storage approach
   - **Aligns with passive storage philosophy** by minimizing metadata complexity

This approach prioritizes simplicity and interoperability over storage optimization, consistent with the framework's core principles.

## 4. CRDT Mapping Validation

To prevent invalid configurations, implementations must validate CRDT mappings against resource identifiability requirements before allowing merge operations.

### 4.1. Identifiable vs Non-Identifiable Resources

**Identifiable Resources** (safe for all CRDT types):
- **IRI-identified resources:** Have globally unique, stable identifiers
- **Context-identified blank nodes:** Blank nodes with identifying properties declared via `sync:identifyingPredicate` within specific subject-predicate contexts

**Non-Identifiable Resources** (cause merge failures in identity-dependent CRDTs):
- **Standard blank nodes:** Document-scoped identifiers that cannot be matched across documents without explicit identification patterns

### 4.2. CRDT Compatibility Matrix

| CRDT Type | Identifiable Resources | Non-Identifiable Resources |
|-----------|----------------------|---------------------------|
| **LWW-Register** | ✅ Supported | ✅ Supported (atomic treatment) |
| **OR-Set** | ✅ Supported | ❌ **INVALID** - tombstone matching fails |
| **2P-Set** | ✅ Supported | ❌ **INVALID** - tombstone matching fails |
| **Sequence** | ✅ Supported | ❌ **INVALID** - element ordering undefined |

### 4.3. Validation Algorithm

```
validateMapping(property, crdtType, objectTypes):
  for each objectType in objectTypes:
    if crdtType in [OR_Set, 2P_Set, Sequence]:
      if not isIdentifiable(objectType):
        throw ValidationError("CRDT type " + crdtType + " requires identifiable resources, but property " + property + " contains non-identifiable " + objectType)
    
  return valid
```

### 4.4. Identifying Property Patterns

**Context-Identified Blank Nodes:** Blank nodes can become identifiable when mapping documents declare identifying properties using `sync:identifyingPredicate`.

**Example - Vector Clock Mapping:**
```turtle
# Predicate-based mapping for vector clock entries (typeless blank nodes)
mappings:clock-mappings-v1 a sync:PredicateMapping;
   sync:identifyingPredicate crdt:clientId ;        # Identifying property
   sync:rule
     [ sync:predicate crdt:clientId; crdt:mergeWith crdt:LWW_Register ],
     [ sync:predicate crdt:clockValue; crdt:mergeWith crdt:LWW_Register ] .
```

**Usage in Data:**
```turtle
# These blank nodes are now identifiable via declared pattern
<> crdt:hasClockEntry [
    crdt:clientId <https://alice.../installation-123> ;  # Identifying property
    crdt:clockValue "15"^^xsd:integer
] .
```

**Validation Rule:** Implementations recognize blank node patterns as identifiable when `sync:identifyingPredicate` are declared in PredicateMappings, or when `sync:identifyingPredicate` is declared in ClassMappings for explicitly typed resources.

### 4.5. Error Handling

**Invalid Mapping Detection:**
- Parse merge contracts during resource loading
- Check each property mapping against object type identifiability
- Reject resources with invalid mappings rather than risk data corruption

**Error Messages:**
```
Error: Property 'schema:keywords' uses OR-Set CRDT with non-identifiable blank node objects.
Solution: Use IRIs for objects or switch to LWW-Register for atomic treatment.
```

## 5. Merge Process Details

### 8.1. Full Merge Algorithm

```
mergeResources(localResource, remoteResource):
  1. loadMergeContract(document.sync:isGovernedBy)
  2. compareVectorClocks(local.clock, remote.clock)
  3. if local.clock == remote.clock:
       return local  // Identical state, no merge needed
  4. if remote.clock dominates local.clock:
       return fastForwardMerge(local, remote)
  5. if local.clock dominates remote.clock:
       return local  // No changes needed
  6. else: // concurrent changes
       return propertyLevelMerge(local, remote, mergeContract)
```

### 8.2. Property-Level Merge

```
propertyLevelMerge(local, remote, contract):
  result = createEmptyResource()
  for each property in contract.propertyMappings:
    localValue = local.getProperty(property.name)
    remoteValue = remote.getProperty(property.name)
    
    switch property.crdtType:
      case LWW_Register:
        result.setProperty(property.name, mergeLWW(localValue, remoteValue))
      case OR_Set:
        result.setProperty(property.name, mergeORSet(localValue, remoteValue))
      // TODO: Add other CRDT types
  
  result.vectorClock = mergeClocks(local.clock, remote.clock)
  return result
```

## 6. Edge Cases and Error Handling

### 8.1. Missing Merge Contracts
If a document's `sync:isGovernedBy` link points to a merge contract that is unavailable (e.g., due to network failure, or the resource was deleted), the document cannot be safely merged. 

**Policy:**
- **Document-Level Failure:** If the merge contract for a document is inaccessible, a client **MUST NOT** attempt to merge that document. It should be treated as temporarily offline-only. The client should periodically retry fetching the contract.
- **Property-Level Failure:** If a contract is successfully fetched but it does not contain a mapping rule for a specific predicate present in the document, that predicate **MUST NOT** be merged. The client should preserve its local value for the unmapped predicate and may log a warning.

### 8.2. Partial Resource Synchronization
- **TODO: Handle cases where only some properties are available**
- **FIXME: Vector clock semantics for partial updates**

### 6.3. Client ID Conflicts
- **TODO: Handle duplicate client IDs (though cryptographically unlikely)**
- **FIXME: Client ID verification and validation**

### 6.4. Large Vector Clocks
For documents that are edited by a very large number of clients over a long period, the document-level vector clock can grow in size, potentially impacting performance and storage.

**Policy:** Naive pruning of vector clock entries (e.g., removing the oldest entry) is **unsafe** as it destroys the causal history required for correct merging, and can lead to data divergence. 

A robust, general-purpose, and safe clock pruning algorithm requires coordination between clients and is an advanced topic beyond the scope of this core specification. For use cases with an extremely high number of collaborators, developers should consider architectural solutions, such as splitting the document into smaller, more focused documents with independent clocks.

## 7. Implementation Notes

### 8.1. Performance Optimizations
- **Incremental Merging:** Instead of creating a new merged resource from scratch, a more memory-efficient approach is to calculate a diff or patch and apply it to the local resource. This is especially effective for large resources with small changes.
- **Efficient Clock Representation:** Vector clocks can be stored in memory as sorted lists or maps for efficient lookups and comparisons. For persistence, client ID IRIs can be compressed using a local mapping (e.g., to integers) to reduce storage size.

### 8.2. Concurrency Control
- **Atomic Updates:** The process of merging and persisting the new state MUST be atomic. An implementation should ensure that a failure during a write operation does not leave the local storage in an inconsistent state. A common pattern is to write the new resource to a temporary file and then atomically rename it to its final destination.
- **Locking:** While the merge algorithm itself is deterministic, the process of reading the local state, merging, and writing it back should be treated as a single transaction to prevent race conditions with other local operations.

## 8. Testing and Validation

A robust implementation of this specification requires a comprehensive test suite. The following strategies are recommended:

### 8.1. Convergence Properties
- **Property-Based Testing:** Use property-based testing frameworks (like `QuickCheck` or `Hypothesis`) to generate long, random sequences of concurrent operations applied to multiple replicas. The test should assert that all replicas eventually converge to the identical state after all operations are merged.
- **Formal Modeling:** For critical components, consider using a formal methods tool like TLA+ or Alloy to prove that the algorithms satisfy the required CRDT properties (associativity, commutativity, idempotence).

### 8.2. Interoperability and Conformance
- **Common Test Suite:** A shared conformance test suite should be developed. This suite would contain a set of reference resources, merge scenarios, and their expected outcomes. Different client implementations can run against this suite to ensure they are fully interoperable.
- **Vocabulary Versioning:** The test suite must include scenarios for handling changes in the `crdt`, `sync`, and `idx` vocabularies, as well as in the application-specific merge contracts. This includes testing for both backward and forward compatibility where applicable.

## 9. Open Questions

1. **Semantic Consistency**: How to handle semantic constraints that might be violated during merge?
2. **Schema Evolution**: How to handle changes in merge contracts over time?
3. **Performance Boundaries**: At what resource size/complexity should we recommend different approaches?
4. **Security Implications**: How to prevent malicious vector clock manipulation?
5. **Blank Nodes** Do the algorithms break for Blank Nodes? rdf:List? rdf:Seq? etc.

---

*This specification is a living document and will be updated as implementation experience provides more insights into the practical challenges of RDF-based CRDT synchronization.*