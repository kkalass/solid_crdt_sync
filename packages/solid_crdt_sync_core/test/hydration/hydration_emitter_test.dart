import 'dart:async';
import 'package:test/test.dart';
import 'package:solid_crdt_sync_core/src/hydration/hydration_emitter.dart';
import 'package:solid_crdt_sync_core/src/hydration/hydration_stream_manager.dart';
import 'package:solid_crdt_sync_core/src/hydration/index_item_converter_registry.dart';
import 'package:solid_crdt_sync_core/src/hydration/type_local_name_key.dart';
import 'package:solid_crdt_sync_core/src/hydration_result.dart';
import 'package:solid_crdt_sync_core/src/config/resource_config.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';
import 'package:solid_crdt_sync_core/src/index/index_item_converter.dart';
import 'package:rdf_core/rdf_core.dart';

// Test data models
class TestNote {
  final String title;
  final String content;
  TestNote(this.title, this.content);
  
  @override
  String toString() => 'TestNote($title, $content)';
}

class TestNoteIndex {
  final String title;
  TestNoteIndex(this.title);
  
  @override
  String toString() => 'TestNoteIndex($title)';
}

// Test implementations
class TestHydrationStreamManager implements HydrationStreamManager {
  final List<String> emittedKeys = [];
  final List<dynamic> emittedResults = [];
  
  @override
  void emitToStream<T>(TypeLocalNameKey key, HydrationResult<T> result) {
    emittedKeys.add(key.toString());
    emittedResults.add(result);
  }
  
  @override
  StreamController<HydrationResult<T>> getOrCreateController<T>(String localName) =>
      throw UnimplementedError('Not needed for emission tests');
      
  @override
  Future<void> close() async {}
  
  void clear() {
    emittedKeys.clear();
    emittedResults.clear();
  }
}

class TestIndexItemConverterRegistry implements IndexItemConverterRegistry {
  final Map<TypeLocalNameKey, dynamic> _converters = {};
  
  @override
  void registerConverter<T>(TypeLocalNameKey key, converter) {
    _converters[key] = converter;
  }
  
  @override
  IndexItemConverter<T>? getConverter<T>(TypeLocalNameKey key) {
    return _converters[key] as IndexItemConverter<T>?;
  }
}

class TestIndexItemConverter implements IndexItemConverter<TestNoteIndex> {
  @override
  HydrationResult<TestNoteIndex> convertHydrationResult<T>(HydrationResult<T> result) {
    // Convert TestNote items to TestNoteIndex items
    final indexItems = result.items.cast<TestNote>()
        .map((note) => TestNoteIndex(note.title))
        .toList();
    final deletedIndexItems = result.deletedItems.cast<TestNote>()
        .map((note) => TestNoteIndex(note.title))
        .toList();
    
    return HydrationResult<TestNoteIndex>(
      items: indexItems,
      deletedItems: deletedIndexItems,
      originalCursor: result.originalCursor,
      nextCursor: result.nextCursor,
      hasMore: result.hasMore,
    );
  }
}

