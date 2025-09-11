/// Resource-focused configuration for CRDT sync setup.
///
/// This provides a resource-centric API where all configuration flows from
/// "what resources am I working with?" rather than separate configuration
/// of indices, mappings, and paths.
library;

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';
import 'validation.dart';

/// Configuration for a single resource type in the sync system.
///
/// Organizes all resource-specific configuration in one place:
/// - Default storage paths on the Pod
/// - CRDT mapping information
/// - Index configurations for this resource
class ResourceConfig {
  /// The Dart type this configuration applies to.
  final Type type;

  /// Default path for storing resources of this type on the Pod.
  /// Used when there's no existing entry in the type registry and the user
  /// allows us to create one with our suggested default.
  /// Example: '/data/notes', '/data/categories'
  final String? defaultResourcePath;

  /// Uri to the CRDT mapping file for this resource type.
  final Uri crdtMapping;

  /// Index configurations for this resource type.
  /// Can include multiple indices (e.g., by category, by date, full index).
  final List<CrdtIndexConfig> indices;

  const ResourceConfig({
    required this.type,
    this.defaultResourcePath,
    required this.crdtMapping,
    this.indices = const [],
  });

  /// Create a resource config with a simple single index.
  ResourceConfig.withSingleIndex({
    required this.type,
    this.defaultResourcePath,
    required this.crdtMapping,
    required CrdtIndexConfig index,
  }) : indices = [index];
}

/// Configuration for the entire sync system organized by resources.
class SyncConfig {
  /// All resource configurations for the application.
  final List<ResourceConfig> resources;

  const SyncConfig({
    required this.resources,
  });

  /// Get all index configurations across all resources.
  List<CrdtIndexConfig> getAllIndices() {
    return resources.expand((resource) => resource.indices).toList();
  }

  /// Get resource configuration for a specific type.
  ResourceConfig? getResourceConfig(Type type) {
    return resources.cast<ResourceConfig?>().firstWhere(
          (resource) => resource?.type == type,
          orElse: () => null,
        );
  }

  /// Validate this configuration for consistency and correctness.
  ValidationResult validate(RdfMapper mapper) {
    final result = ValidationResult();

    _validateResourceUniqueness(result, mapper);
    _validateDefaultPaths(result);
    _validateCrdtMappings(result);
    _validateIndexConfigurations(result);

    return result;
  }

  void _validateResourceUniqueness(ValidationResult result, RdfMapper mapper) {
    // Check for duplicate Dart types
    final dartTypes = <Type>{};
    final rdfTypeIris = <String, Type>{};

    for (final resource in resources) {
      // Check for duplicate Dart types
      if (dartTypes.contains(resource.type)) {
        result.addError(
            'Duplicate resource type: ${resource.type}. Each Dart type can only be configured once.',
            context: {'type': resource.type});
        continue; // Skip further processing for this resource
      }
      dartTypes.add(resource.type);

      // Check for RDF type IRI collisions
      try {
        final rdfTypeIri = _getTypeIri(mapper, resource);
        if (rdfTypeIri != null) {
          final rdfTypeIriString = rdfTypeIri.iri;
          if (rdfTypeIris.containsKey(rdfTypeIriString)) {
            result.addError(
                'RDF type IRI collision: ${resource.type} and ${rdfTypeIris[rdfTypeIriString]} '
                'both use $rdfTypeIriString. Each Dart type must have a unique RDF type IRI.',
                context: {
                  'conflicting_types': [
                    resource.type,
                    rdfTypeIris[rdfTypeIriString]
                  ],
                  'rdf_iri': rdfTypeIriString
                });
          }
          rdfTypeIris[rdfTypeIriString] = resource.type;
        } else {
          result.addError(
              'No RDF type IRI found for ${resource.type}. Resource types must be annotated with @PodResource.',
              context: {'type': resource.type});
        }
      } catch (e) {
        result.addError(
            'Could not resolve RDF type IRI for ${resource.type}: $e',
            context: {'type': resource.type, 'error': e.toString()});
      }
    }
  }

