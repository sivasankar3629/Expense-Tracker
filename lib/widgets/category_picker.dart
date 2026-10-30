import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/expense_store.dart';
import 'category_dialog.dart';
import 'category_style.dart';

/// Wrapping category chips, most-used first, with "New category" at the end.
/// Chips stay put when picked, so the one you tapped is where you left it.
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
    // Picked: solid in the category's colour with a tick, so it stands out
    // from the pale unpicked chips at a glance.
    final ink = selected
        ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black87)
        : categoryInk(context, color);
    return FilterChip(
      avatar: Icon(selected ? Icons.check_rounded : category.icon, size: 18, color: ink),
      label: Text(category.name),
      selected: selected,
      showCheckmark: false,
      backgroundColor: categorySurface(context, color),
      selectedColor: color,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w700),
      side: BorderSide(color: selected ? color : color.withValues(alpha: 0.25)),
      onSelected: (_) => onTap(),
    );
  }
}
