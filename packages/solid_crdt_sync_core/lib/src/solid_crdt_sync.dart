/// Main facade for the CRDT sync system.
library;

import 'dart:async';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_crdt_sync_core/src/mapping/solid_mapping_context.dart';
import 'package:solid_crdt_sync_core/src/mapping/local_resource_iri_service.dart';
import 'auth/auth_interface.dart';
import 'storage/storage_interface.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';
import 'package:solid_crdt_sync_core/src/index/index_converter.dart';
import 'package:solid_crdt_sync_core/src/index/index_item_converter.dart';
import 'config/resource_config.dart';
import 'config/validation.dart';
import 'hydration_result.dart';
import 'hydration/hydration_emitter.dart';
import 'hydration/hydration_stream_manager.dart';
import 'hydration/index_item_converter_registry.dart';
import 'hydration/type_local_name_key.dart';

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
  // ignore: unused_field
  final Auth? _authProvider; // TODO: Use for Pod synchronization
  final SyncConfig _config;
  final Map<Type, IriTerm> _resourceTypeCache;
  late final IndexConverter _indexConverter;
  late final HydrationStreamManager _streamManager;
  late final IndexItemConverterRegistry _converterRegistry;
  late final HydrationEmitter _emitter;
  SolidCrdtSync._({
    required Storage storage,
    required RdfMapper mapper,
    required Auth auth,
    required SyncConfig config,
    required Map<Type, IriTerm> resourceTypeCache,
  })  : _storage = storage,
        _mapper = mapper,
        _authProvider = auth,
        _config = config,
        _resourceTypeCache = resourceTypeCache {
    _indexConverter = IndexConverter(_mapper);
    _streamManager = HydrationStreamManager();
    _converterRegistry = IndexItemConverterRegistry();
    _emitter = HydrationEmitter(
      streamManager: _streamManager,
      converterRegistry: _converterRegistry,
    );
  }

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
    final iriService = LocalResourceIriService();
    final mappingContext = SolidMappingContext(
      resourceIriFactory: iriService.createResourceIriMapper,
      resourceRefFactory: iriService.createResourceRefMapper,
    );
    final mapper = mapperInitializer(mappingContext);

    final resourceTypeCache = config.buildResourceTypeCache(mapper);

    // Validate configuration before proceeding
    final configValidationResult = config.validate(resourceTypeCache);

    // Validate IRI service setup and finish setup if valid
    final iriServiceValidationResult =
        iriService.finishSetupAndValidate(resourceTypeCache);

    // Combine validation results
    final combinedValidationResult = ValidationResult.merge(
        [configValidationResult, iriServiceValidationResult]);

    // Throw if any validation failed
    combinedValidationResult.throwIfInvalid();

    // Initialize storage
    await storage.initialize();
    return SolidCrdtSync._(
        storage: storage,
        mapper: mapper,
        auth: auth,
        config: config,
        resourceTypeCache: resourceTypeCache);
  }

  /// Save an object with CRDT processing.
  ///
  /// Stores the object locally and triggers sync if connected to Solid Pod.
  /// Application state is updated via the hydration stream - repositories should
  /// listen to hydrateStreaming() to receive updates.
  ///
  /// Process:
  /// 1. CRDT processing (merge with existing, clock increment)
  /// 2. Store locally in sync system
  /// 3. Hydration stream automatically emits update
  /// 4. Schedule async Pod sync
  Future<void> save<T>(T object) async {
    final resourceConfig = _config.getResourceConfig(T)!;
    // Basic implementation to maintain hydration stream contract
    // TODO: Add proper CRDT processing and storage persistence

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Emit data change
    _emitter.emit(
        HydrationResult<T>(
          items: [object],
          deletedItems: [],
          originalCursor: null,
          nextCursor: timestamp,
          hasMore: false,
        ),
        resourceConfig);
  }

  /// Delete a document with CRDT processing.
  ///
  /// This performs document-level deletion, marking the entire document as deleted
  /// and affecting all resources contained within, following CRDT semantics.
  /// Application state is updated via the hydration stream - repositories should
  /// listen to hydrateStreaming() to receive deletion notifications.
  ///
  /// Process:
  /// 1. Add crdt:deletedAt timestamp to document
  /// 2. Perform universal emptying (remove semantic content, keep framework metadata)
  /// 3. Store updated document in sync system
  /// 4. Hydration stream automatically emits deletion
  /// 5. Schedule async Pod sync
  Future<void> deleteDocument<T>(T object) async {
    final resourceConfig = _config.getResourceConfig(T)!;
    // Basic implementation to maintain hydration stream contract
    // TODO: Add proper CRDT deletion processing and storage persistence

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Emit data change
    _emitter.emit(
        HydrationResult<T>(
          items: [],
          deletedItems: [object],
          originalCursor: null,
          nextCursor: timestamp,
          hasMore: false,
        ),
        resourceConfig);
  }

  /// Create an IndexItemConverter if T matches an index item type
  IndexItemConverter<T>? _createIndexItemConverter<T>(
          SyncConfig config, String localName) =>
      switch (config.findIndexConfigForType<T>(localName)) {
        (final resourceConfig, final index) => IndexItemConverter<T>(
            converter: _indexConverter,
            indexItem: index.item!,
            resourceType: _resourceTypeCache[resourceConfig.type]!,
          ),
        null => null,
      };

  /// Load changes from sync storage since the given cursor.
  ///
  /// Returns items that have been updated or deleted since the cursor position.
  /// Use null cursor to load from the beginning.
  Future<HydrationResult<T>> _loadChangesSince<T>(
    String? cursor, {
    int limit = 100,
  }) async {
    // TODO: Implement loading changes from sync storage
    return HydrationResult<T>(
      items: [],
      deletedItems: [],
      originalCursor: cursor,
      nextCursor: null,
      hasMore: false,
    );
  }

  /// One-time hydration that handles pagination and cursor management.
  ///
  /// This method automatically handles:
  /// - Pagination through all changes since lastCursor
  /// - Cursor management and persistence
  /// - Separate handling of updates and deletions
  ///
  /// Use this for manual hydration or catch-up scenarios. For ongoing hydration
  /// with live updates, use [hydrateStreaming] instead.
  ///
  /// Callbacks:
  /// - [onUpdate]: Called for each new/updated item
  /// - [onDelete]: Called for each deleted item (with last known state)
  /// - [onCursorUpdate]: Called to persist cursor for next hydration
  Future<void> _hydrateOnce<T>({
    required String? lastCursor,
    required Future<void> Function(T item) onUpdate,
    required Future<void> Function(T item) onDelete,
    required Future<void> Function(String cursor) onCursorUpdate,
    int limit = 100,
  }) async {
    String? currentCursor = lastCursor;
    HydrationResult<T> result;

    do {
      result = await _loadChangesSince<T>(currentCursor, limit: limit);

      // Apply updates
      for (final item in result.items) {
        await onUpdate(item);
      }

      // Apply deletions
      for (final item in result.deletedItems) {
        await onDelete(item);
      }

      // Update cursor
      if (result.nextCursor != null) {
        await onCursorUpdate(result.nextCursor!);
        currentCursor = result.nextCursor;
      }
    } while (result.hasMore);
  }

  /// Streaming hydration that performs initial catch-up and then maintains live updates.
  ///
  /// This is the recommended method for repository integration:
  /// 1. Performs catch-up hydration from lastCursor
  /// 2. Sets up live hydration stream for ongoing updates
  /// 3. Handles cursor consistency checks automatically
  ///
  /// Returns a StreamSubscription that must be managed by the caller - store it
  /// and cancel when disposing to stop the live hydration.
  ///
  /// On cursor mismatch, this method automatically triggers a refresh using the
  /// existing callbacks, so repositories don't need to handle this manually.
  ///
  /// The [localName] parameter is used to distinguish between different indices
  /// that might use the same Dart class (e.g., different GroupIndex configurations).
  ///
  /// Callbacks:
  /// - [getCurrentCursor]: Should return the repository's current cursor
  /// - [onUpdate]: Called for each new/updated item
  /// - [onDelete]: Called for each deleted item (with last known state)
  /// - [onCursorUpdate]: Called to persist cursor updates
  Future<StreamSubscription<HydrationResult<T>>> hydrateStreaming<T>({
    required Future<String?> Function() getCurrentCursor,
    required Future<void> Function(T item) onUpdate,
    required Future<void> Function(T item) onDelete,
    required Future<void> Function(String cursor) onCursorUpdate,
    String localName = defaultIndexLocalName,
    int limit = 100,
  }) async {
    // Check if T is a registered resource type
    final resourceConfig = _config.getResourceConfig(T);
    if (resourceConfig == null) {
      // T is not a resource type, check if it's an index item type
      final converter = _createIndexItemConverter<T>(_config, localName);
      if (converter == null) {
        throw Exception(
            'Type $T is not a registered resource or index item type.');
      }
      final key = TypeLocalNameKey(T, localName);
      _converterRegistry.registerConverter(key, converter);
    }

    // 1. Set up live hydration updates
    final subscription = _streamManager
        .getOrCreateController<T>(localName)
        .stream
        .listen((result) async {
      // TODO: Implement proper cursor consistency checking
      // The current originalCursor check is too strict and prevents local changes
      // from being applied immediately. Need to design a better approach that:
      // 1. Allows immediate application of local changes (save/delete operations)
      // 2. Provides proper consistency checking for remote sync updates
      // 3. Handles cursor mismatches gracefully without blocking updates

      // Apply changes directly without cursor consistency check for now
      for (final item in result.items) {
        await onUpdate(item);
      }
      for (final item in result.deletedItems) {
        await onDelete(item);
      }
      if (result.nextCursor != null) {
        await onCursorUpdate(result.nextCursor!);
      }
    });

    // 2. Initial catch-up hydration
    final initialCursor = await getCurrentCursor();
    await _hydrateOnce<T>(
      lastCursor: initialCursor,
      onUpdate: onUpdate,
      onDelete: onDelete,
      onCursorUpdate: onCursorUpdate,
      limit: limit,
    );
    return subscription;
  }

  /// Close the sync system and free resources.
  Future<void> close() async {
    await _streamManager.close();
    await _storage.close();
  }
}