  void _validateDefaultPaths(ValidationResult result) {
    // Check for path conflicts and invalid paths
    final resourcePaths = <String, List<Type>>{};
    final indexPaths = <String, List<Type>>{};

    for (final resource in resources) {
      // Check resource paths
      if (resource.defaultResourcePath != null) {
        final path = resource.defaultResourcePath!;

        if (path.isEmpty) {
          result.addError(
              'Default resource path cannot be empty for ${resource.type}',
              context: {'type': resource.type});
        } else if (!path.startsWith('/')) {
          result.addError(
              'Default resource path must start with "/" for ${resource.type}: $path',
              context: {'type': resource.type, 'path': path});
        }

        resourcePaths.putIfAbsent(path, () => []).add(resource.type);
      }

      // Check index paths
      for (final index in resource.indices) {
        if (index.defaultIndexPath != null) {
          final path = index.defaultIndexPath!;

          if (path.isEmpty) {
            result.addError(
                'Default index path cannot be empty for ${resource.type}',
                context: {'type': resource.type, 'index': index});
          } else if (!path.startsWith('/')) {
            result.addError(
                'Default index path must start with "/" for ${resource.type}: $path',
                context: {'type': resource.type, 'path': path, 'index': index});
          }

          indexPaths.putIfAbsent(path, () => []).add(resource.type);
        }
      }
    }

    // Warn about path reuse (not necessarily an error)
    resourcePaths.forEach((path, types) {
      if (types.length > 1) {
        result.addWarning(
            'Multiple resource types use the same default path: $path (${types.join(', ')})',
            context: {'path': path, 'types': types});
      }
    });

    indexPaths.forEach((path, types) {
      if (types.length > 1) {
        result.addWarning(
            'Multiple indices use the same default path: $path (${types.join(', ')})',
            context: {'path': path, 'types': types});
      }
    });
  }

  void _validateCrdtMappings(ValidationResult result) {
    for (final resource in resources) {
      final uri = resource.crdtMapping;

      if (!uri.isAbsolute) {
        result.addError(
            'CRDT mapping URI must be absolute for ${resource.type}: $uri',
            context: {'type': resource.type, 'uri': uri});
      }

      if (uri.scheme == 'http') {
        result.addWarning(
            'CRDT mapping URI should use HTTPS for ${resource.type}: $uri',
            context: {'type': resource.type, 'uri': uri});
      }
    }
  }

  void _validateIndexConfigurations(ValidationResult result) {
    // Track local names per index item type across all resources
    final localNamesByItemType = <Type, Map<String, List<Type>>>{};

    for (final resource in resources) {
      for (final index in resource.indices) {
        // Check for empty or invalid local names
        if (index.localName.isEmpty) {
          result.addError(
              'Index local name cannot be empty for ${resource.type}',
              context: {'type': resource.type, 'index': index});
        }

        // Track local names by index item type (if index has an item type)
        if (index.item != null) {
          final itemType = index.item!.itemType;
          final localNamesForType = localNamesByItemType.putIfAbsent(
              itemType, () => <String, List<Type>>{});

          localNamesForType
              .putIfAbsent(index.localName, () => [])
              .add(resource.type);
        }

        // Validate GroupIndex specific requirements
        if (index is GroupIndex) {
          if (index.groupingProperties.isEmpty) {
            result.addError(
                'GroupIndex must have at least one grouping property for ${resource.type}',
                context: {'type': resource.type, 'index': index});
          }
        }
      }
    }

    // Check for duplicate local names within the same index item type
    localNamesByItemType.forEach((itemType, localNames) {
      localNames.forEach((localName, resourceTypes) {
        if (resourceTypes.length > 1) {
          result.addError(
              'Duplicate index local name "$localName" for index item type $itemType. '
              'Used by resources: ${resourceTypes.join(', ')}. '
              'Local names must be unique per index item type.',
              context: {
                'localName': localName,
                'itemType': itemType,
                'conflictingResources': resourceTypes
              });
        }
      });
    });
  }
}

IriTerm? _getTypeIri(RdfMapper mapper, ResourceConfig resource) {
  final registry = mapper.registry;
  try {
    return registry.getResourceSerializerByType(resource.type).typeIri;
  } on SerializerNotFoundException {
    return null;
  }
}
