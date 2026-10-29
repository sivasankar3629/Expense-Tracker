import 'package:flutter/material.dart';

import '../cloud/cloud_sync.dart';
import '../models/currency.dart';
import '../models/preferences.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import '../widgets/expense_list.dart';
import 'accounts_screen.dart';
import 'backup_screen.dart';
import 'categories_screen.dart';

/// Preferences, plus the places to manage categories, accounts and backups.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store, this.cloudSync, this.versionLabel});

  final ExpenseStore store;
  final CloudSync? cloudSync;
  final String? versionLabel;

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final currency = store.currency;
          final startDay = store.preferences.monthStartDay;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              const SectionHeader(title: 'Preferences'),
              Card(
                child: Column(
                  children: [
                    _SettingTile(
                      icon: Icons.payments_outlined,
                      title: 'Currency',
                      subtitle: '${currency.name} · ${currency.format(1234.5)}',
                      onTap: () => _pickCurrency(context),
                    ),
                    const Divider(indent: 72),
                    _SettingTile(
                      icon: Icons.event_repeat_outlined,
                      title: 'Month starts on',
                      subtitle: startDay == 1
                          ? 'The 1st · calendar months'
                          : 'The ${formatOrdinal(startDay)} · budgets reset on this day',
                      onTap: () => _pickMonthStart(context),
                    ),
                    const Divider(indent: 72),
                    _SettingTile(
                      icon: Icons.palette_outlined,
                      title: 'Theme',
                      subtitle: _themeLabel(store.themeChoice),
                      onTap: () => _pickTheme(context),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Your data'),
              Card(
                child: Column(
                  children: [
                    _SettingTile(
                      icon: Icons.category_outlined,
                      title: 'Categories',
                      subtitle: switch (store.categories.length) {
                        0 => 'None yet',
                        1 => '1 category',
                        final n => '$n categories',
                      },
                      onTap: () => _push(context, CategoriesScreen(store: store)),
                    ),
                    const Divider(indent: 72),
                    _SettingTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Accounts & cards',
                      subtitle: 'Where you pay from',
                      onTap: () => _push(context, AccountsScreen(store: store)),
                    ),
                    const Divider(indent: 72),
                    _SettingTile(
                      icon: Icons.settings_backup_restore,
                      title: 'Backup & restore',
                      subtitle: cloudSync == null ? 'Backup files' : 'Cloud backup and backup files',
                      onTap: () =>
                          _push(context, BackupScreen(store: store, cloudSync: cloudSync)),
                    ),
                  ],
                ),
              ),
              if (versionLabel case final label?)
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Text(
                    'Kipto · $label',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _themeLabel(ThemeChoice choice) => switch (choice) {
        ThemeChoice.system => 'System default',
        ThemeChoice.light => 'Light',
        ThemeChoice.dark => 'Dark',
      };

  Future<void> _pickTheme(BuildContext context) async {
    final picked = await showModalBottomSheet<ThemeChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _SheetFrame(
        title: 'Theme',
        message: 'How Kipto looks on this phone.',
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (choice, icon, detail) in [
                (ThemeChoice.system, Icons.brightness_auto_outlined, 'Follows your phone’s setting'),
                (ThemeChoice.light, Icons.light_mode_outlined, 'Always light'),
                (ThemeChoice.dark, Icons.dark_mode_outlined, 'Always dark'),
              ])
                ListTile(
                  leading: _TileIcon(icon),
                  title: Text(_themeLabel(choice)),
                  subtitle: Text(detail),
                  trailing: choice == store.themeChoice
                      ? Icon(Icons.check, color: Theme.of(sheetContext).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(choice),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) store.setThemeChoice(picked);
  }

  Future<void> _pickCurrency(BuildContext context) async {
    final picked = await showModalBottomSheet<Currency>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _SheetFrame(
        title: 'Currency',
        message: 'Changes how amounts are shown. Amounts aren’t converted.',
        child: Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in Currency.all)
                ListTile(
                  leading: _SymbolBadge(c.symbol, selected: c == store.currency),
                  title: Text(c.name),
                  subtitle: Text('${c.code} · ${c.format(123456.5)}'),
                  trailing: c == store.currency
                      ? Icon(Icons.check, color: Theme.of(sheetContext).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(c),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) store.setCurrency(picked);
  }

  Future<void> _pickMonthStart(BuildContext context) async {
    final current = store.preferences.monthStartDay;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return _SheetFrame(
          title: 'Month starts on',
          message: 'Budgets and monthly totals start over on this day. '
              'Pick your payday to budget from one salary to the next.',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var day = 1; day <= Preferences.maxMonthStartDay; day++)
                  Material(
                    color: day == current ? scheme.primary : scheme.surfaceContainerHigh,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(sheetContext).pop(day),
                      child: Center(
                        child: Text(
                          '$day',
                          style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                color: day == current ? scheme.onPrimary : scheme.onSurface,
                                fontWeight: day == current ? FontWeight.w700 : null,
                              ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) store.setMonthStartDay(picked);
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      leading: _TileIcon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
    );
  }
}

class _SymbolBadge extends StatelessWidget {
  const _SymbolBadge(this.symbol, {required this.selected});

  final String symbol;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        symbol,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
      ),
    );
  }
}

/// Title, a line of explanation and the choices, at most most of the screen tall.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.message, required this.child});

  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
