/// Category model for organizing notes with CRDT annotations.
library;

import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';
import 'package:rdf_vocabularies_schema/schema.dart';
import 'package:solid_crdt_sync_annotations/solid_crdt_sync_annotations.dart';

/// A category for organizing personal notes.
///
/// Uses CRDT merge strategies:
/// - LWW-Register for name and description (last writer wins)
/// - Immutable for creation date
@PodResource(SchemaCreativeWork.classIri)
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

  /// When this category was created
  @RdfProperty(SchemaCreativeWork.dateCreated)
  @CrdtImmutable()
  DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy of this category with updated fields
  Category copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name)';
  }
}
