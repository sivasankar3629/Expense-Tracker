import 'package:flutter/material.dart';

import 'currency_scope.dart';
import 'kipto_art.dart';

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
    const foreground = Color(0xFFFFFDF4);
    const muted = Color(0xFFD4E4CD);
    return LayoutBuilder(builder: (context, constraints) {
      final showArt = constraints.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(16) <= 20;
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF234D3B), Color(0xFF123A2C)],
          ),
          border: Border.all(color: const Color(0xFF3B6450)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (showArt)
              Positioned(
                right: -18,
                top: -20,
                child: IgnorePointer(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: foreground.withValues(alpha: 0.04),
                      border: Border.all(color: foreground.withValues(alpha: 0.08)),
                    ),
                  ),
                ),
              ),
            if (showArt)
              const Positioned(
                right: -4,
                top: -8,
                child: IgnorePointer(child: KiptoArt.wallet(size: 112)),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: showArt ? 104 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Spent $period', style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                      const SizedBox(height: 6),
                      Text(
                        context.formatAmount(total),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
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
          ],
        ),
      );
    });
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    const onPrimary = Color(0xFFFFFDF4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.10),
        border: Border.all(color: onPrimary.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onPrimary),
      ),
    );
  }
}
