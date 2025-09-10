/// Resource-focused configuration for CRDT sync setup.
///
/// This provides a resource-centric API where all configuration flows from
/// "what resources am I working with?" rather than separate configuration
/// of indices, mappings, and paths.
library;

import 'package:solid_crdt_sync_core/src/index/index_config.dart';

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
}
