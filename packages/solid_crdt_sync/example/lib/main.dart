/// Personal Notes App - Simple local-first application using solid_crdt_sync.
///
/// Demonstrates:
/// - Local-first operation (works offline)
/// - Optional Solid Pod connection
/// - CRDT conflict resolution
/// - Simple, clean UI
library;

import 'package:flutter/material.dart';
import 'package:personal_notes_app/models/note.dart';
import 'package:personal_notes_app/models/note_index_entry.dart';
import 'package:rdf_mapper/rdf_mapper.dart';
import 'package:rdf_vocabularies_schema/schema.dart';
import 'package:solid_crdt_sync_auth/solid_crdt_sync_auth.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';
import 'package:solid_crdt_sync_drift/solid_crdt_sync_drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'mapper_config.dart';
import 'screens/notes_list_screen.dart';
import 'services/notes_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Example: How to use index updates stream for efficient note browsing
  // final sync = await initializeSolidCrdtSync();
  // sync.indexUpdatesStream<NoteIndexEntry>().listen((entry) {
  //   print('Note index updated: ${entry.title} (${entry.createdAt})');
  //   // Update UI with lightweight index data for fast browsing
  // });
  
  runApp(const PersonalNotesApp());
}

/// Initialize the CRDT sync system with all required components.
///
/// This configures:
/// - Local storage backend (Drift/SQLite)
/// - RDF mapper with user dependencies
/// - CRDT mapping files for conflict resolution
/// - Returns a fully configured sync system
Future<SolidCrdtSync> initializeSolidCrdtSync() async {
  final DriftWebOptions webOptions = DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  );

  return await SolidCrdtSync.setup(
    /* control behaviour and system integration */
    storage: DriftStorage(web: webOptions),
    auth: SolidAuth(),
    indices: [
      GroupIndex(Note, groupingProperties: [
        GroupingProperty(SchemaNoteDigitalDocument.dateCreated,
            format: 'yyyy-MM')
      ])
    ],

    /* bind to generated code */
    mapperInitializer: createMapperInitializer(),
    crdt: createCrdtMappings(
        baseUrl:
            'https://kkalass.github.io/solid_crdt_sync/example/personal_notes_app/mappings'),
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
  NotesService? notesService;
  String? errorMessage;
  bool isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up resources when the widget is disposed
    syncSystem?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Close resources when the app is being terminated
    if (state == AppLifecycleState.detached) {
      syncSystem?.close();
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize the CRDT sync system
      final syncSys = await initializeSolidCrdtSync();

      // Initialize notes service
      final notesSvc = NotesService(syncSys);

      setState(() {
        syncSystem = syncSys;
        notesService = notesSvc;
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
      syncSystem: syncSystem!,
      notesService: notesService!,
    );
  }
}
