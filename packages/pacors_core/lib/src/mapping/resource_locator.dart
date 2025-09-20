import 'package:rdf_core/rdf_core.dart';

/// Translates between application identifiers and storage IRIs for different backends.
///
/// For example:
/// - Solid Pod implementation: Uses type index to find storage location
/// - Google Drive backend: Simple strategy to convert to/from IRIs
abstract interface class ResourceLocator {
  IriTerm toRemoteIri(IriTerm typeIri, String localId);
  String toLocalId(IriTerm typeIri, IriTerm remoteIri);
}
