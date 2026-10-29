import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/expense_store.dart';
import 'category_dialog.dart';
import 'category_style.dart';

/// Wrapping category chips with "New category" at the end.
/// Tapping the selected chip again clears it, since a category is optional.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.store,
    required this.selectedId,
    required this.onChanged,
  });

  final ExpenseStore store;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  Future<void> _create(BuildContext context) async {
    final created = await showCategoryDialog(context, store: store);
    if (created != null) onChanged(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final categories = store.categoriesByUse;
        // Keep the current pick visible at the front even if it's rarely used.
        final selected = store.categoryById(selectedId);
        if (selected != null) {
          categories
            ..removeWhere((c) => c.id == selected.id)
            ..insert(0, selected);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Category',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final category in categories) ...[
                  _CategoryChip(
                    category: category,
                    selected: category.id == selectedId,
                    onTap: () => onChanged(category.id == selectedId ? null : category.id),
                  ),
                ],
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(categories.isEmpty ? 'Create a category' : 'New category'),
                  onPressed: () => _create(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.selected, required this.onTap});

  final ExpenseCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryAccent(category.color);
    return FilterChip(
      avatar: Icon(category.icon, size: 18, color: categoryInk(context, color)),
      label: Text(category.name),
      selected: selected,
      showCheckmark: false,
      backgroundColor: categorySurface(context, color),
      selectedColor: Color.lerp(categorySurface(context, color), color, 0.2),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: categoryInk(context, color), fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: selected ? categoryInk(context, color) : color.withValues(alpha: 0.25), width: selected ? 1.5 : 1),
      onSelected: (_) => onTap(),
    );
  }
}
