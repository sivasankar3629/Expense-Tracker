import 'package:flutter/material.dart';

import '../models/account.dart';
import '../screens/accounts_screen.dart';
import '../state/expense_store.dart';
import 'account_dialog.dart';

/// "Paid from": Cash / Bank / Card tabs, then that kind's accounts, most
/// recently used first. Picking a tab picks Cash, or the top account.
class PaidFromPicker extends StatefulWidget {
  const PaidFromPicker({
    super.key,
    required this.store,
    required this.selected,
    required this.onChanged,
  });

  final ExpenseStore store;
  final Account selected;
  final ValueChanged<Account> onChanged;

  @override
  State<PaidFromPicker> createState() => _PaidFromPickerState();
}

class _PaidFromPickerState extends State<PaidFromPicker> {
  late AccountType _tab = widget.selected.type;

  ExpenseStore get _store => widget.store;

  @override
  void didUpdateWidget(PaidFromPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected.id != oldWidget.selected.id) _tab = widget.selected.type;
  }

  Future<void> _pickTab(AccountType type) async {
    if (type == AccountType.cash) {
      setState(() => _tab = type);
      widget.onChanged(Account.cash);
      return;
    }
    final accounts = _store.accountsByUse(type);
    if (accounts.isEmpty) {
      // Nothing to pick yet: make one, and use it.
      await _create(type);
      return;
    }
    setState(() => _tab = type);
    widget.onChanged(accounts.first.$1);
  }

  Future<void> _create(AccountType type) async {
    final created = await showAccountDialog(context, store: _store, type: type);
    if (created == null || !mounted) return;
    setState(() => _tab = created.type);
    widget.onChanged(created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final accounts = _tab == AccountType.cash ? null : _store.accountsByUse(_tab);
        // By the order they were added, so each keeps its colour as the list re-sorts.
        final added = [for (final a in _store.accountsOfType(_tab)) a.id];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Paid from', style: heading),
            ),
            _Tabs(selected: _tab, onSelected: _pickTab),
            const SizedBox(height: 12),
            if (accounts == null)
              _AccountRow(
                account: Account.cash,
                tint: Theme.of(context).colorScheme.primary,
                detail: 'Physical cash',
                selected: widget.selected.id == Account.cash.id,
                onTap: () => widget.onChanged(Account.cash),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        _tab == AccountType.bank ? 'Your accounts' : 'Your cards',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => AccountsScreen(store: _store)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Text('Manage'), Icon(Icons.chevron_right, size: 18)],
                    ),
                  ),
                ],
              ),
              for (final (i, (account, lastUsed)) in accounts.indexed) ...[
                _AccountRow(
                  account: account,
                  tint: _tints[added.indexOf(account.id) % _tints.length],
                  detail: _usage(lastUsed, first: i == 0),
                  highlightDetail: i == 0 && lastUsed != null,
                  selected: widget.selected.id == account.id,
                  onTap: () => widget.onChanged(account),
                ),
                const SizedBox(height: 8),
              ],
              _AddRow(
                label: _tab == AccountType.bank ? 'Add a bank account' : 'Add a card',
                onTap: () => _create(_tab),
              ),
            ],
          ],
        );
      },
    );
  }

  /// "Recently used", "Used 3 days ago", "Not used yet" …
  static String _usage(DateTime? lastUsed, {required bool first}) {
    if (lastUsed == null) return 'Not used yet';
    final today = DateUtils.dateOnly(DateTime.now());
    final days = today.difference(DateUtils.dateOnly(lastUsed)).inDays;
    if (first && days <= 1) return 'Recently used';
    return switch (days) {
      <= 0 => 'Used today',
      1 => 'Used yesterday',
      < 7 => 'Used $days days ago',
      < 14 => 'Used 1 week ago',
      < 31 => 'Used ${days ~/ 7} weeks ago',
      < 61 => 'Used 1 month ago',
      _ => 'Used ${days ~/ 30} months ago',
    };
  }
}

/// Three pill tabs in a rounded track.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelected});

  final AccountType selected;
  final ValueChanged<AccountType> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (final (type, label) in [
            (AccountType.cash, 'Cash'),
            (AccountType.bank, 'Bank'),
            (AccountType.creditCard, 'Card'),
          ])
            Expanded(
              child: Semantics(
                selected: type == selected,
                button: true,
                child: Material(
                  color: type == selected ? scheme.primary : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelected(type),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              type.icon,
                              size: 20,
                              color: type == selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: type == selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tints so accounts of the same kind are told apart at a glance.
const _tints = [
  Color(0xFF2F6FDB), Color(0xFFB8862B), Color(0xFF7A4CC2), Color(0xFFC0475B),
  Color(0xFF2E8C7A), Color(0xFFD46A2E), Color(0xFF4F6D8F), Color(0xFF8E3E8A),
];

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.tint,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.highlightDetail = false,
  });

  final Account account;
  final Color tint;
  final String detail;
  final bool selected;
  final bool highlightDetail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.08) : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: tint.withValues(alpha: 0.18),
                  child: Icon(account.type.icon, color: tint, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: highlightDetail ? scheme.primary : scheme.onSurfaceVariant,
                          fontWeight: highlightDetail ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                selected
                    ? CircleAvatar(
                        radius: 13,
                        backgroundColor: scheme.primary,
                        child: Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary),
                      )
                    : Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.outline, width: 2),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.add, color: scheme.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
