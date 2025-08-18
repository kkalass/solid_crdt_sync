/// This API is designed around a "Sync Strategy" model.
///
/// The core philosophy is that this service is an "add-on" for synchronization,
/// not a replacement for an application's own database. The developer retains
/// full control over their local storage and querying.
///
/// The developer declares a SyncStrategy for each data type, choosing between:
/// 1. `FullSync`: For small datasets that can be fully synced.
/// 2. `PartitionedSync`: For large datasets that should be synced in logical chunks.
/// 3. `OnDemandSync`: For very large datasets where only an index is synced initially.

// --- Configuration: Sync Strategies ---

/// A base class for defining the synchronization strategy for a data type.
abstract class SyncStrategy {
  /// The Dart [Type] this configuration applies to.
  final Type type;

  /// The base container path on the Solid Pod for this data type.
  final String basePath;

  /// A function that returns the relative path of the shard for an object's ID.
  final String Function(String id) sharder;

  SyncStrategy({
    required this.type,
    required this.basePath,
    required this.sharder,
  });
}

/// Strategy for small datasets that should be fully synchronized.
class FullSync extends SyncStrategy {
  FullSync({
    required super.type,
    required super.basePath,
    required super.sharder,
  });
}

/// Strategy for large datasets that are logically partitioned (e.g., by date).
class PartitionedSync extends SyncStrategy {
  /// A function that returns the partition ID(s) for a given object.
  /// An object can belong to multiple partitions.
  final List<String> Function(Object object) partitioner;

  PartitionedSync({
    required super.type,
    required super.basePath,
    required super.sharder,
    required this.partitioner,
  });
}

/// Strategy for very large datasets where only an index is synced by default.
class OnDemandSync extends SyncStrategy {
  OnDemandSync({
    required super.type,
    required super.basePath,
    required super.sharder,
  });
}

// --- Data & Listener Interfaces ---

/// A lightweight summary of a remote resource, discovered from an index shard.
class ResourceHeader {
  final String iri;
  final String title;
  // Other lightweight metadata like modification date, etc. could be added here.

  ResourceHeader({required this.iri, required this.title});
}

/// A listener for changes in the contents of a synced index.
abstract interface class IndexChangeListener {
  /// Called when the library has synchronized an index.
  ///
  /// For `PartitionedSync`, [sourceId] is the partition path.
  /// For `OnDemandSync`, [sourceId] is the type's base path.
  void onIndexUpdate(String sourceId, List<ResourceHeader> headers);
}

/// A listener for when full data objects are updated or deleted.
abstract interface class DataChangeListener {
  /// Called when a full object is updated, either from a local `store` call
  /// or after a remote change was successfully merged.
  void onUpdate(Object updatedObject);

  /// Called when an object is deleted, either locally or remotely.
  void onDelete(String objectId, Type objectType);
}

// --- The Main Service API ---

/// A service that synchronizes Dart objects with a Solid Pod.
///
/// It is initialized with a list of [SyncStrategy] configurations.
/// It assumes an external, injected `AuthenticationService` handles login.
abstract interface class SolidCrdtSyncService {
  void registerIndexChangeListener(IndexChangeListener listener);
  void unregisterIndexChangeListener(IndexChangeListener listener);

  void registerDataChangeListener(DataChangeListener listener);
  void unregisterDataChangeListener(DataChangeListener listener);

  /// Stores a Dart object. The library uses the configured [SyncStrategy]
  /// to determine how and where to write the data and update the correct indices.
  Future<void> store(Object object);

  /// Deletes a Dart object by its ID.
  Future<void> delete(String id, Type type);

  /// Subscribes to a partition for a type configured with [PartitionedSync].
  ///
  /// This tells the service to start syncing the index for this specific partition.
  Future<void> subscribeToPartition(String partitionPath);

  /// Unsubscribes from a partition.
  Future<void> unsubscribeFromPartition(String partitionPath);

  /// Subscribes to the main index for a type configured with [OnDemandSync].
  Future<void> subscribeToIndex(Type type);

  /// Unsubscribes from an on-demand index.
  Future<void> unsubscribeFromIndex(Type type);

  /// Fetches the full data for a single resource from the Solid Pod.
  ///
  /// The app calls this on-demand. The library downloads the resource,
  /// performs the CRDT merge, and notifies [DataChangeListener]s.
  Future<T?> fetchFromRemote<T extends Object>(String iri);
}
