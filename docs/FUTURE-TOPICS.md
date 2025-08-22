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