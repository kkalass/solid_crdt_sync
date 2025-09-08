# SOLID CRDT Sync: Local-First Collaborative Applications

A comprehensive specification and reference implementation for building **local-first, collaborative, and truly interoperable applications** using Solid Pods as a synchronization backend.

## Overview

This project addresses the fundamental challenge of creating applications that are both **conflict-free** (using CRDT algorithms) and **semantically interoperable** (using standard RDF vocabularies) while maintaining high performance regardless of dataset size.

### Key Features

- **🔄 Conflict-Free Synchronization**: State-based CRDT algorithms ensure safe collaboration without coordination
- **🌐 Semantic Interoperability**: All data stored as clean, standard RDF for maximum compatibility  
- **⚡ Performance at Scale**: Three sync strategies (Full, Grouped, On-Demand) handle datasets from 100 to 100,000+ resources
- **📱 Local-First**: Full offline functionality with sync when connectivity is available
- **🔒 Privacy-Preserving**: Leverages Solid's access control while maintaining user data ownership

## Quick Start

### For Specification Writers
The complete architecture is documented in **[spec/docs/ARCHITECTURE.md](spec/docs/ARCHITECTURE.md)**.

### For Application Developers
The Dart implementation is in early development. The current focus is on establishing the core architecture and interfaces.

📋 **For package structure, current status, and development workflow, see [IMPLEMENTATION.md](IMPLEMENTATION.md)**

### For Framework Implementers  
This specification is designed to be **language-agnostic**. The Dart implementation serves as a reference, but the architecture supports implementations in JavaScript, Python, Java, etc.

## Project Scope

This repository serves **dual purposes**:

### 📋 1. Specification
Complete architectural documentation for building CRDT-enabled Solid applications across any programming language. The specification lives in the **[`spec/`](spec/)** directory and includes:

- **Complete CRDT-RDF architecture** with formal vocabulary definitions
- **Language-agnostic design patterns** for implementers
- **Performance analysis** and optimization strategies  
- **Interoperability contracts** for cross-application compatibility

### 🛠️ 2. Dart Implementation (In Development)
A multipackage Dart library that aims to become production-ready for real-world applications. The implementation will provide:

- **Full-featured library** for building collaborative Solid applications
- **Complete API coverage** of the specification's capabilities  
- **Performance-optimized** implementation suitable for mobile and web applications
- **Reference example** for implementers in other languages

*Note: Implementation is currently in early development - the specification came first to ensure a solid foundation.*

📋 **For implementation details, package structure, and development workflow, see [IMPLEMENTATION.md](IMPLEMENTATION.md)**

## Documentation Structure

### 📋 Specification Documents (`spec/`)
| Document | Purpose | Audience |
|----------|---------|----------|
| **[ARCHITECTURE.md](spec/docs/ARCHITECTURE.md)** | Complete specification | Implementers, standards bodies |
| **[PERFORMANCE.md](spec/docs/PERFORMANCE.md)** | Performance analysis & optimization | Developers, system architects |
| **[ERROR-HANDLING.md](spec/docs/ERROR-HANDLING.md)** | Error scenarios & recovery | Implementation teams |
| **[FUTURE-TOPICS.md](spec/docs/FUTURE-TOPICS.md)** | Roadmap & open questions | Contributors, researchers |

