/// Handles emission of hydration results to both resource and index streams.
library;

import 'package:solid_crdt_sync_core/src/index/index_config.dart';

import '../config/resource_config.dart';
import '../hydration_result.dart';
import '../solid_crdt_sync.dart' show defaultIndexLocalName;
import 'hydration_stream_manager.dart';
import 'index_item_converter_registry.dart';
import 'type_local_name_key.dart';

/// Emits hydration results to appropriate streams with index conversion.
///
/// This component handles the complex logic of emitting hydration results
/// to both resource streams and associated index streams, performing
/// type-safe conversion using registered converters.
class HydrationEmitter {
  final HydrationStreamManager _streamManager;
  final IndexItemConverterRegistry _converterRegistry;

  HydrationEmitter({
    required HydrationStreamManager streamManager,
    required IndexItemConverterRegistry converterRegistry,
  })  : _streamManager = streamManager,
        _converterRegistry = converterRegistry;

  /// Emit a hydration result to resource and index streams
  void emit<T>(HydrationResult<T> result, ResourceConfig resourceConfig) {
    // Emit to resource stream
    _streamManager.emitToStream(
        TypeLocalNameKey(T, defaultIndexLocalName), result);

    // Emit to index streams
    for (final index in resourceConfig.indices) {
      if (index.item != null) {
        final itemIndexKey =
            TypeLocalNameKey(index.item!.itemType, index.localName);
        final converter = _converterRegistry.getConverter(itemIndexKey);
        if (converter != null) {
          final indexItemHydrationResult =
              converter.convertHydrationResult<T>(result);
          _streamManager.emitToStream(itemIndexKey, indexItemHydrationResult);
        }
      }
    }
  }
}
