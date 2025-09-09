/// Context object providing framework services to mapper initializers.
///
/// This is passed to user-provided mapper initializer functions, allowing
/// them to access framework-managed services like IRI strategies, auth
/// providers, and type index resolvers.
library;

import 'package:rdf_mapper/rdf_mapper.dart';
import '../auth/auth_interface.dart';

/// Provides framework services to mapper initializer functions.
///
/// When users provide a `mapperInitializer` function to `SolidCrdtSync.setup()`,
/// it receives this context object containing all the framework-managed
/// services needed to configure RDF mapping for Solid Pods.
abstract interface class SolidMappingContext {
  /// IRI strategy for handling Solid Pod URLs and offline URN schemes.
  /// 
  /// This strategy automatically handles:
  /// - Converting between offline URNs and online Pod URLs
  /// - Looking up resource paths via Type Index
  /// - Partitioning strategies for large datasets
  /// 
  /// The actual type will be determined by the annotation package used.
  Object get iriStrategy;

  /// Base RDF mapper configured with framework defaults.
  /// 
  /// This can be used as a starting point, or users can create
  /// their own mapper configuration.
  RdfMapper get baseMapper;

  /// Authentication provider for accessing Pod resources.
  /// 
  /// Provides WebID, access tokens, and authentication state.
  /// May be null if running in local-only mode.
  SolidAuthProvider? get authProvider;

  /// Service for reading and manipulating Solid Type Index.
  /// 
  /// Used by IRI strategies to discover where different resource
  /// types should be stored on the Pod.
  TypeIndexService? get typeIndexService;

  /// Service for reading Solid profile information.
  /// 
  /// Provides access to profile data and Pod structure.
  ProfileService? get profileService;
}

/// Service for interacting with Solid Type Index files.
abstract interface class TypeIndexService {
  /// Get the storage path for resources of the given RDF type.
  Future<String?> getStoragePathForType(String rdfTypeIri);

  /// Register a new resource type in the Type Index.
  Future<void> registerResourceType(String rdfTypeIri, String storagePath);
}

/// Service for reading Solid profile information.
abstract interface class ProfileService {
  /// Get the base Pod URL for the authenticated user.
  Future<String?> getPodUrl();

  /// Get profile information as RDF triples.
  Future<Map<String, dynamic>?> getProfile();
}