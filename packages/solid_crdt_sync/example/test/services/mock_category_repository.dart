import 'package:flutter_test/flutter_test.dart';
import 'package:personal_notes_app/models/category.dart';
import 'package:personal_notes_app/storage/repositories.dart';

/// Mock repository for testing
class MockCategoryRepository implements CategoryRepository {
  final List<Category> savedCategories = [];
  final List<Category> storedCategories = [];

  @override
  Future<void> saveCategory(Category category) async {
    savedCategories.add(category);
    // Simulate storing the category
    storedCategories.removeWhere((c) => c.id == category.id);
    storedCategories.add(category);
  }

  @override
  Future<List<Category>> getAllCategories() async =>
      List.from(storedCategories);

  @override
  Future<Category?> getCategory(String id) async {
    try {
      return storedCategories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    storedCategories.removeWhere((c) => c.id == id);
  }

  @override
  Future<bool> categoryExists(String id) async {
    return storedCategories.any((c) => c.id == id);
  }

  @override
  Future<void> clear() async {
    storedCategories.clear();
  }

  @override
  void dispose() {}
}
