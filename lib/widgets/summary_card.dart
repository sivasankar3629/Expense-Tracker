import 'package:flutter/material.dart';

import 'currency_scope.dart';

/// The budget month's total on a gradient, with the expense count and today's total.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.period,
    required this.total,
    required this.count,
    required this.todayTotal,
  });

  /// Completes "Spent …", e.g. "in October".
  final String period;
  final double total;
  final int count;
  final double todayTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onPrimary.withValues(alpha: 0.8);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.6)!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spent $period', style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
          const SizedBox(height: 6),
          Text(
            context.formatAmount(total),
            style: theme.textTheme.displaySmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(count == 1 ? '1 expense' : '$count expenses'),
              _Pill('Today ${context.formatAmount(todayTotal)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onPrimary),
      ),
    );
  }
}
