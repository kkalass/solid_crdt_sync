/// Tests for the CategoriesService class.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';
import 'package:personal_notes_app/models/category.dart';
import 'package:personal_notes_app/services/categories_service.dart';

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
  Stream<T> dataUpdatesStream<T>() => Stream.empty();

  @override
  Stream<T> indexUpdatesStream<T>([String localName = '']) => Stream.empty();
}

void main() {
  group('CategoriesService', () {
    late MockSolidCrdtSync mockSyncSystem;
    late CategoriesService categoriesService;

    setUp(() {
      mockSyncSystem = MockSolidCrdtSync();
      categoriesService = CategoriesService(mockSyncSystem);
    });

    group('createCategory', () {
      test('creates category with required fields', () {
        final category = categoriesService.createCategory(name: 'Work');

        expect(category.name, equals('Work'));
        expect(category.id, isNotEmpty);
        expect(category.id, startsWith('category_'));
        expect(category.description, isNull);
        expect(category.color, isNull);
        expect(category.icon, isNull);
      });

      test('creates category with all fields', () {
        final category = categoriesService.createCategory(
          name: 'Personal',
          description: 'Personal notes and tasks',
          color: '#FF5722',
          icon: 'person',
        );

        expect(category.name, equals('Personal'));
        expect(category.description, equals('Personal notes and tasks'));
        expect(category.color, equals('#FF5722'));
        expect(category.icon, equals('person'));
        expect(category.id, isNotEmpty);
        expect(category.id, startsWith('category_'));
      });

      test('generates unique IDs', () {
        final category1 = categoriesService.createCategory(name: 'Test1');
        final category2 = categoriesService.createCategory(name: 'Test2');

        expect(category1.id, isNot(equals(category2.id)));
      });
    });

    group('saveCategory', () {
      test('calls syncSystem.save with category', () async {
        final category = Category(
          id: 'test_id',
          name: 'Test Category',
        );

        await categoriesService.saveCategory(category);

        expect(mockSyncSystem.savedObjects, contains(category));
      });
    });

    // Note: More comprehensive tests would be added once the SolidCrdtSync
    // API is fully implemented. These tests demonstrate the basic structure
    // and test the logic that doesn't depend on the sync system.
  });
}
