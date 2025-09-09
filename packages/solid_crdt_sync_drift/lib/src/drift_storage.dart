/// Drift-based implementation of LocalStorage interface.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';

import 'database.dart';

/// Drift-based implementation of the LocalStorage interface.
///
/// Provides cross-platform SQLite storage for RDF documents, triples,
/// CRDT metadata, and index entries using the Drift ORM.
class DriftStorage implements LocalStorage {
  final DriftWebOptions? web;
  late final SolidCrdtDatabase _db;
  bool _initialized = false;

  DriftStorage({this.web});

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    _db = SolidCrdtDatabase(web: web);

    // Ensure database is ready
    await _db.customSelect('SELECT 1').get();

    _initialized = true;
  }

  @override
  Future<void> storeResource(String resourceIri, String rdfContent) async {
    _ensureInitialized();

    await _db.transaction(() async {
      // Store document
      await _db.into(_db.rdfDocuments).insertOnConflictUpdate(
            RdfDocumentsCompanion.insert(
              documentIri: resourceIri,
              rdfContent: rdfContent,
              clockHash: _generateClockHash(rdfContent),
              lastModified: Value(DateTime.now()),
              syncStatus: const Value('pending'),
            ),
          );

      // TODO: Parse RDF and store as triples for query optimization
      // For now, we just store the document-level RDF content
    });
  }

  @override
  Future<String?> getResource(String resourceIri) async {
    _ensureInitialized();

    final query = _db.select(_db.rdfDocuments)
      ..where((doc) => doc.documentIri.equals(resourceIri));

    final result = await query.getSingleOrNull();
    return result?.rdfContent;
  }

  @override
  Future<void> deleteResource(String resourceIri) async {
    _ensureInitialized();

    await _db.transaction(() async {
      // Delete triples
      await (_db.delete(_db.rdfTriples)
            ..where((triple) => triple.documentIri.equals(resourceIri)))
          .go();

      // Delete metadata
      await (_db.delete(_db.crdtMetadata)
            ..where((meta) => meta.resourceIri.equals(resourceIri)))
          .go();

      // Delete index entries
      await (_db.delete(_db.indexEntries)
            ..where((entry) => entry.resourceIri.equals(resourceIri)))
          .go();

      // Delete document
      await (_db.delete(_db.rdfDocuments)
            ..where((doc) => doc.documentIri.equals(resourceIri)))
          .go();
    });
  }

  @override
  Future<List<String>> getStoredResources() async {
    _ensureInitialized();

    final query = _db.select(_db.rdfDocuments);
    final results = await query.get();

    return results.map((doc) => doc.documentIri).toList();
  }

  @override
  Future<bool> hasResource(String resourceIri) async {
    _ensureInitialized();

    final query = _db.select(_db.rdfDocuments)
      ..where((doc) => doc.documentIri.equals(resourceIri))
      ..limit(1);

    final result = await query.getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> close() async {
    if (_initialized) {
      await _db.close();
      _initialized = false;
    }
  }

  /// Additional methods for CRDT-specific operations

  /// Store CRDT metadata for a resource
  Future<void> storeCrdtMetadata({
    required String resourceIri,
    required String installationId,
    required DateTime wallTime,
    required int logicalTime,
    List<String>? tombstones,
  }) async {
    _ensureInitialized();

    await _db.into(_db.crdtMetadata).insertOnConflictUpdate(
          CrdtMetadataCompanion.insert(
            resourceIri: resourceIri,
            installationId: installationId,
            wallTime: wallTime,
            logicalTime: logicalTime,
            tombstones: Value(tombstones?.join(',') ?? ''),
          ),
        );
  }

  /// Get CRDT metadata for a resource
  Future<List<CrdtMetadataData>> getCrdtMetadata(String resourceIri) async {
    _ensureInitialized();

    final query = _db.select(_db.crdtMetadata)
      ..where((meta) => meta.resourceIri.equals(resourceIri));

    return await query.get();
  }

  /// Store index entries for performance
  Future<void> storeIndexEntry({
    required String indexIri,
    required String resourceIri,
    required String resourceType,
    required Map<String, dynamic> headers,
    required String clockHash,
  }) async {
    _ensureInitialized();

    await _db.into(_db.indexEntries).insertOnConflictUpdate(
          IndexEntriesCompanion.insert(
            indexIri: indexIri,
            resourceIri: resourceIri,
            resourceType: resourceType,
            headers: _jsonEncode(headers),
            clockHash: clockHash,
          ),
        );
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
          'DriftStorage not initialized. Call initialize() first.');
    }
  }

  String _generateClockHash(String content) {
    // TODO: Implement proper HLC hash generation
    return content.hashCode.toString();
  }

  String _jsonEncode(Map<String, dynamic> data) {
    // TODO: Use proper JSON encoding
    return data.toString();
  }
}
