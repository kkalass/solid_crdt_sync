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
library pacors_core;

// Main API facade
export 'src/pacors.dart';
export 'src/hydration_result.dart';

// Core interfaces
export 'src/auth/auth_interface.dart';
export 'src/storage/storage_interface.dart';
export 'src/backend/backend.dart';
export 'src/mapping/resource_locator.dart';
export 'src/storage/remote_storage.dart';

// CRDT implementations
export 'src/crdt/crdt_types.dart';
export 'src/crdt/hybrid_logical_clock.dart';

// NOTE: CRDT annotations have been moved to pacors_annotations package
// Use that package for @CrdtLwwRegister, @CrdtOrSet, etc. annotations

// Sync engine
export 'src/sync/sync_engine.dart';

// Mapping configuration
export 'src/mapping/solid_mapping_context.dart';
export 'src/index/index_config.dart';

// Resource-focused configuration
export 'src/config/resource_config.dart';
export 'src/config/validation.dart';
export 'src/mapping/pod_iri_config.dart';

// Vocabularies
export 'src/vocabulary/idx_vocab.dart';
