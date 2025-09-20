import 'dart:async';
import 'package:test/test.dart';
import 'package:pacors_core/src/hydration/hydration_stream_manager.dart';
import 'package:pacors_core/src/hydration/type_local_name_key.dart';
import 'package:pacors_core/src/hydration_result.dart';

void main() {
  group('HydrationStreamManager', () {
    late HydrationStreamManager manager;

    setUp(() {
      manager = HydrationStreamManager();
    });

    tearDown(() async {
      await manager.close();
    });

    test('should create and return stream controller', () {
      final controller = manager.getOrCreateController<String>('test');

      expect(controller, isNotNull);
      expect(controller.stream, isNotNull);
    });

    test('should return same controller for same type and local name', () {
      final controller1 = manager.getOrCreateController<String>('test');
      final controller2 = manager.getOrCreateController<String>('test');

      expect(controller1, equals(controller2));
    });

    test('should return different controllers for different types', () {
      final controller1 = manager.getOrCreateController<String>('test');
      final controller2 = manager.getOrCreateController<int>('test');

      expect(controller1, isNot(equals(controller2)));
    });

    test('should return different controllers for different local names', () {
      final controller1 = manager.getOrCreateController<String>('test1');
      final controller2 = manager.getOrCreateController<String>('test2');

      expect(controller1, isNot(equals(controller2)));
    });

    test('should emit to correct stream', () async {
      final controller = manager.getOrCreateController<String>('test');
      final key = TypeLocalNameKey(String, 'test');
      final result = HydrationResult<String>(
        items: ['item1', 'item2'],
        deletedItems: [],
        originalCursor: null,
        nextCursor: 'cursor1',
        hasMore: false,
      );

      // Listen to the stream
      final streamEvents = <HydrationResult<String>>[];
      final subscription = controller.stream.listen(streamEvents.add);

      // Emit to the stream
      manager.emitToStream(key, result);

      // Wait for async emission
      await Future.delayed(Duration.zero);

      expect(streamEvents, hasLength(1));
      expect(streamEvents.first, equals(result));

      await subscription.cancel();
    });

    test('should throw when emitting to non-existent stream', () {
      final key = TypeLocalNameKey(String, 'nonexistent');
      final result = HydrationResult<String>(
        items: ['item1'],
        deletedItems: [],
        originalCursor: null,
        nextCursor: null,
        hasMore: false,
      );

      // Should throw StateError for programming errors
      expect(
        () => manager.emitToStream(key, result),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No stream controller exists for key'),
        )),
      );
    });

    test('should handle multiple concurrent listeners', () async {
      final controller = manager.getOrCreateController<String>('test');
      final key = TypeLocalNameKey(String, 'test');

      final result = HydrationResult<String>(
        items: ['broadcast'],
        deletedItems: [],
        originalCursor: null,
        nextCursor: null,
        hasMore: false,
      );

      // Set up multiple listeners
      final events1 = <HydrationResult<String>>[];
      final events2 = <HydrationResult<String>>[];

      final sub1 = controller.stream.listen(events1.add);
      final sub2 = controller.stream.listen(events2.add);

      // Emit once
      manager.emitToStream(key, result);
      await Future.delayed(Duration.zero);

      // Both should receive the event
      expect(events1, hasLength(1));
      expect(events2, hasLength(1));
      expect(events1.first, equals(result));
      expect(events2.first, equals(result));

      await sub1.cancel();
      await sub2.cancel();
    });

    test('should close all controllers', () async {
      final controller1 = manager.getOrCreateController<String>('test1');
      final controller2 = manager.getOrCreateController<int>('test2');

      expect(controller1.isClosed, isFalse);
      expect(controller2.isClosed, isFalse);

      await manager.close();

      expect(controller1.isClosed, isTrue);
      expect(controller2.isClosed, isTrue);
    });
  });
}
