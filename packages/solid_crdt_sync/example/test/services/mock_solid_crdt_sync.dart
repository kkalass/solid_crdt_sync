/// Mock SolidCrdtSync implementation for testing.
library;

import 'dart:async';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';

/// Simple mock implementation for testing
class MockSolidCrdtSync implements SolidCrdtSync {
  final List<dynamic> savedObjects = [];

  @override
  Future<void> save<T>(T object) async {
    savedObjects.add(object);
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteDocument<T>(T object) async {
    savedObjects.removeWhere((item) => item == object);
  }

  @override
  Future<StreamSubscription<HydrationResult<T>>> hydrateStreaming<T>({
    required Future<String?> Function() getCurrentCursor,
    required Future<void> Function(T item) onUpdate,
    required Future<void> Function(T item) onDelete,
    required Future<void> Function(String cursor) onCursorUpdate,
    int limit = 100,
  }) async {
    // Mock implementation - return empty subscription
    return Stream<HydrationResult<T>>.empty().listen(null);
  }
}
