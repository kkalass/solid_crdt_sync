/// Personal Notes vocabulary constants for RDF type and property IRIs.
///
/// This demonstrates a simple approach for managing custom vocabulary IRIs
/// in example applications. For production applications, consider using
/// rdf_vocabulary_to_dart to generate these constants from your .ttl files.
library;

import 'package:rdf_core/rdf_core.dart';

/// Constants for the Personal Notes vocabulary.
///
/// This vocabulary is deployed at GitHub Pages and defines specialized
/// types for note organization that properly subclass Schema.org types.
class PersonalNotesVocab {
  /// Base IRI for the Personal Notes vocabulary
  static const baseIri = 'https://kkalass.github.io/solid_crdt_sync/example/personal_notes_app/vocabulary/personal-notes#';

  // Classes
  
  /// A category for organizing personal notes.
  /// Subclass of schema:CreativeWork.
  static const notesCategory = IriTerm.prevalidated('https://kkalass.github.io/solid_crdt_sync/example/personal_notes_app/vocabulary/personal-notes#NotesCategory');
  
  /// A personal note or memo.
  /// Subclass of schema:NoteDigitalDocument.
  static const personalNote = IriTerm.prevalidated('https://kkalass.github.io/solid_crdt_sync/example/personal_notes_app/vocabulary/personal-notes#PersonalNote');

  // Properties
  
  /// Indicates that a note belongs to a specific notes category.
  /// Domain: PersonalNote, Range: NotesCategory
  static const belongsToCategory = IriTerm.prevalidated('https://kkalass.github.io/solid_crdt_sync/example/personal_notes_app/vocabulary/personal-notes#belongsToCategory');
  
  /// A color code (hex, name, etc.) associated with a category for UI display.
  /// Domain: NotesCategory, Range: xsd:string
  static const categoryColor = IriTerm.prevalidated('https://kkalass.github.io/solid_crdt_sync/example/personal_notes_app/vocabulary/personal-notes#categoryColor');
  
  /// An icon identifier or emoji associated with a category for UI display.
  /// Domain: NotesCategory, Range: xsd:string  
  static const categoryIcon = IriTerm.prevalidated('https://kkalass.github.io/solid_crdt_sync/example/personal_notes_app/vocabulary/personal-notes#categoryIcon');
}