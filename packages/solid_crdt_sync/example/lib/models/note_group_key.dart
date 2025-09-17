import 'package:personal_notes_app/models/note.dart';
import 'package:rdf_mapper_annotations/rdf_mapper_annotations.dart';

@RdfLocalResource()
class NoteGroupKey {
  @NoteCategoryProperty()
  final String? categoryId;

  const NoteGroupKey(this.categoryId);

  /// Helper for uncategorized notes group
  static const uncategorized = NoteGroupKey(null);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteGroupKey &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId;

  @override
  int get hashCode => categoryId.hashCode;

  @override
  String toString() => 'NoteGroupKey(categoryId: $categoryId)';
}
