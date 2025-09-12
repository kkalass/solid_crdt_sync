/// Business logic for managing notes with CRDT sync.
library;

import 'dart:math';
import '../models/note.dart';
import '../models/note_index_entry.dart';
import '../storage/repositories.dart';

/// Service for managing notes with local-first CRDT synchronization.
///
/// This service demonstrates the add-on architecture where:
/// - Repository handles all local queries, operations AND sync coordination
/// - Service focuses purely on business logic
/// - Repository is "sync-aware storage" that handles CRDT processing automatically
class NotesService {
  final NoteRepository _noteRepository;

  NotesService(this._noteRepository);

  /// Get all notes sorted by modification date (newest first)
  Future<List<Note>> getAllNotes() async {
    // Repository handles queries and returns sorted results
    return await _noteRepository.getAllNotes();
  }

  /// Get all note index entries for lightweight browsing
  Future<List<NoteIndexEntry>> getAllNoteIndexEntries() async {
    return await _noteRepository.getAllNoteIndexEntries();
  }

  /// Get note index entries by category for browsing
  Future<List<NoteIndexEntry>> getNoteIndexEntriesByCategory(String categoryId) async {
    return await _noteRepository.getNoteIndexEntriesByCategory(categoryId);
  }

  /// Get note index entries by group for browsing
  Future<List<NoteIndexEntry>> getNoteIndexEntriesByGroup(String groupId) async {
    return await _noteRepository.getNoteIndexEntriesByGroup(groupId);
  }

  /// Get a specific note by ID
  Future<Note?> getNote(String id) async {
    return await _noteRepository.getNote(id);
  }

  /// Save a note (create or update)
  Future<void> saveNote(Note note) async {
    // Repository handles sync coordination automatically
    await _noteRepository.saveNote(note);
  }

  /// Delete a note
  Future<void> deleteNote(String id) async {
    // Repository handles deletion (including future CRDT deletion)
    await _noteRepository.deleteNote(id);
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
    return await _noteRepository.getNotesByCategory(categoryId);
  }

  /// Get notes without a category (uncategorized)
  Future<List<Note>> getUncategorizedNotes() async {
    return await _noteRepository.getUncategorizedNotes();
  }

  /// Assign a note to a category
  Future<void> assignNoteToCategory(String noteId, String? categoryId) async {
    final note = await getNote(noteId);
    if (note != null) {
      final updatedNote = note.copyWith(categoryId: categoryId);
      await saveNote(updatedNote);
    }
  }

  /// Load note index entries for a specific group (category-based grouping)
  /// This is used when navigating to a category that might not be indexed yet
  Future<void> ensureGroupIndexLoaded(String groupId) async {
    // TODO: Call sync system to ensure the group's index is loaded
    // For now, this is a placeholder for the SolidCrdtSync API we discussed
    // In the final implementation, this would call something like:
    // await syncSystem.loadGroupIndex<NoteIndexEntry>(groupId);
    
    // Placeholder: just log the request for now
    print('Ensuring group index is loaded for group: $groupId');
  }

  /// Load full data for a group (prefetch strategy)
  /// This is used when the app determines a group will be heavily accessed
  Future<void> prefetchGroupData(String groupId) async {
    // TODO: Call sync system to prefetch all notes in the group
    // For now, this is a placeholder for the SolidCrdtSync API we discussed
    // In the final implementation, this would call something like:
    // await syncSystem.loadGroupData<Note>(groupId);
    
    // Placeholder: just log the request for now
    print('Prefetching full data for group: $groupId');
  }

  /// Smart navigation helper: ensures a category's notes are available for browsing
  /// Returns true if index entries are available, false if group needs loading
  Future<bool> ensureCategoryAvailable(String categoryId) async {
    // First, ensure the group index is loaded
    await ensureGroupIndexLoaded(categoryId);
    
    // Check if we have index entries for this category
    final indexEntries = await getNoteIndexEntriesByCategory(categoryId);
    
    // Return whether we found any entries (true means ready for browsing)
    return indexEntries.isNotEmpty;
  }

  /// Get notes by category with automatic group loading
  /// This method ensures the category group is available before returning results
  Future<List<NoteIndexEntry>> getNoteIndexEntriesByCategoryWithLoading(String categoryId) async {
    // Ensure the category group is loaded
    await ensureCategoryAvailable(categoryId);
    
    // Return the index entries (may be empty if the category truly has no notes)
    return await getNoteIndexEntriesByCategory(categoryId);
  }

  /// Generate a unique ID for new notes
  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'note_${timestamp}_$random';
  }

  // Note: No dispose method needed - repository handles its own cleanup
}
