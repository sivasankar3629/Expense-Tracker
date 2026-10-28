import 'package:flutter/material.dart';

import '../models/account.dart';
import '../state/expense_store.dart';
import '../widgets/account_dialog.dart';
import '../widgets/account_icon.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key, required this.store});

  final ExpenseStore store;

  Future<void> _confirmDelete(BuildContext context, Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${account.nickname}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) store.deleteAccount(account);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts & cards')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            for (final type in [AccountType.bank, AccountType.creditCard])
              ..._buildSection(context, type),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAccountDialog(context, store: store),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
    );
  }

  List<Widget> _buildSection(BuildContext context, AccountType type) {
    final theme = Theme.of(context);
    final accounts = store.accountsOfType(type);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
        child: Text(
          '${type.label}s',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Card(
        child: accounts.isEmpty
            ? ListTile(
                leading: Opacity(opacity: 0.5, child: AccountIcon(type)),
                title: Text(
                  'None added yet',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            : Column(
                children: [
                  for (var i = 0; i < accounts.length; i++) ...[
                    if (i > 0) const Divider(indent: 72),
                    _buildTile(context, accounts[i]),
                  ],
                ],
              ),
      ),
    ];
  }

  Widget _buildTile(BuildContext context, Account account) {
    final count = store.expenseCountFor(account.id);
    final canDelete = store.canDelete(account);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      leading: AccountIcon(account.type),
      title: Text(account.nickname, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(count == 1 ? '1 expense' : '$count expenses'),
      onTap: () => showAccountDialog(context, store: store, initial: account),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: canDelete ? 'Delete' : 'Has expenses, can\'t delete',
        onPressed: canDelete ? () => _confirmDelete(context, account) : null,
      ),
    );
  }
}
