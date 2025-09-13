/// Manager for hydration stream controllers.
library;

import 'dart:async';
import '../hydration_result.dart';
import 'type_local_name_key.dart';

/// Manages stream controllers for hydration updates.
///
/// Handles creation, storage, and emission for broadcast streams
/// keyed by (Type, localName) pairs.
class HydrationStreamManager {
  final Map<TypeLocalNameKey, StreamController> _controllers = {};

  /// Get or create a stream controller for the given type and local name
  StreamController<HydrationResult<T>> getOrCreateController<T>(String localName) {
    final key = TypeLocalNameKey(T, localName);
    if (!_controllers.containsKey(key)) {
      _controllers[key] = StreamController<HydrationResult<T>>.broadcast();
    }
    return _controllers[key]! as StreamController<HydrationResult<T>>;
  }

  /// Emit a result to the stream identified by the given key
  void emitToStream<T>(TypeLocalNameKey key, HydrationResult<T> result) {
    final controller = _controllers[key];
    if (controller == null) {
      throw StateError('No stream controller exists for key $key. This indicates a programming error - ensure the stream is created before emitting to it.');
    }
    Future.microtask(() => controller.add(result));
  }

  /// Close all stream controllers and free resources
  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
  }
}