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

The project is built around a **4-layer architecture**:

1. **Data Resource Layer**: Individual RDF resources with clean, standard vocabularies
2. **Merge Contract Layer**: Public rules defining CRDT merge behavior via `sync:` and `crdt:` vocabularies  
3. **Indexing Layer**: Optional performance layer using sharded indices with `idx:` vocabulary
4. **Sync Strategy Layer**: Client-side strategies (FullSync, PartitionedSync, OnDemandSync)

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
- `spec/docs/ARCHITECTURE.md` - Detailed 4-layer architecture explanation with RDF examples

### RDF Vocabularies
- `vocabularies/` - Custom RDF vocabularies:
  - `crdt-algorithms.ttl` - CRDT merge algorithms (`algo:` namespace: LWW-Register, OR-Set, etc.)
  - `crdt-mechanics.ttl` - Framework infrastructure (`crdt:` namespace: clocks, installations, deletion)
  - `idx.ttl`, `sync.ttl` - Indexing and synchronization vocabularies
- `mappings/` - Semantic mapping files for CRDT merge contracts:
  - `core-v1.ttl` - Essential CRDT mappings imported by all other mapping files
  - Application-specific mapping files (client-installation-v1.ttl, etc.)

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
- State-based (not operation-based) CRDT approach
- Hybrid Logical Clocks for versioning metadata
- RDF reification tombstones for deletion handling
- Property-level merge strategies (LWW-Register, FWW-Register, OR-Set, Immutable, etc.)

### Indexing Strategy
- Support both monolithic (`idx:RootIndex`) and partitioned (`idx:PartitionedIndex`) indices
- Use sharding for performance with large datasets
- Minimize default indices, allow app-specific indices
- Index entries contain lightweight headers + Hybrid Logical Clock hashes

### API Design Patterns
- SyncStrategy pattern for different sync behaviors
- Listener interfaces (IndexChangeListener, DataChangeListener)
- Developer controls local storage, library handles sync
- On-demand fetching for large datasets

### Deletion Handling
- Framework deletion is for system-level cleanup (storage optimization, retention policies)
- Applications typically implement domain-specific soft deletion (`archived: true`, `hidden: true`) 
- Framework APIs: `deleteDocument()` methods are syntactic sugar for adding `crdt:deletedAt` triples
- Document-level deletion: deleting primary resource triggers cleanup of entire document
- Layered approach: applications can use both soft deletion (user-facing) and framework deletion (backend cleanup)

## Testing Approach

This project uses Dart's built-in `test` package. Run the comprehensive test suite with coverage using the provided tool script.

## Code Style

- Follow standard Dart formatting (`dart format`)
- Use clear, semantic naming that reflects RDF/Solid concepts
- Document public APIs with usage examples
- Maintain separation between sync logic and local storage concerns
- We are in the initial development phase and must not our code with "legacy" or "backwards compatibility" code - just get rid of code that is not right (any more)

### Code Quality
  - Write idiomatic Dart following language conventions and best practices
  - Use Dart's type system effectively - catch specific exceptions, handle nulls explicitly
