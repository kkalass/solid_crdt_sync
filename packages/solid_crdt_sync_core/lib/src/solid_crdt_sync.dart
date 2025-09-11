/// Main facade for the CRDT sync system.
library;

import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_crdt_sync_core/src/mapping/solid_mapping_context.dart';
import 'auth/auth_interface.dart';
import 'storage/storage_interface.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';
import 'config/resource_config.dart';

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
  final SyncConfig _config;
  SolidCrdtSync._({
    required Storage storage,
    required RdfMapper mapper,
    required Auth auth,
    required SyncConfig config,
  })  : _storage = storage,
        _mapper = mapper,
        _authProvider = auth,
        _config = config;

  /// Set up the CRDT sync system with resource-focused configuration.
  ///
  /// This is the main entry point for applications. Creates a fully
  /// configured sync system that works locally by default.
  ///
  /// Configuration is organized around resources (Note, Category, etc.)
  /// with their paths, CRDT mappings, and indices all defined together.
  ///
  /// Throws [SyncConfigValidationException] if the configuration is invalid.
  static Future<SolidCrdtSync> setup({
    required Auth auth,
    required Storage storage,
    required MapperInitializerFunction mapperInitializer,
    required SyncConfig config,
  }) async {
    final mapper = mapperInitializer(SolidMappingContext());
    // Validate configuration before proceeding
    final validationResult = config.validate(mapper);
    validationResult.throwIfInvalid();

    // Initialize storage
    await storage.initialize();
    throw UnimplementedError('Storage initialization not yet implemented');
    /*
    final indices = config.getAllIndices();
    
    return SolidCrdtSync._(
      storage: storage,
      mapper: mapper,
      auth: auth,
      config: config,
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
  ///
  /// FIXME: how to specify the precise index in case of group indices?
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

  /// Save an object with CRDT processing and immediate app notification.
  ///
  /// This is the recommended method for app integration as it ensures
  /// atomic consistency between sync system and app storage.
  ///
  /// Process:
  /// 1. CRDT processing (merge with existing, clock increment)
  /// 2. Store locally in sync system
  /// 3. Notify app immediately via callback
  /// 4. Schedule async Pod sync
  Future<void> saveWithCallback<T>(
    T object, {
    required void Function(T processedObject) onLocalUpdate,
  }) async {
    // TODO: Implement CRDT processing and callback pattern
    throw UnimplementedError('saveWithCallback<T>() not yet implemented');
  }

  /// Stream of remote updates for objects that changed on the Pod.
  ///
  /// Emits objects when they are updated remotely and merged locally.
  /// Use this to keep app storage synchronized with remote changes.
  Stream<T> remoteUpdates<T>() {
    // TODO: Implement remote updates stream
    throw UnimplementedError('remoteUpdates<T>() not yet implemented');
  }

  /// Close the sync system and free resources.
  Future<void> close() async {
    await _storage.close();
  }
}
