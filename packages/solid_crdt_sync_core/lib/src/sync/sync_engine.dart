/// Core synchronization engine implementation.
/// 
/// Orchestrates the sync process between local storage and Solid Pods
/// using the configured authentication and sync strategies.

import '../auth/auth_interface.dart';
import '../storage/storage_interface.dart';
import 'sync_strategy.dart';

/// Main synchronization engine that coordinates all sync operations.
class SyncEngine {
  final SolidAuthProvider _authProvider;
  final LocalStorage _localStorage;
  final List<SyncStrategy> _strategies;
  
  SyncEngine({
    required SolidAuthProvider authProvider,
    required LocalStorage localStorage,
    List<SyncStrategy>? strategies,
  }) : _authProvider = authProvider,
       _localStorage = localStorage,
       _strategies = strategies ?? [];
  
  /// Initialize the sync engine.
  Future<void> initialize() async {
    await _localStorage.initialize();
  }
  
  /// Add a sync strategy for a specific resource type.
  void addStrategy(SyncStrategy strategy) {
    _strategies.add(strategy);
  }
  
  /// Remove a sync strategy.
  void removeStrategy(SyncStrategy strategy) {
    _strategies.remove(strategy);
  }
  
  /// Execute synchronization for all configured strategies.
  Future<void> syncAll() async {
    if (!await _authProvider.isAuthenticated()) {
      throw StateError('Not authenticated - cannot sync');
    }
    
    for (final strategy in _strategies) {
      await strategy.sync();
    }
  }
  
  /// Execute synchronization for a specific resource type.
  Future<void> syncResourceType(String resourceType) async {
    if (!await _authProvider.isAuthenticated()) {
      throw StateError('Not authenticated - cannot sync');
    }
    
    final strategy = _strategies.where((s) => s.canHandle(resourceType)).firstOrNull;
    if (strategy != null) {
      await strategy.sync();
    }
  }
  
  /// Clean up resources.
  Future<void> dispose() async {
    await _localStorage.close();
  }
}