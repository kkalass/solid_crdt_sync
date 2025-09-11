/// Tests for the CategoriesService class.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';
import 'package:personal_notes_app/models/category.dart';
import 'package:personal_notes_app/services/categories_service.dart';

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

  @override
  Stream<T> remoteUpdates<T>() {
    // TODO: implement remoteUpdates
    throw UnimplementedError();
  }

  @override
  Future<void> saveWithCallback<T>(T object,
      {required void Function(T processedObject) onLocalUpdate}) {
    // TODO: implement saveWithCallback
    throw UnimplementedError();
  }
}
