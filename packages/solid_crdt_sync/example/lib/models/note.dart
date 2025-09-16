/// Simple Note model with CRDT annotations for local-first sync.
library;

import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';
import 'package:rdf_vocabularies_schema/schema.dart';
import 'package:solid_crdt_sync_annotations/solid_crdt_sync_annotations.dart';
import '../vocabulary/personal_notes_vocab.dart';
import '../utils/optional.dart';
import 'category.dart';

/// A personal note with title, content, and tags.
///
/// Uses our custom PersonalNote type that specializes schema:NoteDigitalDocument
/// for personal note-taking use cases, following ADR-0002 guidance.
///
/// Uses CRDT merge strategies:
/// - LWW-Register for title and content (last writer wins)
/// - OR-Set for tags (additions and removals merge)
///
@PodResource(PersonalNotesVocab.PersonalNote)
class Note {
  /// Unique identifier for this note
  @RdfIriPart()
  String id;

  /// Note title - last writer wins on conflicts
  @RdfProperty(SchemaNoteDigitalDocument.name)
  @CrdtLwwRegister()
  String title;

  /// Note content - last writer wins on conflicts
  @RdfProperty(SchemaNoteDigitalDocument.text)
  @CrdtLwwRegister()
  String content;

  /// Tags that can be added/removed independently
  @RdfProperty(SchemaNoteDigitalDocument.keywords)
  @CrdtOrSet()
  Set<String> tags;

  /// Category this note belongs to - last writer wins on conflicts
  @RdfProperty(PersonalNotesVocab.belongsToCategory,
      iri: PodResourceRef(Category))
  @CrdtLwwRegister()
  String? categoryId;

  /// When this note was created
  @RdfProperty(SchemaNoteDigitalDocument.dateCreated)
  @CrdtImmutable()
  DateTime createdAt;

  /// When this note was last modified
  @RdfProperty(SchemaNoteDigitalDocument.dateModified)
  @CrdtLwwRegister()
  DateTime modifiedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    Set<String>? tags,
    this.categoryId,
    DateTime? createdAt,
    DateTime? modifiedAt,
  })  : tags = tags ?? <String>{},
        createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();

  /// Create a copy of this note with updated fields
  Note copyWith({
    String? id,
    String? title,
    String? content,
    Set<String>? tags,
    Optional<String>? categoryId,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? Set.from(this.tags),
      categoryId: categoryId != null ? categoryId.value : this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, tags: ${tags.length})';
  }
}
