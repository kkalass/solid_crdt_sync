# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dart library (`solid_crdt_sync`) that enables synchronization of RDF data to Solid Pods using CRDT (Conflict-free Replicated Data Types) for local-first, interoperable applications. The library follows a state-based CRDT approach with passive storage backends.

## Key Architecture Concepts

The project is built around a **4-layer architecture**:

1. **Data Resource Layer**: Individual RDF resources with clean, standard vocabularies
2. **Merge Contract Layer**: Public rules defining CRDT merge behavior via `sync:` and `crdt:` vocabularies  
3. **Indexing Layer**: Optional performance layer using sharded indices with `idx:` vocabulary
4. **Sync Strategy Layer**: Client-side strategies (FullSync, PartitionedSync, OnDemandSync)

The core philosophy is that this service acts as an "add-on" for synchronization, not a database replacement. Developers retain full control over local storage and querying.

## Development Commands

### Testing
- `dart test` - Run all tests
- `dart tool/run_tests.dart` - Run tests with coverage (generates coverage/lcov.info and HTML report)

### Code Quality  
- `dart analyze` - Run static analysis
- `dart format` - Format code (follow this before commits)

### Maintenance
- `dart tool/update_version.dart` - Update version numbers
- `dart tool/release.dart` - Handle release process

## Key Files and Structure

### Core Documentation
- `docs/ARCHITECTURE.md` - Detailed 4-layer architecture explanation with RDF examples
- `docs/Synchronization Algorithm Sketch.md` - Client-side sync algorithm phases
- `examples/interface.dart` - Main API design showing SyncStrategy pattern

### RDF Vocabularies
- `vocabularies/` - Custom RDF vocabularies (crdt.ttl, idx.ttl, sync.ttl)
- `mappings/` - Semantic mapping files for CRDT merge contracts

### Tools
- `tool/` - Dart utilities for testing, versioning, and releases

## Development Guidelines

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

## Testing Approach

This project uses Dart's built-in `test` package. Run the comprehensive test suite with coverage using the provided tool script.

## Code Style

- Follow standard Dart formatting (`dart format`)
- Use clear, semantic naming that reflects RDF/Solid concepts
- Document public APIs with usage examples
- Maintain separation between sync logic and local storage concerns