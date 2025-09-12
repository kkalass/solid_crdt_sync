/// Repository layer for business logic operations.
library;

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';
import '../models/category.dart' as models;
import '../models/note.dart' as models;
import 'database.dart';

/// Repository for Category business logic operations.
///
/// This layer handles business logic, model conversion between 
/// Drift entities and application models, AND sync coordination.
/// Repository becomes "sync-aware storage" following add-on architecture.
class CategoryRepository {
  final CategoryDao _categoryDao;
  final CursorDao _cursorDao;
  final SolidCrdtSync _syncSystem;
  StreamSubscription? _hydrationSubscription;
  
  static const String _resourceType = 'category';

  CategoryRepository(this._categoryDao, this._cursorDao, this._syncSystem);

  /// Initialize the repository with hydration from sync storage.
  ///
  /// This should be called once during app startup to:
  /// 1. Catch up on any missed changes since last shutdown
  /// 2. Set up live hydration for ongoing updates
  Future<void> initialize() async {
    _hydrationSubscription = await _syncSystem.hydrateStreaming<models.Category>(
      getCurrentCursor: () => _getStoredCursor(),
      onUpdate: (category) => _handleCategoryUpdate(category),
      onDelete: (category) => _handleCategoryDelete(category),
      onCursorUpdate: (cursor) => _storeCursor(cursor),
    );
  }

  /// Handle category update from sync storage
  Future<void> _handleCategoryUpdate(models.Category category) async {
    final companion = _categoryToDriftCompanion(category);
    await _categoryDao.insertOrUpdateCategory(companion);
  }

  /// Handle category deletion from sync storage
  Future<void> _handleCategoryDelete(models.Category category) async {
    await _categoryDao.deleteCategoryById(category.id);
  }

  /// Get stored hydration cursor
  Future<String?> _getStoredCursor() async {
    return await _cursorDao.getCursor(_resourceType);
  }

  /// Store hydration cursor
  Future<void> _storeCursor(String cursor) async {
    await _cursorDao.storeCursor(_resourceType, cursor);
  }

  /// Get all categories ordered by name
  Future<List<models.Category>> getAllCategories() async {
    final driftCategories = await _categoryDao.getAllCategories();
    return driftCategories.map(_categoryFromDrift).toList();
  }

  /// Get a specific category by ID
  Future<models.Category?> getCategory(String id) async {
    final driftCategory = await _categoryDao.getCategoryById(id);
    return driftCategory != null ? _categoryFromDrift(driftCategory) : null;
  }

  /// Save a category (insert or update) with sync coordination
  Future<void> saveCategory(models.Category category) async {
    // Use sync system's robust save method with callback
    await _syncSystem.saveWithCallback<models.Category>(
      category,
      onLocalUpdate: (processedCategory) async {
        // Local storage is updated immediately after CRDT processing
        final companion = _categoryToDriftCompanion(processedCategory);
        await _categoryDao.insertOrUpdateCategory(companion);
      },
    );
  }

  /// Delete a category by ID
  Future<void> deleteCategory(String id) async {
    // For now, delete directly from local storage
    // TODO: Implement CRDT deletion via sync system
    await _categoryDao.deleteCategoryById(id);
  }

  /// Check if a category exists
  Future<bool> categoryExists(String id) async {
    return await _categoryDao.categoryExists(id);
  }

  /// Clear all categories (for testing)
  Future<void> clear() async {
    await _categoryDao.clearAllCategories();
  }

  /// Dispose resources when repository is no longer needed
  void dispose() {
    _hydrationSubscription?.cancel();
  }

  /// Convert Drift Category to app Category model
  models.Category _categoryFromDrift(Category drift) {
    return models.Category(
      id: drift.id,
      name: drift.name,
      description: drift.description,
      color: drift.color,
      icon: drift.icon,
      createdAt: drift.createdAt,
      modifiedAt: drift.modifiedAt,
    );
  }

  /// Convert app Category model to Drift CategoriesCompanion
  CategoriesCompanion _categoryToDriftCompanion(models.Category category) {
    return CategoriesCompanion(
      id: Value(category.id),
      name: Value(category.name),
      description: Value(category.description),
      color: Value(category.color),
      icon: Value(category.icon),
      createdAt: Value(category.createdAt),
      modifiedAt: Value(category.modifiedAt),
    );
  }
}

