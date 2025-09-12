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
  final SolidCrdtSync _syncSystem;
  final StreamSubscription _hydrationSubscription;

  static const String _resourceType = 'category';

  /// Private constructor - use [create] factory method instead
  CategoryRepository._(
    this._categoryDao,
    this._syncSystem,
    this._hydrationSubscription,
  );

  /// Create and initialize a CategoryRepository with hydration from sync storage.
  ///
  /// This factory method:
  /// 1. Sets up hydration subscription for live updates
  /// 2. Performs initial catch-up from last cursor position
  /// 3. Returns a fully initialized repository
  static Future<CategoryRepository> create(
    CategoryDao categoryDao,
    CursorDao cursorDao,
    SolidCrdtSync syncSystem,
  ) async {
    final repository = CategoryRepository._(
        categoryDao,
        syncSystem,
        await syncSystem.hydrateStreaming<models.Category>(
          getCurrentCursor: () => cursorDao.getCursor(_resourceType),
          onUpdate: (category) => _handleCategoryUpdate(categoryDao, category),
          onDelete: (category) => _handleCategoryDelete(categoryDao, category),
          onCursorUpdate: (cursor) =>
              cursorDao.storeCursor(_resourceType, cursor),
        ));

    return repository;
  }

  /// Handle category update from sync storage
  static Future<void> _handleCategoryUpdate(
      CategoryDao categoryDao, models.Category category) async {
    final companion = _categoryToDriftCompanion(category);
    await categoryDao.insertOrUpdateCategory(companion);
  }

  /// Handle category deletion from sync storage
  static Future<void> _handleCategoryDelete(
      CategoryDao categoryDao, models.Category category) async {
    await categoryDao.deleteCategoryById(category.id);
  }

  /// Get all categories ordered by name (non-archived only)
  Future<List<models.Category>> getAllCategories() async {
    final driftCategories = await _categoryDao.getAllCategories();
    return driftCategories.map(_categoryFromDrift).toList();
  }

  /// Get all categories including archived ones, ordered by name
  Future<List<models.Category>> getAllCategoriesIncludingArchived() async {
    final driftCategories = await _categoryDao.getAllCategoriesIncludingArchived();
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

  /// Archive a category (soft delete) - sets archived flag to true
  /// 
  /// Soft delete - marks category as archived but keeps it referenceable.
  /// This is the recommended approach for categories since they may be 
  /// referenced by external applications.
  Future<void> archiveCategory(String id) async {
    final category = await getCategory(id);
    if (category != null) {
      final archivedCategory = category.copyWith(
        archived: true,
        modifiedAt: DateTime.now(),
      );
      await saveCategory(archivedCategory);
    }
  }

  /// Check if a category exists
  Future<bool> categoryExists(String id) async {
    return await _categoryDao.categoryExists(id);
  }

  /// Dispose resources when repository is no longer needed
  void dispose() {
    _hydrationSubscription.cancel();
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
      archived: drift.archived,
    );
  }

  /// Convert app Category model to Drift CategoriesCompanion
  static CategoriesCompanion _categoryToDriftCompanion(
      models.Category category) {
    return CategoriesCompanion(
      id: Value(category.id),
      name: Value(category.name),
      description: Value(category.description),
      color: Value(category.color),
      icon: Value(category.icon),
      createdAt: Value(category.createdAt),
      modifiedAt: Value(category.modifiedAt),
      archived: Value(category.archived),
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
  final SolidCrdtSync _syncSystem;
  final StreamSubscription _hydrationSubscription;

  static const String _resourceType = 'note';

  /// Private constructor - use [create] factory method instead
  NoteRepository._(
    this._noteDao,
    this._syncSystem,
    this._hydrationSubscription,
  );

  /// Create and initialize a NoteRepository with hydration from sync storage.
  ///
  /// This factory method:
  /// 1. Sets up hydration subscription for live updates
  /// 2. Performs initial catch-up from last cursor position
  /// 3. Returns a fully initialized repository
  static Future<NoteRepository> create(
    NoteDao noteDao,
    CursorDao cursorDao,
    SolidCrdtSync syncSystem,
  ) async {
    final repository = NoteRepository._(
        noteDao,
        syncSystem,
        await syncSystem.hydrateStreaming<models.Note>(
          getCurrentCursor: () => cursorDao.getCursor(_resourceType),
          onUpdate: (note) => _handleNoteUpdate(noteDao, note),
          onDelete: (note) => _handleNoteDelete(noteDao, note),
          onCursorUpdate: (cursor) =>
              cursorDao.storeCursor(_resourceType, cursor),
        ));

    return repository;
  }

  /// Handle note update from sync storage
  static Future<void> _handleNoteUpdate(
      NoteDao noteDao, models.Note note) async {
    final companion = _noteToDriftCompanion(note);
    await noteDao.insertOrUpdateNote(companion);
  }

  /// Handle note deletion from sync storage
  static Future<void> _handleNoteDelete(
      NoteDao noteDao, models.Note note) async {
    await noteDao.deleteNoteById(note.id);
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

  /// Dispose resources when repository is no longer needed
  void dispose() {
    _hydrationSubscription.cancel();
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
  static NotesCompanion _noteToDriftCompanion(models.Note note) {
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
