import 'package:flutter/material.dart';

import '../models/account.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import '../widgets/category_icon.dart';
import '../widgets/expense_list.dart';

/// Every expense, newest first, filterable by category and payment method.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

/// Stands in for "no category" in the category filter.
const _uncategorised = '';

class _HistoryTabState extends State<HistoryTab> {
  Set<String> _categoryIds = {};
  Set<String> _accountIds = {};

  ExpenseStore get _store => widget.store;

  bool get _filtering => _categoryIds.isNotEmpty || _accountIds.isNotEmpty;

  Future<void> _pickCategories() async {
    final options = [
      for (final c in _store.categories)
        _Option(id: c.id, label: c.name, leading: CategoryIcon.of(c, size: 32)),
      if (_store.expenses.any((e) => e.categoryId == null))
        _Option(
          id: _uncategorised,
          label: 'Uncategorised',
          leading: CategoryIcon(
            icon: Icons.inbox_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 32,
          ),
        ),
    ];
    final picked = await _showFilterSheet('Category', options, _categoryIds);
    if (picked != null) setState(() => _categoryIds = picked);
  }

  Future<void> _pickAccounts() async {
    final options = [
      for (final a in [
        Account.cash,
        ..._store.accountsOfType(AccountType.bank),
        ..._store.accountsOfType(AccountType.creditCard),
      ])
        _Option(id: a.id, label: a.nickname, leading: Icon(a.type.icon)),
    ];
    final picked = await _showFilterSheet('Paid from', options, _accountIds);
    if (picked != null) setState(() => _accountIds = picked);
  }

  Future<Set<String>?> _showFilterSheet(String title, List<_Option> options, Set<String> current) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        var selected = {...current};
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final option in options)
                          CheckboxListTile(
                            value: selected.contains(option.id),
                            secondary: option.leading,
                            title: Text(option.label),
                            onChanged: (on) => setSheetState(() {
                              on == true ? selected.add(option.id) : selected.remove(option.id);
                            }),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => setSheetState(() => selected = {}),
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.of(sheetContext).pop(selected),
                          child: const Text('Show results'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final all = _store.expenses;
        final shown = [
          for (final e in all)
            if ((_categoryIds.isEmpty || _categoryIds.contains(e.categoryId ?? _uncategorised)) &&
                (_accountIds.isEmpty || _accountIds.contains(e.accountId)))
              e,
        ];
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _FilterButton(
                  label: 'Category',
                  count: _categoryIds.length,
                  onTap: _pickCategories,
                ),
                _FilterButton(
                  label: 'Paid from',
                  count: _accountIds.length,
                  onTap: _pickAccounts,
                ),
                if (_filtering)
                  TextButton(
                    onPressed: () => setState(() {
                      _categoryIds = {};
                      _accountIds = {};
                    }),
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
            if (all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                child: Text(
                  '${shown.length == 1 ? '1 expense' : '${shown.length} expenses'}'
                  ' · ${formatAmount(totalOf(shown))}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (all.isEmpty)
              const EmptyMessage(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses yet',
                message: 'Everything you add shows up here.',
              )
            else if (shown.isEmpty)
              const EmptyMessage(
                icon: Icons.filter_alt_off_outlined,
                title: 'No matches',
                message: 'No expenses match these filters.',
              )
            else
              ...expenseMonthSections(context, _store, shown),
          ],
        );
      },
    );
  }
}

class _Option {
  const _Option({required this.id, required this.label, required this.leading});

  final String id;
  final String label;
  final Widget leading;
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label, required this.count, required this.onTap});

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count == 0 ? label : '$label · $count'),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
      selected: count > 0,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }
}
