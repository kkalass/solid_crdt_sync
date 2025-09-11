/// Business logic for managing notes with CRDT sync.
library;

import 'dart:math';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';
import '../models/note.dart';

/// Service for managing notes with local-first CRDT synchronization.
///
/// Provides a simple API for CRUD operations while handling RDF mapping
/// and sync automatically in the background.
class NotesService {
  final SolidCrdtSync _syncSystem;

  NotesService(this._syncSystem);

  /// Get all notes sorted by modification date (newest first)
  Future<List<Note>> getAllNotes() async {
    throw UnimplementedError('Get all notes not yet implemented');
    /*
    final notes = await _syncSystem.getAll<Note>();
    notes.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return notes;
    */
  }

  /// Get a specific note by ID
  Future<Note?> getNote(String id) async {
    throw UnimplementedError('Get note by ID not yet implemented');
    /*
    return await _syncSystem.get<Note>(id);
    */
  }

  /// Save a note (create or update)
  Future<void> saveNote(Note note) async {
    await _syncSystem.save(note);
  }

  /// Delete a note
  Future<void> deleteNote(String id) async {
    throw UnimplementedError('Delete note not yet implemented');
    /*
    await _syncSystem.delete<Note>(id);
    */
  }

  /// Create a new note with generated ID
  Note createNote({
    String title = '',
    String content = '',
    Set<String>? tags,
  }) {
    return Note(
      id: _generateId(),
      title: title,
      content: content,
      tags: tags ?? <String>{},
    );
  }

  /// Add a tag to a note
  Future<void> addTag(String noteId, String tag) async {
    final note = await getNote(noteId);
    if (note != null) {
      final updatedNote = note.copyWith(
        tags: {...note.tags, tag},
      );
      await saveNote(updatedNote);
    }
  }

  /// Remove a tag from a note
  Future<void> removeTag(String noteId, String tag) async {
    final note = await getNote(noteId);
    if (note != null) {
      final updatedTags = Set<String>.from(note.tags);
      updatedTags.remove(tag);
      final updatedNote = note.copyWith(tags: updatedTags);
      await saveNote(updatedNote);
    }
  }

  /// Get all unique tags across all notes
  Future<Set<String>> getAllTags() async {
    final notes = await getAllNotes();
    final allTags = <String>{};
    for (final note in notes) {
      allTags.addAll(note.tags);
    }
    return allTags;
  }

  /// Search notes by title or content
  Future<List<Note>> searchNotes(String query) async {
    final notes = await getAllNotes();
    final lowercaseQuery = query.toLowerCase();

    return notes.where((note) {
      return note.title.toLowerCase().contains(lowercaseQuery) ||
          note.content.toLowerCase().contains(lowercaseQuery) ||
          note.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  /// Get notes by category
  Future<List<Note>> getNotesByCategory(String categoryId) async {
    // TODO: This should use the GroupIndex by category efficiently
    final notes = await getAllNotes();
    return notes.where((note) => note.categoryId == categoryId).toList();
  }

  /// Get notes without a category (uncategorized)
  Future<List<Note>> getUncategorizedNotes() async {
    final notes = await getAllNotes();
    return notes.where((note) => note.categoryId == null).toList();
  }

  /// Assign a note to a category
  Future<void> assignNoteToCategory(String noteId, String? categoryId) async {
    final note = await getNote(noteId);
    if (note != null) {
      final updatedNote = note.copyWith(categoryId: categoryId);
      await saveNote(updatedNote);
    }
  }

  /// Generate a unique ID for new notes
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'note_${timestamp}_$random';
  }
}
