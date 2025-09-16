/// Service providing IRI mapping factories for resources.
///
/// This service creates factory functions that handle resource identification
/// and referencing within the CRDT sync system. The factories work together
/// to provide consistent IRI mapping across the application.
library;

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';

/// State machine service for resource IRI mapping during setup.
///
/// This service implements a two-phase state machine:
///
/// **Setup Phase**: Mappers can be created via:
/// - [createResourceIriMapper]: Creates mappers for primary resource identification
/// - [createResourceRefMapper]: Creates mappers for resource references
///
/// **Runtime Phase**: After [finishSetupAndValidate] is called, no new mappers
/// can be created. The service validates that all referenced types were properly
/// registered as resource types.
///
/// This design ensures that all IRI mapping is established during application
/// initialization, preventing runtime configuration errors.
class ResourceIriService {
  bool _isSetupComplete = false;
  Map<Type, PodIriConfig> _registeredTypes = {};
  Set<Type> _referencedTypes = {};
  late Map<Type, IriTerm> _resourceTypeCache;

  /// Creates a mapper for primary resource IRI mapping during setup phase.
  ///
  /// **Setup Phase Only**: This method can only be called before
  /// [finishSetupAndValidate]. Throws [StateError] if called during runtime phase.
  ///
  /// Creates an [IriTermMapper] for primary resource identification using ID tuples
  /// and the provided [PodIriConfig]. Each type can only be registered once.
  ///
  /// Throws [StateError] if:
  /// - Called after setup phase is complete
  /// - Type T is already registered
  IriTermMapper<(String id,)> createResourceIriMapper<T>(PodIriConfig config) {
    if (_isSetupComplete) {
      throw StateError(
          'Resource IRI mapper cannot be created after setup is complete');
    }
    if (_registeredTypes.containsKey(T)) {
      throw StateError(
          'Resource IRI mapper for type $T is already registered');
    }
    _registeredTypes[T] = config;
    // TODO: Implement resource IRI mapping strategy
    // This should create mappers that handle primary resource IRIs
    // using the ID tuple pattern for the given type T
    throw UnimplementedError('Resource IRI mapper not implemented');
  }

  /// Creates a mapper for resource reference mapping during setup phase.
  ///
  /// **Setup Phase Only**: This method can only be called before
  /// [finishSetupAndValidate]. Throws [StateError] if called during runtime phase.
  ///
  /// Creates an [IriTermMapper] for resource references using string identifiers.
  /// The [targetType] specifies which resource type this mapper references.
  /// Multiple references to the same type are allowed.
  ///
  /// Throws [StateError] if called after setup phase is complete.
  IriTermMapper<String> createResourceRefMapper<T>(Type targetType) {
    if (_isSetupComplete) {
      throw StateError(
          'Resource reference mapper cannot be created after setup is complete');
    }
    // referencing the same type multiple times of course is fine
    _referencedTypes.add(targetType);

    // TODO: Implement resource reference mapping strategy
    // This should create mappers that handle references to resources
    // of the given target type using string identifiers
    throw UnimplementedError('Resource reference mapper not implemented');
  }

  /// Transitions from setup phase to runtime phase and validates configuration.
  ///
  /// This method:
  /// 1. Marks the service as setup complete (prevents further mapper creation)
  /// 2. Validates that all referenced types were properly registered as resource types
  /// 3. Caches the resource type IRI mappings for runtime use
  ///
  /// Throws [StateError] if:
  /// - A referenced type was not registered as a resource type
  /// - A registered type is missing from the resource type cache
  void finishSetupAndValidate(Map<Type, IriTerm> resourceTypeCache) {
    _isSetupComplete = true;
    _resourceTypeCache = <Type, IriTerm>{};
    _registeredTypes.forEach((type, config) {
      final iriTerm = resourceTypeCache[type];
      if (iriTerm == null) {
        throw StateError('Missing IRI term for registered type $type');
      }
      _resourceTypeCache[type] = iriTerm;
    });
    for (final refType in _referencedTypes) {
      if (!_registeredTypes.containsKey(refType)) {
        throw StateError(
            'Referenced type $refType was not registered as a resource type');
      }
    }
  }
}
