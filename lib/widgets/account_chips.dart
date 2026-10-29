import 'package:flutter/material.dart';

import '../models/account.dart';
import '../state/expense_store.dart';
import 'account_dialog.dart';

/// "Paid from" as one-tap chips, one row per kind (Cash, banks, cards) so
/// a long list stays easy to scan, with "New account" at the end. Positions
/// stay put so they're easy to learn.
class AccountChips extends StatelessWidget {
  const AccountChips({
    super.key,
    required this.store,
    required this.selected,
    required this.onChanged,
  });

  final ExpenseStore store;
  final Account selected;
  final ValueChanged<Account> onChanged;

  Future<void> _create(BuildContext context) async {
    final created = await showAccountDialog(context, store: store);
    if (created != null) onChanged(created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final groups = [
          for (final type in [AccountType.cash, AccountType.bank, AccountType.creditCard])
            (type, type == AccountType.cash ? [Account.cash] : store.accountsOfType(type)),
        ].where((group) => group.$2.isNotEmpty).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Paid from',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final (type, accounts) in groups) ...[
              // Cash needs no heading; banks and cards get one so a long
              // list splits into two short, findable rows.
              if (type != AccountType.cash)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 0, 4),
                  child: Text(
                    type == AccountType.bank ? 'Bank accounts' : 'Credit cards',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final account in accounts)
                    // No type icon: the heading already says bank or card.
                    ChoiceChip(
                      label: Text(account.nickname),
                      selected: account.id == selected.id,
                      showCheckmark: false,
                      onSelected: (_) => onChanged(account),
                    ),
                  // At the end of the last row rather than on a line of its own.
                  if (type == groups.last.$1)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('New account'),
                      onPressed: () => _create(context),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
