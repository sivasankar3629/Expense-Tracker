import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../sms/sms_detection.dart';
import '../state/expense_store.dart';
import '../widgets/category_card.dart';
import '../widgets/category_dialog.dart';
import '../widgets/expense_list.dart';
import '../widgets/summary_card.dart';
import 'categories_screen.dart';
import 'category_screen.dart';
import 'review_screen.dart';

/// Home: this month at a glance, by category, plus the latest expenses.
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.store, required this.onSeeAll, this.detection});

  final ExpenseStore store;

  /// Shows a "to review" banner while bank SMS have spends waiting.
  final SmsDetection? detection;

  /// Switches to the full history.
  final VoidCallback onSeeAll;

  static const _recentCount = 5;

  void _openCategory(BuildContext context, String? categoryId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryScreen(store: store, categoryId: categoryId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detection = this.detection;
    return ListenableBuilder(
      listenable: Listenable.merge([store, ?detection]),
      builder: (context, _) {
        final now = DateTime.now();
        final toReview = detection != null && detection.enabled ? detection.pending.length : 0;
        final thisMonth = store.expensesInBudgetMonth(now);
        final expenses = store.expenses;

        final spentBy = <String?, double>{};
        final countBy = <String?, int>{};
        for (final Expense e in thisMonth) {
          spentBy[e.categoryId] = (spentBy[e.categoryId] ?? 0) + e.amount;
          countBy[e.categoryId] = (countBy[e.categoryId] ?? 0) + 1;
        }
        // Biggest spend first, so the categories that matter this month lead.
        final categories = [...store.categories]..sort((a, b) {
            final bySpend = (spentBy[b.id] ?? 0).compareTo(spentBy[a.id] ?? 0);
            return bySpend != 0 ? bySpend : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        final hasUncategorised = expenses.any((e) => e.categoryId == null);

        return ListView(
          // Bottom padding keeps the last row clear of the floating button.
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            SummaryCard(
              period: store.budgetMonthLabel(now),
              total: totalOf(thisMonth),
              count: thisMonth.length,
              todayTotal: totalOf(thisMonth.where((e) => DateUtils.isSameDay(e.dateTime, now))),
            ),
            if (toReview > 0) ...[
              const SizedBox(height: 12),
              ReviewBanner(
                count: toReview,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReviewScreen(detection: detection!)),
                ),
              ),
            ],
            SectionHeader(
              title: 'Categories',
              action: categories.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CategoriesScreen(store: store)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Text('Manage'), SizedBox(width: 4), Icon(Icons.chevron_right, size: 18)],
                      ),
                    ),
            ),
            if (categories.isEmpty && !hasUncategorised)
              _CategoriesIntro(onCreate: () => showCategoryDialog(context, store: store))
            else
              CategoryGrid(
                children: [
                  for (final category in categories)
                    CategoryCard.of(
                      category,
                      spent: spentBy[category.id] ?? 0,
                      count: countBy[category.id] ?? 0,
                      onTap: () => _openCategory(context, category.id),
                    ),
                  if (hasUncategorised)
                    CategoryCard(
                      icon: Icons.inbox_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      name: 'Uncategorised',
                      spent: spentBy[null] ?? 0,
                      count: countBy[null] ?? 0,
                      onTap: () => _openCategory(context, null),
                    ),
                  NewCategoryCard(onTap: () => showCategoryDialog(context, store: store)),
                ],
              ),
            SectionHeader(
              title: 'Recent',
              action: expenses.length > _recentCount
                  ? TextButton(
                      onPressed: onSeeAll,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Text('See all'), SizedBox(width: 4), Icon(Icons.chevron_right, size: 18)],
                      ),
                    )
                  : null,
            ),
            if (expenses.isEmpty)
              const EmptyMessage(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses yet',
                message: 'Tap Add expense to log your first one.',
              )
            else
              ExpenseCard(store: store, expenses: expenses.take(_recentCount).toList(), recent: true),
          ],
        );
      },
    );
  }
}

/// Shown until the first category exists: what categories are for.
class _CategoriesIntro extends StatelessWidget {
  const _CategoriesIntro({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: Color.lerp(
        theme.colorScheme.surfaceContainerLow,
        theme.colorScheme.primary,
        0.045,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Group your spending',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Make categories like Food or Rent to see where your money goes, '
              'and give each one a monthly budget.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create a category'),
            ),
          ],
        ),
      ),
    );
  }
}
