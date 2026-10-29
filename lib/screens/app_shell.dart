import 'package:flutter/material.dart';

import '../cloud/cloud_sync.dart';
import '../state/expense_store.dart';
import '../widgets/expense_list.dart';
import 'accounts_screen.dart';
import 'backup_screen.dart';
import 'categories_screen.dart';
import 'history_tab.dart';
import 'overview_tab.dart';

/// The app's frame: Home and History tabs, a shared top bar and Add button.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store, this.cloudSync, this.versionLabel});

  final ExpenseStore store;

  /// Null when cloud backup isn't set up for this build.
  final CloudSync? cloudSync;

  /// Shown at the bottom of the menu so it's easy to tell which build is installed.
  final String? versionLabel;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  ExpenseStore get _store => widget.store;

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openBackup() => _push(BackupScreen(store: _store, cloudSync: widget.cloudSync));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Kipto' : 'History'),
        actions: [
          if (widget.cloudSync case final sync?)
            ListenableBuilder(
              listenable: sync,
              builder: (context, _) =>
                  _CloudStatusButton(status: sync.status, onPressed: _openBackup),
            ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Accounts & cards',
            onPressed: () => _push(AccountsScreen(store: _store)),
          ),
          PopupMenuButton<VoidCallback>(
            tooltip: 'More',
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: () => _push(CategoriesScreen(store: _store)),
                child: const ListTile(
                  leading: Icon(Icons.category_outlined),
                  title: Text('Categories'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _openBackup,
                child: const ListTile(
                  leading: Icon(Icons.settings_backup_restore),
                  title: Text('Backup & restore'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (widget.versionLabel case final label?) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  height: 36,
                  child: Text(label, style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Keeps each tab's scroll position and History's filters when switching.
      body: IndexedStack(
        index: _tab,
        children: [
          OverviewTab(store: _store, onSeeAll: () => setState(() => _tab = 1)),
          HistoryTab(store: _store),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ExpenseActions.add(context, _store),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
        ],
      ),
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
    return IconButton(icon: Icon(icon, color: color), tooltip: tooltip, onPressed: onPressed);
  }
}
