# Implementation Guide - Dart Library

This document covers the Dart implementation of the pacors specification.

## Multipackage Structure

The Dart implementation is organized as a monorepo with the following packages:

### Core Packages

- **`pacors_core`**: Platform-agnostic sync logic and CRDT implementations
  - Abstract interfaces (`Auth`, `Storage`)
  - CRDT types (`LwwRegister`, `FwwRegister`, `OrSet`)
  - Hybrid Logical Clock implementation  
  - Sync strategies and engine
  - **Pure Dart** - no platform dependencies

- **`pacors_solid_auth`**: Solid Pod authentication integration
  - Concrete implementation of `Auth`
  - Integration with solid-auth library
  - Auth UI components: `SolidLoginScreen`, `SolidStatusWidget`
  - **Depends on:** Flutter + pacors_core + solid_auth

- **`pacors_ui`**: Flutter UI components for sync functionality
  - Pure sync-related UI components that don't depend on auth state
  - **Depends on:** Flutter + pacors_core

## Quick Start for App Developers

TBD

## Development Workflow

### Workspace Setup

This project uses Melos for multipackage management:

```bash
git clone https://github.com/kkalass/pacors.git
cd pacors
dart pub get
dart pub run melos bootstrap
```

### Development Commands

```bash
# Run tests across all packages
dart pub run melos test
dart tool/run_tests.dart  # With usage guidance

# Code quality
dart pub run melos analyze
dart pub run melos format
dart pub run melos lint

# Version and release management
dart pub run melos version    # Update versions + changelog
dart pub run melos publish   # Publish to pub.dev
dart pub run melos release   # Preview full release
```


## Future Package Structure

Additional packages planned:

```
packages/
├── pacors_core/      # ✅ Platform-agnostic core
├── pacors_solid_auth/      # 🚧 Authentication bridge  
├── pacors_ui/        # ✅ Flutter UI components
├── pacors_drift/     # 📋 Drift storage backend
```

## Architecture Alignment

This implementation follows the 4-layer architecture defined in the specification:

1. **Data Resource Layer** → Core RDF handling in `pacors_core`
2. **Merge Contract Layer** → CRDT implementations in `pacors_core`  
3. **Indexing Layer** → Performance optimization in `pacors_core`
4. **Sync Strategy Layer** → Application strategies in `pacors_core`

Platform-specific concerns (authentication, storage, UI) are separated into dedicated packages while keeping the core logic pure and reusable.