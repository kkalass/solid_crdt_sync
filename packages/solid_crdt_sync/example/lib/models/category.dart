/// Category model for organizing notes with CRDT annotations.
library;

import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';
import 'package:rdf_vocabularies_schema/schema.dart';
import 'package:solid_crdt_sync_annotations/solid_crdt_sync_annotations.dart';
import '../vocabulary/personal_notes_vocab.dart';

/// A category for organizing personal notes.
///
/// Uses our custom vocabulary that properly specializes schema:CreativeWork
/// for note categorization, following ADR-0002 guidance for specific types.
///
/// Uses CRDT merge strategies:
/// - LWW-Register for name and description (last writer wins)
/// - Immutable for creation date
///
/// FIXME: implement and use PodResource
//@PodResource(PersonalNotesVocab.NotesCategory)
@RdfGlobalResource(PersonalNotesVocab.NotesCategory, IriStrategy())
class Category {
  /// Unique identifier for this category
  @RdfIriPart()
  String id;

  /// Category name - last writer wins on conflicts
  @RdfProperty(SchemaCreativeWork.name)
  @CrdtLwwRegister()
  String name;

  /// Optional description - last writer wins on conflicts
  @RdfProperty(SchemaCreativeWork.description)
  @CrdtLwwRegister()
  String? description;

  /// Color for UI display (hex code, CSS color name, etc.)
  @RdfProperty(PersonalNotesVocab.categoryColor)
  @CrdtLwwRegister()
  String? color;

  /// Icon for UI display (emoji, icon name, etc.)
  @RdfProperty(PersonalNotesVocab.categoryIcon)
  @CrdtLwwRegister()
  String? icon;

  /// When this category was created
  @RdfProperty(SchemaCreativeWork.dateCreated)
  @CrdtImmutable()
  DateTime createdAt;

  /// When this category was last modified
  @RdfProperty(SchemaCreativeWork.dateModified)
  @CrdtLwwRegister()
  DateTime modifiedAt;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.icon,
    DateTime? createdAt,
    DateTime? modifiedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();

  /// Create a copy of this category with updated fields
  Category copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    String? icon,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name)';
  }
}
