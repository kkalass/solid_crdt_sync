import 'package:test/test.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:solid_crdt_sync_core/src/config/resource_config.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';

// Test model classes
class TestNote {
  final String title;
  final String content;
  TestNote(this.title, this.content);
}

class TestNoteIndex {
  final String title;
  TestNoteIndex(this.title);
}

class TestContact {
  final String name;
  final String email;
  TestContact(this.name, this.email);
}

class TestContactIndex {
  final String name;
  TestContactIndex(this.name);
}

void main() {
  group('SyncConfig.findIndexConfigForType', () {
    late SyncConfig config;
    late ResourceConfig noteResourceConfig;
    late ResourceConfig contactResourceConfig;
    late FullIndex noteIndex;
    late FullIndex contactIndex;

    setUp(() {
      // Set up test configurations
      final noteIndexItem =
          IndexItem(TestNoteIndex, {IriTerm('http://example.org/title')});
      noteIndex = FullIndex(
        TestNote,
        localName: 'note-title-index',
        item: noteIndexItem,
      );

      final contactIndexItem =
          IndexItem(TestContactIndex, {IriTerm('http://example.org/name')});
      contactIndex = FullIndex(
        TestContact,
        localName: 'contact-name-index',
        item: contactIndexItem,
      );

      noteResourceConfig = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/note-mapping'),
        indices: [noteIndex],
      );

      contactResourceConfig = ResourceConfig(
        type: TestContact,
        crdtMapping: Uri.parse('http://example.org/contact-mapping'),
        indices: [contactIndex],
      );

      config = SyncConfig(
        resources: [noteResourceConfig, contactResourceConfig],
      );
    });

    test('should find correct index config for matching type and local name',
        () {
      final result =
          config.findIndexConfigForType<TestNoteIndex>('note-title-index');

      expect(result, isNotNull);
      final (resourceConfig, indexConfig) = result!;
      expect(resourceConfig, equals(noteResourceConfig));
      expect(indexConfig, equals(noteIndex));
    });

    test('should find correct index config for different resource type', () {
      final result =
          config.findIndexConfigForType<TestContactIndex>('contact-name-index');

      expect(result, isNotNull);
      final (resourceConfig, indexConfig) = result!;
      expect(resourceConfig, equals(contactResourceConfig));
      expect(indexConfig, equals(contactIndex));
    });

    test('should return null for non-existent type', () {
      final result = config.findIndexConfigForType<String>('note-title-index');

      expect(result, isNull);
    });

    test('should return null for non-existent local name', () {
      final result =
          config.findIndexConfigForType<TestNoteIndex>('non-existent-index');

      expect(result, isNull);
    });

    test('should return null for mismatched type and local name combination',
        () {
      // Wrong type for contact index
      final result =
          config.findIndexConfigForType<TestNoteIndex>('contact-name-index');

      expect(result, isNull);
    });

    test('should handle resource with multiple indices', () {
      // Add another index to the note resource
      final noteTagsIndexItem =
          IndexItem(String, {IriTerm('http://example.org/tags')});
      final noteTagsIndex = FullIndex(
        TestNote,
        localName: 'note-tags-index',
        item: noteTagsIndexItem,
      );

      final multiIndexResourceConfig = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/note-mapping'),
        indices: [noteIndex, noteTagsIndex],
      );

      final multiIndexConfig = SyncConfig(
        resources: [multiIndexResourceConfig, contactResourceConfig],
      );

      // Should find the correct index even with multiple indices
      final noteIndexResult = multiIndexConfig
          .findIndexConfigForType<TestNoteIndex>('note-title-index');
      expect(noteIndexResult, isNotNull);
      expect(noteIndexResult!.$2, equals(noteIndex));

      final tagsIndexResult =
          multiIndexConfig.findIndexConfigForType<String>('note-tags-index');
      expect(tagsIndexResult, isNotNull);
      expect(tagsIndexResult!.$2, equals(noteTagsIndex));
    });

    test('should handle resource with no indices', () {
      final noIndexResourceConfig = ResourceConfig(
        type: String,
        crdtMapping: Uri.parse('http://example.org/string-mapping'),
        indices: [], // No indices
      );

      final noIndexConfig = SyncConfig(
        resources: [noIndexResourceConfig, noteResourceConfig],
      );

      // Should still find note index
      final noteResult = noIndexConfig
          .findIndexConfigForType<TestNoteIndex>('note-title-index');
      expect(noteResult, isNotNull);

      // Should not find anything for the resource with no indices
      final stringResult =
          noIndexConfig.findIndexConfigForType<String>('any-index');
      expect(stringResult, isNull);
    });

    test('should handle index with null item', () {
      final nullItemIndex = FullIndex(
        TestNote,
        localName: 'null-item-index',
        item: null, // No item specified
      );

      final nullItemResourceConfig = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/note-mapping'),
        indices: [nullItemIndex],
      );

      final nullItemConfig = SyncConfig(
        resources: [nullItemResourceConfig],
      );

      // Should not find anything since item is null
      final result = nullItemConfig
          .findIndexConfigForType<TestNoteIndex>('null-item-index');
      expect(result, isNull);
    });

    test('should handle empty configuration', () {
      final emptyConfig = SyncConfig(resources: []);

      final result =
          emptyConfig.findIndexConfigForType<TestNoteIndex>('any-index');
      expect(result, isNull);
    });

    test('should distinguish between different local names for same type', () {
      // Create two indices with same item type but different local names
      final noteIndexItem1 =
          IndexItem(TestNoteIndex, {IriTerm('http://example.org/title')});
      final noteIndexItem2 =
          IndexItem(TestNoteIndex, {IriTerm('http://example.org/content')});

      final noteIndex1 = FullIndex(
        TestNote,
        localName: 'note-title-index',
        item: noteIndexItem1,
      );

      final noteIndex2 = FullIndex(
        TestNote,
        localName: 'note-content-index',
        item: noteIndexItem2,
      );

      final multiSameTypeResourceConfig = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/note-mapping'),
        indices: [noteIndex1, noteIndex2],
      );

      final multiSameTypeConfig = SyncConfig(
        resources: [multiSameTypeResourceConfig],
      );

      // Should find the correct index based on local name
      final titleResult = multiSameTypeConfig
          .findIndexConfigForType<TestNoteIndex>('note-title-index');
      expect(titleResult, isNotNull);
      expect(titleResult!.$2, equals(noteIndex1));

      final contentResult = multiSameTypeConfig
          .findIndexConfigForType<TestNoteIndex>('note-content-index');
      expect(contentResult, isNotNull);
      expect(contentResult!.$2, equals(noteIndex2));
    });
  });
}
