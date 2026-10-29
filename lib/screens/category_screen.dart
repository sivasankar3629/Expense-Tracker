import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import '../widgets/budget.dart';
import '../widgets/category_dialog.dart';
import '../widgets/category_icon.dart';
import '../widgets/expense_list.dart';

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
        final thisMonth = expenses
            .where((e) => e.dateTime.year == now.year && e.dateTime.month == now.month)
            .toList();
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
                month: formatMonthName(now),
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
    required this.month,
    required this.spent,
    required this.count,
  });

  final ExpenseStore store;
  final ExpenseCategory? category;
  final String month;
  final double spent;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final category = this.category;
    final budget = category?.monthlyBudget;
    final color = category?.color ?? scheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIcon(
                  icon: category?.icon ?? Icons.inbox_outlined,
                  color: color,
                  size: 52,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spent in $month',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        formatAmount(spent),
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
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
                  action: TextButton(
                    onPressed: () => showBudgetDialog(context, store: store, category: category),
                    child: const Text('Edit budget'),
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
