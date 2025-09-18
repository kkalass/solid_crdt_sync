import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:rdf_vocabularies_schema/schema.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';
import 'package:solid_crdt_sync_core/src/index/index_converter.dart';
import 'package:solid_crdt_sync_core/src/vocabulary/idx_vocab.dart';
import 'package:test/test.dart';

/// Test vocabulary for our test models
class TestVocab {
  static const baseIri = 'https://example.org/test#';
  static const TestNote = IriTerm.prevalidated('${baseIri}TestNote');
}

/// Test Note model matching the example structure
class TestNote {
  final String id;
  final String title;
  final String content;
  final Set<String> tags;
  final DateTime createdAt;
  final DateTime modifiedAt;

  TestNote({
    required this.id,
    required this.title,
    required this.content,
    Set<String>? tags,
    DateTime? createdAt,
    DateTime? modifiedAt,
  })  : tags = tags ?? <String>{},
        createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();
}

/// Test Note Index Entry matching the example structure
class TestNoteIndexEntry {
  final String id;
  final String name;
  final DateTime dateCreated;
  final DateTime dateModified;
  final Set<String> keywords;

  const TestNoteIndexEntry({
    required this.id,
    required this.name,
    required this.dateCreated,
    required this.dateModified,
    this.keywords = const {},
  });
}

/// Test mapper for TestNote (similar to generated NoteMapper)
class TestNoteMapper implements GlobalResourceMapper<TestNote> {
  const TestNoteMapper();

  @override
  IriTerm get typeIri => TestVocab.TestNote;

  @override
  TestNote fromRdfResource(IriTerm subject, DeserializationContext context) {
    final reader = context.reader(subject);

    return TestNote(
      id: subject.iri,
      title: reader.require(SchemaNoteDigitalDocument.name),
      content: reader.require(SchemaNoteDigitalDocument.text),
      tags: reader.requireCollection<Set<String>, String>(
        SchemaNoteDigitalDocument.keywords,
        UnorderedItemsSetMapper.new,
      ),
      createdAt: reader.require(SchemaNoteDigitalDocument.dateCreated),
      modifiedAt: reader.require(SchemaNoteDigitalDocument.dateModified),
    );
  }

  @override
  (IriTerm, Iterable<Triple>) toRdfResource(
    TestNote resource,
    SerializationContext context, {
    RdfSubject? parentSubject,
  }) {
    final subject = IriTerm(resource.id);

    return context
        .resourceBuilder(subject)
        .addValue(SchemaNoteDigitalDocument.name, resource.title)
        .addValue(SchemaNoteDigitalDocument.text, resource.content)
        .addCollection<Set<String>, String>(
          SchemaNoteDigitalDocument.keywords,
          resource.tags,
          UnorderedItemsSetMapper.new,
        )
        .addValue(SchemaNoteDigitalDocument.dateCreated, resource.createdAt)
        .addValue(SchemaNoteDigitalDocument.dateModified, resource.modifiedAt)
        .build();
  }
}

/// Test mapper for TestNoteIndexEntry (similar to generated NoteIndexEntryMapper)
class TestNoteIndexEntryMapper
    implements LocalResourceMapper<TestNoteIndexEntry> {
  const TestNoteIndexEntryMapper();

  @override
  IriTerm? get typeIri => null;

  @override
  TestNoteIndexEntry fromRdfResource(
    BlankNodeTerm subject,
    DeserializationContext context,
  ) {
    final reader = context.reader(subject);

    return TestNoteIndexEntry(
      id: reader.require(IdxVocab.resource,
          deserializer: const IriFullMapper()),
      name: reader.require(SchemaNoteDigitalDocument.name),
      dateCreated: reader.require(SchemaNoteDigitalDocument.dateCreated),
      dateModified: reader.require(SchemaNoteDigitalDocument.dateModified),
      keywords: reader.requireCollection<Set<String>, String>(
        SchemaNoteDigitalDocument.keywords,
        UnorderedItemsSetMapper.new,
      ),
    );
  }

  @override
  (BlankNodeTerm, Iterable<Triple>) toRdfResource(
    TestNoteIndexEntry resource,
    SerializationContext context, {
    RdfSubject? parentSubject,
  }) {
    final subject = BlankNodeTerm();

    return context
        .resourceBuilder(subject)
        .addValue(IdxVocab.resource, resource.id,
            serializer: const IriFullMapper())
        .addValue(SchemaNoteDigitalDocument.name, resource.name)
        .addValue(SchemaNoteDigitalDocument.dateCreated, resource.dateCreated)
        .addValue(SchemaNoteDigitalDocument.dateModified, resource.dateModified)
        .addCollection<Set<String>, String>(
          SchemaNoteDigitalDocument.keywords,
          resource.keywords,
          UnorderedItemsSetMapper.new,
        )
        .build();
  }
}

