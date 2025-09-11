/// Business logic for managing categories with CRDT sync.
library;

import 'dart:math';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';
import '../models/category.dart';
import '../models/note.dart';

/// Service for managing categories with local-first CRDT synchronization.
///
/// Provides a simple API for CRUD operations while handling RDF mapping
/// and sync automatically in the background. Categories use FullIndex with
/// prefetch policy for immediate availability.
class CategoriesService {
  final SolidCrdtSync _syncSystem;

  CategoriesService(this._syncSystem);

  /// Get all categories sorted by name
  Future<List<Category>> getAllCategories() async {
    // TODO: This should work with the FullIndex - categories are prefetched
    throw UnimplementedError('Get all categories not yet implemented');
    /*
    final categories = await _syncSystem.getAll<Category>();
    categories.sort((a, b) => a.name.compareTo(b.name));
    return categories;
    */
  }

  /// Get a specific category by ID
  Future<Category?> getCategory(String id) async {
    // TODO: Should be fast since categories are prefetched
    throw UnimplementedError('Get category by ID not yet implemented');
    /*
    return await _syncSystem.get<Category>(id);
    */
  }

  /// Save a category (create or update)
  Future<void> saveCategory(Category category) async {
    await _syncSystem.save(category);
  }

  /// Delete a category
  ///
  /// Note: This does not check if the category is in use by notes.
  /// Consider using [deleteCategoryIfUnused] for safer deletion.
  Future<void> deleteCategory(String id) async {
    throw UnimplementedError('Delete category not yet implemented');
    /*
    await _syncSystem.delete<Category>(id);
    */
  }

  /// Delete a category only if it's not used by any notes
  ///
  /// Returns true if category was deleted, false if it's in use.
  Future<bool> deleteCategoryIfUnused(String id) async {
    // Check if category is used by any notes
    final notesInCategory = await getNotesInCategory(id);

    if (notesInCategory.isNotEmpty) {
      return false; // Category is in use, cannot delete
    }

    await deleteCategory(id);
    return true;
  }

  /// Create a new category with generated ID
  Category createCategory({
    required String name,
    String? description,
    String? color,
    String? icon,
  }) {
    return Category(
      id: _generateCategoryId(),
      name: name,
      description: description,
      color: color,
      icon: icon,
    );
  }

  /// Get all notes that belong to a specific category
  ///
  /// This method queries notes by category, which should use the GroupIndex
  /// by category efficiently when implemented.
  Future<List<Note>> getNotesInCategory(String categoryId) async {
    // TODO: This should use the GroupIndex by category efficiently
    throw UnimplementedError('Get notes in category not yet implemented');
    /*
    final notes = await _syncSystem.getAll<Note>();
    return notes.where((note) => note.categoryId == categoryId).toList();
    */
  }

  /// Get count of notes in each category
  ///
  /// Returns a map of category ID to note count.
  Future<Map<String, int>> getCategoryNoteCounts() async {
    throw UnimplementedError('Get category note counts not yet implemented');
    /*
    final notes = await _syncSystem.getAll<Note>();
    final counts = <String, int>{};
    
    for (final note in notes) {
      if (note.categoryId != null) {
        counts[note.categoryId!] = (counts[note.categoryId!] ?? 0) + 1;
      }
    }
    
    return counts;
    */
  }

  /// Check if a category exists
  Future<bool> categoryExists(String id) async {
    final category = await getCategory(id);
    return category != null;
  }

  /// Generate a unique ID for new categories
  String _generateCategoryId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'category_${timestamp}_$random';
  }
}