### 🌐 Web Resources
| Resource | Purpose | Audience |
|----------|---------|----------|
| **[📋 RDF Vocabularies & Mappings](https://kkalass.github.io/solid_crdt_sync/)** | Web access to RDF vocabularies and semantic mappings | Developers, semantic web tools |

### 🛠️ Implementation Documents (Root Level)
| Document | Purpose | Audience |
|----------|---------|----------|
| **[IMPLEMENTATION.md](IMPLEMENTATION.md)** | Package structure & development workflow | Dart developers & contributors |
| **[CLAUDE.md](CLAUDE.md)** | Development guidelines | Contributors to Dart implementation |
| **[examples/](examples/)** | Usage patterns & API examples | Dart developers |

## Architecture Overview

The framework uses a **4-layer architecture**:

1. **Data Resource Layer**: Clean RDF resources using standard vocabularies
2. **Merge Contract Layer**: Public CRDT rules for conflict resolution  
3. **Indexing Layer**: Efficient change detection and performance optimization
4. **Sync Strategy Layer**: Application-specific performance trade-offs

```turtle
# Example: Recipe with automatic conflict resolution
<#recipe> a schema:Recipe;
  schema:name "Tomato Soup";           # LWW-Register (last writer wins)
  schema:keywords "vegan", "soup";     # OR-Set (additions/removals merge)
  schema:cookTime "PT30M" .            # Immutable (cannot be changed)

<> a sync:ManagedDocument;
   sync:isGovernedBy <https://app.example/contracts/recipe-v1>;
   foaf:primaryTopic <#recipe> .
```

## Standards Alignment

This work aligns with and wants to eventually contribute to:

- **[W3C CRDT for RDF Community Group](https://www.w3.org/community/crdt4rdf/)**
- **[Solid Protocol](https://solidproject.org/)** ecosystem
- **[RDF](https://www.w3.org/RDF/)** and **[Linked Data](https://www.w3.org/standards/semanticweb/data)** principles

## Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| **Specification** | ✅ Draft Complete | Ready for community review |
| **Dart Library** | 🚧 In Development | Reference implementation in progress |
| **JavaScript Library** | 📋 Future | Community implementation welcomed |

## Contributing

### Specification Feedback
- **Issues & Suggestions**: [GitHub Issues](https://github.com/klaaskalass/solid_crdt_sync/issues)
- **Architectural Discussions**: [W3C CRDT for RDF Community Group](https://www.w3.org/community/crdt4rdf/)
- **Pull Requests**: Documentation improvements and clarifications welcome

### Implementation Contributions
- **Dart Reference Implementation**: See [IMPLEMENTATION.md](IMPLEMENTATION.md) for package structure and development workflow
- **Tests**: Specification compliance tests across package directories
- **Examples**: Real-world usage patterns in `examples/`


### Other Languages
Interested in implementing this specification in other languages? We'd love to collaborate! The architecture is designed to be language-agnostic.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Citation

If you use this work in academic research, please cite:

```bibtex
@misc{kalaß2025solidcrdt,
  title={A Framework for Local-First, Interoperable Apps on Solid},
  author={Klas Kalaß},
  year={2025},
  url={https://github.com/klaaskalass/solid_crdt_sync}
}
```

## Community

- **Discussions**: [GitHub Discussions](https://github.com/klaaskalass/solid_crdt_sync/discussions)
- **W3C Community Group**: [CRDT for RDF](https://www.w3.org/community/crdt4rdf/)
- **Matrix Chat**: [#solid-crdt:matrix.org](https://matrix.to/#/#solid-crdt:matrix.org) *(planned)*

## AI Assistance Acknowledgment

This specification was developed with assistance from large language models (Claude, Gemini) for:
- **Research assistance**: Exploring CRDT literature, Solid ecosystem standards, and related work
- **Technical writing and editing**: Improving clarity, consistency, and professional formatting
- **Architecture review**: Identifying gaps, inconsistencies, and improvement opportunities  
- **Documentation structure**: Organizing complex technical concepts for multiple audiences

**Human oversight**: All architectural decisions, technical approaches, and conceptual frameworks remain under full human authorship and responsibility. AI tools served as sophisticated writing and analysis assistants, not as sources of technical authority.

**Quality assurance**: The specification's technical validity comes from careful review, implementation experience, and community feedback - not from AI generation.

---

*This project bridges the gap between theoretical CRDT research and practical Solid application development, enabling a new generation of truly collaborative, interoperable applications.*