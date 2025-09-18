import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_vocabularies_schema/schema.dart';
import 'package:solid_crdt_sync_core/src/index/group_key_generator.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';
import 'package:test/test.dart';

void main() {
  group('GroupKeyGenerator', () {
    // Test vocabulary for consistent URIs
    final testSubject = IriTerm.prevalidated('http://example.org/resource/123');
    final categoryPredicate =
        IriTerm.prevalidated('http://example.org/category');

    group('basic functionality', () {
      test('generates simple group key from single property', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              SchemaNoteDigitalDocument.dateCreated,
              transforms: [
                RegexTransform(
                    r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${1}-${2}'),
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'2024-08'}));
      });

      test('generates group key without transforms', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(categoryPredicate),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, categoryPredicate, LiteralTerm.string('work')),
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'work'}));
      });

      test('returns null when required property is missing', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(SchemaNoteDigitalDocument.dateCreated),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, categoryPredicate, LiteralTerm.string('work')),
          // Missing the required dateCreated property
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, isEmpty);
      });

      test('uses missing value when property is absent', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              categoryPredicate,
              missingValue: 'uncategorized',
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
          // Missing the category property
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'uncategorized'}));
      });
    });

    group('hierarchical grouping', () {
      test('generates hierarchical group key with multiple levels', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              SchemaNoteDigitalDocument.dateCreated,
              hierarchyLevel: 1,
              transforms: [
                RegexTransform(
                    r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${1}'), // Year
              ],
            ),
            GroupingProperty(
              SchemaNoteDigitalDocument.dateCreated,
              hierarchyLevel: 2,
              transforms: [
                RegexTransform(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$',
                    r'${1}-${2}'), // Month
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'2024/2024-08'}));
      });

      test('handles multiple properties at the same hierarchy level', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              categoryPredicate, // http://example.org/category
              hierarchyLevel: 1,
            ),
            GroupingProperty(
              SchemaNoteDigitalDocument
                  .dateCreated, // https://schema.org/dateCreated
              hierarchyLevel: 1,
              transforms: [
                RegexTransform(
                    r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${1}-${2}'),
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, categoryPredicate, LiteralTerm.string('work')),
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
        ];

        final result = generator.generateGroupKeys(triples);
        // Properties are ordered lexicographically by IRI:
        // http://example.org/category < https://schema.org/dateCreated
        expect(result, equals({'work-2024-08'}));
      });

      test('processes hierarchy levels in correct order', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              SchemaNoteDigitalDocument.dateCreated,
              hierarchyLevel: 3, // Intentionally out of order
              transforms: [
                RegexTransform(
                    r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${3}'), // Day
              ],
            ),
            GroupingProperty(
              categoryPredicate,
              hierarchyLevel: 1,
            ),
            GroupingProperty(
              SchemaNoteDigitalDocument.dateCreated,
              hierarchyLevel: 2,
              transforms: [
                RegexTransform(
                    r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${2}'), // Month
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, categoryPredicate, LiteralTerm.string('work')),
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'work/08/15'}));
      });
    });

    group('regex transform integration', () {
      test('applies multiple transforms in order - first match wins', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              SchemaNoteDigitalDocument.dateCreated,
              transforms: [
                RegexTransform(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$',
                    r'${1}-${2}'), // ISO format
                RegexTransform(r'^([0-9]{4})/([0-9]{2})/([0-9]{2})$',
                    r'${1}-${2}'), // US format
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);

        // Test ISO format (first transform should match)
        final isoTriples = [
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
        ];
        expect(generator.generateGroupKeys(isoTriples), equals({'2024-08'}));

        // Test US format (second transform should match)
        final usTriples = [
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024/08/15')),
        ];
        expect(generator.generateGroupKeys(usTriples), equals({'2024-08'}));
      });

      test('handles complex transform patterns from specification', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              categoryPredicate,
              transforms: [
                RegexTransform(r'^project[-_]([a-zA-Z0-9]+)$', r'${1}'),
                RegexTransform(r'^proj[-_]([a-zA-Z0-9]+)$', r'${1}'),
                RegexTransform(r'^([a-zA-Z0-9]+)[-_]project$', r'${1}'),
                RegexTransform(r'^([a-zA-Z0-9]+)[-_]proj$', r'${1}'),
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);

        final testCases = [
          ('project-alpha', 'alpha'),
          ('proj_beta', 'beta'),
          ('gamma-project', 'gamma'),
          ('delta_proj', 'delta'),
        ];

        for (final (input, expected) in testCases) {
          final triples = [
            Triple(testSubject, categoryPredicate, LiteralTerm.string(input)),
          ];
          final result = generator.generateGroupKeys(triples);
          expect(result, equals({expected}), reason: 'Input: $input');
        }
      });

      test('uses original value when no transforms match', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              categoryPredicate,
              transforms: [
                RegexTransform(r'^number-(\d+)$', r'${1}'), // Won't match
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(
              testSubject, categoryPredicate, LiteralTerm.string('text-value')),
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'text-value'}));
      });
    });

    group('RDF term type handling', () {
      test('handles IRI objects', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              categoryPredicate,
              transforms: [
                RegexTransform(r'^http://example\.org/category/(.+)$', r'${1}'),
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, categoryPredicate,
              IriTerm.prevalidated('http://example.org/category/work')),
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'work'}));
      });

      test('handles literal with datatype', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              SchemaNoteDigitalDocument.dateCreated,
              transforms: [
                RegexTransform(
                    r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${1}-${2}'),
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'2024-08'}));
      });

      test('returns null for blank node objects', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(categoryPredicate),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, categoryPredicate, BlankNodeTerm()),
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, isEmpty);
      });
    });

    group('multiple triples handling', () {
      test(
          'generates multiple group keys when multiple property values present',
          () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(categoryPredicate),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, categoryPredicate, LiteralTerm.string('work')),
          Triple(
              testSubject,
              categoryPredicate,
              LiteralTerm.string(
                  'personal')), // Second value creates Cartesian product
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'work', 'personal'}));
      });

      test('handles mixed relevant and irrelevant triples', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              SchemaNoteDigitalDocument.dateCreated,
              transforms: [
                RegexTransform(
                    r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${1}-${2}'),
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, IriTerm.prevalidated('http://example.org/title'),
              LiteralTerm.string('Some Title')),
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
          Triple(
              testSubject,
              IriTerm.prevalidated('http://example.org/content'),
              LiteralTerm.string('Content here')),
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'2024-08'}));
      });
    });

    group('edge cases and error handling', () {
      test('handles empty triples list', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(categoryPredicate),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final result = generator.generateGroupKeys([]);

        expect(result, isEmpty);
      });

      test('handles empty triples list with missing values', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              categoryPredicate,
              missingValue: 'default',
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final result = generator.generateGroupKeys([]);

        expect(result, equals({'default'}));
      });

      test('handles configuration with no grouping properties', () {
        // This should not happen in practice due to assertion in GroupIndex constructor
        // The constructor should throw an assertion error for empty grouping properties
        expect(
            () => GroupIndex(
                  String, // dartType
                  String, // groupKeyType
                  groupingProperties: [], // This will fail assertion
                ),
            throwsA(isA<AssertionError>()));
      });

      test('handles mixed missing and present properties', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              categoryPredicate,
              hierarchyLevel: 1,
              missingValue: 'uncategorized',
            ),
            GroupingProperty(
              SchemaNoteDigitalDocument.dateCreated,
              hierarchyLevel: 2,
              transforms: [
                RegexTransform(
                    r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${1}-${2}'),
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
          // Missing category property
        ];

        final result = generator.generateGroupKeys(triples);
        expect(result, equals({'uncategorized/2024-08'}));
      });
    });

    group('performance and efficiency', () {
      test('efficiently organizes extractors by level', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(categoryPredicate, hierarchyLevel: 2),
            GroupingProperty(SchemaNoteDigitalDocument.dateCreated,
                hierarchyLevel: 1),
            GroupingProperty(
                IriTerm.prevalidated('http://example.org/priority'),
                hierarchyLevel: 2),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, categoryPredicate, LiteralTerm.string('work')),
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
          Triple(
              testSubject,
              IriTerm.prevalidated('http://example.org/priority'),
              LiteralTerm.string('high')),
        ];

        final result = generator.generateGroupKeys(triples);
        // Level 1: dateCreated, Level 2: category-priority (lexicographic IRI order)
        // http://example.org/category < http://example.org/priority
        expect(result, equals({'2024-08-15/work-high'}));
      });

      test('enforces lexicographic IRI ordering within same level', () {
        // Create predicates with clear lexicographic ordering
        final aProperty = IriTerm.prevalidated('http://example.org/a');
        final zProperty = IriTerm.prevalidated('http://example.org/z');

        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            // Intentionally declare in reverse alphabetical order
            GroupingProperty(zProperty, hierarchyLevel: 1),
            GroupingProperty(aProperty, hierarchyLevel: 1),
          ],
        );

        final generator = GroupKeyGenerator(config);
        final triples = [
          Triple(testSubject, aProperty, LiteralTerm.string('first')),
          Triple(testSubject, zProperty, LiteralTerm.string('last')),
        ];

        final result = generator.generateGroupKeys(triples);
        // Despite declaration order (z, a), lexicographic IRI ordering gives us (a, z)
        expect(result, equals({'first-last'}));
      });

      test('reuses compiled regex patterns', () {
        final config = GroupIndex(
          String, // dartType
          String, // groupKeyType
          groupingProperties: [
            GroupingProperty(
              SchemaNoteDigitalDocument.dateCreated,
              transforms: [
                RegexTransform(
                    r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$', r'${1}-${2}'),
              ],
            ),
          ],
        );

        final generator = GroupKeyGenerator(config);

        // Multiple calls should reuse the compiled patterns efficiently
        final triples1 = [
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-08-15')),
        ];
        final triples2 = [
          Triple(testSubject, SchemaNoteDigitalDocument.dateCreated,
              LiteralTerm.string('2024-09-20')),
        ];

        expect(generator.generateGroupKeys(triples1), equals({'2024-08'}));
        expect(generator.generateGroupKeys(triples2), equals({'2024-09'}));
      });
    });
  });
}
