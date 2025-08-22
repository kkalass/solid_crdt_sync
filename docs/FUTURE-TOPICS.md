# Future Topics and Open Questions

This document tracks substantial topics identified for future discussion and potential implementation. These represent areas where the current specification could be enhanced or optimized, but require deeper analysis and design work.

## 1. Restore Consistency

The architecture has been growing a lot, and many good things were added or updated, but I think we have started losing consistency and started to contradict ourselves.
I think that the most important upcoming topic is, to get back on track and try to get everything consistent and correct that we have defined so far, without
really adding anything new to the spec.

## 2. Custom Tombstone Format vs RDF Reification

**Status**: Open Question  
**Current Approach**: Uses RDF Reification for semantic correctness but with significant overhead.

**Alternative Approaches**:
- **Custom Compact Format**: Define framework-specific tombstone representation

**Trade-offs to Analyze**:
- Semantic correctness vs storage efficiency
- Interoperability vs performance
- Standard RDF tooling compatibility vs custom processing requirements

**Related**: Current RDF Reification approach in CRDT-SPECIFICATION.md sections 3.2, 3.3

---

## 3. Vector Clock Optimization for Tombstones

**Status**: Open Question  
**Current Limitation**: Document-level vector clocks prevent tombstone compaction.

**Optimization Strategies**:
- **Referenced Vector Clocks**: Multiple tombstones share clock references instead of full copies
- **Clock Base + Diffs**: Represent clocks as base + incremental changes rather than full state
- **Hybrid Per-Tombstone Clocks**: Enable compaction while minimizing storage overhead
- **Clock Compression**: Develop algorithms for safely pruning old clock entries

**Implementation Ideas**:
- Clock reference pool within document
- Diff-based clock representation with reconstruction algorithms
- Selective per-tombstone clocks based on property churn analysis

**Related**: CRDT-SPECIFICATION.md section 3.3.1 compaction limitations

---

## 4. Hybrid Approach Specification

**Status**: Open Question  
**Current Issue**: "Hybrid Approach" mentioned in compaction section but not fully specified.

**Definition Needed**:
- Which properties/scenarios warrant per-tombstone clocks?
- How do applications declare hybrid clock strategies?
- Merge algorithm modifications for mixed clock approaches
- Performance analysis and recommendation guidelines

**Specification Requirements**:
- Formal algorithm for hybrid clock selection
- Migration path from document-level to hybrid approach
- Compatibility matrix for mixed-clock scenarios
- Implementation guidance for library developers

**Related**: CRDT-SPECIFICATION.md line 189 "Hybrid Approach" mention

---

## 5. RDF Collections and Extended CRDT Algorithms

**Status**: Open Question  
**Current Gap**: Framework focuses on basic CRDT types but doesn't address complex RDF structures or additional CRDT algorithms.

**RDF Structure Analysis Needed**:
- **rdf:List**: How do ordered lists merge? Position-based vs content-based conflict resolution?
- **rdf:Seq/rdf:Bag/rdf:Alt**: Merge semantics for RDF container types
- **Blank Node Graphs**: Complex structures with interdependent blank nodes
- **Property Paths**: Multi-hop relationships and their CRDT implications
- **Reification Chains**: Nested reified statements and metadata

**Additional CRDT Algorithms to Specify**:
- **Counters**: G-Counter, PN-Counter for numeric aggregation use cases
- **Sequences**: CRDT algorithms for ordered data (recipes steps, procedure lists)
- **Maps/Dictionaries**: Key-value structures with CRDT merge semantics  
- **Trees**: Hierarchical data structures (taxonomies, organizational charts)
- **Multi-Value Registers**: MV-Register for preserving concurrent writes

**Design Questions**:
- Should complex RDF structures be decomposed into simpler CRDT-manageable parts?
- How do we handle CRDT operations on interdependent RDF subgraphs?
- Can we define compositional rules for building complex CRDT behaviors from simpler ones?
- What's the interaction between RDF semantics and CRDT operational semantics?

**Related**: Current CRDT-SPECIFICATION.md sections 3.1-3.3 cover only basic types, section 8 mentions "Blank Nodes" as open question

--- 
## 6. Automated Metadata Partitioning for Scalability

**Status:** Future Topic (Advanced Research)

**Current Limitation:** In long-running systems with many participants, a single resource's vector clock and tombstone set can grow indefinitely. This impacts storage and sync performance, as all clients must download and process the entire metadata set on every sync.

#### Proposed Solution: Hot/Cold Metadata Partitioning
This proposal introduces a library-level, transparent mechanism to partition CRDT metadata into "hot" (active) and "cold" (inactive/stable) sets, keeping the primary data resource lean and sync operations fast.

* **Primary Document ("Hot"):** The main data resource would only contain metadata for recently active clients and tombstones for recent deletions.

* **Metadata Documents ("Cold"):** Linked, separate documents would archive vector clock entries for inactive clients and "stable" tombstones (those acknowledged by all active clients). The primary document would only store a link and a hash for these cold documents.

This would allow the vast majority of sync operations to only involve the small, "hot" document.

