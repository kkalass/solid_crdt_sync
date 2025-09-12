/// Tests for the CategoriesService class.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_notes_app/models/category.dart';
import 'package:personal_notes_app/services/categories_service.dart';

import 'mock_category_repository.dart';
import 'mock_note_repository.dart';

void main() {
  group('CategoriesService', () {
    late MockCategoryRepository mockCategoryRepository;
    late MockNoteRepository mockNoteRepository;
    late CategoriesService categoriesService;

    setUp(() {
      mockCategoryRepository = MockCategoryRepository();
      mockNoteRepository = MockNoteRepository();
      categoriesService =
          CategoriesService(mockCategoryRepository, mockNoteRepository);
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
      test('calls repository.saveCategory with category', () async {
        final category = Category(
          id: 'test_id',
          name: 'Test Category',
        );

        await categoriesService.saveCategory(category);

        expect(mockCategoryRepository.savedCategories, contains(category));
      });
    });

    // Note: More comprehensive tests would be added once the SolidCrdtSync
    // API is fully implemented. These tests demonstrate the basic structure
    // and test the logic that doesn't depend on the sync system.
  });
}
