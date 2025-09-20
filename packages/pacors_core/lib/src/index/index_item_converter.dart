/// Controller for type-safe index item conversion.
library;

import 'package:rdf_core/rdf_core.dart';

import '../hydration_result.dart';
import 'index_config.dart';
import 'index_converter.dart';

/// Handles type-safe conversion of resource objects to index items.
///
/// This converter maintains the type information needed for proper conversion
/// without managing any streams - it's purely for conversion logic.
class IndexItemConverter<I> {
  final IndexConverter _converter;
  final IndexItem _indexItem;
  final IriTerm _resourceType;

  IndexItemConverter({
    required IndexConverter converter,
    required IndexItem indexItem,
    required IriTerm resourceType,
  })  : _converter = converter,
        _indexItem = indexItem,
        _resourceType = resourceType;

  /// Convert a resource hydration result to an index item hydration result
  HydrationResult<I> convertHydrationResult<T>(
      HydrationResult<T> resourceResult) {
    return _converter.convertHydrationResult<T, I>(
      _resourceType,
      resourceResult,
      _indexItem,
    );
  }
}
