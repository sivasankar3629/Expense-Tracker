import 'package:flutter/material.dart';

import '../cloud/cloud_sync.dart';
import '../state/expense_store.dart';
import '../widgets/expense_list.dart';
import 'backup_screen.dart';
import 'history_tab.dart';
import 'overview_tab.dart';
import 'settings_screen.dart';

/// The app's frame: Home and History tabs, a shared top bar and Add button.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store, this.cloudSync, this.versionLabel});

  final ExpenseStore store;

  /// Null when cloud backup isn't set up for this build.
  final CloudSync? cloudSync;

  /// Shown at the bottom of Settings so it's easy to tell which build is installed.
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_tab == 0) ...[
              ExcludeSemantics(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(child: Text(_tab == 0 ? 'Kipto' : 'History')),
          ],
        ),
        actions: [
          if (widget.cloudSync case final sync?)
            ListenableBuilder(
              listenable: sync,
              builder: (context, _) =>
                  _CloudStatusButton(status: sync.status, onPressed: _openBackup),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _push(SettingsScreen(
              store: _store,
              cloudSync: widget.cloudSync,
              versionLabel: widget.versionLabel,
            )),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Keeps each tab's scroll position and History's filters when switching.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: IndexedStack(
            index: _tab,
            children: [
              OverviewTab(store: _store, onSeeAll: () => setState(() => _tab = 1)),
              HistoryTab(store: _store),
            ],
          ),
        ),
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
