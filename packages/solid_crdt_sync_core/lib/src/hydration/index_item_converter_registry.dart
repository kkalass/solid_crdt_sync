/// Registry for managing IndexItemConverter instances.
library;

import '../index/index_item_converter.dart';
import 'type_local_name_key.dart';

/// Registry for storing and retrieving IndexItemConverter instances.
///
/// This registry provides a simple storage mechanism for IndexItemConverter
/// instances keyed by (Type, localName) pairs. It does not handle creation
/// logic - that responsibility belongs to the components that have access
/// to configuration and dependencies.
class IndexItemConverterRegistry {
  final Map<TypeLocalNameKey, IndexItemConverter> _converters = {};

  /// Register a converter for the given key
  void registerConverter<T>(
      TypeLocalNameKey key, IndexItemConverter<T> converter) {
    if (_converters.containsKey(key)) {
      throw ArgumentError(
          'IndexItemConverter for key $key is already registered');
    }
    _converters[key] = converter;
  }

  /// Get a converter for the given key, or null if not found
  IndexItemConverter<T>? getConverter<T>(TypeLocalNameKey key) {
    final converter = _converters[key];
    return converter as IndexItemConverter<T>?;
  }
}
