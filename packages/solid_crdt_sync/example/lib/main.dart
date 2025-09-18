/// Personal Notes App - Simple local-first application using solid_crdt_sync.
///
/// Demonstrates:
/// - Local-first operation (works offline)
/// - Optional Solid Pod connection
/// - CRDT conflict resolution
/// - Simple, clean UI
library;

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:personal_notes_app/init_rdf_mapper.g.dart';
import 'package:personal_notes_app/models/category.dart';
import 'package:personal_notes_app/models/note.dart';
import 'package:personal_notes_app/models/note_group_key.dart';
import 'package:personal_notes_app/models/note_index_entry.dart';
import 'package:personal_notes_app/vocabulary/personal_notes_vocab.dart';
import 'package:rdf_vocabularies_schema/schema.dart';
import 'package:solid_crdt_sync_auth/solid_crdt_sync_auth.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';
import 'package:solid_crdt_sync_drift/solid_crdt_sync_drift.dart';

import 'screens/notes_list_screen.dart';
import 'services/categories_service.dart';
import 'services/notes_service.dart';
import 'storage/database.dart' show AppDatabase;
import 'storage/repositories.dart' show CategoryRepository, NoteRepository;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const PersonalNotesApp());
}

/// Initialize the CRDT sync system with resource-focused configuration.
///
/// This configures:
/// - Local storage backend (Drift/SQLite)
/// - RDF mapper with user dependencies
/// - All resources (Note, Category) with their paths, indices, and CRDT mappings
/// - Returns a fully configured sync system
Future<SolidCrdtSync> initializeSolidCrdtSync(
    {DriftWebOptions? driftWeb, DriftNativeOptions? driftNative}) async {
  const baseUrl =
      'https://kkalass.github.io/solid_crdt_sync/example/personal_notes_app/mappings';

  return await SolidCrdtSync.setup(
    /* control behaviour and system integration */
    storage: DriftStorage(web: driftWeb, native: driftNative),
    auth: SolidAuth(),
    mapperInitializer: (context) => initRdfMapper(
        $resourceIriFactory: context.resourceIriFactory,
        $resourceRefFactory: context.resourceRefFactory),

    /* resource-focused configuration */
    config: SyncConfig(
      resources: [
        // Configure Note resource with grouping index by category
        ResourceConfig(
          type: Note,
          crdtMapping: Uri.parse('$baseUrl/note-v1.ttl'),
          indices: [
            GroupIndex(NoteGroupKey,
                item: IndexItem(NoteIndexEntry, {
                  SchemaNoteDigitalDocument.name,
                  SchemaNoteDigitalDocument.dateCreated,
                  SchemaNoteDigitalDocument.dateModified,
                  SchemaNoteDigitalDocument.keywords,
                  PersonalNotesVocab.belongsToCategory
                }),
                groupingProperties: [
                  GroupingProperty(SchemaNoteDigitalDocument.dateCreated,
                      transforms: [
                        RegexTransform(r'^([0-9]{4})-([0-9]{2})-([0-9]{2}).*',
                            r'${1}-${2}')
                      ])
                ]),
          ],
        ),

        // Configure Category resource with full index
        ResourceConfig(
          type: Category,
          crdtMapping: Uri.parse('$baseUrl/category-v1.ttl'),
          indices: [FullIndex(itemFetchPolicy: ItemFetchPolicy.prefetch)],
        ),
      ],
    ),
  );
}

class PersonalNotesApp extends StatelessWidget {
  const PersonalNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer>
    with WidgetsBindingObserver {
  SolidCrdtSync? syncSystem;
  AppDatabase? appDatabase;
  CategoryRepository? categoryRepository;
  NoteRepository? noteRepository;
  NotesService? notesService;
  CategoriesService? categoriesService;
  String? errorMessage;
  bool isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  /// Clean up all app resources
  Future<void> _cleanupResources() async {
    categoryRepository?.dispose();
    noteRepository?.dispose();
    await appDatabase?.close();
    await syncSystem?.close();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up resources when the widget is disposed
    _cleanupResources();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Close resources when the app is being terminated
    if (state == AppLifecycleState.detached) {
      _cleanupResources();
    }
  }

  Future<void> _initializeApp() async {
    try {
      final DriftWebOptions webOptions = DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      );

      // Initialize the CRDT sync system
      final syncSys = await initializeSolidCrdtSync(driftWeb: webOptions);

      // Initialize app database (Drift)
      final appDb = AppDatabase(web: webOptions);

      // Initialize repositories with database DAOs, cursor DAO, and sync system, hydrating existing data
      final categoryRepo = await CategoryRepository.create(
          appDb.categoryDao, appDb.cursorDao, syncSys);
      final noteRepo = await NoteRepository.create(
          appDb.noteDao, appDb.noteIndexEntryDao, appDb.cursorDao, syncSys);

      // Initialize services with repositories
      final notesSvc = NotesService(noteRepo);
      final categoriesSvc = CategoriesService(categoryRepo);

      setState(() {
        syncSystem = syncSys;
        appDatabase = appDb;
        categoryRepository = categoryRepo;
        noteRepository = noteRepo;
        notesService = notesSvc;
        categoriesService = categoriesSvc;
        isInitializing = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to initialize app: $e';
        isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initializing Personal Notes...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    errorMessage = null;
                    isInitializing = true;
                  });
                  _initializeApp();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Successfully initialized - show the main app
    return NotesListScreen(
      notesService: notesService!,
      categoriesService: categoriesService!,
    );
  }
}
