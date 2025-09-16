/// Screen for creating and editing individual notes.
library;

import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/category.dart' as models;
import '../services/notes_service.dart';
import '../services/categories_service.dart';
import '../utils/optional.dart';

class NoteEditorScreen extends StatefulWidget {
  final NotesService notesService;
  final CategoriesService categoriesService;
  final Note? note;

  const NoteEditorScreen({
    super.key,
    required this.notesService,
    required this.categoriesService,
    this.note,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagController;
  late Set<String> _tags;
  late String? _selectedCategoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _tagController = TextEditingController();
    _tags = Set.from(widget.note?.tags ?? <String>{});
    _selectedCategoryId = widget.note?.categoryId;

    // Debug print to see if tags are being loaded correctly
    print('Initializing note editor with ${_tags.length} tags: $_tags');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final note = widget.note?.copyWith(
            title: _titleController.text,
            content: _contentController.text,
            tags: _tags,
            categoryId: Optional(_selectedCategoryId),
          ) ??
          widget.notesService
              .createNote(
                title: _titleController.text,
                content: _contentController.text,
                tags: _tags,
              )
              .copyWith(categoryId: Optional(_selectedCategoryId));

      await widget.notesService.saveNote(note);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: $error')),
        );
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Note' : 'New Note'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveNote,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 16),

            // Content field
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),

            const SizedBox(height: 16),

            // Category selection
            StreamBuilder<List<models.Category>>(
              stream: widget.categoriesService.getAllCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final categories = snapshot.data ?? [];
                return DropdownButtonFormField<String?>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No Category'),
                    ),
                    ...categories.map((category) => DropdownMenuItem<String>(
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
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // Tags section
            const Text(
              'Tags',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 8),

            // Tag input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Add a tag...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tags display
            if (_tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => _removeTag(tag),
                        ))
                    .toList(),
              ),
            ] else ...[
              const Text(
                'No tags added',
                style: TextStyle(color: Colors.grey),
              ),
            ],

            const SizedBox(height: 16),

            // Local-first info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withAlpha(100)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Changes are saved locally and will sync automatically when connected to your Solid Pod.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
}