void main() {
  group('IndexConverter', () {
    late RdfMapper mapper;
    late IndexConverter converter;

    setUp(() {
      // Create RDF mapper with our test mappers registered
      mapper = RdfMapper(
        registry: RdfMapperRegistry()
          ..registerMapper(const TestNoteMapper())
          ..registerMapper(const TestNoteIndexEntryMapper()),
        rdfCore: RdfCore.withStandardCodecs(),
      );

      converter = IndexConverter(mapper);
    });

    test('constructor creates instance with required dependencies', () {
      expect(converter, isNotNull);
      expect(converter, isA<IndexConverter>());
    });

    test('converts full resource to index item with filtered properties',
        () async {
      // Create a full note with all properties
      final note = TestNote(
        id: 'https://example.org/notes/test-note',
        title: 'Test Note',
        content: 'This is the full content of the note',
        tags: {'work', 'important'},
        createdAt: DateTime.parse('2023-01-01T10:00:00Z'),
        modifiedAt: DateTime.parse('2023-01-02T15:30:00Z'),
      );

      // Define index item configuration with only selected properties
      final indexItem = IndexItem(
        TestNoteIndexEntry,
        {
          IdxVocab.resource,
          SchemaNoteDigitalDocument.name,
          SchemaNoteDigitalDocument.dateCreated,
          SchemaNoteDigitalDocument.dateModified,
          SchemaNoteDigitalDocument.keywords,
        },
      );

      // Convert to index item
      final indexEntry =
          await converter.convertToIndexItem<TestNote, TestNoteIndexEntry>(
        TestVocab.TestNote,
        note,
        indexItem,
      );

      // Verify conversion
      expect(indexEntry.id, equals('https://example.org/notes/test-note'));
      expect(indexEntry.name, equals('Test Note'));
      expect(indexEntry.dateCreated,
          equals(DateTime.parse('2023-01-01T10:00:00Z')));
      expect(indexEntry.dateModified,
          equals(DateTime.parse('2023-01-02T15:30:00Z')));
      expect(indexEntry.keywords, equals({'work', 'important'}));

      // Note: content property should be filtered out (not in index item properties)
    });

    test('handles note with minimal properties', () async {
      final note = TestNote(
        id: 'https://example.org/notes/minimal',
        title: 'Minimal Note',
        content: '',
        tags: {},
        createdAt: DateTime.parse('2023-01-01T10:00:00Z'),
        modifiedAt: DateTime.parse('2023-01-01T10:00:00Z'),
      );

      final indexItem = IndexItem(
        TestNoteIndexEntry,
        {
          IdxVocab.resource,
          SchemaNoteDigitalDocument.name,
          SchemaNoteDigitalDocument.dateCreated,
          SchemaNoteDigitalDocument.dateModified,
          SchemaNoteDigitalDocument.keywords,
        },
      );

      final indexEntry =
          await converter.convertToIndexItem<TestNote, TestNoteIndexEntry>(
        TestVocab.TestNote,
        note,
        indexItem,
      );

      expect(indexEntry.id, equals('https://example.org/notes/minimal'));
      expect(indexEntry.name, equals('Minimal Note'));
      expect(indexEntry.keywords, isEmpty);
    });

    test('includes idx:resource type in converted RDF', () async {
      final note = TestNote(
        id: 'https://example.org/notes/test',
        title: 'Test',
        content: 'Content',
        createdAt: DateTime.now(),
      );

      final indexItem = IndexItem(
        TestNoteIndexEntry,
        {
          IdxVocab.resource,
          SchemaNoteDigitalDocument.name,
          SchemaNoteDigitalDocument.dateCreated,
          SchemaNoteDigitalDocument.dateModified,
          SchemaNoteDigitalDocument.keywords,
        },
      );

      final indexEntry =
          await converter.convertToIndexItem<TestNote, TestNoteIndexEntry>(
        TestVocab.TestNote,
        note,
        indexItem,
      );

      // The idx:resource should be automatically added by the converter
      // and properly mapped by our TestNoteIndexEntryMapper
      expect(indexEntry.id, equals('https://example.org/notes/test'));
    });
  });
}
