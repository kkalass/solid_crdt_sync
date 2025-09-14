/// Main screen showing list of notes with connect and sync options.
library;

import 'package:flutter/material.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';

import '../models/note_index_entry.dart';
import '../models/category.dart' as models;
import '../services/notes_service.dart';
import '../services/categories_service.dart';
import 'categories_screen.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends StatefulWidget {
  final SolidCrdtSync syncSystem;
  final NotesService notesService;
  final CategoriesService categoriesService;

  const NotesListScreen({
    super.key,
    required this.syncSystem,
    required this.notesService,
    required this.categoriesService,
  });

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<NoteIndexEntry> _noteEntries = [];
  List<models.Category> _categories = [];
  bool _loading = true;
  bool _isConnected = false;
  String? _selectedCategoryFilter;

  Stream<List<models.Category>> get _categoriesStream =>
      widget.categoriesService.getAllCategories();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadCategories();
    _checkConnectionStatus();
  }

  Future<void> _loadCategories() async {
    try {
      // Convert stream to list for now to maintain existing behavior
      final categories = await widget.categoriesService.getAllCategories().first;
      setState(() {
        _categories = categories;
      });
    } catch (error) {
      // Categories loading failed - continue without them
      print('Error loading categories: $error');
    }
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      List<NoteIndexEntry> noteEntries;
      
      if (_selectedCategoryFilter != null) {
        // Demonstrate group loading: ensure category group is available before browsing
        noteEntries = await widget.notesService
            .getNoteIndexEntriesByCategoryWithLoading(_selectedCategoryFilter!);
      } else {
        // Load all note index entries for browsing
        noteEntries = await widget.notesService.getAllNoteIndexEntries();
      }
      
      setState(() {
        _noteEntries = noteEntries;
        _loading = false;
      });
    } catch (error) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notes: $error')),
        );
      }
    }
  }

  /// Filter notes by category - demonstrates group loading behavior
  Future<void> _filterByCategory(String? categoryId) async {
    setState(() {
      _selectedCategoryFilter = categoryId;
    });
    
    // Demonstrate smart loading strategy decisions
    if (categoryId != null) {
      await _applySmartLoadingStrategy(categoryId);
    }
    
    // Reload notes with the new filter
    await _loadNotes();
    
    // Show feedback about group loading (for demonstration)
    if (mounted && categoryId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded notes for category: $categoryId\n'
                      'Group loading ensures index is available.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Demonstrate application-level smart loading strategy decisions
  Future<void> _applySmartLoadingStrategy(String categoryId) async {
    // This demonstrates how the application can decide between different loading strategies
    // based on user behavior, category type, or other factors
    
    // Find the category to determine strategy
    final category = _categories.cast<models.Category?>().firstWhere(
      (cat) => cat?.id == categoryId,
      orElse: () => null,
    );
    
    if (category?.icon == 'work') {
      // Work category: User likely to browse multiple items - prefetch full data
      await widget.notesService.prefetchGroupData(categoryId);
      print('Strategy: Prefetching full data for work category (heavy usage expected)');
    } else if (category?.icon == 'archive') {
      // Archive category: User likely just browsing - load index only
      await widget.notesService.ensureGroupIndexLoaded(categoryId);
      print('Strategy: Index-only for archived category (light browsing expected)');
    } else {
      // Other categories: Balanced approach - ensure index, prefetch on demand
      await widget.notesService.ensureGroupIndexLoaded(categoryId);
      print('Strategy: Index-first for ${category?.name ?? categoryId} category (balanced approach)');
    }
  }

  Future<void> _checkConnectionStatus() async {
    // TODO: Check if connected to Solid Pod
    // final connected = await widget.syncSystem.isConnected();
    // setState(() => _isConnected = connected);
  }

  Future<void> _connectToSolid() async {
    try {
      // TODO: Show login screen and connect
      // final authProvider = SolidAuthProviderImpl();
      // await widget.syncSystem.connectToSolid(authProvider);
      // setState(() => _isConnected = true);

      // For now, show a placeholder
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solid connection not yet implemented')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $error')),
        );
      }
    }
  }

  Future<void> _sync() async {
    if (!_isConnected) return;

    try {
      // TODO: Trigger manual sync
      // await widget.syncSystem.sync();
      await _loadNotes(); // Reload notes after sync

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $error')),
        );
      }
    }
  }

  void _openCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoriesScreen(
          categoriesService: widget.categoriesService,
        ),
      ),
    );
  }

  void _createNote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          notesService: widget.notesService,
          onSaved: _loadNotes,
        ),
      ),
    );
  }

  Future<void> _editNote(NoteIndexEntry noteEntry) async {
    // Load full note data on-demand for editing
    final note = await widget.notesService.getNote(noteEntry.id);
    if (note == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Note not found: ${noteEntry.id}')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoteEditorScreen(
            notesService: widget.notesService,
            note: note,
            onSaved: _loadNotes,
          ),
        ),
      );
    }
  }

  Future<void> _deleteNote(NoteIndexEntry noteEntry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${noteEntry.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.notesService.deleteNote(noteEntry.id);
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Notes'),
        elevation: 0,
        actions: [
          // Category filter dropdown - demonstrates group loading
          StreamBuilder<List<models.Category>>(
            stream: _categoriesStream,
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              return PopupMenuButton<String?>(
                icon: Icon(_selectedCategoryFilter != null 
                    ? Icons.filter_alt 
                    : Icons.filter_alt_outlined),
                tooltip: 'Filter by Category',
                onSelected: _filterByCategory,
                itemBuilder: (context) => [
                  const PopupMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.clear_all),
                        SizedBox(width: 8),
                        Text('All Notes'),
                      ],
                    ),
                  ),
                  if (categories.isNotEmpty) const PopupMenuDivider(),
                  // Dynamic categories from the reactive categories service
                  ...categories.map((category) => PopupMenuItem<String>(
                    value: category.id,
                    child: Row(
                      children: [
                        Icon(_getCategoryIcon(category.icon)),
                        const SizedBox(width: 8),
                        Text(category.name),
                      ],
                    ),
                  )),
                ],
              );
            },
          ),
          // Categories button
          IconButton(
            onPressed: _openCategories,
            icon: const Icon(Icons.category),
            tooltip: 'Manage Categories',
          ),
          // Connect to Solid Pod button
          IconButton(
            onPressed: _isConnected ? null : _connectToSolid,
            icon: Icon(_isConnected ? Icons.cloud_done : Icons.cloud_off),
            tooltip: _isConnected
                ? 'Connected to Solid Pod'
                : 'Connect to Solid Pod',
          ),
          // Manual sync button (only when connected)
          if (_isConnected)
            IconButton(
              onPressed: _sync,
              icon: const Icon(Icons.sync),
              tooltip: 'Sync now',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _noteEntries.isEmpty
              ? _buildEmptyState()
              : _buildNotesList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        tooltip: 'Add Note',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No notes yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to create your first note',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (!_isConnected) ...[
            const Text(
              'Working locally - connect to Solid Pod to sync across devices',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    return ListView.builder(
      itemCount: _noteEntries.length,
      itemBuilder: (context, index) {
        final noteEntry = _noteEntries[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(
              noteEntry.name.isEmpty ? 'Untitled' : noteEntry.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: noteEntry.name.isEmpty ? Colors.grey : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note: content not available in index entries - this is expected
                // Users need to tap to load full note for content
                const SizedBox(height: 4),
                Text(
                  'Tap to view content...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (noteEntry.keywords.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: noteEntry.keywords
                        .take(3)
                        .map((keyword) => Chip(
                              label: Text(keyword,
                                  style: const TextStyle(fontSize: 11)),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Modified ${_formatDate(noteEntry.dateModified)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            onTap: () => _editNote(noteEntry),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: const Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteNote(noteEntry);
                }
              },
            ),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work;
      case 'personal':
        return Icons.person;
      case 'archive':
        return Icons.archive;
      case 'folder':
        return Icons.folder;
      default:
        return Icons.category;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
