/// Configuration for CRDT mapping files and their deployment.
///
/// This handles the relationship between Dart types, RDF types, and the
/// CRDT mapping files that define their merge behavior.
library;

/// Configuration describing how Dart types map to CRDT mapping files.
///
/// Contains the metadata needed to:
/// - Map Dart types to their RDF type IRIs
/// - Find the corresponding CRDT mapping file for each type
class CrdtMappingsConfig {
  /// Map from Dart type to its CRDT mapping metadata.
  final Map<Type, CrdtMappingInfo> typeMappings;

  /// Map from RDF type IRI to its CRDT mapping metadata.
  final Map<String, CrdtMappingInfo> iriMappings;

  const CrdtMappingsConfig({
    required this.typeMappings,
    required this.iriMappings,
  });

  /// Get mapping info for a Dart type.
  CrdtMappingInfo? getMappingForType(Type dartType) {
    return typeMappings[dartType];
  }

  /// Get mapping info for an RDF type IRI.
  CrdtMappingInfo? getMappingForIri(String rdfTypeIri) {
    return iriMappings[rdfTypeIri];
  }
}

/// Information about a single CRDT mapping file.
class CrdtMappingInfo {
  /// The Dart type this mapping applies to.
  final Type dartType;

  /// The RDF type IRI this mapping applies to.
  final String rdfTypeIri;

  /// Full IRI of the CRDT mapping file (e.g., "https://myapp.com/mappings/note-v1.ttl").
  final String mappingIri;

  /// Version of the mapping contract.
  final String version;

  /// Optional description of what this mapping handles.
  final String? description;

  const CrdtMappingInfo({
    required this.dartType,
    required this.rdfTypeIri,
    required this.mappingIri,
    required this.version,
    this.description,
  });

  @override
  String toString() {
    return 'CrdtMappingInfo(type: $dartType, iri: $rdfTypeIri, mapping: $mappingIri)';
  }
}

/// Factory function type for creating CRDT mappings configuration.
///
/// This is what user-provided `createCrdtMappings()` functions should return,
/// and what generated `createCrdtMappings()` functions will return.
typedef CrdtMappingsFactory = CrdtMappingsConfig Function();