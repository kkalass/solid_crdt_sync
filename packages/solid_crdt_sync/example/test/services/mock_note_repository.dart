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
  Stream<List<Note>> getAllNotes() => Stream.value(List.from(storedNotes));
  
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
  Stream<List<Note>> getNotesByCategory(String categoryId) {
    return Stream.value(storedNotes.where((n) => n.categoryId == categoryId).toList());
  }
  
  @override
  Stream<List<Note>> getUncategorizedNotes() {
    return Stream.value(storedNotes.where((n) => n.categoryId == null).toList());
  }

  // Reactive NoteIndexEntry methods
  @override
  Stream<List<NoteIndexEntry>> watchAllNoteIndexEntries() {
    return Stream.value(List.from(storedIndexEntries));
  }

  @override
  Stream<List<NoteIndexEntry>> watchNoteIndexEntriesByCategory(String categoryId) {
    return Stream.value(storedIndexEntries.where((e) => e.categoryId == categoryId).toList());
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
