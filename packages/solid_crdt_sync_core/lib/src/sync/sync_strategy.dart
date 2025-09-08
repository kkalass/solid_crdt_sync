/// Sync strategy definitions for different synchronization patterns.
/// 
/// Defines the three main sync strategies from the architecture:
/// - FullSync: Complete dataset synchronization
/// - GroupedSync: Partition-based synchronization  
/// - OnDemandSync: Lazy loading synchronization

enum SyncStrategyType {
  full,
  grouped, 
  onDemand,
}

/// Base interface for all sync strategies.
abstract interface class SyncStrategy {
  SyncStrategyType get type;
  
  /// Execute the sync strategy.
  Future<void> sync();
  
  /// Check if this strategy can handle the given resource type.
  bool canHandle(String resourceType);
}

/// Full synchronization strategy - downloads entire dataset.
abstract interface class FullSyncStrategy extends SyncStrategy {
  @override
  SyncStrategyType get type => SyncStrategyType.full;
}

/// Grouped synchronization strategy - downloads data in partitions.
abstract interface class GroupedSyncStrategy extends SyncStrategy {
  @override
  SyncStrategyType get type => SyncStrategyType.grouped;
  
  /// Get the grouping criteria for this strategy.
  List<String> get groupingProperties;
}

/// On-demand synchronization strategy - lazy loading as needed.
abstract interface class OnDemandSyncStrategy extends SyncStrategy {
  @override
  SyncStrategyType get type => SyncStrategyType.onDemand;
  
  /// Load specific resource on demand.
  Future<void> loadResource(String resourceIri);
}