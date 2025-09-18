import 'package:rdf_core/rdf_core.dart';
import 'package:solid_crdt_sync_core/src/config/resource_config.dart';
import 'package:solid_crdt_sync_core/src/index/group_index_subscription_manager.dart';
import 'package:solid_crdt_sync_core/src/index/index_config.dart';
import 'package:test/test.dart';
import '../test_models.dart';

void main() {
  group('GroupIndexSubscriptionManager', () {
    late SyncConfig config;
    late GroupIndexSubscriptionManager manager;

    setUp(() {
      final mapper = createTestMapper();

      // Create a test config with a GroupIndex using the correct constructor syntax
      config = SyncConfig(
        resources: [
          ResourceConfig(
            type: TestDocument,
            defaultResourcePath: '/documents/',
            crdtMapping: Uri.parse('http://example.org/crdt/document'),
            indices: [
              GroupIndex(
                TestDocumentGroupKey,
                localName: 'document-groups',
                groupingProperties: [
                  GroupingProperty(
                    TestVocab.testCategory, // Use same predicate as mapper
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      manager = GroupIndexSubscriptionManager(
        config: config,
        mapper: mapper,
      );
    });

    group('subscribeToGroupIndex', () {
      test('successfully subscribes to valid group index', () async {
        final groupKey = TestDocumentGroupKey(category: 'work');

        final groupIdentifiers =
            await manager.getGroupIdentifiers<TestDocumentGroupKey>(
          groupKey,
          localName: 'document-groups',
        );

        expect(groupIdentifiers, isNotEmpty);
        expect(groupIdentifiers.first, equals('work'));
      });

      test('Creates correct group identifiers for DateTimeGroupKey', () async {
        final manager = GroupIndexSubscriptionManager(
            config: SyncConfig(resources: [
              ResourceConfig(
                type: TestDocument,
                crdtMapping: Uri.parse('http://example.org/crdt/document'),
                indices: [
                  GroupIndex(
                    DateTimeGroupKey,
                    groupingProperties: [
                      GroupingProperty(
                          IriTerm('https://test.example/vocab#createdAt'),
                          transforms: [
                            RegexTransform(
                                r'^([0-9]{4})-([0-9]{2})-([0-9]{2}).*',
                                r'${1}-${2}')
                          ]),
                    ],
                  ),
                ],
              ),
            ]),
            mapper: createTestMapper());

        final groupIdentifiers =
            await manager.getGroupIdentifiers<DateTimeGroupKey>(
          DateTimeGroupKey(createdAt: DateTime(2023, 10, 5)),
        );

        expect(groupIdentifiers, isNotEmpty);
        expect(groupIdentifiers.single, equals('2023-10'));
      });

      test('throws exception for unknown group key type', () async {
        expect(
          () => manager.getGroupIdentifiers<String>('invalid',
              localName: 'document-groups'),
          throwsA(isA<GroupIndexSubscriptionException>()),
        );
      });

      test('throws exception for unknown local name', () async {
        final groupKey = TestDocumentGroupKey(category: 'work');

        expect(
          () => manager.getGroupIdentifiers<TestDocumentGroupKey>(groupKey,
              localName: 'unknown-index'),
          throwsA(isA<GroupIndexSubscriptionException>()),
        );
      });

      test('throws exception when RDF conversion fails', () async {
        // This should fail because String is not a mapped type
        expect(
          () => manager.getGroupIdentifiers<String>('invalid',
              localName: 'document-groups'),
          throwsA(isA<GroupIndexSubscriptionException>()),
        );
      });
    });

    group('configuration validation', () {
      test('gets all configured group key types', () {
        final types = manager.getConfiguredGroupKeyTypes();
        expect(types, contains(TestDocumentGroupKey));
        expect(types.length, equals(1));
      });

      test('validates group key type registration', () {
        // This should throw for an unregistered type
        expect(
          () => manager.validateGroupKeyType<String>(),
          throwsA(isA<GroupIndexSubscriptionException>()),
        );

        // For registered types, we can test that they can be converted to RDF
        // (which is the main validation we need)
        final groupKey = TestDocumentGroupKey(category: 'work');
        expect(
          () => manager.getGroupIdentifiers(groupKey,
              localName: 'document-groups'),
          returnsNormally,
        );
      });
    });
  });
}
