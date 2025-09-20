# Personal Notes App

**Bring your own persistence layer and make it syncable to a Solid Pod.**

A simple local-first personal notes application demonstrating the `pacors` framework.

## Overview

This example app showcases the key principles of local-first development with Solid Pod synchronization:

- **Works immediately offline** - No account required to start using
- **Optional Solid connection** - Connect to sync across devices when ready
- **CRDT conflict resolution** - Automatic merging of concurrent edits
- **Clean, simple UI** - Focus on demonstrating the sync technology

## Features

### Note Management
- Create, edit, and delete personal notes
- Add/remove tags for organization 
- Search notes by title, content, or tags
- Automatic timestamps for created/modified dates

### Local-First Operation
- Instant startup - no network required
- All data stored locally using SQLite (via Drift)
- Full functionality when offline
- Changes saved immediately to local storage

### Optional Solid Synchronization
- Connect button to link with your Solid Pod
- Automatic background sync when connected
- Manual sync trigger available
- Visual sync status indicators
- Seamless offline/online operation

**Security Note:** This example demonstrates secure OAuth/OIDC redirect URI configuration. See [spec/docs/SECURITY.md](../../../spec/docs/SECURITY.md) for critical security considerations when configuring authentication for different platforms.

## CRDT Conflict Resolution

The app demonstrates different CRDT merge strategies:

- **Title & Content**: `LWW-Register` (Last Writer Wins)
  - When two devices edit simultaneously, the most recent edit wins
- **Tags**: `OR-Set` (Observed Remove Set)  
  - Tags can be added/removed independently
  - All additions merge together, explicit removals are preserved
- **Created Date**: `Immutable`
  - Never changes after initial creation

## Technical Architecture

### Data Model
```dart
@RdfGlobalResource(IriTerm.prevalidated('https://example.org/vocab/Note'), IriStrategy())
class Note {
  @RdfIriPart String id;
  @RdfProperty(Schema.name) @LwwRegister() String title;
  @RdfProperty(Schema.text) @LwwRegister() String content;  
  @RdfProperty(Schema.keywords) @OrSet() Set<String> tags;
  @RdfProperty(Schema.dateCreated) @Immutable() DateTime createdAt;
}
```

### Setup (main.dart)
```dart
// Simple one-line setup connecting all components
final syncSystem = await SolidCrdtSync.setup(
  storage: DriftStorage(),        // SQLite via Drift
  mapper: getGeneratedRdfMapper(), // RDF annotations → RDF conversion
  // authProvider: optional initially
);
```

### Service Layer
```dart
// Clean API working with plain Dart objects
final notes = await notesService.getAllNotes();
await notesService.saveNote(myNote);  // Automatically converts to RDF + syncs
```

## Getting Started

### Prerequisites
- Flutter 3.24.0 or later
- Dart 3.6.0 or later

### Installation

**For Mobile/macOS:**
```bash
cd packages/pacors/example
flutter pub get
dart run build_runner build  # Generate RDF mappers
flutter run -d macos  # or -d android, -d ios
```

**For Web:**
```bash
cd packages/pacors/example
flutter pub get
dart run build_runner build  # Generate RDF mappers
# Setup web dependencies (required for Drift storage)
./setup_web.sh
flutter run -d chrome --web-port=8080
```

### Platform-Specific Setup

#### Web (Chrome/Firefox/Safari)
The example app uses `pacors_drift` for local storage, which requires SQLite WASM files for web deployment.

**Quick setup:**
```bash
./setup_web.sh  # Downloads required WASM files
```

**Manual setup (if needed):**
```bash
# Download SQLite3 WASM and Drift worker files
curl -L -o web/sqlite3.wasm https://github.com/simolus3/sqlite3.dart/releases/latest/download/sqlite3.wasm
curl -L -o web/drift_worker.js https://github.com/simolus3/drift/releases/latest/download/drift_worker.js
```

**Important:** This requirement comes from `drift` via the `pacors_drift` storage backend. The core `pacors` library works with any storage implementation and doesn't require WASM files.

#### Mobile/macOS
No additional setup required - uses native SQLite directly.

#### Windows/Linux
**Not supported.** For security reasons, this example app only supports platforms with secure OAuth redirect URI mechanisms (mobile custom URI schemes, macOS custom URI schemes, and web HTTPS redirects). Windows/Linux users should use the web version at the deployed URL.

### First Run
1. App opens immediately - start creating notes
2. All changes saved locally via SQLite
3. Optional: Click "Connect to Solid Pod" to sync across devices
4. Works seamlessly online and offline

## Implementation Status

- ✅ **UI Implementation** - Complete Flutter screens
- ✅ **Data Model** - RDF annotations and CRDT strategies  
- 🚧 **Core Integration** - Placeholder implementations for sync APIs
- 📋 **RDF Generation** - Needs build_runner setup for mappers
- 📋 **Solid Connection** - UI ready, backend integration pending

This example serves as both a working demonstration and a template for building local-first applications with Solid Pod synchronization.

## Key Takeaways

1. **Local-first is accessible** - No complex setup or accounts needed
2. **CRDT sync is invisible** - Developers work with plain Dart objects  
3. **Solid adds value** - Optional sync enhances rather than complicates
4. **Architecture scales** - Same patterns work for simple and complex apps

The goal is for developers to see this code and think: *"This isn't scary at all - I can build this!"*