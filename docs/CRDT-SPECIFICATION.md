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
```
merge(A, B):
  if A.clock dominates B.clock:
    return A.value
  elif B.clock dominates A.clock:
    return B.value
  else: // concurrent
    // FIXME: Need deterministic tie-breaking (e.g., lexicographic order of client IDs)
    return deterministicChoice(A.value, B.value, A.clientId, B.clientId)
```

**Example:**
```turtle
# Alice's version (clock dominates)
schema:name "Tomato Basil Soup"

# Bob's version (clock dominated)  
schema:name "Tomato Soup"

# Result: "Tomato Basil Soup" (Alice's clock wins)
```

### 3.2. OR-Set (Observed-Remove Set)

Used for properties where elements can be added and removed multiple times.

**Current Implementation Issues:**
```turtle
# FIXME: Current implementation is actually 2P-Set (Two-Phase Set)
schema:keywords "vegan", "soup"   # Alice's version
vs.
schema:keywords "vegan", "quick"  # Bob's version  
→ Result: "vegan", "soup", "quick" # Simple union

# TODO: True OR-Set needs unique tags per add operation:
# schema:keywords [
#   crdt:element "vegan";
#   crdt:addTag "alice-mobile-001"
# ], [
#   crdt:element "soup";  
#   crdt:addTag "alice-mobile-002"
# ] .
```

**True OR-Set Algorithm (TODO):**
```
merge(A, B):
  added = union(A.added, B.added)
  removed = union(A.removed, B.removed)
  return added - removed  // Elements in added but not removed
```

### 3.3. Tombstone Handling

**Current Tombstone Structure:**
```turtle
<< :it schema:keywords "spicy" >> crdt:isDeleted true .
```

**Issues with Current Approach:**
- **FIXME: No timestamp/causality info on tombstones**
- **TODO: Tombstone cleanup cannot work safely without timing information**
- **TODO: Need `crdt:deletedAt` timestamp or vector clock on tombstones**

**Proposed Tombstone Structure (TODO):**
```turtle
<< :it schema:keywords "spicy" >> crdt:isDeleted true;
   crdt:deletedAt "2024-08-19T15:30:00Z"^^xsd:dateTime;
   crdt:deletedByClient <https://alice.podprovider.org/installations/mobile-recipe-app-2024-08-19-xyz>;
   crdt:deletionClock [
     crdt:clientId <https://alice.podprovider.org/installations/mobile-recipe-app-2024-08-19-xyz>;
     crdt:clockValue "5"^^xsd:integer
   ] .
```

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
- **TODO: Define fallback behavior when `sync:isGovernedBy` resource is unavailable**
- **FIXME: Should operations fail or use default merge strategies?**

### 5.2. Partial Resource Synchronization
- **TODO: Handle cases where only some properties are available**
- **FIXME: Vector clock semantics for partial updates**

### 5.3. Client ID Conflicts
- **TODO: Handle duplicate client IDs (though cryptographically unlikely)**
- **FIXME: Client ID verification and validation**

### 5.4. Large Vector Clocks
- **TODO: Clock pruning strategies for clients that haven't been seen recently**
- **FIXME: Storage efficiency for resources with many historical clients**

## 6. Implementation Notes

### 6.1. Performance Optimizations
- **TODO: Incremental merge algorithms for large resources**
- **TODO: Efficient vector clock comparison algorithms**
- **FIXME: Memory usage optimization for vector clocks**

### 6.2. Concurrency Control
- **TODO: Lock-free merge algorithms**
- **FIXME: Atomic resource updates during merge operations**

## 7. Testing and Validation

### 7.1. Convergence Properties
- **TODO: Automated tests for CRDT convergence properties**
- **FIXME: Stress testing with high concurrency scenarios**

### 7.2. Interoperability Testing
- **TODO: Cross-implementation compatibility tests**
- **FIXME: Version compatibility for vocabulary changes**

## 8. Open Questions

1. **Semantic Consistency**: How to handle semantic constraints that might be violated during merge?
2. **Schema Evolution**: How to handle changes in merge contracts over time?
3. **Performance Boundaries**: At what resource size/complexity should we recommend different approaches?
4. **Security Implications**: How to prevent malicious vector clock manipulation?
5. **Blank Nodes** Do the algorithms break for Blank Nodes? rdf:List? rdf:Seq? etc.

---

*This specification is a living document and will be updated as implementation experience provides more insights into the practical challenges of RDF-based CRDT synchronization.*