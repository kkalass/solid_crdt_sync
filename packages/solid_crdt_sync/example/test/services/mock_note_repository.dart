import 'package:flutter_test/flutter_test.dart';
import 'package:personal_notes_app/models/note.dart';
import 'package:personal_notes_app/storage/repositories.dart';

/// Mock repository for testing
class MockNoteRepository implements NoteRepository {
  final List<Note> savedNotes = [];
  final List<Note> storedNotes = [];
  
  @override
  Future<void> saveNote(Note note) async {
    savedNotes.add(note);
    // Simulate storing the note
    storedNotes.removeWhere((n) => n.id == note.id);
    storedNotes.add(note);
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
  }
  
  @override
  Future<List<Note>> getNotesByCategory(String categoryId) async {
    return storedNotes.where((n) => n.categoryId == categoryId).toList();
  }
  
  @override
  Future<List<Note>> getUncategorizedNotes() async {
    return storedNotes.where((n) => n.categoryId == null).toList();
  }
  

  @override
  void dispose() {}
}
