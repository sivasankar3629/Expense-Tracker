import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../screens/expense_form_screen.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'currency_scope.dart';

/// Opening, editing and deleting expenses the same way from every screen.
class ExpenseActions {
  const ExpenseActions._();

  /// [categoryId] pre-selects a category, e.g. when adding from its screen.
  static void add(BuildContext context, ExpenseStore store, {String? categoryId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(store: store, initialCategoryId: categoryId),
      ),
    );
  }

  static Future<void> edit(BuildContext context, ExpenseStore store, Expense expense) async {
    final result = await Navigator.of(context).push<ExpenseFormResult>(
      MaterialPageRoute(builder: (_) => ExpenseFormScreen(store: store, initial: expense)),
    );
    if (result == ExpenseFormResult.deleted && context.mounted) {
      _showUndo(context, store, expense);
    }
  }

  static void delete(BuildContext context, ExpenseStore store, Expense expense) {
    store.deleteExpense(expense);
    _showUndo(context, store, expense);
  }

  static void _showUndo(BuildContext context, ExpenseStore store, Expense expense) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${expense.title}"'),
          behavior: SnackBarBehavior.floating,
          // Snack bars with an action stay up by default; let this one time out.
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => store.restoreExpense(expense),
          ),
        ),
      );
  }
}

/// [expenses] (newest first) split into month sections with totals.
///
/// Turn off [showCategory] when every expense shares one, e.g. on its page.
List<Widget> expenseMonthSections(
  BuildContext context,
  ExpenseStore store,
  List<Expense> expenses, {
  bool showCategory = true,
}) {
  final byMonth = <String, List<Expense>>{};
  for (final expense in expenses) {
    byMonth.putIfAbsent(formatMonth(expense.dateTime), () => []).add(expense);
  }
  return [
    for (final MapEntry(key: month, value: items) in byMonth.entries)
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: month,
            trailing: context.formatAmount(items.fold<double>(0, (sum, e) => sum + e.amount)),
          ),
          ExpenseCard(store: store, expenses: items, showCategory: showCategory),
        ],
      ),
  ];
}

/// A rounded card of expense rows; tap to edit, swipe left to delete.
class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.store,
    required this.expenses,
    this.showCategory = true,
  });

  final ExpenseStore store;
  final List<Expense> expenses;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < expenses.length; i++) ...[
            if (i > 0) const Divider(indent: 76),
            Dismissible(
              key: ValueKey(expenses[i].id),
              direction: DismissDirection.endToStart,
              background: const _DeleteBackground(),
              onDismissed: (_) => ExpenseActions.delete(context, store, expenses[i]),
              child: InkWell(
                onTap: () => ExpenseActions.edit(context, store, expenses[i]),
                child: ExpenseTile(
                  expense: expenses[i],
                  account: store.accountById(expenses[i].accountId),
                  category: store.categoryById(expenses[i].categoryId),
                  showCategory: showCategory,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A list heading with an optional value or action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing, this.action});

  final String title;
  final String? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, action == null ? 16 : 4, action == null ? 10 : 2),
      child: Row(
        children: [
          Expanded(child: Text(title, style: style)),
          if (trailing != null) Text(trailing!, style: style),
          ?action,
        ],
      ),
    );
  }
}

/// Revealed behind a row while it's swiped away.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Delete',
            style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Icon(Icons.delete_outline, color: scheme.onErrorContainer),
        ],
      ),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    this.account,
    this.category,
    this.showCategory = true,
  });

  final Expense expense;
  final Account? account;

  /// Still tints the date badge when [showCategory] is off.
  final ExpenseCategory? category;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final category = showCategory ? this.category : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _DateBadge(date: expense.dateTime, color: this.category?.color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (account != null || category != null) ...[
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(children: [
                      if (category case final c?) ...[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(c.icon, size: 14, color: c.color),
                        ),
                        TextSpan(
                          text: ' ${c.name}',
                          style: TextStyle(color: c.color, fontWeight: FontWeight.w500),
                        ),
                        if (account != null) const TextSpan(text: '  ·  '),
                      ],
                      if (account case final a?) ...[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(a.type.icon, size: 14, color: muted),
                        ),
                        TextSpan(text: ' ${a.nickname}'),
                      ],
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            context.formatAmount(expense.amount),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date, this.color});

  final DateTime date;

  /// The expense's category colour, so rows are colour-coded at a glance.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = this.color;
    final color = tint ?? theme.colorScheme.onPrimaryContainer;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.16) ??
            theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '${date.day}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          Text(
            formatWeekday(date),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.75),
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// A centred icon, title and hint for screens with nothing to show yet.
class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
