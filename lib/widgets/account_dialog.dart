import 'package:flutter/material.dart';

import '../models/account.dart';
import '../state/expense_store.dart';

/// Adds a new account, or edits [initial] when given. Returns the saved
/// account, or null if cancelled. A new account starts as [type].
Future<Account?> showAccountDialog(
  BuildContext context, {
  required ExpenseStore store,
  Account? initial,
  AccountType type = AccountType.bank,
}) {
  return showDialog<Account>(
    context: context,
    builder: (_) => _AccountDialog(store: store, initial: initial, type: type),
  );
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.store, this.initial, required this.type});

  final ExpenseStore store;
  final Account? initial;
  final AccountType type;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nicknameController =
      TextEditingController(text: widget.initial?.nickname);
  late AccountType _type = widget.initial?.type ?? widget.type;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final nickname = _nicknameController.text.trim();
    final initial = widget.initial;
    final Account saved;
    if (initial == null) {
      saved = widget.store.addAccount(nickname, _type);
    } else {
      saved = initial.copyWith(nickname: nickname, type: _type);
      widget.store.updateAccount(saved);
    }
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit account' : 'Add account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<AccountType>(
              segments: [
                for (final type in [AccountType.bank, AccountType.creditCard])
                  ButtonSegment(
                    value: type,
                    label: Text(type.shortLabel),
                    icon: Icon(type.icon),
                  ),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nicknameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: 'Nickname',
                hintText: _type == AccountType.bank ? 'e.g. SBI Savings' : 'e.g. HDFC Millennia',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final nickname = value?.trim() ?? '';
                if (nickname.isEmpty) return 'Enter a nickname';
                if (widget.store.isNicknameTaken(nickname, exceptId: widget.initial?.id)) {
                  return 'You already have an account with this name';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
