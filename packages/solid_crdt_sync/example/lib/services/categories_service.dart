/// Business logic for managing categories with CRDT sync.
library;

import 'dart:async';
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

  /// Get all categories sorted by name (non-archived only)
  Future<List<Category>> getAllCategories() async {
    // Query from repository - fast and flexible
    return await _categoryRepository.getAllCategories();
  }

  /// Get all categories including archived ones, sorted by name
  Future<List<Category>> getAllCategoriesIncludingArchived() async {
    return await _categoryRepository.getAllCategoriesIncludingArchived();
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

  /// Archive a category (soft delete) - sets archived flag to true
  ///
  /// Soft delete - marks category as archived but keeps it referenceable.
  /// This is the recommended approach for categories since they may be
  /// referenced by external applications.
  Future<void> archiveCategory(String id) async {
    await _categoryRepository.archiveCategory(id);
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
