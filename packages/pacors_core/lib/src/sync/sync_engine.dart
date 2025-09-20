/// Core synchronization engine implementation.
///
/// Orchestrates the sync process between local storage and Solid Pods
/// using the configured authentication and sync strategies.

import '../auth/auth_interface.dart';
import '../storage/storage_interface.dart';

/// Main synchronization engine that coordinates all sync operations.
class SyncEngine {
  final Auth _authProvider;
  final Storage _localStorage;

  SyncEngine({
    required Auth authProvider,
    required Storage localStorage,
  })  : _authProvider = authProvider,
        _localStorage = localStorage;

  /// Initialize the sync engine.
  Future<void> initialize() async {
    await _localStorage.initialize();
  }

  /// Execute synchronization for all configured strategies.
  Future<void> syncAll() async {
    if (!await _authProvider.isAuthenticated()) {
      throw StateError('Not authenticated - cannot sync');
    }
  }

  /// Execute synchronization for a specific resource type.
  Future<void> syncResourceType(String resourceType) async {
    if (!await _authProvider.isAuthenticated()) {
      throw StateError('Not authenticated - cannot sync');
    }
  }

  /// Clean up resources.
  Future<void> dispose() async {
    await _localStorage.close();
  }
}