#### High-Level Workflow
1. **Standard Sync:** Active clients sync only the "hot" document, verifying the hashes of the linked "cold" documents. As long as the hashes are unchanged, the cold documents are not fetched.

2. **Hot-to-Cold Transition (Demotion):** The library would follow a deterministic, specified rule to decide when metadata becomes "cold." For example, after a client has been inactive for a certain number of sync cycles, any client can perform the housekeeping task of moving its clock entry to the "cold" document and updating the hashes. This is a special, non-CRDT "compaction" operation.

3. **Cold-to-Hot Transition (Promotion):** When an inactive client comes back online, it will perform an initial sync of both the hot and cold documents. Discovering its clientId in the cold document, it will initiate a CRDT-based transaction to:

    - Remove its entry from the cold document.

    - Re-calculate the hash of the cold document.

    - Add its entry to the hot document.

    - Update the hash pointer in the hot document.

#### Open Questions and Design Challenges
* **Deterministic Demotion Rule:** Defining a robust, deterministic, and coordination-free rule for moving metadata from hot to cold is the primary challenge. This cannot be a standard CRDT merge and requires careful specification.

* **Initial Sync Cost:** While avoiding continuous overhead, the one-time cost for a returning client to download and process the cold metadata still exists. For extremely large archives, this could be a bottleneck.

* **Concurrency on Metadata Archives:** While standard CRDT merging should handle concurrent "promotion" events, the interaction between CRDT operations and the special "demotion" rule needs to be formally proven to be safe under all conditions.

#### Ideas for improvements
* If the "cold state" of a client is global and recorded in its instance identification document, we could probably get around the need to sync the cold data initially. Only if a client learns that he is cold will he have to do this extra work - and only this client has to do it. All others never need to touch the cold document unless they want to move someone from hot to cold. 
* For the question who does the demotion when: We could state that a client that adds himself to a clock needs to check if he can demote another client.
* And for really extreme cases, we could even think about sharding of the cold metadata
* Instead of real tombstones, when moving a tombstone to cold, we could maybe att its fragment identifier to some list and record a vector clock in cold, so that we can reduce this list after some time? 
* Could we also do a similar approach of highly optimized pseudo tombstones in the main document for vector clock entries to signal during merge that an item was "tombstoned" (e.g. moved to cold) and should be removed safely? 
* But ok, how do we get this list reduced later? Maybe by treating it as a LMW_Register? But that could cause data loss. Or putting this list into its own fragment identifier resource and then "forking" the list, using LMW_Register to determine who wins? OK, this still needs a lot of thoughts.

---
## 7. Incorporate Gemini Pro's Feedback:

> ---
> Points for Discussion and Consideration
>
> While the overall concept is very strong, here are a few points that I would raise for discussion as a senior developer:
>
> * **Blank Node Identity:** The ARCHITECTURE.md document correctly identifies the challenge of blank node identity in a distributed system. The proposed solution of using sync:identifyingPredicate for context-based identification is clever. However, this relies on careful data modeling and mapping design. It would be beneficial to provide clear guidelines and examples for developers on how to design their data to be "CRDT-friendly," especially when dealing with complex, nested structures.
>
Idea: Should we incorporate a mapping analyzis phase or such? probably not viable, but we should at least provide helpful error and logging messages. But: Once the core functionality works I was planning to generate the mapping document out of annotations on dart classes and then we should be able to let the generator fail and give helpful advice. 

> * **Tombstone Compaction:** The CRDT-SPECIFICATION.md explicitly states that with the current document-level vector clock approach, tombstone compaction is not possible. While the document justifies this as a trade-off for implementation simplicity, for very long-lived, highly dynamic data, the accumulation of tombstones could become a storage and performance issue. This is a valid architectural trade-off, but it's worth keeping in mind for future versions.

Agreed - we should find some efficient way to attach vector clocks. Or we need to make it optional. 
**!!! IMPORTANT: Maybe put vector clocks on tombstones after all, trusting on future solutions like the cold metadata**!!! - that would be more future safe, since this way we do not lose information. And also some more efficient vector clock handling could likely be based on this.

> * **Initialization of Existing Pods:** The documentation mentions the "cold start" problem for new indices but doesn't go into extensive detail about the process of integrating with a Pod that already contains a large amount of legacy data. A clear strategy for a "retro-fitting" or migration process would be a valuable addition.
>
> * **Error Handling and User Feedback:** The ERROR-HANDLING.md document provides a good breakdown of failure modes. In practice, surfacing these complex distributed system errors to the end-user in a way that is understandable and actionable is very challenging. It would be good to see some discussion on best practices for UI/UX patterns that can handle these states gracefully.
>
> ---



## Contributing to Future Topics

When identifying new topics:
1. **Clearly describe the current limitation or opportunity**
2. **Outline potential approaches or solutions**
3. **Identify trade-offs and risks that need discussion**
4. **Reference related sections in existing specifications**
5. **Add to this document with "Status: Open Question"**

Topics graduate to active development when:
- Problem scope is well-defined
- Solution approaches are compared
- Implementation plan is developed
- Backwards compatibility is addressed