# SOLID CRDT Sync Specification

This document serves as the main entry point for the **SOLID CRDT Sync Specification** - a comprehensive framework for building local-first, collaborative, and interoperable applications using Solid Pods as a synchronization backend.

## Specification Overview

This specification defines a **language-agnostic architecture** for implementing conflict-free replicated data types (CRDTs) on top of RDF data stored in Solid Pods. The framework enables applications to:

- **Synchronize without conflicts** using mathematically proven CRDT algorithms
- **Maintain semantic interoperability** through standard RDF vocabularies
- **Scale to large datasets** with efficient indexing and sync strategies
- **Work offline-first** with eventual consistency when connectivity is available

> **📖 Main Specification Document**  
> The complete technical specification is in **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - start there for the full architectural details, RDF examples, and implementation requirements.

## Architecture Documents

The specification is organized into the following core documents:

### Core Specification
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Complete technical specification with RDF examples
- **[CRDT-SPECIFICATION.md](docs/CRDT-SPECIFICATION.md)** - Detailed CRDT implementation requirements

### Implementation Guidance
- **[PERFORMANCE.md](docs/PERFORMANCE.md)** - Performance analysis and optimization strategies
- **[ERROR-HANDLING.md](docs/ERROR-HANDLING.md)** - Error scenarios and recovery mechanisms
- **[SHARDING.md](docs/SHARDING.md)** - Index sharding for large datasets

### Roadmap & Extensions
- **[FUTURE-TOPICS.md](docs/FUTURE-TOPICS.md)** - Planned features and open research questions

## RDF Vocabularies

The specification defines several custom vocabularies in the `vocabularies/` directory:

- **[crdt-mechanics.ttl](vocabularies/crdt-mechanics.ttl)** - Core CRDT infrastructure (`crdt:` namespace)
- **[crdt-algorithms.ttl](vocabularies/crdt-algorithms.ttl)** - CRDT merge algorithms (`algo:` namespace)
- **[merge-contract.ttl](vocabularies/merge-contract.ttl)** - Merge contract definitions and validation
- **[sync.ttl](vocabularies/sync.ttl)** - Document synchronization vocabulary (`sync:` namespace)
- **[idx.ttl](vocabularies/idx.ttl)** - Indexing and performance optimization (`idx:` namespace)

## Semantic Mappings

The `mappings/` directory contains authoritative RDF mapping files provided by the framework that define CRDT merge contracts for framework predicates and properties:

- **[core-v1.ttl](mappings/core-v1.ttl)** - Essential CRDT mappings (imported by all other mappings)
- **[client-installation-v1.ttl](mappings/client-installation-v1.ttl)** - Client and installation management
- **[index-v1.ttl](mappings/index-v1.ttl)** - Index management and performance optimization
- **[shard-v1.ttl](mappings/shard-v1.ttl)** - Index sharding for large datasets

## Document Templates

The `templates/` directory provides ready-to-use RDF document templates as implementation aids for library authors, offering good defaults for common document structures:

- **[installation-document.ttl](templates/installation-document.ttl)** - Client installation metadata
- **[installation-index-template.ttl](templates/installation-index-template.ttl)** - Index structure for installations
- **[type-index-entries.ttl](templates/type-index-entries.ttl)** - Type index integration
- Additional templates for common use cases

## Implementation Requirements

### Language Agnostic Design
This specification is designed to be implemented in client-side programming languages. The reference implementation in Dart serves as a proof-of-concept, but the architecture supports:

- **JavaScript/TypeScript** for web applications and Electron desktop apps
- **Swift** for iOS and macOS applications
- **Java/Kotlin** for Android applications
- **C#** for Windows applications and Xamarin cross-platform apps
- **C++** for native desktop applications

### Core Components
Any compliant implementation must provide:

1. **RDF Store Interface** - Storage and retrieval of RDF triples
2. **CRDT Merge Engine** - Implementation of supported CRDT algorithms
3. **Sync Strategy Framework** - Pluggable synchronization approaches
4. **Index Management** - Efficient change detection and querying
5. **Solid Pod Integration** - Authentication, authorization, and data transfer

### Compliance Testing
The specification includes test scenarios in the reference implementation that can be adapted for other languages to ensure compatibility and correctness.

## Standards Alignment

This work aligns with and wants to eventually contribute to:

- **[W3C CRDT for RDF Community Group](https://www.w3.org/community/crdt4rdf/)**
- **[Solid Protocol](https://solidproject.org/)** ecosystem
- **[RDF](https://www.w3.org/RDF/)** and **[Linked Data](https://www.w3.org/standards/semanticweb/data)** principles

## Version History

- **v0.9.0-draft** (2025) - Initial specification release
- Future versions will be tracked here as the specification matures

## Contributing to the Specification

Specification contributions are welcome! Please see the main **[CONTRIBUTING.md](../CONTRIBUTING.md)** for guidelines, and feel free to open issues for:
- Proposing specification changes
- Contributing vocabulary extensions  
- Adding new CRDT algorithms
- Improving documentation and examples

## Reference Implementation

The Dart reference implementation is available in the root directory of this repository and demonstrates all specification features in a working codebase.

## License

This specification is released under the MIT License, allowing for both open-source and commercial implementations.

---

*This specification enables a new generation of truly collaborative, interoperable applications that respect user data ownership while providing seamless synchronization across devices and applications.*