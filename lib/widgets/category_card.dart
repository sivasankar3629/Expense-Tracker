import 'package:flutter/material.dart';

import '../models/category.dart';
import 'budget.dart';
import 'category_icon.dart';
import 'category_style.dart';
import 'currency_scope.dart';

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
      color: categorySurface(context, color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryIcon(icon: icon, color: color, size: 38),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: categoryInk(context, color),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.formatAmount(spent),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        if (over)
                          Icon(Icons.warning_amber_rounded, size: 15, color: theme.colorScheme.error),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (budget != null)
                      BudgetProgress(spent: spent, budget: budget, color: categoryAccent(color), compact: true)
                    else
                      Text(
                        count == 0 ? 'Nothing this month' : (count == 1 ? '1 this month' : '$count this month'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
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
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: CustomPaint(
        painter: _DashedBorder(scheme.outlineVariant),
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, color: scheme.primary, size: 25),
                ),
                const SizedBox(height: 6),
                Text(
                  'New category',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
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
        maxCrossAxisExtent: MediaQuery.textScalerOf(context).scale(14) > 18 ? 480 : 240,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: MediaQuery.textScalerOf(context).scale(96),
      ),
      children: children,
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Path()..addRRect(RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1), const Radius.circular(20),
    ));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in border.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 9) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => color != oldDelegate.color;
}
