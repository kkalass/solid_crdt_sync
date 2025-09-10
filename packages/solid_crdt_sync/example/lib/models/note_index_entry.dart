/// Index entry for Note resources containing lightweight header properties.
///
/// Index entries are used for efficient querying and on-demand sync scenarios.
/// They contain selected properties from the full Note resource plus metadata
/// like Hybrid Logical Clock hashes for change detection.
library;

import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';
import 'package:rdf_vocabularies_schema/schema.dart';

/// Lightweight index entry for Note resources.
///
/// Contains essential properties for browsing and filtering notes without
/// loading the full note content. Used in index update streams and
/// on-demand sync scenarios.
///
/// Index entries automatically use LWW-Register for all properties (framework-managed).
/// No CRDT annotations needed - the framework handles conflict resolution.
@RdfLocalResource()
class NoteIndexEntry {
  /// Note title for display in lists
  @RdfProperty(SchemaNoteDigitalDocument.name)
  final String title;

  /// Creation date for sorting and grouping
  @RdfProperty(SchemaNoteDigitalDocument.dateCreated)
  final DateTime createdAt;

  /// Last modification time
  @RdfProperty(SchemaNoteDigitalDocument.dateModified)
  final DateTime modifiedAt;

  /// Tags for filtering
  @RdfProperty(SchemaNoteDigitalDocument.keywords)
  final Set<String> tags;

  /// Category ID for grouping
  @RdfProperty(SchemaNoteDigitalDocument.about)
  final String? categoryId;

  const NoteIndexEntry({
    required this.title,
    required this.createdAt,
    required this.modifiedAt,
    this.tags = const {},
    this.categoryId,
  });

  @override
  String toString() =>
      'NoteIndexEntry(title: $title, createdAt: $createdAt, tags: $tags)';
}
