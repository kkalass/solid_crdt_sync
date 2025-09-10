/// Index configuration classes for defining CRDT sync indices.
///
/// These classes define how data should be indexed for efficient sync and querying.
/// The framework uses these configurations to generate idx:GroupIndexTemplate
/// and idx:FullIndex RDF resources on the Solid Pod.
library;

import 'package:rdf_core/rdf_core.dart';

const defaultIndexLocalName = "default";

abstract interface class CrdtIndexConfig {
  /// The Dart type being indexed (e.g., Contact)
  Type get dartType;

  /// Local name for referencing this index within the app (not used in Pod structure)
  /// Defaults to [defaultIndexLocalName]. Must be unique per Type within the application.
  /// Used for referencing in indexUpdatesStream<T>(localName) calls.
  String get localName;

  /// Properties to include in index headers for efficient queries
  List<IriTerm> get indexedProperties;

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

  /// Local name for referencing this index within the app (not used in Pod structure)
  @override
  final String localName;

  /// Properties used for grouping resources
  final List<GroupingProperty> groupingProperties;

  /// Properties to include in index headers for efficient queries
  @override
  final List<IriTerm> indexedProperties;

  const GroupIndex(
    this.dartType, {
    this.localName = defaultIndexLocalName,
    required this.groupingProperties,
    this.indexedProperties = const [],
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

  /// Properties to include in index headers for efficient queries
  @override
  final List<IriTerm> indexedProperties;

  const FullIndex(
    this.dartType, {
    this.localName = defaultIndexLocalName,
    required this.indexedProperties,
  });
}

/// Defines how a property should be used for grouping in a GroupIndex.
///
/// Extracts group identifiers from RDF property values using format patterns.
/// Example: Extract 'yyyy-MM' from schema:dateCreated to group by month.
class GroupingProperty {
  /// RDF predicate IRI for the source property (e.g., schema:dateCreated)
  final IriTerm predicate;

  final int hierarchyLevel;

  /// Format pattern for extracting group values from the property
  /// Example: 'yyyy-MM' extracts "2025-08" from date values
  final String format;

  /// Value to use when the source property is missing
  /// If null, resources missing the property are excluded from the index
  /// Example: 'unknown' to group all missing values together
  final String? missingValue;

  const GroupingProperty(
    this.predicate, {
    required this.format,
    this.hierarchyLevel = 1,
    this.missingValue,
  });
}
