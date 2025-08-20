# CRDT Specification for RDF Synchronization

This document provides the detailed algorithms and mechanics for implementing state-based CRDTs with RDF data in the Solid ecosystem.

## 1. Overview

This specification defines how to implement conflict-free replicated data types (CRDTs) for RDF resources, enabling automatic synchronization without coordination between replicas.

**Core Principles:**
- **State-based**: Entire resource state is synchronized, not operations
- **RDF-native**: Uses RDF vocabularies and structures throughout
- **Property-level**: Different CRDT types can be applied to different properties
- **Vector clock causality**: Determines merge order and conflict resolution

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
- **Removals:** A removal is marked with a simple, un-timestamped tombstone using RDF-Star.

```turtle
# The tombstone marks the triple as deleted.
<< :it schema:keywords "vegan" >> crdt:isDeleted true .
```

**Merge Algorithm:**
The merge of two replicas, A and B, is the union of their elements minus the union of their tombstones.
1.  `merged_elements = elements(A) ∪ elements(B)`
2.  `merged_tombstones = tombstones(A) ∪ tombstones(B)`
3.  `result = { e | e ∈ merged_elements and e ∉ merged_tombstones }`

**Limitation:** Because tombstones are simple truthy values without causality information, they are permanent. If a value is removed, it can never be re-added, as the tombstone will always cause it to be removed during a merge.

### 3.3. OR-Set (Observed-Remove Set) with Add-Wins

A true OR-Set allows elements to be added and removed multiple times. The recommended implementation for this framework uses an "Add-Wins" semantic, which is efficient and avoids the metadata overhead of traditional tagged OR-Sets.

An element's presence is determined by comparing the causality information of its addition (the resource's vector clock) and its removal (a timestamped tombstone).

**RDF Representation:**
- **Additions:** The presence of a triple in a version of a resource implies an "add" operation whose timestamp is the resource's document-level vector clock.
- **Removals:** A removal is marked with a **timestamped tombstone**. This tombstone must capture the document's vector clock at the time of removal.

**Tombstone Structure:**
```turtle
<< :it schema:keywords "spicy" >> crdt:isDeleted true;
   # The vector clock at the time of deletion.
   crdt:hasClockEntry [
     crdt:clientId <...>;
     crdt:clockValue "5"^^xsd:integer
   ], [
     crdt:clientId <...>;
     crdt:clockValue "8"^^xsd:integer
   ] .
```

**Merge Algorithm (Add-Wins):**
When merging two replicas, A and B, every potential element `e` is decided by comparing the clocks of the conflicting states (add vs. remove).

For each element `e`:
- If `e` exists in A and not in B (and no tombstone for `e` exists in B), it is kept.
- If `e` exists in A and is tombstoned in B:
    1. Get the vector clock from resource A: `add_clock`.
    2. Get the vector clock from the tombstone in B: `remove_clock`.
    3. If `add_clock` dominates `remove_clock`, the add is newer. The element is kept and the tombstone is discarded.
    4. If `remove_clock` dominates `add_clock`, the remove is newer. The element is removed.
    5. If the clocks are concurrent, the conflict must be resolved deterministically. **The recommended policy is Add-Wins**, meaning the element is kept. This ensures that if two users concurrently add and remove the same item, it is preserved.
- The final vector clock of the merged resource is the union of the clocks from the resource and any winning tombstones.

This Add-Wins approach provides the desired OR-Set semantics (elements can be re-added) without requiring complex tags on every set element, thus preserving the clean, interoperable nature of the RDF data.

#### 3.3.1. Tombstone Garbage Collection (Cleanup)

To prevent unbounded growth of tombstones over the lifetime of an application, a garbage collection mechanism is essential. Tombstones can be safely removed once they become redundant.

**Cleanup Rule:**
A tombstone for an element `e` with clock `C_remove` is considered redundant and can be safely deleted if the current resource state contains the element `e`, and the resource's vector clock `C_add` dominates `C_remove`.

**Why this is safe:**
The existence of the "add" state with a dominating clock `C_add` is sufficient to guarantee that this version of the element will win against any older version of the resource, including any that were concurrent with the removal. The tombstone is therefore no longer needed to ensure the correct outcome of future merges.

This cleanup process can be performed by any client during a regular merge operation or as a periodic background task.


## 4. Merge Process Details

### 4.1. Full Merge Algorithm

