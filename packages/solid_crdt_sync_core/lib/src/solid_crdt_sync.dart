/// Main facade for the CRDT sync system.
library;

import 'dart:async';
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

/// Result of hydrating app storage from sync storage.
class HydrationResult<T> {
  final List<T> items; // New/updated items
  final List<T> deletedItems; // Deleted items (last known state)
  final String?
      originalCursor; // Expected current cursor (for consistency check)
  final String? nextCursor; // New cursor after hydration
  final bool hasMore; // Whether more data is available

  const HydrationResult({
    required this.items,
    required this.deletedItems,
    required this.originalCursor,
    required this.nextCursor,
    required this.hasMore,
  });
}

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
    return SolidCrdtSync._(
      storage: storage,
      mapper: mapper,
      auth: auth,
      config: config,
    );
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
    // TODO: Implement using mapper + storage
    // throw UnimplementedError('save<T>(object) not yet implemented');
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
    // TODO: Implement document deletion with CRDT tombstone
    // throw UnimplementedError('deleteDocument<T>(object) not yet implemented');
  }

  /// Stream of hydration updates for objects that changed in sync storage.
  ///
  /// Emits HydrationResult batches when objects are updated in sync storage.
  /// Each result includes originalCursor for consistency checking.
  Stream<HydrationResult<T>> _hydrationUpdates<T>() {
    // TODO: Implement hydration updates stream
    return Stream<HydrationResult<T>>.empty();
  }

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
    int limit = 100,
  }) async {
    // 1. Initial catch-up hydration
    final initialCursor = await getCurrentCursor();
    await _hydrateOnce<T>(
      lastCursor: initialCursor,
      onUpdate: onUpdate,
      onDelete: onDelete,
      onCursorUpdate: onCursorUpdate,
      limit: limit,
    );

    // 2. Set up live hydration updates
    return _hydrationUpdates<T>().listen((result) async {
      final currentCursor = await getCurrentCursor();

      if (result.originalCursor == currentCursor) {
        // Cursor matches - safe to apply changes
        for (final item in result.items) {
          await onUpdate(item);
        }
        for (final item in result.deletedItems) {
          await onDelete(item);
        }
        if (result.nextCursor != null) {
          await onCursorUpdate(result.nextCursor!);
        }
      } else {
        // Cursor mismatch - trigger catch-up hydration using existing callbacks
        await _hydrateOnce<T>(
          lastCursor: currentCursor,
          onUpdate: onUpdate,
          onDelete: onDelete,
          onCursorUpdate: onCursorUpdate,
          limit: limit,
        );
      }
    });
  }

  /// Close the sync system and free resources.
  Future<void> close() async {
    await _storage.close();
  }
}
