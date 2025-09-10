/// Context object providing framework services to mapper initializers.
///
/// This is passed to user-provided mapper initializer functions, allowing
/// them to access framework-managed services like IRI strategies, auth
/// providers, and type index resolvers.
library;

import 'package:rdf_mapper/rdf_mapper.dart';

/// Provides framework services to mapper initializer functions.
///
/// When users provide a `mapperInitializer` function to `SolidCrdtSync.setup()`,
/// it receives this context object containing all the framework-managed
/// services needed to configure RDF mapping for Solid Pods.
abstract interface class SolidMappingContext {
  /// Base RDF mapper configured with framework defaults.
  ///
  /// This can be used as a starting point, or users can create
  /// their own mapper configuration.
  RdfMapper get baseMapper;

// FIXME: We will need some way to handle IRI mapping
// Object get iriStrategy;
}