/// Repository for Note business logic operations.
///
/// This layer handles business logic, model conversion between 
/// Drift entities and application models, AND sync coordination.
/// Repository becomes "sync-aware storage" following add-on architecture.
class NoteRepository {
  final NoteDao _noteDao;
  final CursorDao _cursorDao;
  final SolidCrdtSync _syncSystem;
  StreamSubscription? _hydrationSubscription;
  
  static const String _resourceType = 'note';

  NoteRepository(this._noteDao, this._cursorDao, this._syncSystem);

  /// Initialize the repository with hydration from sync storage.
  ///
  /// This should be called once during app startup to:
  /// 1. Catch up on any missed changes since last shutdown
  /// 2. Set up live hydration for ongoing updates
  Future<void> initialize() async {
    _hydrationSubscription = await _syncSystem.hydrateStreaming<models.Note>(
      getCurrentCursor: () => _getStoredCursor(),
      onUpdate: (note) => _handleNoteUpdate(note),
      onDelete: (note) => _handleNoteDelete(note),
      onCursorUpdate: (cursor) => _storeCursor(cursor),
    );
  }

  /// Handle note update from sync storage
  Future<void> _handleNoteUpdate(models.Note note) async {
    final companion = _noteToDriftCompanion(note);
    await _noteDao.insertOrUpdateNote(companion);
  }

  /// Handle note deletion from sync storage
  Future<void> _handleNoteDelete(models.Note note) async {
    await _noteDao.deleteNoteById(note.id);
  }

  /// Get stored hydration cursor
  Future<String?> _getStoredCursor() async {
    return await _cursorDao.getCursor(_resourceType);
  }

  /// Store hydration cursor
  Future<void> _storeCursor(String cursor) async {
    await _cursorDao.storeCursor(_resourceType, cursor);
  }

  /// Get all notes ordered by modification date (newest first)
  Future<List<models.Note>> getAllNotes() async {
    final driftNotes = await _noteDao.getAllNotes();
    return driftNotes.map(_noteFromDrift).toList();
  }

  /// Get a specific note by ID
  Future<models.Note?> getNote(String id) async {
    final driftNote = await _noteDao.getNoteById(id);
    return driftNote != null ? _noteFromDrift(driftNote) : null;
  }

  /// Save a note (insert or update) with sync coordination
  Future<void> saveNote(models.Note note) async {
    // Use sync system's robust save method with callback
    await _syncSystem.saveWithCallback<models.Note>(
      note,
      onLocalUpdate: (processedNote) async {
        // Local storage is updated immediately after CRDT processing
        final companion = _noteToDriftCompanion(processedNote);
        await _noteDao.insertOrUpdateNote(companion);
      },
    );
  }

  /// Delete a note by ID
  Future<void> deleteNote(String id) async {
    // For now, delete directly from local storage
    // TODO: Implement CRDT deletion via sync system
    await _noteDao.deleteNoteById(id);
  }

  /// Get notes by category
  Future<List<models.Note>> getNotesByCategory(String categoryId) async {
    final driftNotes = await _noteDao.getNotesByCategory(categoryId);
    return driftNotes.map(_noteFromDrift).toList();
  }

  /// Get notes without a category
  Future<List<models.Note>> getUncategorizedNotes() async {
    final driftNotes = await _noteDao.getUncategorizedNotes();
    return driftNotes.map(_noteFromDrift).toList();
  }

  /// Clear all notes (for testing)
  Future<void> clear() async {
    await _noteDao.clearAllNotes();
  }

  /// Dispose resources when repository is no longer needed
  void dispose() {
    _hydrationSubscription?.cancel();
  }

  /// Convert Drift Note to app Note model
  models.Note _noteFromDrift(Note drift) {
    return models.Note(
      id: drift.id,
      title: drift.title,
      content: drift.content,
      categoryId: drift.categoryId,
      createdAt: drift.createdAt,
      modifiedAt: drift.modifiedAt,
    );
  }

  /// Convert app Note model to Drift NotesCompanion
  NotesCompanion _noteToDriftCompanion(models.Note note) {
    return NotesCompanion(
      id: Value(note.id),
      title: Value(note.title),
      content: Value(note.content),
      categoryId: Value(note.categoryId),
      createdAt: Value(note.createdAt),
      modifiedAt: Value(note.modifiedAt),
    );
  }
}