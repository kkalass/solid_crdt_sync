/// This API is designed around a declarative "Sync Strategy" model aligned with the 4-layer architecture.
///
/// The core philosophy is that this service is an "add-on" for synchronization,
/// not a replacement for an application's own database. The developer retains
/// full control over their local storage and querying.
///
/// The developer declares a SyncStrategy for each data type, choosing between:
/// 1. `FullSync`: For small to medium datasets using a single idx:FullIndex
/// 2. `GroupedSync`: For large datasets broken into logical groups using idx:GroupIndexTemplate  
/// 3. `OnDemandSync`: For very large datasets where only indices are synced initially

import 'dart:async';

// --- Configuration: Sync Strategies ---

/// Base class defining synchronization strategy for a data type.
/// 
/// Strategies are discovered through the Solid Type Index rather than hardcoded paths.
/// The framework uses Type Index entries to find both data containers and corresponding indices.
abstract class SyncStrategy {
  /// The Dart [Type] this configuration applies to.
  final Type type;

  /// The RDF class this strategy synchronizes (e.g., 'schema:Recipe').
  /// Used for Type Index discovery of both data containers and indices.
  final String rdfClass;

  SyncStrategy({
    required this.type,
    required this.rdfClass,
  });
}

/// Strategy for small to medium datasets using a single idx:FullIndex.
/// 
/// Suitable when:
/// - Dataset is small enough to sync completely (~1000s of items)
/// - Application needs all data available locally
/// - No logical partitioning is needed
/// 
/// Example: Personal recipe collection, contact lists, bookmarks
class FullSync extends SyncStrategy {
  /// Whether to immediately load full data or just index headers
  final bool loadDataImmediately;

  FullSync({
    required super.type,
    required super.rdfClass,
    this.loadDataImmediately = true,
  });
}

/// Strategy for large datasets broken into logical groups using idx:GroupIndexTemplate.
/// 
/// Suitable when:
/// - Dataset is very large (10,000s+ items)  
/// - Data has natural grouping (by date, category, etc.)
/// - Application typically works with subsets
/// 
/// Example: Shopping list entries by month, photos by year, messages by conversation
class GroupedSync extends SyncStrategy {
  /// Function that determines which group(s) an object belongs to.
  /// Objects can belong to multiple groups.
  /// Returns group identifiers that match the GroupIndexTemplate's grouping rules.
  final List<String> Function(Object object) grouper;

  /// Whether to immediately load full data for subscribed groups
  final bool loadDataImmediately;

  GroupedSync({
    required super.type, 
    required super.rdfClass,
    required this.grouper,
    this.loadDataImmediately = true,
  });
}

/// Strategy for very large datasets where only indices are synced by default.
/// 
/// Suitable when:
/// - Individual resources are large (documents, images, etc.)
/// - Application needs browse-then-load workflow  
/// - Network bandwidth is constrained
/// 
/// Example: Document libraries, photo albums, video collections
class OnDemandSync extends SyncStrategy {
  OnDemandSync({
    required super.type,
    required super.rdfClass,
  });
}

// --- Data & Listener Interfaces ---

/// Lightweight summary of a remote resource discovered from an index.
/// 
/// Contains enough information for UI display without loading full resource.
/// Properties available depend on the index's idx:indexedProperty configuration.
class ResourceHeader {
  final String iri;
  final Map<String, dynamic> properties;

  ResourceHeader({
    required this.iri, 
    required this.properties,
  });
  
  /// Convenience getter for common title properties
  String? get title => 
    properties['schema:name'] ?? 
    properties['foaf:name'] ?? 
    properties['rdfs:label'];
}

/// Listener for changes in synchronized indices.
abstract interface class IndexChangeListener {
  /// Called when the library has synchronized an index and discovered changes.
  ///
  /// - For `FullSync`: [sourceId] is the data type's RDF class
  /// - For `GroupedSync`: [sourceId] is the specific group identifier  
  /// - For `OnDemandSync`: [sourceId] is the data type's RDF class
  /// 
  /// [headers] contains the current set of resources in this index/group.
  void onIndexUpdate(String sourceId, List<ResourceHeader> headers);
}

/// Listener for when full data objects are synchronized.
abstract interface class DataChangeListener {
  /// Called when a full object is updated, either from a local `store` call
  /// or after a remote change was successfully merged using CRDT rules.
  void onUpdate(Object updatedObject);

  /// Called when an object is deleted, either locally or remotely.
  void onDelete(String objectId, Type objectType);
}

// --- Discovery and Configuration ---

/// Service discovery and setup configuration.
/// 
/// The framework automatically discovers data and index locations through the user's
/// Solid Type Index. Missing configuration triggers a setup dialog.
abstract interface class DiscoveryConfiguration {
  /// Called when Pod setup is required (missing Type Index entries).
  /// 
  /// The implementation should display a setup dialog allowing the user to:
  /// - Approve automatic configuration with standard paths
  /// - Customize the proposed configuration  
  /// - Cancel setup (framework will use fallback paths with reduced interoperability)
  /// 
  /// Returns true if user approved setup, false if cancelled.
  Future<bool> requestPodSetup({
    required List<String> missingDataTypes,
    required List<String> missingIndexTypes, 
    required Map<String, String> proposedPaths,
  });

  /// Called when authentication is required for setup operations.
  /// Setup modifications require write access to Profile Document and Type Index.
  Future<bool> requestSetupAuthentication();
}

// --- Main Service API ---

