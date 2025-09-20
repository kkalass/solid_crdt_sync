# solid_crdt_sync

**Bring your own persistence layer and make it syncable to a Solid Pod.**

Local-first CRDT synchronization with Solid Pods. Build Flutter apps that work offline and sync seamlessly with Solid Pods using conflict-free replicated data types (CRDTs).

## Quick Start

Add to your `pubspec.yaml`:

```yaml
dependencies:
  solid_crdt_sync: ^0.1.0
  solid_crdt_sync_drift: ^0.1.0  # SQLite storage backend
```

Create a model with CRDT annotations:

```dart
import 'package:solid_crdt_sync/solid_crdt_sync.dart';
import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';

@RdfGlobalResource(IriTerm.prevalidated('https://example.org/Note'))
class Note {
  @RdfProperty(Schema.identifier)
  @RdfIriPart()
  String id;

  @RdfProperty(Schema.name)
  @CrdtLwwRegister()  // Last writer wins for title
  String title;

  @RdfProperty(Schema.text)
  @CrdtLwwRegister()  // Last writer wins for content
  String content;

  @RdfProperty(Schema.keywords)
  @CrdtOrSet()  // Tags can be added/removed independently
  Set<String> tags;

  Note({required this.id, required this.title, required this.content, Set<String>? tags})
      : tags = tags ?? {};
}
```

Set up the sync system:

```dart
import 'package:solid_crdt_sync/solid_crdt_sync.dart';
import 'package:solid_crdt_sync_drift/solid_crdt_sync_drift.dart';

void main() async {
  // Create storage backend
  final storage = DriftStorage(path: 'notes.db');
  
  // Set up sync system
  final sync = await SolidCrdtSync.setup(storage: storage);
  
  // Create and save a note (works offline!)
  final note = Note(
    id: 'note-1',
    title: 'My First Note',
    content: 'This works offline and syncs to Solid Pods!',
    tags: {'local-first', 'crdt'},
  );
  
  await sync.save(note);
  
  // Retrieve notes
  final allNotes = await sync.getAll<Note>();
  print('Notes: ${allNotes.length}');
  
  // Optional: Connect to Solid Pod for sync
  final auth = SolidAuthProvider(/* your config */);
  await sync.connectToSolid(auth);
  await sync.sync();  // Sync with pod
}
```

## Features

- **Local-First**: Your app works completely offline
- **CRDT Merge Strategies**: Conflict-free synchronization
  - `@CrdtLwwRegister()` - Last writer wins (good for titles, content)
  - `@CrdtOrSet()` - Observed-remove sets (good for tags, lists)
  - `@CrdtImmutable()` - Never changes after creation
- **Solid Pod Integration**: Optional sync with Solid Pods
- **Flutter Ready**: UI components for auth and sync status
- **RDF-Based**: Clean, semantic data that's interoperable

## Architecture

This package provides a convenient entry point to the solid_crdt_sync ecosystem:

- `solid_crdt_sync_core` - Platform-agnostic sync engine
- `solid_crdt_sync_annotations` - CRDT merge strategy annotations  
- `solid_crdt_sync_drift` - SQLite/Drift storage implementation
- `solid_crdt_sync_auth` - Solid authentication integration
- `solid_crdt_sync_ui` - Flutter UI components

## Examples

See the `example/` directory for a complete personal notes app demonstrating:
- Local-first note creation and editing
- CRDT merge strategies in action
- Optional Solid Pod authentication
- Conflict resolution when syncing

## Learn More

- [Architecture Documentation](https://github.com/your-org/solid_crdt_sync/blob/main/spec/docs/ARCHITECTURE.md)
- [CRDT Specification](https://github.com/your-org/solid_crdt_sync/blob/main/spec/CRDT_SPECIFICATION.md)
- [Security Considerations](https://github.com/your-org/solid_crdt_sync/blob/main/spec/docs/SECURITY.md) - Critical OAuth/OIDC redirect URI security
- [Solid Integration Guide](https://github.com/your-org/solid_crdt_sync/blob/main/docs/SOLID_INTEGRATION.md)