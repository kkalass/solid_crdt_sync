/// Solid Pod resource annotation for RDF classes stored in Solid Pods.
library;

import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:pacors_annotations/pacors_annotations.dart';
import 'package:pacors_core/pacors_core.dart';

const resourceIriFactoryKey = r'$resourceIriFactory';

class PodIriStrategy extends IriStrategy {
  const PodIriStrategy([PodIriConfig? config])
      : super.namedFactory(
            resourceIriFactoryKey, config ?? const PodIriConfig());
}

/// Annotation for RDF classes that represent resources stored in Solid Pods.
///
/// This annotation extends [RdfGlobalResource] to provide Solid-specific
/// functionality for managing RDF resources within a Solid Pod ecosystem.
/// It handles the mapping between Dart objects and RDF resources that will
/// be synchronized across Solid Pods using CRDT merge strategies.
///
/// ## What is a Solid Pod?
///
/// A Solid Pod is a personal data store that gives users complete control
/// over their data. Each Pod acts as a secure, decentralized storage space
/// where users can store any kind of information while maintaining full
/// ownership and control over who can access it.
///
/// ## IRI Strategy and Resource Identification
///
/// In Solid, every resource is identified by an IRI (Internationalized
/// Resource Identifier). This annotation works with the pacors
/// framework to automatically generate appropriate IRIs for your resources
/// based on configurable strategies:
///
/// - **Fragment-based IRIs**: Resources are always identified using fragment
///   identifiers (e.g., `https://example.pod/notes/note1.ttl#it`). The
///   framework owns the RDF documents while your application resources
///   live as fragments within those documents.
/// - **Type Index integration**: Resources can be automatically registered
///   in the user's type index for discoverability
///
/// ## Usage Example
///
/// ```dart
/// @SolidPodResource()
/// class Note extends RdfResource {
///   @LwwRegister()
///   late String title;
///
///   @LwwRegister()
///   late String content;
///
///   @Immutable()
///   late DateTime createdAt;
///
///   Note();
/// }
/// ```
///
/// ## CRDT Integration
///
/// Resources annotated with `@SolidPodResource()` automatically participate
/// in CRDT-based conflict resolution when synchronized across multiple
/// devices or users. Properties within the class should use appropriate
/// CRDT annotations ([CrdtLwwRegister], [CrdtFwwRegister], [CrdtOrSet], [CrdtImmutable])
/// to define their merge behavior.
///
/// ## Code Generation
///
/// The pacors generator will process this annotation to create:
/// - Proper IRI mapping based on the configured strategy
/// - CRDT merge logic for conflict resolution
/// - Integration with Solid authentication and type indices
/// - Serialization/deserialization methods for RDF storage
///
/// See also:
/// - [RdfGlobalResource] - The base annotation this extends
/// - CRDT annotations: [CrdtLwwRegister], [CrdtFwwRegister], [CrdtOrSet], [CrdtImmutable]
/// - [SolidCrdtSync] - The main synchronization engine
class PodResource extends RdfGlobalResource {
  /// Creates a Solid Pod resource annotation.
  ///
  /// This annotation inherits all functionality from [RdfGlobalResource]
  /// and adds Solid-specific features for Pod-based resource management.
  ///
  /// The [classIri] parameter defines the RDF type for this resource class.
  /// The IRI strategy is configured globally when initializing the
  /// [SolidCrdtSync] system rather than per-annotation, providing consistent
  /// IRI generation across all Solid Pod resources.
  ///
  /// Example:
  /// ```dart
  /// @SolidPodResource(IriTerm.prevalidated('https://example.org/Note'))
  /// class Note extends RdfResource {
  ///   @LwwRegister()
  ///   late String title;
  /// }
  /// ```
  const PodResource(IriTerm? classIri,
      [PodIriStrategy iriStrategy = const PodIriStrategy()])
      : super(classIri, iriStrategy);
}
