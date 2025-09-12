/// Mock SolidCrdtSync implementation for testing.
library;

import 'dart:async';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';

/// Simple mock implementation for testing
class MockSolidCrdtSync implements SolidCrdtSync {
  final List<dynamic> savedObjects = [];

  @override
  Future<void> save<T>(T object, {Future<void> Function(T processedObject)? onLocalUpdate}) async {
    savedObjects.add(object);
    if (onLocalUpdate != null) {
      await onLocalUpdate(object);
    }
  }

  @override
  Future<void> close() async {}

  @override
  Stream<T> dataUpdatesStream<T>() => Stream.empty();

  @override
  Stream<T> indexUpdatesStream<T>([String localName = '']) => Stream.empty();

  @override
  Future<void> deleteDocument<T>(T object, {Future<void> Function(T deletedObject)? onLocalUpdate}) async {
    savedObjects.removeWhere((item) => item == object);
    if (onLocalUpdate != null) {
      await onLocalUpdate(object);
    }
  }

  @override
  Stream<HydrationResult<T>> hydrationUpdates<T>() => Stream.empty();

  @override
  Future<HydrationResult<T>> loadChangesSince<T>(String? cursor, {int limit = 100}) async {
    return HydrationResult<T>(
      items: [],
      deletedItems: [],
      originalCursor: cursor,
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<void> hydrateOnce<T>({
    required String? lastCursor,
    required Future<void> Function(T item) onUpdate,
    required Future<void> Function(T item) onDelete,
    required Future<void> Function(String cursor) onCursorUpdate,
    int limit = 100,
  }) async {
    // Mock implementation - no-op
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
