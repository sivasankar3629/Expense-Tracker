import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/expense_store.dart';
import '../widgets/budget.dart';
import '../widgets/category_dialog.dart';
import '../widgets/category_icon.dart';
import '../widgets/category_style.dart';
import '../widgets/expense_list.dart';
import '../widgets/currency_scope.dart';

/// One category's expenses and budget; null [categoryId] shows the
/// uncategorised expenses.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.store, required this.categoryId});

  final ExpenseStore store;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final category = store.categoryById(categoryId);
        if (categoryId != null && category == null) {
          // Deleted (e.g. from its edit dialog, or on another phone): nothing to show.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold();
        }
        final expenses = store.expensesInCategory(categoryId);
        final now = DateTime.now();
        final thisMonth = [
          for (final e in store.expensesInBudgetMonth(now))
            if (e.categoryId == categoryId) e,
        ];
        return Scaffold(
          appBar: AppBar(
            title: Text(category?.name ?? 'Uncategorised'),
            actions: [
              if (category != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit category',
                  onPressed: () => showCategoryDialog(context, store: store, initial: category),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _Header(
                store: store,
                category: category,
                period: store.budgetMonthLabel(now),
                spent: totalOf(thisMonth),
                count: thisMonth.length,
              ),
              if (expenses.isEmpty)
                EmptyMessage(
                  icon: category?.icon ?? Icons.inbox_outlined,
                  title: 'Nothing here yet',
                  message: category == null
                      ? 'Expenses without a category show up here.'
                      : 'Tap Add expense to add one to ${category.name}.',
                )
              else
                ...expenseMonthSections(context, store, expenses, showCategory: false),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => ExpenseActions.add(context, store, categoryId: categoryId),
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.store,
    required this.category,
    required this.period,
    required this.spent,
    required this.count,
  });

  final ExpenseStore store;
  final ExpenseCategory? category;
  final String period;
  final double spent;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final category = this.category;
    final budget = category?.monthlyBudget;
    final color = categoryAccent(category?.color ?? scheme.onSurfaceVariant);
    return Card(
      color: categorySurface(context, color),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spent $period',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: categoryInk(context, color), fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.formatAmount(spent),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800, letterSpacing: -1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                CategoryIcon(
                  icon: category?.icon ?? Icons.inbox_outlined,
                  color: color,
                  size: 64,
                ),
              ],
            ),
            if (category != null) ...[
              const SizedBox(height: 18),
              if (budget != null) ...[
                BudgetProgress(
                  spent: spent,
                  budget: budget,
                  color: color,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => showBudgetDialog(context, store: store, category: category),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Edit budget'),
                    style: TextButton.styleFrom(foregroundColor: categoryInk(context, color)),
                  ),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: () => showBudgetDialog(context, store: store, category: category),
                  icon: const Icon(Icons.savings_outlined),
                  label: const Text('Set a monthly budget'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                count == 1 ? '1 expense this month' : '$count expenses this month',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
