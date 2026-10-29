import 'package:flutter/material.dart';

import '../models/account.dart';
import '../state/expense_store.dart';
import 'account_dialog.dart';

/// "Paid from" as one-tap chips (Cash, then banks, then cards) with
/// "New account" at the end. Positions stay put so they're easy to learn.
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
        final accounts = [
          Account.cash,
          ...store.accountsOfType(AccountType.bank),
          ...store.accountsOfType(AccountType.creditCard),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Paid from',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final account in accounts) ...[
                    ChoiceChip(
                      avatar: Icon(account.type.icon, size: 18),
                      label: Text(account.nickname),
                      selected: account.id == selected.id,
                      showCheckmark: false,
                      onSelected: (_) => onChanged(account),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('New account'),
                    onPressed: () => _create(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