```
mergeResources(localResource, remoteResource):
  1. loadMergeContract(localResource.sync:isGovernedBy)
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

### 4.2. Property-Level Merge

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

## 5. Edge Cases and Error Handling

### 5.1. Missing Merge Contracts
If a resource's `sync:isGovernedBy` link points to a merge contract that is unavailable (e.g., due to network failure, or the resource was deleted), the resource cannot be safely merged. 

**Policy:**
- **Resource-Level Failure:** If the merge contract for a resource is inaccessible, a client **MUST NOT** attempt to merge that resource. It should be treated as temporarily offline-only. The client should periodically retry fetching the contract.
- **Property-Level Failure:** If a contract is successfully fetched but it does not contain a `sync:propertyMapping` for a specific property present in the resource, that property **MUST NOT** be merged. The client should preserve its local value for the unmapped property and may log a warning.

### 5.2. Partial Resource Synchronization
- **TODO: Handle cases where only some properties are available**
- **FIXME: Vector clock semantics for partial updates**

### 5.3. Client ID Conflicts
- **TODO: Handle duplicate client IDs (though cryptographically unlikely)**
- **FIXME: Client ID verification and validation**

### 5.4. Large Vector Clocks
For resources that are edited by a very large number of clients over a long period, the vector clock can grow in size, potentially impacting performance and storage.

**Policy:** Naive pruning of vector clock entries (e.g., removing the oldest entry) is **unsafe** as it destroys the causal history required for correct merging, and can lead to data divergence. 

A robust, general-purpose, and safe clock pruning algorithm requires coordination between clients and is an advanced topic beyond the scope of this core specification. For use cases with an extremely high number of collaborators, developers should consider architectural solutions, such as splitting the resource into smaller, more focused resources with independent clocks.

## 6. Implementation Notes

### 6.1. Performance Optimizations
- **Incremental Merging:** Instead of creating a new merged resource from scratch, a more memory-efficient approach is to calculate a diff or patch and apply it to the local resource. This is especially effective for large resources with small changes.
- **Efficient Clock Representation:** Vector clocks can be stored in memory as sorted lists or maps for efficient lookups and comparisons. For persistence, client ID IRIs can be compressed using a local mapping (e.g., to integers) to reduce storage size.

### 6.2. Concurrency Control
- **Atomic Updates:** The process of merging and persisting the new state MUST be atomic. An implementation should ensure that a failure during a write operation does not leave the local storage in an inconsistent state. A common pattern is to write the new resource to a temporary file and then atomically rename it to its final destination.
- **Locking:** While the merge algorithm itself is deterministic, the process of reading the local state, merging, and writing it back should be treated as a single transaction to prevent race conditions with other local operations.

## 7. Testing and Validation

A robust implementation of this specification requires a comprehensive test suite. The following strategies are recommended:

### 7.1. Convergence Properties
- **Property-Based Testing:** Use property-based testing frameworks (like `QuickCheck` or `Hypothesis`) to generate long, random sequences of concurrent operations applied to multiple replicas. The test should assert that all replicas eventually converge to the identical state after all operations are merged.
- **Formal Modeling:** For critical components, consider using a formal methods tool like TLA+ or Alloy to prove that the algorithms satisfy the required CRDT properties (associativity, commutativity, idempotence).

### 7.2. Interoperability and Conformance
- **Common Test Suite:** A shared conformance test suite should be developed. This suite would contain a set of reference resources, merge scenarios, and their expected outcomes. Different client implementations can run against this suite to ensure they are fully interoperable.
- **Vocabulary Versioning:** The test suite must include scenarios for handling changes in the `crdt`, `sync`, and `idx` vocabularies, as well as in the application-specific merge contracts. This includes testing for both backward and forward compatibility where applicable.

## 8. Open Questions

1. **Semantic Consistency**: How to handle semantic constraints that might be violated during merge?
2. **Schema Evolution**: How to handle changes in merge contracts over time?
3. **Performance Boundaries**: At what resource size/complexity should we recommend different approaches?
4. **Security Implications**: How to prevent malicious vector clock manipulation?
5. **Blank Nodes** Do the algorithms break for Blank Nodes? rdf:List? rdf:Seq? etc.

---

*This specification is a living document and will be updated as implementation experience provides more insights into the practical challenges of RDF-based CRDT synchronization.*