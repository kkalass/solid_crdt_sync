/// Solid Pod resource annotation for RDF classes stored in Solid Pods.
library;

import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';

class PodResourceRef extends IriMapping {
  // FIXME: unclear how the actual Iri mapper is specified and handled
  const PodResourceRef(Type cls) : super();
}
