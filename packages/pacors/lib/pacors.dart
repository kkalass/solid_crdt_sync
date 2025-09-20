/// Local-first CRDT synchronization with Solid Pods.
///
/// This is the main entry point package that provides documentation,
/// examples, and convenient access to the pacors ecosystem.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:pacors/pacors.dart';
/// import 'package:pacors_drift/pacors_drift.dart';
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
/// - `pacors_core` - Core sync engine and interfaces
/// - `pacors_annotations` - CRDT merge strategy annotations
/// - `pacors_drift` - SQLite storage backend
/// - `pacors_solid_auth` - Solid authentication
/// - `pacors_ui` - Flutter UI components
library pacors;

// Re-export the main API from core
export 'package:pacors_core/pacors_core.dart';
