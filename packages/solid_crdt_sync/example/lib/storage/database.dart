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

  /// Whether this category is archived (soft deleted)
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

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
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last modification timestamp
  DateTimeColumn get modifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Note index entries table - lightweight metadata for browsing
class NoteIndexEntries extends Table {
  /// Note ID (primary key, references note)
  TextColumn get id => text()();

  /// Note name/title (from indexed properties)
  TextColumn get name => text()();

  /// Creation timestamp (from indexed properties)
  DateTimeColumn get dateCreated => dateTime()();

  /// Last modification timestamp (from indexed properties)  
  DateTimeColumn get dateModified => dateTime()();

  /// Keywords (from indexed properties)
  TextColumn get keywords => text().nullable()();

  /// Category ID (from indexed properties)
  TextColumn get categoryId => text().nullable()();

  /// Group ID - which GroupIndex group this entry belongs to
  TextColumn get groupId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Hydration cursors table for tracking sync storage state
class HydrationCursors extends Table {
  /// Resource type (e.g., 'category', 'note')
  TextColumn get resourceType => text()();

  /// Last processed cursor value
  TextColumn get cursor => text()();

  /// Last update timestamp
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {resourceType};
}

/// Main app database class (schema only)
@DriftDatabase(
    tables: [Categories, Notes, NoteIndexEntries, HydrationCursors],
    daos: [CategoryDao, NoteDao, NoteIndexEntryDao, CursorDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase({DriftWebOptions? web, DriftNativeOptions? native})
      : super(_openConnection(web: web, native: native));

  @override
  int get schemaVersion => 4;

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

          await m.database.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_note_index_entries_group 
        ON note_index_entries(group_id);
      ''');

          await m.database.customStatement('''
        CREATE INDEX IF NOT EXISTS idx_note_index_entries_category 
        ON note_index_entries(category_id);
      ''');
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // Add HydrationCursors table in version 2
            await m.createTable(hydrationCursors);
          }
          if (from < 3) {
            // Add archived column to categories table in version 3
            await m.addColumn(categories, categories.archived);
          }
          if (from < 4) {
            // Add NoteIndexEntries table in version 4
            await m.createTable(noteIndexEntries);
            
            await m.database.customStatement('''
              CREATE INDEX IF NOT EXISTS idx_note_index_entries_group 
              ON note_index_entries(group_id);
            ''');

            await m.database.customStatement('''
              CREATE INDEX IF NOT EXISTS idx_note_index_entries_category 
              ON note_index_entries(category_id);
            ''');
          }
        },
      );
}

/// Data Access Object for Categories
@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// Get all categories ordered by name (non-archived only)
  Future<List<Category>> getAllCategories() {
    return (select(categories)
          ..where((c) => c.archived.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .get();
  }

  /// Get all categories including archived ones, ordered by name
  Future<List<Category>> getAllCategoriesIncludingArchived() {
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
}

/// Data Access Object for Notes
@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> with _$NoteDaoMixin {
  NoteDao(super.db);

  /// Get all notes ordered by modification date (newest first)
  Future<List<Note>> getAllNotes() {
    return (select(notes)
          ..orderBy([
            (n) =>
                OrderingTerm(expression: n.modifiedAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get a specific note by ID
  Future<Note?> getNoteById(String id) {
    return (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();
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
          ..orderBy([
            (n) =>
                OrderingTerm(expression: n.modifiedAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get notes without a category
  Future<List<Note>> getUncategorizedNotes() {
    return (select(notes)
          ..where((n) => n.categoryId.isNull())
          ..orderBy([
            (n) =>
                OrderingTerm(expression: n.modifiedAt, mode: OrderingMode.desc)
          ]))
        .get();
  }
}

/// Data Access Object for Note Index Entries
@DriftAccessor(tables: [NoteIndexEntries])
class NoteIndexEntryDao extends DatabaseAccessor<AppDatabase> with _$NoteIndexEntryDaoMixin {
  NoteIndexEntryDao(super.db);

  /// Get all note index entries ordered by modification date (newest first)
  Future<List<NoteIndexEntry>> getAllNoteIndexEntries() {
    return (select(noteIndexEntries)
          ..orderBy([
            (n) => OrderingTerm(expression: n.dateModified, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get a specific note index entry by ID
  Future<NoteIndexEntry?> getNoteIndexEntryById(String id) {
    return (select(noteIndexEntries)..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  /// Insert or update a note index entry
  Future<void> insertOrUpdateNoteIndexEntry(NoteIndexEntriesCompanion companion) {
    return into(noteIndexEntries).insertOnConflictUpdate(companion);
  }

  /// Delete a note index entry by ID
  Future<void> deleteNoteIndexEntryById(String id) {
    return (delete(noteIndexEntries)..where((n) => n.id.equals(id))).go();
  }

  /// Get note index entries by category
  Future<List<NoteIndexEntry>> getNoteIndexEntriesByCategory(String categoryId) {
    return (select(noteIndexEntries)
          ..where((n) => n.categoryId.equals(categoryId))
          ..orderBy([
            (n) => OrderingTerm(expression: n.dateModified, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get note index entries without a category
  Future<List<NoteIndexEntry>> getUncategorizedNoteIndexEntries() {
    return (select(noteIndexEntries)
          ..where((n) => n.categoryId.isNull())
          ..orderBy([
            (n) => OrderingTerm(expression: n.dateModified, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Get note index entries by group
  Future<List<NoteIndexEntry>> getNoteIndexEntriesByGroup(String groupId) {
    return (select(noteIndexEntries)
          ..where((n) => n.groupId.equals(groupId))
          ..orderBy([
            (n) => OrderingTerm(expression: n.dateModified, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Check if a note index entry exists
  Future<bool> noteIndexEntryExists(String id) async {
    final query = selectOnly(noteIndexEntries)
      ..addColumns([noteIndexEntries.id.count()])
      ..where(noteIndexEntries.id.equals(id));

    final result = await query.getSingle();
    return result.read(noteIndexEntries.id.count())! > 0;
  }
}

/// Data Access Object for Hydration Cursors
@DriftAccessor(tables: [HydrationCursors])
class CursorDao extends DatabaseAccessor<AppDatabase> with _$CursorDaoMixin {
  CursorDao(super.db);

  /// Get cursor for a specific resource type
  Future<String?> getCursor(String resourceType) async {
    final cursor = await (select(hydrationCursors)
          ..where((c) => c.resourceType.equals(resourceType)))
        .getSingleOrNull();
    return cursor?.cursor;
  }

  /// Store cursor for a specific resource type
  Future<void> storeCursor(String resourceType, String cursor) {
    return into(hydrationCursors).insertOnConflictUpdate(
      HydrationCursorsCompanion(
        resourceType: Value(resourceType),
        cursor: Value(cursor),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Clear cursor for a specific resource type
  Future<void> clearCursor(String resourceType) {
    return (delete(hydrationCursors)
          ..where((c) => c.resourceType.equals(resourceType)))
        .go();
  }
}

/// Create database connection based on platform
QueryExecutor _openConnection(
    {DriftWebOptions? web, DriftNativeOptions? native}) {
  // For web, explicitly configure IndexedDB storage
  return driftDatabase(name: 'personal_notes_app', web: web, native: native);
}
