/// Business logic for managing categories with CRDT sync.
library;

import 'dart:math';
import '../models/category.dart';
import '../models/note.dart';
import '../storage/repositories.dart';

/// Service for managing categories with local-first CRDT synchronization.
///
/// This service demonstrates the add-on architecture where:
/// - Repository handles all local queries, operations AND sync coordination
/// - Service focuses purely on business logic and cross-entity operations
/// - Repositories are "sync-aware storage" that handle CRDT processing automatically
///
/// Categories use FullIndex with prefetch policy for immediate availability.
class CategoriesService {
  final CategoryRepository _categoryRepository;
  final NoteRepository _noteRepository;

  CategoriesService(this._categoryRepository, this._noteRepository);

  /// Get all categories sorted by name
  Future<List<Category>> getAllCategories() async {
    // Query from repository - fast and flexible
    return await _categoryRepository.getAllCategories();
  }

  /// Get a specific category by ID
  Future<Category?> getCategory(String id) async {
    // Query from repository - immediate response
    return await _categoryRepository.getCategory(id);
  }

  /// Save a category (create or update)
  Future<void> saveCategory(Category category) async {
    // Repository handles sync coordination automatically
    await _categoryRepository.saveCategory(category);
  }

  /// Delete a category
  ///
  /// Note: This does not check if the category is in use by notes.
  /// Consider using [deleteCategoryIfUnused] for safer deletion.
  Future<void> deleteCategory(String id) async {
    // For now, delete directly from repository
    // TODO: Implement CRDT deletion via sync system
    await _categoryRepository.deleteCategory(id);
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
  /// This method queries notes by category from repository.
  /// In the future, this could be optimized using GroupIndex.
  Future<List<Note>> getNotesInCategory(String categoryId) async {
    return await _noteRepository.getNotesByCategory(categoryId);
  }

  /// Get count of notes in each category
  ///
  /// Returns a map of category ID to note count.
  Future<Map<String, int>> getCategoryNoteCounts() async {
    final notes = await _noteRepository.getAllNotes();
    final counts = <String, int>{};

    for (final note in notes) {
      if (note.categoryId != null) {
        counts[note.categoryId!] = (counts[note.categoryId!] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// Check if a category exists
  Future<bool> categoryExists(String id) async {
    return await _categoryRepository.categoryExists(id);
  }

  // Note: No dispose method needed - repositories handle their own cleanup

  /// Generate a unique ID for new categories
  String _generateCategoryId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'category_${timestamp}_$random';
  }
}
