import 'dart:async';

import 'package:flutter/material.dart';

import '../cloud/cloud_sync.dart';
import '../state/expense_store.dart';
import '../widgets/expense_list.dart';
import '../widgets/kipto_backdrop.dart';
import 'backup_screen.dart';
import 'history_tab.dart';
import 'overview_tab.dart';
import 'settings_screen.dart';

/// The app's frame: Home and History tabs, a shared top bar and Add button.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.store,
    this.cloudSync,
    this.versionLabel,
    this.addRequests,
  });

  final ExpenseStore store;

  /// Null when cloud backup isn't set up for this build.
  final CloudSync? cloudSync;

  /// Shown at the bottom of Settings so it's easy to tell which build is installed.
  final String? versionLabel;

  /// Requests from outside the app (the home-screen widget) to add an expense.
  final Stream<void>? addRequests;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  StreamSubscription<void>? _addRequests;

  ExpenseStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    // Only once the first frame is up, so there's a navigator to open the form
    // on; a request made while launching waits in the stream until then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _addRequests = widget.addRequests?.listen((_) {
        if (mounted) ExpenseActions.add(context, _store);
      });
    });
  }

  @override
  void dispose() {
    _addRequests?.cancel();
    super.dispose();
  }

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
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: const CircleBorder(),
            ),
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
      body: KiptoBackdrop(
        child: Center(
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          onPressed: () => ExpenseActions.add(context, _store),
          tooltip: 'Add expense',
          shape: CircleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerLow, width: 4),
          ),
          child: const Icon(Icons.add_rounded, size: 34),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: NavigationBar(
            height: 80,
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_rounded),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
            ],
          ),
        ),
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
    return IconButton(
      icon: Icon(icon, color: color), tooltip: tooltip, onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
        shape: const CircleBorder(),
      ),
    );
  }
}
