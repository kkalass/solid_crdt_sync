# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the `pacors` project.

## Project Overview

`pacors` is a multipackage Dart library designed to facilitate local-first, collaborative applications by synchronizing RDF data with Solid Pods. It uses state-based Conflict-free Replicated Data Types (CRDTs) to ensure data consistency and enable offline functionality.

### Package Structure

The project is organized as a monorepo with the following packages:

- **`pacors_core`**: Platform-agnostic sync logic, CRDT implementations, and abstract interfaces
- **`pacors_solid_auth`**: Authentication bridge to the solid-auth library for Solid Pod login
- **`pacors_ui`**: Flutter UI components including login screens and sync status widgets

The project's architecture is composed of four layers:

1.  **Data Resource:** The raw RDF data stored on a Solid Pod.
2.  **Merge Contract:** A public, discoverable set of rules that define how to merge data using specific CRDT algorithms. This is defined in `.ttl` files in the `vocabularies/` directory.
3.  **Indexing Layer:** An optional layer for performance optimization and data discovery, allowing for sharding and partitioning of data.
4.  **Sync Strategy:** A client-side configuration that determines how data is synchronized. The available strategies are:
    *   `FullSync`: For small datasets.
    *   `PartitionedSync`: For large, time-series datasets.
    *   `OnDemandSync`: For very large datasets where only an index is synced initially.

The library is designed to be an "add-on" to an existing application, rather than a full-fledged database, giving developers control over their local storage and querying logic.

## Building and Running

### Workspace Setup

This project uses Melos for multipackage management. To set up the workspace:

```bash
dart pub get
dart pub run melos bootstrap
```

### Running Tests

To run tests across all packages, use Melos:

```bash
dart pub run melos test
```

For coverage reporting on the entire workspace, use:

```bash
dart tool/run_tests.dart
```

This will execute the tests and generate a coverage report in the `coverage/` directory.

### CI/CD

The project uses GitHub Actions for continuous integration. The CI workflow is defined in `.github/workflows/ci.yml` and includes the following steps:

1.  Install dependencies (`dart pub get`)
2.  Analyze the code (`dart analyze`)
3.  Run tests with coverage (`dart test --coverage=coverage`)
4.  Upload coverage report to Codecov

## Development Conventions

### Code Style

The project follows the core Dart linting rules, as defined in `analysis_options.yaml`. All code should be formatted using `dart format`.

### Contribution Guidelines

Contributions are welcome. The process is as follows:

1.  Fork the repository and create a branch from `main`.
2.  Open an issue to discuss the proposed changes.
3.  Write tests for any new features or bug fixes.
4.  Ensure that `dart analyze` and `dart test` pass.
5.  Submit a pull request.

### Vocabularies

The project uses custom RDF vocabularies to define the CRDT and synchronization logic. These are located in the `vocabularies/` directory:

*   `crdt.ttl`: Defines the low-level CRDT mechanics.
*   `sync.ttl`: Defines the high-level merge contract.
*   `idx.ttl`: Defines the indexing vocabulary.
