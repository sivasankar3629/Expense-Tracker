import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/category.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'currency_scope.dart';
import 'category_style.dart';

/// How close spending is to a budget.
enum BudgetLevel {
  ok,

  /// 80% or more used, but not over.
  near,
  over;

  static BudgetLevel of(double spent, double budget) {
    if (spent > budget) return over;
    if (spent >= budget * 0.8) return near;
    return ok;
  }
}

/// Amber near the limit, red over it, otherwise the category's own colour.
Color budgetColor(BuildContext context, BudgetLevel level, Color normal) => switch (level) {
      BudgetLevel.ok => normal,
      BudgetLevel.near => const Color(0xFFE69500),
      BudgetLevel.over => Theme.of(context).colorScheme.error,
    };

/// A progress bar plus "₹1,800 left of ₹5,000" or "₹200 over ₹5,000".
class BudgetProgress extends StatelessWidget {
  const BudgetProgress({
    super.key,
    required this.spent,
    required this.budget,
    required this.color,
    this.compact = false,
    this.action,
  });

  final double spent;
  final double budget;
  final Color color;

  /// Shorter caption for small cards.
  final bool compact;

  /// Shown at the end of the caption's line.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = BudgetLevel.of(spent, budget);
    final barColor = budgetColor(context, level, color);
    final left = budget - spent;
    final caption = switch (level) {
      _ when left == 0 => 'Budget used up',
      BudgetLevel.over => compact
          ? '${context.formatAmount(-left)} over'
          : '${context.formatAmount(-left)} over your ${context.formatAmount(budget)} budget',
      _ => compact
          ? '${context.formatAmount(left)} left'
          : '${context.formatAmount(left)} left of ${context.formatAmount(budget)}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: budget <= 0 ? 1 : (spent / budget).clamp(0, 1),
            minHeight: compact ? 4 : 8,
            color: barColor,
            backgroundColor: barColor.withValues(alpha: 0.15),
          ),
        ),
        SizedBox(height: action == null ? (compact ? 4 : 6) : 2),
        Row(
          children: [
            Expanded(
              child: Text(
                caption,
                maxLines: compact ? 1 : null,
                overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: compact ? 10.5 : null,
                  height: compact ? 1.2 : null,
                  color: level == BudgetLevel.ok
                      ? theme.colorScheme.onSurfaceVariant
                      : categoryInk(context, barColor),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ],
    );
  }
}

/// Sets, changes or removes a category's monthly budget.
Future<void> showBudgetDialog(
  BuildContext context, {
  required ExpenseStore store,
  required ExpenseCategory category,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BudgetDialog(store: store, category: category),
  );
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.store, required this.category});

  final ExpenseStore store;
  final ExpenseCategory category;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(
    text: switch (widget.category.monthlyBudget) {
      final b? => b.toStringAsFixed(b == b.roundToDouble() ? 0 : 2),
      null => null,
    },
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.store.setCategoryBudget(widget.category, double.parse(_controller.text));
    Navigator.of(context).pop();
  }

  void _remove() {
    widget.store.setCategoryBudget(widget.category, null);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasBudget = widget.category.monthlyBudget != null;
    return AlertDialog(
      title: Text('Monthly budget for ${widget.category.name}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          onFieldSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: 'Budget',
            prefixText: context.currencyPrefix,
            helperText: switch (widget.store.preferences.monthStartDay) {
              1 => 'Starts fresh at the beginning of each month.',
              final day => 'Starts fresh on the ${formatOrdinal(day)} of each month.',
            },
          ),
          validator: (value) {
            final amount = double.tryParse(value ?? '');
            if (amount == null || amount <= 0) return 'Enter an amount';
            return null;
          },
        ),
      ),
      actions: [
        if (hasBudget)
          TextButton(
            onPressed: _remove,
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
