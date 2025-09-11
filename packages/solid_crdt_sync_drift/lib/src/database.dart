/// Drift database schema for CRDT storage.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// RDF documents with sync metadata
class RdfDocuments extends Table {
  /// Document IRI (primary key)
  TextColumn get documentIri => text()();

  /// Full RDF content as text
  TextColumn get rdfContent => text()();

  /// Hybrid Logical Clock hash for change detection
  TextColumn get clockHash => text()();

  /// Last modified timestamp
  DateTimeColumn get lastModified =>
      dateTime().withDefault(currentDateAndTime)();

  /// Sync status (pending, synced, conflict)
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {documentIri};
}

/// Individual RDF triples for query optimization
class RdfTriples extends Table {
  /// Auto-incrementing ID
  IntColumn get id => integer().autoIncrement()();

  /// Subject IRI or blank node
  TextColumn get subject => text()();

  /// Predicate IRI
  TextColumn get predicate => text()();

  /// Object value (IRI, literal, or blank node)
  TextColumn get object => text()();

  /// Object datatype (for literals)
  TextColumn get objectType => text().nullable()();

  /// Language tag (for literals)
  TextColumn get objectLang => text().nullable()();

  /// Source document IRI
  TextColumn get documentIri => text().references(RdfDocuments, #documentIri)();
}

/// CRDT metadata and clocks
class CrdtMetadata extends Table {
  /// Resource IRI + installation ID (composite key)
  TextColumn get resourceIri => text()();
  TextColumn get installationId => text()();

  /// Hybrid Logical Clock components
  DateTimeColumn get wallTime => dateTime()();
  IntColumn get logicalTime => integer()();

  /// CRDT tombstones for deletions
  TextColumn get tombstones => text().nullable()(); // JSON array

  @override
  Set<Column> get primaryKey => {resourceIri, installationId};
}

/// Index entries for performance optimization
class IndexEntries extends Table {
  /// Index shard IRI
  TextColumn get indexIri => text()();

  /// Indexed resource IRI
  TextColumn get resourceIri => text()();

  /// Resource type (for filtering)
  TextColumn get resourceType => text()();

  /// Header properties as JSON
  TextColumn get headers => text()(); // JSON object

  /// Clock hash for change detection
  TextColumn get clockHash => text()();

  @override
  Set<Column> get primaryKey => {indexIri, resourceIri};
}

/// Main database class
@DriftDatabase(tables: [RdfDocuments, RdfTriples, CrdtMetadata, IndexEntries])
class SolidCrdtDatabase extends _$SolidCrdtDatabase {
  SolidCrdtDatabase({DriftWebOptions? web, DriftNativeOptions? native})
      : super(_openConnection(web: web, native: native));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();

          // Create indices for performance
          await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_triples_spo 
        ON rdf_triples(subject, predicate, object);
      ''');

          await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_triples_document 
        ON rdf_triples(document_iri);
      ''');

          await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_metadata_resource 
        ON crdt_metadata(resource_iri);
      ''');

          await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_entries_type 
        ON index_entries(resource_type);
      ''');
        },
      );
}

/// Create database connection based on platform
QueryExecutor _openConnection(
    {DriftWebOptions? web, DriftNativeOptions? native}) {
  // For web, explicitly configure IndexedDB storage
  return driftDatabase(name: 'solid_crdt_sync', web: web, native: native);
}
