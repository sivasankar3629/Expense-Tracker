import 'package:flutter/material.dart';

import '../models/category.dart';
import '../utils/format.dart';
import 'budget.dart';
import 'category_icon.dart';

/// A home-screen tile: this month's spending in a category, with its budget.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.icon,
    required this.color,
    required this.name,
    required this.spent,
    required this.count,
    required this.onTap,
    this.budget,
  });

  CategoryCard.of(
    ExpenseCategory category, {
    Key? key,
    required double spent,
    required int count,
    required VoidCallback onTap,
  }) : this(
          key: key,
          icon: category.icon,
          color: category.color,
          name: category.name,
          spent: spent,
          count: count,
          budget: category.monthlyBudget,
          onTap: onTap,
        );

  final IconData icon;
  final Color color;
  final String name;

  /// This month.
  final double spent;
  final int count;
  final double? budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budget = this.budget;
    final over = budget != null && BudgetLevel.of(spent, budget) == BudgetLevel.over;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CategoryIcon(icon: icon, color: color, size: 36),
                  const Spacer(),
                  if (over)
                    Icon(Icons.warning_amber_rounded, size: 20, color: theme.colorScheme.error),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                formatAmount(spent),
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (budget != null)
                BudgetProgress(spent: spent, budget: budget, color: color, compact: true)
              else ...[
                // Same height as a budget bar and its gap, so tiles line up.
                const SizedBox(height: 12),
                Text(
                  count == 0 ? 'Nothing this month' : (count == 1 ? '1 this month' : '$count this month'),
                  maxLines: 1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The last tile in the grid: makes a new category.
class NewCategoryCard extends StatelessWidget {
  const NewCategoryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                'New category',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid of equal-height tiles: two columns on a phone, more on wider
/// screens, and taller when the system text size is larger.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: MediaQuery.textScalerOf(context).scale(162),
      ),
      children: children,
    );
  }
}
