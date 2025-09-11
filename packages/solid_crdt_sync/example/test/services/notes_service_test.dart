/// Tests for the NotesService class.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';
import 'package:personal_notes_app/models/note.dart';
import 'package:personal_notes_app/services/notes_service.dart';

/// Simple mock implementation for testing
class MockSolidCrdtSync implements SolidCrdtSync {
  final List<dynamic> savedObjects = [];

  @override
  Future<void> save<T>(T object) async {
    savedObjects.add(object);
  }

  @override
  Future<void> close() async {}

  @override
  Stream<T> dataUpdatesStream<T>() => Stream.empty();

  @override
  Stream<T> indexUpdatesStream<T>([String localName = '']) => Stream.empty();
}

void main() {
  group('NotesService', () {
    late MockSolidCrdtSync mockSyncSystem;
    late NotesService notesService;

    setUp(() {
      mockSyncSystem = MockSolidCrdtSync();
      notesService = NotesService(mockSyncSystem);
    });

    group('createNote', () {
      test('creates note with default values', () {
        final note = notesService.createNote();

        expect(note.title, equals(''));
        expect(note.content, equals(''));
        expect(note.tags, isEmpty);
        expect(note.id, isNotEmpty);
        expect(note.id, startsWith('note_'));
        expect(note.categoryId, isNull);
      });

      test('creates note with provided values', () {
        final tags = {'work', 'important'};
        final note = notesService.createNote(
          title: 'Meeting Notes',
          content: 'Discussed project timeline',
          tags: tags,
        );

        expect(note.title, equals('Meeting Notes'));
        expect(note.content, equals('Discussed project timeline'));
        expect(note.tags, equals(tags));
        expect(note.id, isNotEmpty);
        expect(note.id, startsWith('note_'));
      });

      test('generates unique IDs', () {
        final note1 = notesService.createNote(title: 'Note 1');
        final note2 = notesService.createNote(title: 'Note 2');

        expect(note1.id, isNot(equals(note2.id)));
      });
    });

    group('saveNote', () {
      test('calls syncSystem.save with note', () async {
        final note = Note(
          id: 'test_id',
          title: 'Test Note',
          content: 'Test content',
          tags: {'test'},
        );

        await notesService.saveNote(note);

        expect(mockSyncSystem.savedObjects, contains(note));
      });
    });

    group('ID generation', () {
      test('generates IDs with note prefix', () {
        final note = notesService.createNote();
        expect(note.id, startsWith('note_'));
      });

      test('generates different IDs for consecutive calls', () {
        final note1 = notesService.createNote();
        final note2 = notesService.createNote();

        expect(note1.id, isNot(equals(note2.id)));
      });
    });

    // Note: Tests for methods that depend on getAllNotes() cannot be fully
    // tested until the SolidCrdtSync API is implemented. These tests focus
    // on the logic that doesn't require the sync system to be functional.
  });
}
