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
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  /// Filter notes by category using reactive streams
  void _filterByCategory(String? categoryId) {
    if (categoryId == 'null') {
      categoryId = null; // Clear filter
    }
    // Update the service filter - this will automatically update the stream
    widget.notesService.setCategoryFilter(categoryId);

    // Demonstrate smart loading strategy decisions
    if (categoryId != null) {
      _applySmartLoadingStrategy(categoryId);
    }

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

  // FIXME this method probably is intended well, but it seems to be wrong. Need to think about the group prefetching.
  /// Demonstrate application-level smart loading strategy decisions
  Future<void> _applySmartLoadingStrategy(String categoryId) async {
    // This demonstrates how the application can decide between different loading strategies
    // based on user behavior, category type, or other factors

    // For now, we'll use a simplified strategy based on categoryId
    // TODO: Look up the actual category to determine the best strategy
    if (categoryId.contains('work')) {
      // Work category: User likely to browse multiple items - prefetch full data
      await widget.notesService.prefetchGroupData(categoryId);
      print(
          'Strategy: Prefetching full data for work category (heavy usage expected)');
    } else if (categoryId.contains('archive')) {
      // Archive category: User likely just browsing - load index only
      await widget.notesService.ensureGroupIndexLoaded(categoryId);
      print(
          'Strategy: Index-only for archived category (light browsing expected)');
    } else {
      // Other categories: Balanced approach - ensure index, prefetch on demand
      await widget.notesService.ensureGroupIndexLoaded(categoryId);
      print(
          'Strategy: Index-first for $categoryId category (balanced approach)');
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
      // Notes will update automatically via reactive streams

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
          categoriesService: widget.categoriesService,
          // Notes will update automatically via reactive streams
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
            categoriesService: widget.categoriesService,
            note: note,
            // Notes will update automatically via reactive streams
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
      // Notes will update automatically via reactive streams
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
          StreamBuilder<String?>(
            stream: widget.notesService.categoryFilterStream,
            builder: (context, filterSnapshot) {
              final selectedFilter = filterSnapshot.data;
              return StreamBuilder<List<models.Category>>(
                stream: widget.categoriesService.getAllCategories(),
                builder: (context, categoriesSnapshot) {
                  final categories = categoriesSnapshot.data ?? [];
                  return PopupMenuButton<String?>(
                    icon: Icon(selectedFilter != null
                        ? Icons.filter_alt
                        : Icons.filter_alt_outlined),
                    tooltip: 'Filter by Category',
                    onSelected: _filterByCategory,
                    itemBuilder: (context) => [
                      const PopupMenuItem<String?>(
                        value: 'null',
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
      body: StreamBuilder<List<NoteIndexEntry>>(
        stream: widget.notesService.filteredNoteIndexEntries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Force refresh by changing filter
                      final currentFilter =
                          widget.notesService.currentCategoryFilter;
                      widget.notesService.setCategoryFilter(null);
                      widget.notesService.setCategoryFilter(currentFilter);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final noteEntries = snapshot.data ?? [];
          return noteEntries.isEmpty
              ? _buildEmptyState()
              : _buildNotesList(noteEntries);
        },
      ),
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

  Widget _buildNotesList(List<NoteIndexEntry> noteEntries) {
    return ListView.builder(
      itemCount: noteEntries.length,
      itemBuilder: (context, index) {
        final noteEntry = noteEntries[index];
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
