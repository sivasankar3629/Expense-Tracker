import 'package:flutter/material.dart';

import '../cloud/cloud_sync.dart';
import '../models/account.dart';
import '../models/expense.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import 'accounts_screen.dart';
import 'backup_screen.dart';
import 'expense_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store, this.cloudSync, this.versionLabel});

  final ExpenseStore store;

  /// Null when cloud backup isn't set up for this build.
  final CloudSync? cloudSync;

  /// Shown at the bottom of the menu so it's easy to tell which build is installed.
  final String? versionLabel;

  void _openAddExpense(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ExpenseFormScreen(store: store)),
    );
  }

  Future<void> _openEditExpense(BuildContext context, Expense expense) async {
    final result = await Navigator.of(context).push<ExpenseFormResult>(
      MaterialPageRoute(builder: (_) => ExpenseFormScreen(store: store, initial: expense)),
    );
    if (result == ExpenseFormResult.deleted && context.mounted) {
      _showUndo(context, expense);
    }
  }

  void _deleteExpense(BuildContext context, Expense expense) {
    store.deleteExpense(expense);
    _showUndo(context, expense);
  }

  void _showUndo(BuildContext context, Expense expense) {
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

  void _openAccounts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AccountsScreen(store: store)),
    );
  }

  void _openBackup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BackupScreen(store: store, cloudSync: cloudSync)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          if (cloudSync case final sync?)
            ListenableBuilder(
              listenable: sync,
              builder: (context, _) => _CloudStatusButton(
                status: sync.status,
                onPressed: () => _openBackup(context),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Accounts & cards',
            onPressed: () => _openAccounts(context),
          ),
          PopupMenuButton<VoidCallback>(
            tooltip: 'More',
            onSelected: (action) => action(),
            // `_` keeps the screen's context in scope; the menu's own context is
            // disposed once it closes, before onSelected runs.
            itemBuilder: (_) => [
              PopupMenuItem(
                value: () => _openBackup(context),
                child: const ListTile(
                  leading: Icon(Icons.settings_backup_restore),
                  title: Text('Backup & restore'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (versionLabel != null) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  height: 36,
                  child: Text(versionLabel!, style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => _buildBody(context),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddExpense(context),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final expenses = store.expenses;
    final now = DateTime.now();
    final thisMonth = expenses
        .where((e) => e.dateTime.year == now.year && e.dateTime.month == now.month)
        .toList();
    final today = thisMonth.where((e) => DateUtils.isSameDay(e.dateTime, now));

    // Expenses are newest first, so months come out in order too.
    final byMonth = <String, List<Expense>>{};
    for (final expense in expenses) {
      byMonth.putIfAbsent(formatMonth(expense.dateTime), () => []).add(expense);
    }

    return ListView(
      // Bottom padding keeps the last row clear of the floating button.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _SummaryCard(
          month: formatMonthName(now),
          total: _sum(thisMonth),
          count: thisMonth.length,
          todayTotal: _sum(today),
        ),
        if (expenses.isEmpty)
          const _EmptyState()
        else
          for (final MapEntry(key: month, value: items) in byMonth.entries)
            _MonthSection(
              month: month,
              expenses: items,
              store: store,
              onTap: (expense) => _openEditExpense(context, expense),
              onDelete: (expense) => _deleteExpense(context, expense),
            ),
      ],
    );
  }

  static double _sum(Iterable<Expense> expenses) =>
      expenses.fold(0, (sum, e) => sum + e.amount);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.month,
    required this.total,
    required this.count,
    required this.todayTotal,
  });

  final String month;
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
          Text(
            'Spent in $month',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 6),
          Text(
            formatAmount(total),
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
              _Pill('Today ${formatAmount(todayTotal)}'),
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

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.month,
    required this.expenses,
    required this.store,
    required this.onTap,
    required this.onDelete,
  });

  final String month;
  final List<Expense> expenses;
  final ExpenseStore store;
  final ValueChanged<Expense> onTap;
  final ValueChanged<Expense> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
          child: Row(
            children: [
              Expanded(child: Text(month, style: headerStyle)),
              Text(formatAmount(total), style: headerStyle),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < expenses.length; i++) ...[
                if (i > 0) const Divider(indent: 76),
                Dismissible(
                  key: ValueKey(expenses[i].id),
                  direction: DismissDirection.endToStart,
                  background: const _DeleteBackground(),
                  onDismissed: (_) => onDelete(expenses[i]),
                  child: InkWell(
                    onTap: () => onTap(expenses[i]),
                    child: _ExpenseTile(
                      expense: expenses[i],
                      account: store.accountById(expenses[i].accountId),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows at a glance whether changes are safely in the cloud.
class _CloudStatusButton extends StatelessWidget {
  const _CloudStatusButton({required this.status, required this.onPressed});

  final CloudStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, tooltip, color) = switch (status) {
      CloudStatus.signedOut => (Icons.cloud_off_outlined, 'Cloud backup is off', null),
      CloudStatus.connecting ||
      CloudStatus.syncing =>
        (Icons.cloud_upload_outlined, 'Backing up…', scheme.primary),
      CloudStatus.upToDate => (Icons.cloud_done_outlined, 'Backed up', scheme.primary),
      CloudStatus.failing => (Icons.cloud_off_outlined, 'Backup problem', scheme.error),
    };
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
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

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, this.account});

  final Expense expense;
  final Account? account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _DateBadge(date: expense.dateTime),
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
                if (account != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(account!.type.icon, size: 14, color: muted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          account!.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatAmount(expense.amount),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, size: 40, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 20),
          Text(
            'No expenses yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap Add expense to log your first one.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
