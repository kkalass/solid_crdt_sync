/// Solid Pod resource annotation for RDF classes stored in Solid Pods.
library;

import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';

const resourceRefFactoryKey = r'$resourceRefFactory';

class PodResourceRef extends IriMapping {
  const PodResourceRef(Type cls)
      : super.namedFactory(resourceRefFactoryKey, cls);
}
