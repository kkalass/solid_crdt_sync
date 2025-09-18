/// Index configuration classes for defining CRDT sync indices.
///
/// These classes define how data should be indexed for efficient sync and querying.
/// The framework uses these configurations to generate idx:GroupIndexTemplate
/// and idx:FullIndex RDF resources on the Solid Pod.
library;

import 'package:rdf_core/rdf_core.dart';

const defaultIndexLocalName = "default";

enum ItemFetchPolicy {
  /// Proactive item fetching - all items referenced in the index are automatically
  /// downloaded from the pod to local when they are updated remotely or not already present locally.
  prefetch,

  /// Lazy item fetching - items are only downloaded from the pod to local
  /// when explicitly requested by the application. Once downloaded, items are
  /// automatically updated when remote changes occur.
  onRequest
}

/// Defines how index items are structured and deserialized.
///
/// Specifies both the Dart type for deserialization and the RDF properties
/// to include in index items for efficient querying.
class IndexItem {
  /// Dart type for index item deserialization (e.g., NoteIndexEntry)
  final Type itemType;

  /// RDF properties to include in index items
  final Set<IriTerm> properties;

  const IndexItem(this.itemType, this.properties);
}

sealed class CrdtIndexConfig {
  /// The Dart type being indexed (e.g., Note - the source data type)
  Type get dartType;

  /// Local name for referencing this index within the app (not used in Pod structure)
  /// Defaults to [defaultIndexLocalName]. Must be unique per index item type
  /// across all resources (e.g., if multiple resources use NoteIndexEntry,
  /// they must have different local names).
  /// Used for referencing in indexUpdatesStream<T>(localName) calls.
  String get localName;

  /// Default path for storing this index on the Pod.
  /// Used when there's no existing entry in the type registry and the user
  /// allows us to create one with our suggested default.
  /// Example: '/index/notes', '/index/categories'
  String? get defaultIndexPath;

  /// Configuration for index items (type and properties) - if null then we
  /// do not have index properties and the index items cannot be queried, but
  /// the synchronization of the data still happens.
  IndexItem? get item;

  const CrdtIndexConfig();
}

/// Defines a grouped index configuration that will generate an idx:GroupIndexTemplate.
///
/// Groups data by time periods or other criteria for efficient partial sync.
/// Example: Group notes by year-month for scalable historical data handling.
class GroupIndex extends CrdtIndexConfig {
  /// The Dart type being indexed (e.g., Note)
  @override
  final Type dartType;

  final Type groupKeyType;

  /// Local name for referencing this index within the app (not used in Pod structure)
  @override
  final String localName;

  /// Default path for storing this index on the Pod
  @override
  final String? defaultIndexPath;

  /// Configuration for index items (type and properties)
  @override
  final IndexItem? item;

  /// Properties used for grouping resources, must be in sync with the groupKeyType
  final List<GroupingProperty> groupingProperties;

  const GroupIndex(
    this.dartType,
    this.groupKeyType, {
    this.localName = defaultIndexLocalName,
    this.defaultIndexPath,
    this.item,
    required this.groupingProperties,
  }) : assert(groupingProperties.length > 0,
            'GroupIndex requires at least one grouping property');
}

/// Defines a full index configuration that will generate an idx:FullIndex.
///
/// Creates a single index covering an entire dataset for bounded collections.
/// Example: All user contacts, recipe collection, document library.
class FullIndex extends CrdtIndexConfig {
  /// The Dart type being indexed (e.g., Contact)
  @override
  final Type dartType;

  /// Local name for referencing this index within the app (not used in Pod structure)
  @override
  final String localName;

  /// Default path for storing this index on the Pod
  @override
  final String? defaultIndexPath;

  /// Configuration for index items (type and properties)
  @override
  final IndexItem? item;

  final ItemFetchPolicy itemFetchPolicy;

  const FullIndex(
    this.dartType, {
    this.localName = defaultIndexLocalName,
    this.defaultIndexPath,
    this.item,
    this.itemFetchPolicy = ItemFetchPolicy.prefetch,
  });
}

/// Defines how a property should be used for grouping in a GroupIndex.
///
/// Extracts group identifiers from RDF property values using format patterns.
/// Example: Extract 'yyyy-MM' from schema:dateCreated to group by month.
/// A regex transform rule for extracting group keys from RDF literal values
/// Uses cross-platform compatible regex subset with deterministic list processing
class RegexTransform {
  /// Cross-platform compatible regex pattern (no alternation, no named character classes)
  final String pattern;

  /// Replacement template with ${n} backreferences to capture groups
  final String replacement;

  const RegexTransform(this.pattern, this.replacement);

  @override
  String toString() => 'RegexTransform($pattern -> $replacement)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegexTransform &&
          runtimeType == other.runtimeType &&
          pattern == other.pattern &&
          replacement == other.replacement;

  @override
  int get hashCode => pattern.hashCode ^ replacement.hashCode;
}

class GroupingProperty {
  /// RDF predicate IRI for the source property (e.g., schema:dateCreated)
  final IriTerm predicate;

  final int hierarchyLevel;

  /// Optional regex transforms for extracting group values from the property
  /// Example: RegexTransform("^([0-9]{4})-([0-9]{2})-([0-9]{2})\$", "\${1}-\${2}")
  /// extracts "2025-08" from date values like "2025-08-15".
  ///
  /// Note that the transforms are applied in order, so multiple transforms can be
  /// chained together for more complex extraction logic.
  ///
  /// Also note that the transforms operate on the RDF representation of the property value - not on the dart object.
  /// For literals, transforms operate on the lexical value (without language tag or datatype);
  /// for IRIs, transforms operate on the IRI string.
  ///
  /// If not specified, the RDF representation of the property value is used as-is.
  /// For literals, this is the lexical value (without language tag or datatype); for IRIs, the IRI string.
  ///
  final List<RegexTransform>? transforms;

  /// Value to use when the source property is missing
  /// If null, resources missing the property are excluded from the index
  /// Example: 'unknown' to group all missing values together
  final String? missingValue;

  const GroupingProperty(
    this.predicate, {
    this.transforms,
    this.hierarchyLevel = 1,
    this.missingValue,
  });
}
