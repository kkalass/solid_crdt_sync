/// CRDT merge strategy annotations for pacors code generation.
///
/// This library provides annotations to specify how properties should be merged
/// in CRDT scenarios. The annotations work with RDF mapping and are used by
/// the pacors generator to create proper merge logic.
library pacors_annotations;

export 'src/crdt_annotations.dart';
export 'src/pod_resource.dart';
export 'src/pod_resource_ref.dart';
