/// Main facade for the CRDT sync system.
library;

import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';
import 'package:solid_crdt_sync_core/src/mapping/solid_mapping_context.dart';
import 'auth/auth_interface.dart';
import 'storage/storage_interface.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';

/// Type alias for mapper initializer functions.
///
/// These functions receive framework services via SolidMappingContext
/// and return a fully configured RdfMapper.
typedef MapperInitializerFunction = RdfMapper Function(
    SolidMappingContext context);

/// Main facade for the solid_crdt_sync system.
///
/// Provides a simple, high-level API for local-first applications with
/// optional Solid Pod synchronization. Handles RDF mapping, storage,
/// and sync operations transparently.
class SolidCrdtSync {
  final Storage _storage;
  final RdfMapper _mapper;
  final Auth? _authProvider;
  final CrdtMappingsConfig _crdtMappings;
  SolidCrdtSync._({
    required Storage storage,
    required RdfMapper mapper,
    required Auth auth,
    required CrdtMappingsConfig crdt,
  })  : _storage = storage,
        _mapper = mapper,
        _authProvider = auth,
        _crdtMappings = crdt;

  /// Set up the CRDT sync system with storage and optional components.
  ///
  /// This is the main entry point for applications. Creates a fully
  /// configured sync system that works locally by default.
  static Future<SolidCrdtSync> setup({
    required Auth auth,
    required Storage storage,
    required MapperInitializerFunction mapperInitializer,
    required CrdtMappingsConfig crdt,
    List<CrdtIndexConfig> indices = const [],
  }) async {
    // Initialize storage
    await storage.initialize();
    throw UnimplementedError('Storage initialization not yet implemented');
    /*
    return SolidCrdtSync._(
      storage: storage,
      mapper: mapper,
      authProvider: authProvider,
      crdtMappings: crdtMappings,
    );
    */
  }

  /// Stream of data updates from sync operations.
  ///
  /// Emits objects when they are freshly fetched or updated from the server,
  /// not existing local data. Use this to react to new data coming through sync.
  Stream<T> dataUpdatesStream<T>() {
    // TODO: Implement data updates stream
    throw UnimplementedError('dataUpdatesStream<T>() not yet implemented');
  }

  /// Stream of index entry updates from sync operations.
  ///
  /// Emits index entries when they are freshly fetched or updated from the server.
  /// Index entries contain lightweight copies of selected fields for efficient queries.
  ///
  /// The localName parameter refers to the localName specified in the index configuration,
  /// which is used only for local identification within the app.
  Stream<T> indexUpdatesStream<T>([String localName = defaultIndexLocalName]) {
    // TODO: Implement index updates stream
    throw UnimplementedError(
        'indexUpdatesStream<T>(localName) not yet implemented');
  }

  /// Save an object (create or update).
  ///
  /// Stores the object locally and triggers sync if connected to Solid Pod.
  Future<void> save<T>(T object) async {
    // TODO: Implement using mapper + storage
    throw UnimplementedError('save<T>(object) not yet implemented');
  }

  /// Close the sync system and free resources.
  Future<void> close() async {
    await _storage.close();
  }
}
