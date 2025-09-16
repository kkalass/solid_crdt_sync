/// Service providing IRI mapping factories for resources.
///
/// This service creates factory functions that handle resource identification
/// and referencing within the CRDT sync system. The factories work together
/// to provide consistent IRI mapping across the application.
library;

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';

/// Local-first IRI mapping service for offline and pre-pod-connection usage.
///
/// This service generates stable, deterministic local IRIs using the scheme:
/// `app://local/{type-name}/{id}` for both resources and references.
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
/// Local IRIs are stable and collision-free, making them suitable for offline
/// usage and later migration to pod-based IRIs when connecting to a Solid Pod.
class LocalResourceIriService {
  bool _isSetupComplete = false;
  Map<Type, PodIriConfig> _registeredTypes = {};
  Set<Type> _referencedTypes = {};
  late Map<Type, IriTerm> _resourceTypeCache;
  final List<ValidationError> _setupErrors = [];

  /// Creates a mapper for primary resource IRI mapping during setup phase.
  ///
  /// **Setup Phase Only**: This method must only be called before
  /// [finishSetupAndValidate].
  ///
  /// Creates an [IriTermMapper] for primary resource identification using ID tuples
  /// and the provided [PodIriConfig]. Each type can only be registered once.
  ///
  /// Throws [StateError] if called after setup phase is complete.
  /// Validation errors will be collected if type T is already registered.
  IriTermMapper<(String id,)> createResourceIriMapper<T>(PodIriConfig config) {
    // This is a programming constraint - throw immediately
    if (_isSetupComplete) {
      throw StateError(
          'Resource IRI mapper cannot be created after setup is complete');
    }

    // This is a configuration validation issue - collect for later reporting
    if (_registeredTypes.containsKey(T)) {
      _setupErrors.add(ValidationError(
          'Resource IRI mapper for type $T is already registered',
          context: {'type': T, 'operation': 'createResourceIriMapper'}));
    } else {
      _registeredTypes[T] = config;
    }

    // Create local IRI mapper for type T using the tuple (String id,) pattern
    return _LocalResourceIriMapper<T>();
  }

  /// Creates a mapper for resource reference mapping during setup phase.
  ///
  /// **Setup Phase Only**: This method must only be called before
  /// [finishSetupAndValidate].
  ///
  /// Creates an [IriTermMapper] for resource references using string identifiers.
  /// The [targetType] specifies which resource type this mapper references.
  /// Multiple references to the same type are allowed.
  ///
  /// Throws [StateError] if called after setup phase is complete.
  IriTermMapper<String> createResourceRefMapper<T>(Type targetType) {
    // This is a programming constraint - throw immediately
    if (_isSetupComplete) {
      throw StateError(
          'Resource reference mapper cannot be created after setup is complete');
    }
    // referencing the same type multiple times of course is fine
    _referencedTypes.add(targetType);

    // Create local reference mapper that uses the same IRI scheme as resources
    return _LocalReferenceIriMapper(targetType);
  }

  /// Validates the current setup configuration.
  ///
  /// Returns a [ValidationResult] containing any errors or warnings found
  /// during setup. This should be called before [finishSetupAndValidate]
  /// to check for issues.
  ///
  /// Validates:
  /// - Setup errors collected during mapper creation
  /// - Referenced types have corresponding registered types
  /// - Resource type cache consistency
  ValidationResult validate(Map<Type, IriTerm> resourceTypeCache) {
    final result = ValidationResult();

    // Add any setup errors that were collected during mapper creation
    for (final error in _setupErrors) {
      result.errors.add(error);
    }

    // Validate that all referenced types were registered as resource types
    _validateReferencedTypes(result);

    // Validate resource type cache consistency
    _validateResourceTypeCache(result, resourceTypeCache);

    return result;
  }

  void _validateReferencedTypes(ValidationResult result) {
    for (final refType in _referencedTypes) {
      if (!_registeredTypes.containsKey(refType)) {
        result.addError(
            'Referenced type $refType was not registered as a resource type. '
            'All types used in resource references must be registered via createResourceIriMapper.',
            context: {
              'referencedType': refType,
              'registeredTypes': _registeredTypes.keys.toList()
            });
      }
    }
  }

  void _validateResourceTypeCache(ValidationResult result, Map<Type, IriTerm> resourceTypeCache) {
    for (final type in _registeredTypes.keys) {
      final iriTerm = resourceTypeCache[type];
      if (iriTerm == null) {
        result.addError(
            'Missing IRI term for registered type $type in resource type cache. '
            'This indicates a configuration error in the RDF mapper setup.',
            context: {'type': type});
      }
    }
  }

  /// Transitions from setup phase to runtime phase and validates configuration.
  ///
  /// This method:
  /// 1. Validates the entire setup configuration
  /// 2. Marks the service as setup complete (prevents further mapper creation)
  /// 3. Caches the resource type IRI mappings for runtime use if validation passes
  ///
  /// Returns a [ValidationResult] that should be checked before proceeding.
  /// If validation fails, the service remains in setup phase and no state changes occur.
  ValidationResult finishSetupAndValidate(Map<Type, IriTerm> resourceTypeCache) {
    // First validate the configuration
    final validationResult = validate(resourceTypeCache);

    // Only proceed with setup completion if validation passes
    if (validationResult.isValid) {
      _isSetupComplete = true;
      _resourceTypeCache = <Type, IriTerm>{};

      // Cache the IRI terms for registered types
      _registeredTypes.forEach((type, config) {
        final iriTerm = resourceTypeCache[type];
        // We already validated this in validate(), so this should not be null
        assert(iriTerm != null, 'IRI term should exist after successful validation');
        _resourceTypeCache[type] = iriTerm!;
      });
    }

    return validationResult;
  }
}

/// Local IRI mapper for primary resources using the app://local/{type}/{id} scheme.
class _LocalResourceIriMapper<T> implements IriTermMapper<(String,)> {
  @override
  (String,) fromRdfTerm(IriTerm term, DeserializationContext context) {
    final iri = term.iri;
    final typeName = T.toString();
    final expectedPrefix = 'app://local/$typeName/';

    if (!iri.startsWith(expectedPrefix)) {
      throw ArgumentError('IRI $iri does not match expected pattern for type $T');
    }

    final id = iri.substring(expectedPrefix.length);
    return (id,);
  }

  @override
  IriTerm toRdfTerm((String,) value, SerializationContext context) {
    final (id,) = value;
    final typeName = T.toString();
    final iri = 'app://local/$typeName/$id';
    return IriTerm(iri);
  }
}

/// Local IRI mapper for resource references using the same scheme as resources.
class _LocalReferenceIriMapper implements IriTermMapper<String> {
  final Type targetType;

  const _LocalReferenceIriMapper(this.targetType);

  @override
  String fromRdfTerm(IriTerm term, DeserializationContext context) {
    final iri = term.iri;
    final typeName = targetType.toString();
    final expectedPrefix = 'app://local/$typeName/';

    if (!iri.startsWith(expectedPrefix)) {
      throw ArgumentError('IRI $iri does not match expected pattern for target type $targetType');
    }

    // Return just the ID part (same as resource, but return String instead of tuple)
    return iri.substring(expectedPrefix.length);
  }

  @override
  IriTerm toRdfTerm(String value, SerializationContext context) {
    final typeName = targetType.toString();
    final iri = 'app://local/$typeName/$value';
    return IriTerm(iri);
  }
}
