/// Utility for converting resources to index items via RDF transformation.
library;

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:rdf_vocabularies_core/rdf.dart';

import '../hydration_result.dart';
import '../vocabulary/idx_vocab.dart';
import 'index_config.dart';

/// Converts resource objects to index items using RDF mapping.
///
/// This utility handles the complex transformation of full resource objects
/// into lightweight index items by:
/// 1. Encoding the resource to RDF
/// 2. Filtering to only the properties specified in the IndexItem
/// 3. Decoding back to the target index item type
///
/// This conversion is critical for maintaining performant indices while
/// preserving semantic correctness of the RDF representation.
class IndexConverter {
  final RdfMapper _mapper;

  /// Creates an IndexConverter with the given mapper and resource type cache.
  const IndexConverter(this._mapper);

  /// Convert a resource to an index item using RDF transformation.
  ///
  /// Takes a resource object of type [T] and converts it to an index item
  /// of type [I] by filtering the RDF representation to only include
  /// the properties specified in [indexItem].
  ///
  /// Returns the converted index item, or throws if the conversion fails.
  ///
  /// The conversion process:
  /// 1. Encode resource to RDF using the configured mapper
  /// 2. Find the primary subject (typed with the resource type)
  /// 3. Filter triples to only those with predicates in indexItem.properties
  /// 4. Create new RDF graph with filtered triples plus idx:resource type
  /// 5. Decode the filtered RDF back to the index item type
  I convertToIndexItem<T, I>(
      IriTerm resourceType, T resource, IndexItem indexItem) {
    // Convert resource to RDF
    final rdfResource = _mapper.graph.encodeObject(resource);

    // Find the primary subject for this resource type
    final subject = rdfResource
        .findTriples(predicate: Rdf.type, object: resourceType)
        .map((t) => t.subject)
        .toSet()
        .single;

    // Get all triples for this subject
    final subjectTriples = rdfResource.findTriples(subject: subject);

    // Create new subject for the index item
    final BlankNodeTerm indexItemSubject = BlankNodeTerm();

    // Filter to only the properties specified in the index item config
    final indexItemTriples = subjectTriples
        .where((t) => indexItem.properties.contains(t.predicate))
        .map((t) => Triple(indexItemSubject, t.predicate, t.object))
        .toList()
      ..add(Triple(indexItemSubject, IdxVocab.resource, subject));

    // Convert filtered RDF back to index item type

    return _mapper.graph
        .decodeObject<I>(RdfGraph.fromTriples(indexItemTriples));
  }

  HydrationResult<I> convertHydrationResult<T, I>(
      IriTerm resourceType, HydrationResult<T> r, IndexItem indexItem) {
    final items = r.items.map((item) {
      return convertToIndexItem<T, I>(resourceType, item, indexItem);
    }).toList();
    final deletedItems = r.deletedItems.map((item) {
      return convertToIndexItem<T, I>(resourceType, item, indexItem);
    }).toList();
    return HydrationResult<I>(
        items: items,
        deletedItems: deletedItems,
        originalCursor: r.originalCursor,
        nextCursor: r.nextCursor,
        hasMore: r.hasMore);
  }
}
