# solid_crdt_sync_drift

Drift (SQLite) storage implementation for solid_crdt_sync_core.

## Overview

This package provides a concrete implementation of the `LocalStorage` interface from `solid_crdt_sync_core` using Drift ORM for cross-platform SQLite storage.

## Features

- **Cross-platform SQLite storage** - Works on iOS, Android, Web, Windows, macOS, Linux
- **Document + Triple storage** - Stores RDF as both complete documents and queryable triples
- **CRDT metadata support** - Dedicated tables for Hybrid Logical Clocks and tombstones  
- **Index optimization** - Efficient storage for sync performance indices
- **Type-safe queries** - Generated Drift APIs for compile-time safety

## Database Schema

```sql
-- Main RDF documents with sync metadata
CREATE TABLE rdf_documents (
  document_iri TEXT PRIMARY KEY,
  rdf_content TEXT NOT NULL,
  clock_hash TEXT NOT NULL,
  last_modified DATETIME DEFAULT CURRENT_TIMESTAMP,
  sync_status TEXT DEFAULT 'pending'
);

-- Individual triples for query optimization  
CREATE TABLE rdf_triples (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject TEXT NOT NULL,
  predicate TEXT NOT NULL,
  object TEXT NOT NULL,
  object_type TEXT,
  object_lang TEXT,
  document_iri TEXT REFERENCES rdf_documents(document_iri)
);

-- CRDT clocks and metadata
CREATE TABLE crdt_metadata (
  resource_iri TEXT NOT NULL,
  installation_id TEXT NOT NULL,
  wall_time DATETIME NOT NULL,
  logical_time INTEGER NOT NULL,
  tombstones TEXT,
  PRIMARY KEY (resource_iri, installation_id)
);

-- Performance indices
CREATE TABLE index_entries (
  index_iri TEXT NOT NULL,
  resource_iri TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  headers TEXT NOT NULL,
  clock_hash TEXT NOT NULL,
  PRIMARY KEY (index_iri, resource_iri)
);
```

## Usage

```dart
import 'package:solid_crdt_sync_drift/solid_crdt_sync_drift.dart';

// Create storage instance
final storage = DriftStorage();

// Initialize (creates database file)
await storage.initialize();

// Use with sync engine
final syncEngine = SyncEngine(
  authProvider: authProvider,
  localStorage: storage,
  strategies: strategies,
);
```

## Implementation Status

- ✅ **Database schema** - Complete with proper indices
- ✅ **Basic CRUD operations** - Store, retrieve, delete resources
- 🚧 **CRDT operations** - Metadata storage implemented, merge logic pending
- 📋 **RDF parsing** - Triple extraction not yet implemented
- 📋 **Query optimization** - SPARQL-like queries not yet implemented

This is a foundational implementation that will be extended as the core CRDT logic is developed.