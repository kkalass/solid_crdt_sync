/// Drift database schema for the example app's local storage.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Categories table
class Categories extends Table {
  /// Category ID (primary key)
  TextColumn get id => text()();

  /// Category name
  TextColumn get name => text()();

  /// Category description (optional)
  TextColumn get description => text().nullable()();

  /// Category color (optional)
  TextColumn get color => text().nullable()();

  /// Category icon (optional)
  TextColumn get icon => text().nullable()();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last modification timestamp
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Notes table
class Notes extends Table {
  /// Note ID (primary key)
  TextColumn get id => text()();

  /// Note title
  TextColumn get title => text()();

  /// Note content
  TextColumn get content => text()();

  /// Category ID (foreign key)
  TextColumn get categoryId => 
      text().nullable().references(Categories, #id)();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last modification timestamp
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Main app database class (schema only)
@DriftDatabase(tables: [Categories, Notes], daos: [CategoryDao, NoteDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase({DriftWebOptions? web, DriftNativeOptions? native})
      : super(_openConnection(web: web, native: native));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      
      // Create indices for performance
      await m.database.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_category 
        ON notes(category_id);
      ''');
      
      await m.database.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_notes_modified 
        ON notes(modified_at DESC);
      ''');
      
      await m.database.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_categories_name 
        ON categories(name);
      ''');
    },
  );
}

/// Data Access Object for Categories
@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// Get all categories ordered by name
  Future<List<Category>> getAllCategories() {
    return (select(categories)
      ..orderBy([(c) => OrderingTerm(expression: c.name)]))
      .get();
  }

  /// Get a specific category by ID
  Future<Category?> getCategoryById(String id) {
    return (select(categories)..where((c) => c.id.equals(id)))
      .getSingleOrNull();
  }

  /// Insert or update a category
  Future<void> insertOrUpdateCategory(CategoriesCompanion companion) {
    return into(categories).insertOnConflictUpdate(companion);
  }

  /// Delete a category by ID
  Future<void> deleteCategoryById(String id) {
    return (delete(categories)..where((c) => c.id.equals(id))).go();
  }

  /// Check if a category exists
  Future<bool> categoryExists(String id) async {
    final query = selectOnly(categories)
      ..addColumns([categories.id.count()])
      ..where(categories.id.equals(id));
    
    final result = await query.getSingle();
    return result.read(categories.id.count())! > 0;
  }

  /// Clear all categories (for testing)
  Future<void> clearAllCategories() {
    return delete(categories).go();
  }
}

/// Data Access Object for Notes
@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  /// Get all notes ordered by modification date (newest first)
  Future<List<Note>> getAllNotes() {
    return (select(notes)
      ..orderBy([(n) => OrderingTerm(expression: n.modifiedAt, mode: OrderingMode.desc)]))
      .get();
  }

  /// Get a specific note by ID
  Future<Note?> getNoteById(String id) {
    return (select(notes)..where((n) => n.id.equals(id)))
      .getSingleOrNull();
  }

  /// Insert or update a note
  Future<void> insertOrUpdateNote(NotesCompanion companion) {
    return into(notes).insertOnConflictUpdate(companion);
  }

  /// Delete a note by ID
  Future<void> deleteNoteById(String id) {
    return (delete(notes)..where((n) => n.id.equals(id))).go();
  }

  /// Get notes by category
  Future<List<Note>> getNotesByCategory(String categoryId) {
    return (select(notes)
      ..where((n) => n.categoryId.equals(categoryId))
      ..orderBy([(n) => OrderingTerm(expression: n.modifiedAt, mode: OrderingMode.desc)]))
      .get();
  }

  /// Get notes without a category
  Future<List<Note>> getUncategorizedNotes() {
    return (select(notes)
      ..where((n) => n.categoryId.isNull())
      ..orderBy([(n) => OrderingTerm(expression: n.modifiedAt, mode: OrderingMode.desc)]))
      .get();
  }

  /// Clear all notes (for testing)
  Future<void> clearAllNotes() {
    return delete(notes).go();
  }
}

/// Create database connection based on platform
QueryExecutor _openConnection(
    {DriftWebOptions? web, DriftNativeOptions? native}) {
  // For web, explicitly configure IndexedDB storage
  return driftDatabase(name: 'personal_notes_app', web: web, native: native);
}