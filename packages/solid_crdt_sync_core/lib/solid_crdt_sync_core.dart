/// Core CRDT synchronization logic for Solid Pods.
///
/// This library provides the platform-agnostic core functionality for
/// syncing RDF data to Solid Pods using CRDT (Conflict-free Replicated Data Types).
///
/// The library follows a 4-layer architecture:
/// 1. Data Resource Layer - Individual RDF resources
/// 2. Merge Contract Layer - CRDT merge behavior rules
/// 3. Indexing Layer - Performance optimization via indices
/// 4. Sync Strategy Layer - Client-side sync strategies
library solid_crdt_sync_core;

// Main API facade
export 'src/solid_crdt_sync.dart';

// Core interfaces
export 'src/auth/auth_interface.dart';
export 'src/storage/storage_interface.dart';
export 'src/sync/sync_strategy.dart';

// CRDT implementations
export 'src/crdt/crdt_types.dart';
export 'src/crdt/hybrid_logical_clock.dart';

// NOTE: CRDT annotations have been moved to solid_crdt_sync_annotations package
// Use that package for @CrdtLwwRegister, @CrdtOrSet, etc. annotations

// Sync engine
export 'src/sync/sync_engine.dart';

// Mapping configuration
export 'src/mapping/solid_mapping_context.dart';
export 'src/mapping/crdt_mappings_config.dart';
export 'src/index/index_config.dart';
