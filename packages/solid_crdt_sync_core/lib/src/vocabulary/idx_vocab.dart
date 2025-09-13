/// Vocabulary for solid-crdt-sync index semantics.
library;

import 'package:rdf_core/rdf_core.dart';

/// Index vocabulary (idx:) for solid-crdt-sync framework.
///
/// Defines terms used in index structures and metadata.
class IdxVocab {
  static const String _namespace =
      'https://w3id.org/solid-crdt-sync/vocab/idx#';

  /// Property linking index items back to their source resource
  static const IriTerm resource = IriTerm.prevalidated('${_namespace}resource');

  // Future vocabulary terms can be added here as needed:
  // static final IriTerm groupIndex = IriTerm.prevalidated('${_namespace}GroupIndex');
  // static final IriTerm fullIndex = IriTerm.prevalidated('${_namespace}FullIndex');
  // static final IriTerm indexEntry = IriTerm.prevalidated('${_namespace}IndexEntry');
}