void main() {
  group('HydrationEmitter', () {
    late TestHydrationStreamManager streamManager;
    late TestIndexItemConverterRegistry converterRegistry;
    late HydrationEmitter emitter;

    setUp(() {
      streamManager = TestHydrationStreamManager();
      converterRegistry = TestIndexItemConverterRegistry();
      emitter = HydrationEmitter(
        streamManager: streamManager,
        converterRegistry: converterRegistry,
      );
    });

    test('should emit to resource stream only when no indices', () {
      // Config without indices
      final config = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/mapping'),
        indices: [],
      );

      final result = HydrationResult<TestNote>(
        items: [TestNote('Test', 'Content')],
        deletedItems: [],
        originalCursor: 'cursor1',
        nextCursor: 'cursor2',
        hasMore: false,
      );

      emitter.emit(result, config);

      // Should emit only to resource stream
      expect(streamManager.emittedKeys, hasLength(1));
      expect(streamManager.emittedKeys.first, contains('TestNote'));
      expect(streamManager.emittedKeys.first, contains('default'));
      expect(streamManager.emittedResults.first, equals(result));
    });

    test('should emit to both resource and index streams', () {
      // Set up index configuration
      final indexItem = IndexItem(TestNoteIndex, {IriTerm('http://example.org/title')});
      final index = FullIndex(
        TestNote,
        localName: 'title-index',
        item: indexItem,
      );
      
      final config = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/mapping'),
        indices: [index],
      );

      // Register converter
      final key = TypeLocalNameKey(TestNoteIndex, 'title-index');
      converterRegistry.registerConverter(key, TestIndexItemConverter());

      final result = HydrationResult<TestNote>(
        items: [TestNote('Test Title', 'Content')],
        deletedItems: [],
        originalCursor: 'cursor1',
        nextCursor: 'cursor2',
        hasMore: false,
      );

      emitter.emit(result, config);

      // Should emit to both streams
      expect(streamManager.emittedKeys, hasLength(2));
      
      // Check resource stream emission
      expect(streamManager.emittedKeys[0], contains('TestNote'));
      expect(streamManager.emittedKeys[0], contains('default'));
      expect(streamManager.emittedResults[0], equals(result));
      
      // Check index stream emission
      expect(streamManager.emittedKeys[1], contains('TestNoteIndex'));
      expect(streamManager.emittedKeys[1], contains('title-index'));
      
      final indexResult = streamManager.emittedResults[1] as HydrationResult<TestNoteIndex>;
      expect(indexResult.items, hasLength(1));
      expect(indexResult.items.first.title, equals('Test Title'));
      expect(indexResult.originalCursor, equals('cursor1'));
      expect(indexResult.nextCursor, equals('cursor2'));
    });

    test('should handle deletions in index conversion', () {
      final indexItem = IndexItem(TestNoteIndex, {IriTerm('http://example.org/title')});
      final index = FullIndex(
        TestNote,
        localName: 'title-index',
        item: indexItem,
      );
      
      final config = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/mapping'),
        indices: [index],
      );

      final key = TypeLocalNameKey(TestNoteIndex, 'title-index');
      converterRegistry.registerConverter(key, TestIndexItemConverter());

      final result = HydrationResult<TestNote>(
        items: [],
        deletedItems: [TestNote('Deleted Title', 'Deleted Content')],
        originalCursor: 'cursor1',
        nextCursor: 'cursor2',
        hasMore: false,
      );

      emitter.emit(result, config);

      // Check index deletion conversion
      expect(streamManager.emittedKeys, hasLength(2));
      final indexResult = streamManager.emittedResults[1] as HydrationResult<TestNoteIndex>;
      expect(indexResult.deletedItems, hasLength(1));
      expect(indexResult.deletedItems.first.title, equals('Deleted Title'));
      expect(indexResult.items, isEmpty);
    });

    test('should skip index emission when converter not registered', () {
      final indexItem = IndexItem(String, {IriTerm('http://example.org/title')});
      final index = FullIndex(
        TestNote,
        localName: 'unregistered-index',
        item: indexItem,
      );
      
      final config = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/mapping'),
        indices: [index],
      );

      final result = HydrationResult<TestNote>(
        items: [TestNote('Test', 'Content')],
        deletedItems: [],
        originalCursor: null,
        nextCursor: null,
        hasMore: false,
      );

      emitter.emit(result, config);

      // Should emit only to resource stream (no converter for index)
      expect(streamManager.emittedKeys, hasLength(1));
      expect(streamManager.emittedKeys.first, contains('TestNote'));
      expect(streamManager.emittedKeys.first, contains('default'));
    });

    test('should handle index with null item', () {
      final index = FullIndex(
        TestNote,
        localName: 'null-item-index',
        item: null,
      );
      
      final config = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/mapping'),
        indices: [index],
      );

      final result = HydrationResult<TestNote>(
        items: [TestNote('Test', 'Content')],
        deletedItems: [],
        originalCursor: null,
        nextCursor: null,
        hasMore: false,
      );

      // Should not throw and should only emit to resource stream
      expect(() => emitter.emit(result, config), returnsNormally);
      expect(streamManager.emittedKeys, hasLength(1));
    });

    test('should handle multiple indices', () {
      final titleIndexItem = IndexItem(TestNoteIndex, {IriTerm('http://example.org/title')});
      final contentIndexItem = IndexItem(String, {IriTerm('http://example.org/content')});
      
      final titleIndex = FullIndex(
        TestNote,
        localName: 'title-index',
        item: titleIndexItem,
      );
      
      final contentIndex = FullIndex(
        TestNote,
        localName: 'content-index',
        item: contentIndexItem,
      );
      
      final config = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/mapping'),
        indices: [titleIndex, contentIndex],
      );

      // Register only title converter
      final titleKey = TypeLocalNameKey(TestNoteIndex, 'title-index');
      converterRegistry.registerConverter(titleKey, TestIndexItemConverter());
      // contentIndex converter not registered

      final result = HydrationResult<TestNote>(
        items: [TestNote('Test Title', 'Test Content')],
        deletedItems: [],
        originalCursor: null,
        nextCursor: null,
        hasMore: false,
      );

      emitter.emit(result, config);

      // Should emit to resource stream + title index only
      expect(streamManager.emittedKeys, hasLength(2));
      expect(streamManager.emittedKeys[0], contains('TestNote'));
      expect(streamManager.emittedKeys[1], contains('TestNoteIndex'));
      expect(streamManager.emittedKeys[1], contains('title-index'));
    });

    test('should preserve all HydrationResult fields in conversion', () {
      final indexItem = IndexItem(TestNoteIndex, {IriTerm('http://example.org/title')});
      final index = FullIndex(
        TestNote,
        localName: 'title-index',
        item: indexItem,
      );
      
      final config = ResourceConfig(
        type: TestNote,
        crdtMapping: Uri.parse('http://example.org/mapping'),
        indices: [index],
      );

      final key = TypeLocalNameKey(TestNoteIndex, 'title-index');
      converterRegistry.registerConverter(key, TestIndexItemConverter());

      final result = HydrationResult<TestNote>(
        items: [TestNote('Item', 'Content')],
        deletedItems: [TestNote('Deleted', 'Content')],
        originalCursor: 'original-cursor',
        nextCursor: 'next-cursor',
        hasMore: true,
      );

      emitter.emit(result, config);

      final indexResult = streamManager.emittedResults[1] as HydrationResult<TestNoteIndex>;
      expect(indexResult.originalCursor, equals('original-cursor'));
      expect(indexResult.nextCursor, equals('next-cursor'));
      expect(indexResult.hasMore, equals(true));
      expect(indexResult.items, hasLength(1));
      expect(indexResult.deletedItems, hasLength(1));
    });
  });
}