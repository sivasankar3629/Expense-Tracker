import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/expense_store.dart';
import '../widgets/category_dialog.dart';
import '../widgets/category_icon.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, required this.store});

  final ExpenseStore store;

  Future<void> _confirmDelete(BuildContext context, ExpenseCategory category) async {
    final count = store.expenseCountForCategory(category.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: count == 0
            ? null
            : Text(
                '${count == 1 ? '1 expense uses' : '$count expenses use'} this category. '
                '${count == 1 ? 'It' : 'They'}’ll be kept, just without a category.',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) store.deleteCategory(category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final categories = [...store.categories]
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          if (categories.isEmpty) return const _EmptyState();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < categories.length; i++) ...[
                      if (i > 0) const Divider(indent: 72),
                      _buildTile(context, categories[i]),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryDialog(context, store: store),
        icon: const Icon(Icons.add),
        label: const Text('New category'),
      ),
    );
  }

  Widget _buildTile(BuildContext context, ExpenseCategory category) {
    final count = store.expenseCountForCategory(category.id);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      leading: CategoryIcon.of(category),
      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(count == 1 ? '1 expense' : '$count expenses'),
      onTap: () => showCategoryDialog(context, store: store, initial: category),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
        onPressed: () => _confirmDelete(context, category),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.category_outlined, size: 40, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text(
              'No categories yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Create categories like Food or Rent to see where your money goes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
