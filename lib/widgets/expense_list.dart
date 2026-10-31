import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../screens/expense_form_screen.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'currency_scope.dart';
import 'category_style.dart';
import 'category_icon.dart';
import 'kipto_art.dart';

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

  /// Opens the add form filled in from [draft]; [onSaved] hears if it's kept.
  /// A [draft] without a title starts with the title field focused.
  static void addDraft(
    BuildContext context,
    ExpenseStore store,
    Expense draft, {
    String? source,
    ValueChanged<Expense>? onSaved,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(store: store, draft: draft, draftSource: source, onSaved: onSaved),
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
    this.recent = false,
  });

  final ExpenseStore store;
  final List<Expense> expenses;
  final bool showCategory;
  final bool recent;

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
                  recent: recent,
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
    final style = theme.textTheme.titleLarge?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.1,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(4, 20, 4, action == null ? 10 : 2),
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
    this.recent = false,
  });

  final Expense expense;
  final Account? account;

  /// Still tints the date badge when [showCategory] is off.
  final ExpenseCategory? category;
  final bool showCategory;
  final bool recent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final category = showCategory ? this.category : null;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: recent ? 11 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recent)
            CategoryIcon(
              icon: this.category?.icon ?? Icons.receipt_long_outlined,
              color: this.category?.color ?? theme.colorScheme.primary,
              size: 38,
            )
          else
            _DateBadge(date: expense.dateTime, color: this.category?.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        expense.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          context.formatAmount(expense.amount),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                if (recent) ...[
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${_recentDate(expense.dateTime)}, '
                          '${TimeOfDay.fromDateTime(expense.dateTime).format(context)}'),
                      if (category case final c?) TextSpan(text: ' · ${c.name}'),
                      if (account case final a?) TextSpan(text: ' · ${a.nickname}'),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ] else if (account != null || category != null) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (category case final c?)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: categorySurface(context, c.color),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text.rich(
                            TextSpan(children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(c.icon, size: 12, color: categoryInk(context, c.color)),
                              ),
                              TextSpan(text: ' ${c.name}'),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: categoryInk(context, c.color), fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (account case final a?)
                        Text.rich(
                          TextSpan(children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(a.type.icon, size: 13, color: muted),
                            ),
                            TextSpan(text: ' ${a.nickname}'),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(color: muted),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _recentDate(DateTime date) {
  final now = DateTime.now();
  if (DateUtils.isSameDay(date, now)) return 'Today';
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (DateUtils.isSameDay(date, yesterday)) return 'Yesterday';
  return formatShortDate(date);
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
    final color = tint == null ? theme.colorScheme.primary : categoryInk(context, tint);
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tint == null
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
            : categorySurface(context, tint),
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
            formatWeekday(date).toUpperCase(),
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
          if (icon == Icons.receipt_long_outlined)
            const KiptoArt.receipt(size: 80)
          else
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
