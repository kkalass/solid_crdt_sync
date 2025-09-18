/// Manages group index subscriptions and group key generation.
library;

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_crdt_sync_core/src/config/resource_config.dart';
import 'package:solid_crdt_sync_core/src/index/group_key_generator.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';

/// Exception thrown when group index subscription validation fails.
class GroupIndexSubscriptionException implements Exception {
  final String message;
  final Object? context;

  const GroupIndexSubscriptionException(this.message, {this.context});

  @override
  String toString() => 'GroupIndexSubscriptionException: $message';
}

/// Manages subscriptions to group indices and converts group keys to group identifiers.
///
/// This class handles:
/// - Validation of group key types against configured GroupIndex
/// - Conversion of group key objects to RDF triples
/// - Generation of group identifiers using GroupKeyGenerator
/// - Validation that group key types are properly registered
class GroupIndexSubscriptionManager {
  final SyncConfig _config;
  final RdfMapper _mapper;

  const GroupIndexSubscriptionManager({
    required SyncConfig config,
    required RdfMapper mapper,
  })  : _config = config,
        _mapper = mapper;

  /// Subscribe to a group index with proper validation and group key generation.
  ///
  /// Validates that:
  /// - G is a valid group key type registered in a GroupIndex
  /// - The localName corresponds to a GroupIndex with groupKeyType G
  /// - The groupKey can be serialized to RDF
  /// - The GroupIndex configuration has valid group key generators
  ///
  /// Returns the set of group identifiers generated from the group key.
  Future<Set<String>> subscribeToGroupIndex<G>(G groupKey,
      {String localName = defaultIndexLocalName}) async {
    // Step 1: Find the GroupIndex configuration for type G and localName
    final groupIndexConfig = _findGroupIndexConfig<G>(localName);
    if (groupIndexConfig == null) {
      throw GroupIndexSubscriptionException(
          'No GroupIndex found for group key type ${G.runtimeType} with localName "$localName". '
          'Ensure the type is configured in a GroupIndex with the specified localName.',
          context: {
            'groupKeyType': G.runtimeType,
            'localName': localName,
          });
    }

    final (resourceConfig, groupIndex) = groupIndexConfig;

    // Step 2: Validate that the group key type matches
    if (groupIndex.groupKeyType != G) {
      throw GroupIndexSubscriptionException(
          'Group key type mismatch. Expected ${groupIndex.groupKeyType}, got ${G.runtimeType}.',
          context: {
            'expectedType': groupIndex.groupKeyType,
            'actualType': G.runtimeType,
            'localName': localName,
          });
    }

    // Step 3: Convert group key to RDF triples
    final groupKeyTriples = _convertGroupKeyToTriples(groupKey);

    // Step 4: Generate group identifiers using GroupKeyGenerator
    final groupKeyGenerator = GroupKeyGenerator(groupIndex);
    final groupIdentifiers =
        groupKeyGenerator.generateGroupKeys(groupKeyTriples);

    if (groupIdentifiers.isEmpty) {
      throw GroupIndexSubscriptionException(
          'No group identifiers generated from group key. '
          'This may indicate missing required properties or invalid transforms.',
          context: {
            'groupKey': groupKey,
            'groupKeyType': G.runtimeType,
            'localName': localName,
            'tripleCount': groupKeyTriples.length,
          });
    }

    return groupIdentifiers;
  }

  /// Find the GroupIndex configuration for the given type and localName.
  (ResourceConfig, GroupIndex)? _findGroupIndexConfig<G>(String localName) {
    for (final resource in _config.resources) {
      for (final index in resource.indices) {
        if (index is GroupIndex &&
            index.localName == localName &&
            index.groupKeyType == G) {
          return (resource, index);
        }
      }
    }
    return null;
  }

  /// Convert a group key object to RDF triples using the mapper.
  List<Triple> _convertGroupKeyToTriples<G>(G groupKey) {
    try {
      // Encode the group key object to RDF
      final rdfGraph = _mapper.graph.encodeObject(groupKey);

      // Return all triples from the graph
      return rdfGraph.triples.toList();
    } catch (e) {
      throw GroupIndexSubscriptionException(
          'Failed to convert group key to RDF triples. '
          'Ensure the group key type is properly annotated and registered in the mapper.',
          context: {
            'groupKey': groupKey,
            'groupKeyType': G.runtimeType,
            'mapperError': e,
          });
    }
  }

  /// Validate that the group key type is properly registered in the mapper.
  ///
  /// This can be called during application setup to ensure all group key types
  /// are properly configured before attempting subscriptions.
  void validateGroupKeyType<G>() {
    try {
      // Try to create a test instance to verify mapper registration
      final testGraph = RdfGraph.fromTriples([]);

      // This will throw if the type is not registered
      _mapper.graph.decodeObject<G>(testGraph);
    } catch (e) {
      throw GroupIndexSubscriptionException(
          'Group key type ${G.runtimeType} is not properly registered in the mapper. '
          'Ensure the type is annotated with @PodResource or appropriate RDF annotations.',
          context: {
            'groupKeyType': G.runtimeType,
            'mapperError': e,
          });
    }
  }

  /// Get all configured group key types from the configuration.
  ///
  /// Returns a set of all types used as groupKeyType in GroupIndex configurations.
  Set<Type> getConfiguredGroupKeyTypes() {
    final types = <Type>{};

    for (final resource in _config.resources) {
      for (final index in resource.indices) {
        if (index is GroupIndex) {
          types.add(index.groupKeyType);
        }
      }
    }

    return types;
  }
}
