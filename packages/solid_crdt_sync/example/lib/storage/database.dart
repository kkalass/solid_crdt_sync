/// Drift database schema for the example app's local storage.
library;

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Type converter for Set<String> to/from JSON
class StringSetConverter extends TypeConverter<Set<String>, String> {
  const StringSetConverter();

  @override
  Set<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return <String>{};
    try {
      final List<dynamic> decoded = json.decode(fromDb);
      return decoded.cast<String>().toSet();
    } catch (e) {
      // Fallback for comma-separated format
      return fromDb.split(',').where((s) => s.isNotEmpty).toSet();
    }
  }

  @override
  String toSql(Set<String> value) {
    return json.encode(value.toList());
  }
}

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

  /// Tags that can be added/removed independently
  TextColumn get tags => text()
      .map(const StringSetConverter())
      .withDefault(const Constant('[]'))();

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
  TextColumn get keywords =>
      text().map(const StringSetConverter()).nullable()();

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
  int get schemaVersion => 5;

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
          if (from < 5) {
            // Add tags column to notes table in version 5
            await m.database.customStatement('''
              ALTER TABLE notes ADD COLUMN tags TEXT NOT NULL DEFAULT '[]';
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

  /// Watch all categories ordered by name (non-archived only)
  Stream<List<Category>> getAllCategories() {
    return (select(categories)
          ..where((c) => c.archived.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch();
  }

  /// Watch all categories including archived ones, ordered by name
  Stream<List<Category>> getAllCategoriesIncludingArchived() {
    return (select(categories)
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch();
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

  /// Watch all notes ordered by modification date (newest first)
  Stream<List<Note>> getAllNotes() {
    return (select(notes)
          ..orderBy([
            (n) =>
                OrderingTerm(expression: n.modifiedAt, mode: OrderingMode.desc)
          ]))
        .watch();
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

  /// Watch notes by category
  Stream<List<Note>> getNotesByCategory(String categoryId) {
    return (select(notes)
          ..where((n) => n.categoryId.equals(categoryId))
          ..orderBy([
            (n) =>
                OrderingTerm(expression: n.modifiedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  /// Watch notes without a category
  Stream<List<Note>> getUncategorizedNotes() {
    return (select(notes)
          ..where((n) => n.categoryId.isNull())
          ..orderBy([
            (n) =>
                OrderingTerm(expression: n.modifiedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }
}

/// Data Access Object for Note Index Entries
@DriftAccessor(tables: [NoteIndexEntries])
class NoteIndexEntryDao extends DatabaseAccessor<AppDatabase>
    with _$NoteIndexEntryDaoMixin {
  NoteIndexEntryDao(super.db);

  /// Watch all note index entries ordered by modification date (newest first)
  Stream<List<NoteIndexEntry>> watchAllNoteIndexEntries() {
    return (select(noteIndexEntries)
          ..orderBy([
            (n) => OrderingTerm(
                expression: n.dateModified, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  /// Get a specific note index entry by ID
  Future<NoteIndexEntry?> getNoteIndexEntryById(String id) {
    return (select(noteIndexEntries)..where((n) => n.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert or update a note index entry
  Future<void> insertOrUpdateNoteIndexEntry(
      NoteIndexEntriesCompanion companion) {
    return into(noteIndexEntries).insertOnConflictUpdate(companion);
  }

  /// Delete a note index entry by ID
  Future<void> deleteNoteIndexEntryById(String id) {
    return (delete(noteIndexEntries)..where((n) => n.id.equals(id))).go();
  }

  /// Watch note index entries by category
  Stream<List<NoteIndexEntry>> watchNoteIndexEntriesByCategory(
      String categoryId) {
    return (select(noteIndexEntries)
          ..where((n) => n.categoryId.equals(categoryId))
          ..orderBy([
            (n) => OrderingTerm(
                expression: n.dateModified, mode: OrderingMode.desc)
          ]))
        .watch();
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
