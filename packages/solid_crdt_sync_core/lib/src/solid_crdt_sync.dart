/// Main facade for the CRDT sync system.
library;

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'auth/auth_interface.dart';
import 'storage/storage_interface.dart';
import 'sync/sync_engine.dart';

/// Main facade for the solid_crdt_sync system.
/// 
/// Provides a simple, high-level API for local-first applications with
/// optional Solid Pod synchronization. Handles RDF mapping, storage,
/// and sync operations transparently.
class SolidCrdtSync {
  final LocalStorage _storage;
  final RdfMapper _mapper;
  final SyncEngine _syncEngine;
  SolidAuthProvider? _authProvider;
  bool _isConnected = false;

  SolidCrdtSync._({
    required LocalStorage storage,
    required RdfMapper mapper,
    required SyncEngine syncEngine,
    SolidAuthProvider? authProvider,
  }) : _storage = storage,
       _mapper = mapper,
       _syncEngine = syncEngine,
       _authProvider = authProvider,
       _isConnected = authProvider != null;

  /// Set up the CRDT sync system with storage and optional components.
  /// 
  /// This is the main entry point for applications. Creates a fully
  /// configured sync system that works locally by default.
  static Future<SolidCrdtSync> setup({
    required LocalStorage storage,
    RdfMapper? mapper,
    SolidAuthProvider? authProvider,
  }) async {
    // Initialize storage
    await storage.initialize();
    
    // Create default mapper if none provided
    final rdfMapper = mapper ?? RdfMapper(
      registry: RdfMapperRegistry(),
      rdfCore: RdfCore.withStandardCodecs(),
    );
    
    // Create sync engine - auth provider is optional initially
    final syncEngine = authProvider != null 
        ? SyncEngine(
            authProvider: authProvider,
            localStorage: storage,
          )
        : SyncEngine(
            authProvider: _NoOpAuthProvider(),
            localStorage: storage,
          );
    
    await syncEngine.initialize();
    
    return SolidCrdtSync._(
      storage: storage,
      mapper: rdfMapper,
      syncEngine: syncEngine,
      authProvider: authProvider,
    );
  }
  
  /// Connect to a Solid Pod for synchronization.
  /// 
  /// This is optional - the app works locally without this call.
  /// Once connected, data will sync automatically in the background.
  Future<void> connectToSolid(SolidAuthProvider authProvider) async {
    _authProvider = authProvider;
    
    // TODO: Update sync engine with auth provider
    // await _syncEngine.setAuthProvider(authProvider);
    
    _isConnected = await authProvider.isAuthenticated();
  }
  
  /// Check if connected to a Solid Pod.
  Future<bool> isConnected() async {
    if (_authProvider == null) return false;
    _isConnected = await _authProvider!.isAuthenticated();
    return _isConnected;
  }
  
  /// Manually trigger synchronization (when connected).
  Future<void> sync() async {
    if (!_isConnected) {
      throw StateError('Not connected to Solid Pod - call connectToSolid() first');
    }
    await _syncEngine.syncAll();
  }
  
  /// Get all objects of a specific type.
  Future<List<T>> getAll<T>() async {
    // TODO: Implement using storage + mapper
    // 1. Get all stored resources of type T
    // 2. Convert from RDF to Dart objects using mapper
    throw UnimplementedError('getAll<T>() not yet implemented');
  }
  
  /// Get a specific object by ID.
  Future<T?> get<T>(String id) async {
    // TODO: Implement using storage + mapper
    // 1. Get resource by IRI
    // 2. Convert from RDF to Dart object using mapper
    throw UnimplementedError('get<T>(id) not yet implemented');
  }
  
  /// Save an object (create or update).
  Future<void> save<T>(T object) async {
    // TODO: Implement using mapper + storage
    // 1. Convert Dart object to RDF using mapper
    // 2. Store RDF in local storage
    // 3. Trigger sync if connected
    throw UnimplementedError('save<T>(object) not yet implemented');
  }
  
  /// Delete an object by ID.
  Future<void> delete<T>(String id) async {
    // TODO: Implement using storage
    // 1. Delete from local storage
    // 2. Create deletion tombstone for sync
    // 3. Trigger sync if connected
    throw UnimplementedError('delete<T>(id) not yet implemented');
  }
  
  /// Close the sync system and free resources.
  Future<void> close() async {
    await _storage.close();
    await _syncEngine.dispose();
  }
}

/// No-op auth provider for local-only operation.
class _NoOpAuthProvider implements SolidAuthProvider {
  @override
  Future<String?> getWebId() async => null;

  @override
  Future<String?> getAccessToken(String resourceUrl) async => null;

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<void> signOut() async {}

  @override
  Stream<bool> get authStateChanges => Stream.value(false);
}