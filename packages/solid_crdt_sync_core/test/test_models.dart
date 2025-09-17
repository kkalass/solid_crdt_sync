/// Test model classes for configuration validation tests.
library;

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';

/// Test vocabulary constants
class TestVocab {
  static const baseIri = 'https://test.example/vocab#';
  static const testDocument = IriTerm.prevalidated('${baseIri}TestDocument');
  static const testCategory = IriTerm.prevalidated('${baseIri}TestCategory');
  static const testNote = IriTerm.prevalidated('${baseIri}TestNote');
  static const note = IriTerm.prevalidated('${baseIri}Note');
  static const noteIndex = IriTerm.prevalidated('${baseIri}NoteIndex');
  static const sameTypeIri = IriTerm.prevalidated('${baseIri}SameType');
}

/// Test document model
class TestDocument {
  final String id;
  final String title;
  final String category;
  TestDocument({required this.id, required this.title, required this.category});
}

class TestDocumentGroupKey {
  final String category;
  TestDocumentGroupKey({required this.category});
}

/// Test category model
class TestCategory {
  final String id;
  final String name;

  TestCategory({required this.id, required this.name});
}

/// Test note model
class TestNote {
  final String id;
  final String content;

  TestNote({required this.id, required this.content});
}

/// Note model for testing IndexConverter
class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Note index item for testing IndexConverter
class NoteIndex {
  final String title;
  final DateTime createdAt;

  NoteIndex({
    required this.title,
    required this.createdAt,
  });
}

/// Two classes that would have the same RDF type IRI (for collision testing)
class ConflictingTypeA {
  final String id;
  ConflictingTypeA({required this.id});
}

class ConflictingTypeB {
  final String id;
  ConflictingTypeB({required this.id});
}

/// Type without any RDF mapping (for missing type IRI testing)
class UnmappedType {
  final String id;
  UnmappedType({required this.id});
}

/// Create a mock RDF mapper for testing type IRI resolution
RdfMapper createTestMapper() {
  // We'll use a real RdfMapper but override the getTypeIri function in tests
  return RdfMapper(
    registry: RdfMapperRegistry()
      ..registerMapper(MockResourceMapper<TestDocument>(TestVocab.testDocument))
      ..registerMapper(MockResourceMapper<TestCategory>(TestVocab.testCategory))
      ..registerMapper(MockResourceMapper<TestNote>(TestVocab.testNote))
      ..registerMapper(MockResourceMapper<Note>(TestVocab.note))
      ..registerMapper(MockResourceMapper<NoteIndex>(TestVocab.noteIndex))
      ..registerMapper(
          MockResourceMapper<ConflictingTypeA>(TestVocab.sameTypeIri))
      ..registerMapper(
          MockResourceMapper<ConflictingTypeB>(TestVocab.sameTypeIri))
    // Note: UnmappedType is intentionally not registered
    ,
    rdfCore: RdfCore.withStandardCodecs(),
  );
}

/// Mock function that simulates type IRI resolution for testing
IriTerm? mockGetTypeIri(Type dartType) {
  // Map of Dart types to their RDF type IRIs for testing
  const typeMap = <Type, IriTerm>{
    TestDocument: TestVocab.testDocument,
    TestCategory: TestVocab.testCategory,
    TestNote: TestVocab.testNote,
    ConflictingTypeA: TestVocab.sameTypeIri,
    ConflictingTypeB: TestVocab.sameTypeIri, // Same IRI for collision testing
    // UnmappedType is intentionally not included
  };

  return typeMap[dartType];
}

/// Mock resource serializer for testing
class MockResourceMapper<T> implements GlobalResourceMapper<T> {
  final IriTerm typeIri;
  MockResourceMapper(this.typeIri);

  @override
  T fromRdfResource(IriTerm term, DeserializationContext context) {
    throw UnimplementedError();
  }

  @override
  (IriTerm, Iterable<Triple>) toRdfResource(
      T value, SerializationContext context,
      {RdfSubject? parentSubject}) {
    throw UnimplementedError();
  }
}
