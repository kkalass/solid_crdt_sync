/// Local-first CRDT synchronization with Solid Pods.
///
/// This is the main entry point package that provides documentation,
/// examples, and convenient access to the solid_crdt_sync ecosystem.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:solid_crdt_sync/solid_crdt_sync.dart';
/// import 'package:solid_crdt_sync_drift/solid_crdt_sync_drift.dart';
///
/// // Set up local-first sync system
/// final storage = DriftStorage(path: 'app.db');
/// final sync = await SolidCrdtSync.setup(storage: storage);
///
/// // Use your annotated models
/// final note = Note(
///   id: 'note-1',
///   title: 'My first note',
///   content: 'Local-first with optional Solid sync!',
/// );
///
/// await sync.save(note);
/// final notes = await sync.getAll<Note>();
///
/// // Optionally connect to Solid Pod
/// final auth = SolidAuthProvider(/* config */);
/// await sync.connectToSolid(auth);
/// await sync.sync(); // Sync to pod
/// ```
///
/// ## Package Architecture
///
/// - `solid_crdt_sync_core` - Core sync engine and interfaces
/// - `solid_crdt_sync_annotations` - CRDT merge strategy annotations
/// - `solid_crdt_sync_drift` - SQLite storage backend
/// - `solid_crdt_sync_auth` - Solid authentication
/// - `solid_crdt_sync_ui` - Flutter UI components
library solid_crdt_sync;

// Re-export the main API from core
export 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';
