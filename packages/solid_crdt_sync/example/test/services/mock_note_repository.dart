import 'package:flutter_test/flutter_test.dart';
import 'package:personal_notes_app/models/note.dart';
import 'package:personal_notes_app/models/note_index_entry.dart';
import 'package:personal_notes_app/storage/repositories.dart';

/// Mock repository for testing
class MockNoteRepository implements NoteRepository {
  final List<Note> savedNotes = [];
  final List<Note> storedNotes = [];
  final List<NoteIndexEntry> storedIndexEntries = [];
  
  @override
  Future<void> saveNote(Note note) async {
    savedNotes.add(note);
    // Simulate storing the note
    storedNotes.removeWhere((n) => n.id == note.id);
    storedNotes.add(note);
    
    // Also create/update corresponding index entry
    final indexEntry = _createIndexEntryFromNote(note);
    storedIndexEntries.removeWhere((e) => e.id == note.id);
    storedIndexEntries.add(indexEntry);
  }
  
  @override
  Future<List<Note>> getAllNotes() async => List.from(storedNotes);
  
  @override
  Future<Note?> getNote(String id) async {
    try {
      return storedNotes.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> deleteNote(String id) async {
    storedNotes.removeWhere((n) => n.id == id);
    storedIndexEntries.removeWhere((e) => e.id == id);
  }
  
  @override
  Future<List<Note>> getNotesByCategory(String categoryId) async {
    return storedNotes.where((n) => n.categoryId == categoryId).toList();
  }
  
  @override
  Future<List<Note>> getUncategorizedNotes() async {
    return storedNotes.where((n) => n.categoryId == null).toList();
  }

  // New NoteIndexEntry methods
  @override
  Future<List<NoteIndexEntry>> getAllNoteIndexEntries() async {
    return List.from(storedIndexEntries);
  }

  @override
  Future<List<NoteIndexEntry>> getNoteIndexEntriesByCategory(String categoryId) async {
    return storedIndexEntries.where((e) => e.categoryId == categoryId).toList();
  }

  @override
  Future<List<NoteIndexEntry>> getNoteIndexEntriesByGroup(String groupId) async {
    // In the mock, we simulate groupId as categoryId for simplicity
    return storedIndexEntries.where((e) => e.categoryId == groupId).toList();
  }

  @override
  void dispose() {}

  /// Helper method to create NoteIndexEntry from Note
  NoteIndexEntry _createIndexEntryFromNote(Note note) {
    return NoteIndexEntry(
      id: note.id,
      name: note.title,
      dateCreated: note.createdAt,
      dateModified: note.modifiedAt,
      keywords: note.tags,
      categoryId: note.categoryId,
    );
  }
}
