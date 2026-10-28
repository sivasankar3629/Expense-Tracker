import 'package:flutter/material.dart';

import '../models/account.dart';
import '../state/expense_store.dart';
import 'account_dialog.dart';
import 'account_icon.dart';

/// Lets the user pick which account an expense was paid from, or add a new
/// one on the spot. Returns the chosen account, or null if dismissed.
Future<Account?> showAccountPicker(
  BuildContext context, {
  required ExpenseStore store,
  required Account selected,
}) {
  return showModalBottomSheet<Account>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: store,
      builder: (_, _) {
        Widget tile(Account account) {
          final isSelected = account.id == selected.id;
          return ListTile(
            leading: AccountIcon(account.type),
            title: Text(
              account.nickname,
              style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
            ),
            trailing: isSelected ? const Icon(Icons.check_circle) : null,
            selected: isSelected,
            onTap: () => Navigator.of(sheetContext).pop(account),
          );
        }

        final sections = [
          for (final type in [AccountType.bank, AccountType.creditCard])
            if (store.accountsOfType(type).isNotEmpty) ...[
              _SectionLabel('${type.label}s'),
              ...store.accountsOfType(type).map(tile),
            ],
        ];

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Paid from',
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                tile(Account.cash),
                ...sections,
                const Divider(),
                ListTile(
                  leading: const SizedBox(width: 40, child: Icon(Icons.add)),
                  title: const Text('Add bank account or card'),
                  onTap: () async {
                    final added = await showAccountDialog(sheetContext, store: store);
                    if (added != null && sheetContext.mounted) {
                      Navigator.of(sheetContext).pop(added);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
