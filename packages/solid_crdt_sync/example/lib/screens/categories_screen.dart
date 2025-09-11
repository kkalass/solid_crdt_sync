/// Screen for managing note categories.
library;

import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/categories_service.dart';

/// Screen for managing categories with local-first functionality.
///
/// Demonstrates:
/// - FullIndex with prefetch (categories should load immediately)
/// - CRUD operations on categories
/// - Simple, clean UI for category management
class CategoriesScreen extends StatefulWidget {
  final CategoriesService categoriesService;

  const CategoriesScreen({
    super.key,
    required this.categoriesService,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category>? categories;
  String? errorMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final loadedCategories =
          await widget.categoriesService.getAllCategories();

      setState(() {
        categories = loadedCategories;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load categories: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _showCategoryDialog({Category? category}) async {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final descriptionController =
        TextEditingController(text: category?.description ?? '');
    final colorController = TextEditingController(text: category?.color ?? '');
    final iconController = TextEditingController(text: category?.icon ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Category' : 'New Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name *',
                  hintText: 'Enter category name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional description',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  hintText: 'e.g. #FF0000, red, blue',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(
                  labelText: 'Icon',
                  hintText: 'e.g. 📝, work, home',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category name is required')),
                );
                return;
              }

              try {
                final newCategory = isEditing
                    ? category!.copyWith(
                        name: name,
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        color: colorController.text.trim().isEmpty
                            ? null
                            : colorController.text.trim(),
                        icon: iconController.text.trim().isEmpty
                            ? null
                            : iconController.text.trim(),
                      )
                    : widget.categoriesService.createCategory(
                        name: name,
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        color: colorController.text.trim().isEmpty
                            ? null
                            : colorController.text.trim(),
                        icon: iconController.text.trim().isEmpty
                            ? null
                            : iconController.text.trim(),
                      );

                await widget.categoriesService.saveCategory(newCategory);
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save category: $e')),
                  );
                }
              }
            },
            child: Text(isEditing ? 'Update' : 'Create'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadCategories();
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"?\n\n'
          'Notes in this category will become uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.categoriesService.deleteCategory(category.id);
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted category "${category.name}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete category: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          if (errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Error',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(errorMessage!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadCategories,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : categories!.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No categories yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first category to organize your notes',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCategories,
                        child: ListView.builder(
                          itemCount: categories!.length,
                          itemBuilder: (context, index) {
                            final category = categories![index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: category.color != null
                                      ? _parseColor(category.color!)
                                      : Theme.of(context).primaryColor,
                                  child: Text(
                                    category.icon ??
                                        category.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  category.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                subtitle: category.description != null
                                    ? Text(category.description!)
                                    : null,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'edit':
                                        _showCategoryDialog(category: category);
                                        break;
                                      case 'delete':
                                        _deleteCategory(category);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        tooltip: 'Add Category',
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _parseColor(String colorString) {
    // Simple color parsing - could be enhanced
    if (colorString.startsWith('#') && colorString.length == 7) {
      return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
    }

    // Basic color names
    switch (colorString.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pink;
      case 'teal':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
