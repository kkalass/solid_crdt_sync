/// Drift (SQLite) storage implementation for solid_crdt_sync.
/// 
/// This library provides a concrete implementation of the storage interfaces
/// from solid_crdt_sync_core using Drift for cross-platform SQLite support.
/// 
/// Supports all Flutter platforms: iOS, Android, Web, Windows, macOS, Linux.
library solid_crdt_sync_drift;

export 'src/drift_storage.dart';
export 'src/database.dart';