/// A service that synchronizes Dart objects with Solid Pods using CRDT-based merging.
/// 
/// Initialization:
/// 1. Configure with list of [SyncStrategy] instances for each data type
/// 2. Set [DiscoveryConfiguration] for handling setup scenarios  
/// 3. Inject authentication service for Solid Pod access
/// 
/// The service automatically:
/// - Discovers data and index locations via Type Index
/// - Handles first-time Pod setup with user consent
/// - Synchronizes indices and data according to strategies
/// - Performs CRDT merging using published merge contracts
abstract interface class SolidCrdtSyncService {
  
  // --- Listener Management ---
  
  void registerIndexChangeListener(IndexChangeListener listener);
  void unregisterIndexChangeListener(IndexChangeListener listener);

  void registerDataChangeListener(DataChangeListener listener);
  void unregisterDataChangeListener(DataChangeListener listener);

  // --- Data Operations ---

  /// Stores a Dart object to the Solid Pod.
  /// 
  /// The service:
  /// 1. Determines storage location using Type Index discovery
  /// 2. Fetches current remote version (if exists)
  /// 3. Performs CRDT merge with local changes
  /// 4. Updates all relevant index shards
  /// 5. Uploads merged resource and updated indices
  /// 6. Notifies DataChangeListeners
  Future<void> store(Object object);

  /// Deletes an object by ID and type.
  /// 
  /// Creates tombstone entries in CRDT metadata and updates indices.
  Future<void> delete(String id, Type type);

  // --- Subscription Management ---

  /// Subscribes to a specific group for a type configured with [GroupedSync].
  /// 
  /// [groupId] should match the grouping logic defined in the GroupIndexTemplate.
  /// For example, if grouping by date with format "YYYY-MM", use "2025-08".
  /// 
  /// The service will:
  /// 1. Discover the GroupIndexTemplate via Type Index
  /// 2. Resolve the specific GroupIndex for [groupId]  
  /// 3. Begin synchronizing that group's index and data
  Future<void> subscribeToGroup(Type type, String groupId);

  /// Unsubscribes from a specific group.
  /// Stops synchronizing the group but retains local data.
  Future<void> unsubscribeFromGroup(Type type, String groupId);

  /// Lists currently subscribed groups for a type.
  List<String> getSubscribedGroups(Type type);

  // --- On-Demand Operations ---

  /// Fetches full data for a single resource from the Solid Pod.
  /// 
  /// Primarily used with [OnDemandSync] strategy after browsing headers.
  /// The service:
  /// 1. Downloads the resource from [iri]
  /// 2. Performs CRDT merge with any local version
  /// 3. Notifies DataChangeListeners
  /// 4. Returns the merged object
  /// 
  /// Returns null if resource doesn't exist or is inaccessible.
  Future<T?> fetchFromRemote<T extends Object>(String iri);

  /// Gets currently cached headers for a type (without triggering network requests).
  /// 
  /// Useful for OnDemandSync to display available resources before loading data.
  List<ResourceHeader> getCachedHeaders(Type type, {String? groupId});

  // --- Service Lifecycle ---

  /// Starts the synchronization service.
  /// 
  /// Begins discovery process and initial sync according to configured strategies.
  /// Will trigger setup dialog if Pod configuration is incomplete.
  Future<void> start();

  /// Stops the synchronization service.
  /// 
  /// Cancels ongoing sync operations but retains local data.
  Future<void> stop();

  /// Gets current sync status.
  SyncStatus getStatus();

  /// Manually triggers a sync cycle for all configured types.
  /// 
  /// Useful for explicit refresh operations in UI.
  Future<void> triggerSync();
}

/// Current synchronization status.
enum SyncStatus {
  /// Service not started
  stopped,
  
  /// Performing initial discovery and setup
  initializing,
  
  /// Pod setup required (waiting for user)
  setupRequired,
  
  /// Actively synchronizing data
  syncing,
  
  /// Synchronized and monitoring for changes
  monitoring,
  
  /// Offline mode (network unavailable)
  offline,
  
  /// Error state requiring attention
  error,
}

// --- Usage Example ---

/// Example showing how to configure the service for a meal planning application.
/// 
/// This demonstrates the three different sync strategies:
/// - Recipes: OnDemandSync (browse titles, load on-demand)
/// - Shopping entries: GroupedSync by month (large dataset, group by date)  
/// - Meal plans: FullSync (small dataset, always needed)
/*

void setupMealPlanningSync() {
  final service = SolidCrdtSyncService.create([
    // Recipe collection - browse before loading
    OnDemandSync(
      type: Recipe,
      rdfClass: 'schema:Recipe',
    ),
    
    // Shopping list entries - group by month
    GroupedSync(
      type: ShoppingListEntry, 
      rdfClass: 'meal:ShoppingListEntry',
      grouper: (entry) => [
        // Group by required date in YYYY-MM format to match GroupIndexTemplate
        (entry as ShoppingListEntry).requiredForDate.toIso8601String().substring(0, 7)
      ],
      loadDataImmediately: true,
    ),
    
    // Meal plans - small dataset, always sync
    FullSync(
      type: MealPlan,
      rdfClass: 'meal:MealPlan', 
      loadDataImmediately: true,
    ),
  ]);
  
  // Configure Pod setup handling
  service.setDiscoveryConfiguration(MySetupHandler());
  
  // Set up listeners
  service.registerIndexChangeListener(MyIndexListener());
  service.registerDataChangeListener(MyDataListener());
  
  // Start the service
  service.start();
  
  // Subscribe to current month's shopping entries
  final currentMonth = DateTime.now().toIso8601String().substring(0, 7);
  service.subscribeToGroup(ShoppingListEntry, currentMonth);
}

*/