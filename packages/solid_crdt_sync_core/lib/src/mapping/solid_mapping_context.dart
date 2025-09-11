/// Context object providing framework services to mapper initializers.
///
/// This is passed to user-provided mapper initializer functions, allowing
/// them to access framework-managed services like IRI strategies, auth
/// providers, and type index resolvers.
library;

/// Provides framework services to mapper initializer functions.
///
/// When users provide a `mapperInitializer` function to `SolidCrdtSync.setup()`,
/// it receives this context object containing all the framework-managed
/// services needed to configure RDF mapping for Solid Pods.
class SolidMappingContext {
  // FIXME: We will need some way to handle IRI mapping
  // Object get iriStrategy;

  SolidMappingContext();
}
