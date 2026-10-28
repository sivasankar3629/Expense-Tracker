import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../utils/format.dart';
import 'add_expense_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Expense> _expenses = [];

  Future<void> _openAddExpense() async {
    final expense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
    if (expense == null) return;
    setState(() {
      _expenses
        ..add(expense)
        // Newest first; for identical times, the most recently added wins.
        ..sort((a, b) {
          final byDate = b.dateTime.compareTo(a.dateTime);
          return byDate != 0 ? byDate : b.id.compareTo(a.id);
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: _expenses.isEmpty ? const _EmptyState() : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
    );
  }

  /// Expenses grouped under month headers, so the day number on each row
  /// is never ambiguous.
  Widget _buildList() {
    final items = <Widget>[];
    String? currentMonth;
    for (final expense in _expenses) {
      final month = formatMonth(expense.dateTime);
      if (month != currentMonth) {
        currentMonth = month;
        final total = _expenses
            .where((e) => formatMonth(e.dateTime) == month)
            .fold<double>(0, (sum, e) => sum + e.amount);
        items.add(_MonthHeader(month: month, total: total));
      }
      items.add(_ExpenseTile(expense: expense));
    }
    // Bottom padding keeps the last row clear of the floating button.
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: items,
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.total});

  final String month;
  final double total;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Expanded(child: Text(month, style: style)),
          Text(formatAmount(total), style: style),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      // Match the month header's padding so amounts line up with the total.
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: SizedBox(
        width: 32,
        child: Text(
          '${expense.dateTime.day}',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      minLeadingWidth: 32,
      title: Text(expense.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        formatAmount(expense.amount),
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 56, color: color),
          const SizedBox(height: 12),
          Text('No expenses yet', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
