/// Main screen showing list of notes with connect and sync options.
library;

import 'package:flutter/material.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';

import '../models/note.dart';
import '../services/notes_service.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends StatefulWidget {
  final SolidCrdtSync syncSystem;
  final NotesService notesService;
  
  const NotesListScreen({
    super.key,
    required this.syncSystem,
    required this.notesService,
  });

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Note> _notes = [];
  bool _loading = true;
  bool _isConnected = false;
  
  @override
  void initState() {
    super.initState();
    _loadNotes();
    _checkConnectionStatus();
  }
  
  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      final notes = await widget.notesService.getAllNotes();
      setState(() {
        _notes = notes;
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
  
  void _editNote(Note note) {
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
  
  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
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
      await widget.notesService.deleteNote(note.id);
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
          // Connect to Solid Pod button
          IconButton(
            onPressed: _isConnected ? null : _connectToSolid,
            icon: Icon(_isConnected ? Icons.cloud_done : Icons.cloud_off),
            tooltip: _isConnected ? 'Connected to Solid Pod' : 'Connect to Solid Pod',
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
          : _notes.isEmpty
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
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(
              note.title.isEmpty ? 'Untitled' : note.title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: note.title.isEmpty ? Colors.grey : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: note.tags.take(3).map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Modified ${_formatDate(note.modifiedAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            onTap: () => _editNote(note),
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
                  _deleteNote(note);
                }
              },
            ),
          ),
        );
      },
    );
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