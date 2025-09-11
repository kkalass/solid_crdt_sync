import 'package:test/test.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:solid_crdt_sync_core/src/config/resource_config.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';

import '../test_models.dart';

void main() {
  group('SyncConfig Validation', () {
    late RdfMapper mockMapper;

    setUp(() {
      mockMapper = createTestMapper();
    });

    group('Resource Uniqueness Validation', () {
      test('should pass with unique Dart types', () {
        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: TestDocument,
              defaultResourcePath: '/data/documents',
              crdtMapping: Uri.parse('https://example.com/document.ttl'),
            ),
            ResourceConfig(
              type: TestCategory,
              defaultResourcePath: '/data/categories',
              crdtMapping: Uri.parse('https://example.com/category.ttl'),
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should fail with duplicate Dart types', () {
        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: TestDocument,
              defaultResourcePath: '/data/documents1',
              crdtMapping: Uri.parse('https://example.com/document1.ttl'),
            ),
            ResourceConfig(
              type: TestDocument, // Duplicate!
              defaultResourcePath: '/data/documents2',
              crdtMapping: Uri.parse('https://example.com/document2.ttl'),
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isFalse);
        expect(result.errors, hasLength(1));
        expect(
            result.errors.first.message, contains('Duplicate resource type'));
        expect(result.errors.first.message, contains('TestDocument'));
      });

      test('should fail with RDF type IRI collisions', () {
        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: ConflictingTypeA,
              defaultResourcePath: '/data/typeA',
              crdtMapping: Uri.parse('https://example.com/typeA.ttl'),
            ),
            ResourceConfig(
              type: ConflictingTypeB,
              defaultResourcePath: '/data/typeB',
              crdtMapping: Uri.parse('https://example.com/typeB.ttl'),
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isFalse);
        expect(result.errors, hasLength(1));
        expect(
            result.errors.first.message, contains('RDF type IRI collision'));
        expect(result.errors.first.message, contains('ConflictingTypeA'));
        expect(result.errors.first.message, contains('ConflictingTypeB'));
      });

      test('should fail when type has no RDF IRI mapping', () {
        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: UnmappedType,
              defaultResourcePath: '/data/unmapped',
              crdtMapping: Uri.parse('https://example.com/unmapped.ttl'),
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isFalse);
        expect(result.errors, hasLength(1));
        expect(
            result.errors.first.message, contains('No RDF type IRI found'));
        expect(result.errors.first.message, contains('UnmappedType'));
        expect(result.errors.first.message, contains('@PodResource'));
      });
    });

    group('Path Validation', () {
      test('should fail with empty resource path', () {
        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: TestDocument,
              defaultResourcePath: '', // Empty!
              crdtMapping: Uri.parse('https://example.com/document.ttl'),
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isFalse);
        expect(
            result.errors
                .any((e) => e.message.contains('path cannot be empty')),
            isTrue);
      });

      test('should fail with relative resource path', () {
        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: TestDocument,
              defaultResourcePath: 'data/documents', // No leading slash!
              crdtMapping: Uri.parse('https://example.com/document.ttl'),
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isFalse);
        expect(
            result.errors
                .any((e) => e.message.contains('must start with "/"')),
            isTrue);
      });

      test('should warn about duplicate resource paths', () {
        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: TestDocument,
              defaultResourcePath: '/data/shared',
              crdtMapping: Uri.parse('https://example.com/document.ttl'),
            ),
            ResourceConfig(
              type: TestCategory,
              defaultResourcePath: '/data/shared', // Same path!
              crdtMapping: Uri.parse('https://example.com/category.ttl'),
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isTrue);
        expect(result.warnings, hasLength(1));
        expect(result.warnings.first.message,
            contains('Multiple resource types use the same default path'));
      });
    });

    group('CRDT Mapping Validation', () {
      test('should fail with relative URI', () {
        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: TestDocument,
              defaultResourcePath: '/data/documents',
              crdtMapping: Uri.parse('mappings/document.ttl'), // Relative!
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isFalse);
        expect(
            result.errors.any((e) => e.message.contains('must be absolute')),
            isTrue);
      });

      test('should warn about HTTP (non-HTTPS) URI', () {
        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: TestDocument,
              defaultResourcePath: '/data/documents',
              crdtMapping: Uri.parse(
                  'http://example.com/document.ttl'), // HTTP not HTTPS!
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isTrue);
        expect(result.warnings, isNotEmpty);
        expect(
            result.warnings
                .any((e) => e.message.contains('should use HTTPS')),
            isTrue);
      });
    });

    group('Index Configuration Validation', () {
      test('should fail with empty index local name', () {
        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: TestDocument,
              defaultResourcePath: '/data/documents',
              crdtMapping: Uri.parse('https://example.com/document.ttl'),
              indices: [
                FullIndex(TestDocument, localName: ''), // Empty local name!
              ],
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isFalse);
        expect(
            result.errors
                .any((e) => e.message.contains('local name cannot be empty')),
            isTrue);
      });

      test('should fail with duplicate local names for same index item type',
          () {
        final testIndexItem = IndexItem(TestDocument, []);

        final config = SyncConfig(
          resources: [
            ResourceConfig(
              type: TestDocument,
              defaultResourcePath: '/data/documents',
              crdtMapping: Uri.parse('https://example.com/document.ttl'),
              indices: [
                FullIndex(TestDocument,
                    localName: 'shared', item: testIndexItem),
              ],
            ),
            ResourceConfig(
              type: TestCategory,
              defaultResourcePath: '/data/categories',
              crdtMapping: Uri.parse('https://example.com/category.ttl'),
              indices: [
                FullIndex(TestCategory,
                    localName: 'shared',
                    item: testIndexItem), // Same local name, same item type!
              ],
            ),
          ],
        );

        final result = config.validate(mockMapper);
        expect(result.isValid, isFalse);
        expect(
            result.errors
                .any((e) => e.message.contains('Duplicate index local name')),
            isTrue);
      });

      test('should fail when GroupIndex has no grouping properties', () {
        // Test that the constructor itself prevents creating invalid GroupIndex
        expect(
          () => GroupIndex(
            TestDocument,
            item: IndexItem(TestDocument, []),
            groupingProperties: [], // Empty!
          ),
          throwsA(isA<AssertionError>()),
        );

        // The validation would catch this if the constructor allowed it
        // But since the constructor prevents it, we test the constructor behavior instead
      });
    });
  });
}
