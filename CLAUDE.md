# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multipackage Dart library (`solid_crdt_sync`) that enables synchronization of RDF data to Solid Pods using CRDT (Conflict-free Replicated Data Types) for local-first, interoperable applications. The library follows a state-based CRDT approach with passive storage backends.

The project is organized as a monorepo with the following packages:
- `solid_crdt_sync` - Main entry point package with documentation and examples
- `solid_crdt_sync_core` - Platform-agnostic sync logic and runtime engine
- `solid_crdt_sync_annotations` - CRDT merge strategy annotations for code generation
- `solid_crdt_sync_generator` - Build runner integration for RDF + CRDT code generation
- `solid_crdt_sync_auth` - Solid authentication integration using solid-auth library
- `solid_crdt_sync_ui` - Flutter UI components including login forms and sync status widgets
- `solid_crdt_sync_drift` - Drift (SQLite) storage backend implementation

## Key Architecture Concepts

The project is built around a **4-layer architecture** that enables local-first, collaborative, and truly interoperable applications using Solid Pods as synchronization backends:

### 4-Layer Architecture

1. **Data Resource Layer**: Individual RDF resources with clean, standard vocabularies
   - Clean RDF using standard vocabularies (schema.org, custom vocabularies)
   - Fragment identifiers (#it) to distinguish "things" from documents
   - Self-contained resources with semantic IRIs

2. **Merge Contract Layer**: Public CRDT rules for conflict resolution
   - Declarative property-to-CRDT mappings via `sync:` and `crdt:` vocabularies
   - Public, discoverable merge contracts for cross-application interoperability
   - Property-level merge strategies (LWW-Register, OR-Set, Immutable, etc.)

3. **Indexing Layer**: Performance optimization through sharded indices
   - Sharded indices with `idx:` vocabulary for scalable data organization
   - Supports both monolithic (`idx:RootIndex`) and partitioned (`idx:PartitionedIndex`) indices
   - Group-based organization using regex transformations for hierarchical structures

4. **Sync Strategy Layer**: Application-controlled synchronization patterns
   - **FullSync**: Immediate download of all indexed resources
   - **GroupedSync**: Selective sync of specific groups (e.g., date ranges, categories)
   - **OnDemandSync**: Lazy loading with explicit resource requests

### Core Design Principles

- **Local-First**: Fully functional offline with cached data, optional partial sync for large datasets
- **State-Based CRDTs**: Synchronizes complete resource states (not operations) using property-specific algorithms
- **Hybrid Logical Clocks**: Combines logical causality tracking with physical timestamps for tamper-resistant ordering
- **Passive Storage Integration**: Works with Solid Pods as simple storage buckets, all logic client-side
- **Semantic Preservation**: RDF semantics maintained throughout synchronization process
- **Managed Resource Discoverability**: Self-describing system via `sync:ManagedDocument` Type Index registrations

### Scale and Performance Characteristics

**Target Scale:**
- Designed for **2-100 installations** with optimal performance at **2-20 installations**
- Personal sync: 2-5 installations (multiple devices)
- Family collaboration: 5-15 installations
- Small teams: 10-20 installations
- Small organizations: up to 100 installations

**Performance Patterns:**
- **Cold Start**: O(s) where s = number of index shards (must download all)
- **Incremental Sync**: O(k) where k = number of changed shards
- **Change Detection**: O(1) per shard via Hybrid Logical Clock hash comparison
- **Bandwidth Efficiency**: Index headers provide metadata without downloading full resources

**Current Scope Limitations:**
- **Single-Pod Focus**: Designed for CRDT synchronization within one Solid Pod
- **Multi-Pod Integration**: Cross-Pod data integration requires additional orchestration (planned for v2/v3)
- Applications requiring data from multiple Pods need separate discovery and coordination mechanisms

The core philosophy is that this service acts as an "add-on" for synchronization, not a database replacement. Developers retain full control over local storage and querying.

## Development Commands

### Melos Workspace Management
- `dart pub run melos bootstrap` - Bootstrap all packages (run after cloning)
- `dart pub run melos list` - List all packages in workspace
- `dart pub run melos clean` - Clean and get dependencies for all packages

### Testing
- `dart pub run melos test` - Run tests for all packages
- `dart tool/run_tests.dart` - Run tests with coverage (generates coverage/lcov.info and HTML report)
- Individual package testing: `cd packages/PACKAGE_NAME && dart test --coverage=coverage`

### Code Quality  
- `dart pub run melos analyze` - Run static analysis for all packages
- `dart pub run melos format` - Format code for all packages (follow this before commits)
- `dart pub run melos lint` - Combined analyze + format check for all packages

### Version Management & Publishing
- `dart pub run melos version` - Update versions across all packages with changelog generation
- `dart pub run melos publish` - Publish all packages to pub.dev
- `dart pub run melos release` - Preview version + publish process
- See `tool/version_and_release.md` for detailed workflow

## Key Files and Structure

### Core Documentation
- `spec/docs/ARCHITECTURE.md` - Complete architectural specification with 4-layer model, CRDT algorithms, and implementation guidance
- `spec/docs/CRDT-SPECIFICATION.md` - Detailed CRDT algorithms, Hybrid Logical Clock mechanics, and merge procedures
- `spec/docs/GROUP-INDEXING.md` - Group indexing system with regex transformations and hierarchical organization
- `spec/docs/PERFORMANCE.md` - Performance analysis, benchmarks, and optimization guidance
- `spec/docs/ERROR-HANDLING.md` - Comprehensive error handling and graceful degradation patterns
- `spec/docs/SHARDING.md` - Index sharding strategies and filesystem mapping
- `spec/docs/FUTURE-TOPICS.md` - Roadmap for multi-Pod integration and advanced features

### RDF Vocabularies and Specifications

**Core Vocabularies:**
- `vocabularies/` - Custom RDF vocabularies:
  - `crdt-algorithms.ttl` - CRDT merge algorithms (`algo:` namespace: LWW-Register, OR-Set, FWW-Register, Immutable, 2P-Set)
  - `crdt-mechanics.ttl` - Framework infrastructure (`crdt:` namespace: clocks, installations, deletion, tombstones)
  - `idx.ttl` - Indexing vocabulary (sharding, group keys, index types)
  - `sync.ttl` - Synchronization vocabulary (managed documents, strategies, contracts)

**Merge Contract Mappings:**
- `mappings/` - Semantic mapping files for CRDT merge contracts:
  - `core-v1.ttl` - Essential CRDT mappings imported by all other mapping files
  - Application-specific mapping files (client-installation-v1.ttl, recipe-v1.ttl, etc.)
  - Public, discoverable contracts enabling cross-application interoperability

**RDF Integration Patterns:**
- Fragment identifiers (#it) for clean thing/document separation
- RDF reification for semantically correct deletion tombstones
- Blank node context identification for stable CRDT object identity
- Standard vocabulary usage (schema.org) with CRDT extensions

### Tools
- `tool/` - Dart utilities for testing, versioning, and releases

## Package Architecture Guidelines

### Multipackage Structure Requirements
The project follows these architectural principles established during development:

- **Separate packages with clear dependency chains** - No circular dependencies between packages
- **No re-exports between packages** - Each package exports only its own functionality  
- **Clean separation of concerns** - CRDT annotations separate from core runtime logic
- **Single entry point package** - `solid_crdt_sync` provides documentation and convenient access
- **RDF mapper ecosystem integration** - CRDT annotations depend on `rdf_mapper_annotations`
- **Good documentation** - Follow comprehensive documentation standards (see Documentation Guidelines below)

### Dependency Architecture
```
solid_crdt_sync (main entry point)
├── solid_crdt_sync_core (runtime engine)
├── solid_crdt_sync_annotations (code gen annotations)
├── solid_crdt_sync_auth (authentication)
├── solid_crdt_sync_ui (Flutter widgets)  
└── solid_crdt_sync_drift (storage backend)

solid_crdt_sync_annotations
└── rdf_mapper_annotations (external dependency)
```

## Documentation Guidelines

### What "Good Documentation" Means

**Content-wise:**
1. **Single narrative** - Treats RDF + CRDT as one coherent story, not separate technologies
2. **Progressive disclosure** - Simple example → full features → advanced concepts  
3. **Working examples** - Personal notes app as the "hello world" demonstration
4. **Clear mental models** - "This is distributed data modeling, not just sync"
5. **Troubleshooting guide** - Common annotation mistakes, build issues, sync conflicts

**Technically:**
1. **DartDoc + more** - DartDoc for API reference, but need guides/tutorials beyond generated docs
2. **README hierarchy** - Main package has complete story, sub-packages reference back to main narrative
3. **Inline examples** - Every annotation shows usage in context with real code
4. **Generated examples** - Show what the code generator produces, not just input

### Documentation Structure
- Main `solid_crdt_sync` package README provides the complete story and mental model
- Individual package READMEs focus on their specific role within the larger narrative
- Examples demonstrate real-world usage patterns, not toy scenarios
- API documentation includes both what and why for each component

### Architecture Decision Records (ADRs)

**Location**: `packages/solid_crdt_sync/docs/adrs/` - See README.md and template.md in that directory for process and format.

## Development Guidelines


### Collaborative Development Approach

**CRITICAL: Always discuss API design before implementing**

When working on this codebase:

1. **Discussion-first approach**: When implementing new interfaces, classes, or packages, always discuss the API design with the user before writing code
2. **Ask before implementing**: Explicitly ask "Should I implement this?" or "Would you like me to code this up?" before creating classes or making architectural changes
3. **Start minimal**: When moving to implementation, start with the smallest possible change that serves the real needs of the example application
4. **Focus on actual usage**: Design interfaces based on what the example app actually needs, not theoretical requirements
5. **Avoid over-engineering**: Do not create complex database schemas, elaborate class hierarchies, or interconnected systems without explicit approval
6. **Iterative refinement**: Build incrementally - get the basic API working first, then add complexity only when needed

**Example of what NOT to do**: Creating comprehensive database schemas, complex interfaces, and multiple interconnected classes when asked to create a storage package, without first discussing what the storage interface should look like.

**Example of what TO do**: Ask "What storage operations does the example app actually need?" and design a minimal interface that serves those specific needs.

### RDF and Semantic Web Focus
- All data stored as clean, standard RDF that's human-readable
- Use fragment identifiers (#it) to distinguish "things" from documents  
- Maintain interoperability through public merge contracts
- Follow semantic web best practices with proper vocabulary usage

### CRDT Implementation

**State-Based CRDT Algorithms:**
- **LWW-Register (Last-Writer-Wins)**: Single-value properties where newest wins (names, timestamps, status)
- **FWW-Register (First-Writer-Wins)**: Immutable properties where first write wins (IDs, permanent classifications)
- **OR-Set (Observed-Remove Set)**: Multi-value properties with add/remove tracking (keywords, tags, ingredient lists)
- **2P-Set (Two-Phase Set)**: Add-only sets with tombstone removal (prevent re-addition after removal)
- **Immutable**: Strict framework constraint - any modification causes merge failure, forces resource versioning

**Hybrid Logical Clock Mechanics:**
- Combines logical causality tracking (tamper-proof) with physical timestamps (intuitive tie-breaking)
- Each installation maintains monotonically increasing logical counters
- Physical timestamps provide "most recent wins" semantics for concurrent operations
- Clock hash comparison enables efficient change detection

**Deletion and Tombstone Handling:**
- RDF reification tombstones for property-level deletion
- Document-level deletion via `crdt:deletedAt` triples
- Framework deletion for system cleanup vs application soft deletion
- Universal emptying process preserves framework metadata while removing semantic content

### Indexing Strategy

**Index Types:**
- **FullIndex (Monolithic)**: Single index covering entire dataset, good for bounded collections
- **GroupedIndex (Partitioned)**: Hierarchical organization using property transformations
  - Regex-based property extraction and normalization
  - Hierarchical group keys mapping to filesystem directories
  - Cross-platform compatible regex subset for consistent group generation

**Sharding and Performance:**
- Sharded indices for scalable data organization (1-16 shards typical)
- Index entries contain lightweight headers + Hybrid Logical Clock hashes
- Change detection via shard hash comparison (O(1) per shard)
- Minimize default indices, allow app-specific indices

**Group Key Generation:**
- Property transformations using compatible regex subset
- Date-based grouping (year/month/day hierarchies)
- Category-based organization
- Cross-platform consistency ensuring identical results across installations

### API Design Patterns

**Sync Strategy Pattern:**
- Configurable sync behaviors (FullSync, GroupedSync, OnDemandSync)
- Developer declares preferred approach, implementation handles discovery/creation
- Index selection based on application needs and group subscriptions

**Event-Driven Architecture:**
- Listener interfaces (IndexChangeListener, DataChangeListener)
- `onIndexUpdate`: Notifies app with synchronized index headers
- `onUpdate`: Provides complete merged objects for local storage
- Clear separation between index sync and resource fetch phases

**Developer Control Model:**
- Developer controls local storage and querying completely
- Library handles Pod communication, CRDT merging, and conflict resolution
- `fetchFromRemote()` for explicit on-demand resource requests
- Lazy evaluation principles minimize unnecessary work

**Integration Patterns:**
- Discovery-first approach balances Pod configuration with developer intent
- Compatible index reuse when available, creation when needed
- HTTP caching and change detection for bandwidth efficiency
- Type Index integration for resource location discovery

### Deletion Handling
- Framework deletion is for system-level cleanup (storage optimization, retention policies)
- Applications typically implement domain-specific soft deletion (`archived: true`, `hidden: true`) 
- Framework APIs: `deleteDocument()` methods are syntactic sugar for adding `crdt:deletedAt` triples
- Document-level deletion: deleting primary resource triggers cleanup of entire document
- Layered approach: applications can use both soft deletion (user-facing) and framework deletion (backend cleanup)

## Testing Approach

This project uses Dart's built-in `test` package with comprehensive coverage across all architectural layers:

**Test Coverage Areas:**
- CRDT algorithm implementations (LWW-Register, OR-Set, FWW-Register, Immutable, 2P-Set)
- Hybrid Logical Clock mechanics and causality determination
- Index management and sharding strategies
- Group key generation and regex transformations
- Merge contract resolution and property mapping
- Sync strategy implementations and performance characteristics
- Error handling and graceful degradation patterns

Run the comprehensive test suite with coverage using the provided tool script: `dart tool/run_tests.dart`

## Code Style

- Follow standard Dart formatting (`dart format`)
- Use clear, semantic naming that reflects RDF/Solid concepts
- Document public APIs with usage examples
- Maintain separation between sync logic and local storage concerns
- We are in the initial development phase and must not burden our code with "legacy" or "backwards compatibility" code - just get rid of code that is not right (any more)
- Align with W3C CRDT for RDF Community Group standardization efforts
- Follow semantic web best practices with proper vocabulary usage
- Maintain interoperability through public merge contracts and standard RDF

### Code Quality
  - Write idiomatic Dart following language conventions and best practices
  - Use Dart's type system effectively - catch specific exceptions, handle nulls explicitly
