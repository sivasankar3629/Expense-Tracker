import 'dart:convert';

import 'package:flutter/material.dart';

import '../cloud/cloud_sync.dart';
import '../data/backup.dart';
import '../data/backup_files.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.store,
    this.cloudSync,
    this.files = const SystemBackupFiles(),
  });

  final ExpenseStore store;

  /// Null when cloud backup isn't set up for this build.
  final CloudSync? cloudSync;
  final BackupFiles files;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  ExpenseStore get _store => widget.store;

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backUp() => _run(() async {
        final backup = Backup(data: _store.snapshot, exportedAt: DateTime.now());
        try {
          final saved = await widget.files.save(
            backup.fileName,
            utf8.encode(backup.encode()),
          );
          if (!saved) return;
          _store.markBackedUp(backup.exportedAt);
          _showMessage('Backup saved');
        } catch (_) {
          _showMessage('Couldn’t save the backup. Please try again.');
        }
      });

  Future<void> _restore() => _run(() async {
        final Backup backup;
        try {
          final bytes = await widget.files.open();
          if (bytes == null) return;
          backup = Backup.decode(utf8.decode(bytes, allowMalformed: true));
        } on BackupFormatException catch (e) {
          await _showError(e.message);
          return;
        } catch (_) {
          await _showError('Couldn’t open that file. Please try again.');
          return;
        }
        if (!mounted || !await _confirmRestore(backup)) return;
        _store.replaceAll(backup.data);
        _showMessage('Restored ${_count(backup.data.expenses.length, 'expense')}');
      });

  Future<bool> _confirmRestore(Backup backup) async {
    final current = _store.snapshot;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.restore),
        title: const Text('Restore this backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BackupSummary(backup: backup),
            const SizedBox(height: 16),
            Text(
              'This replaces the ${_count(current.expenses.length, 'expense')} and '
              '${_count(current.accounts.length, 'account')} in the app now'
              '${widget.cloudSync?.user != null ? ', and in your cloud backup' : ''}. '
              'It can’t be undone.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showError(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline),
        title: const Text('Can’t restore'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (widget.cloudSync case final sync?) ...[
              _CloudCard(sync: sync),
              const _SectionLabel('Backup file'),
            ],
            _ActionCard(
              icon: Icons.save_alt,
              title: 'Back up',
              description: 'Save all expenses, accounts and cards to a file. '
                  'Keep it somewhere safe, like Google Drive, so you can restore it '
                  'on a new phone.',
              status: _lastBackupText(context),
              buttonLabel: 'Back up now',
              // With cloud backup on offer, it's the main action, not this.
              outlined: widget.cloudSync != null,
              onPressed: _busy ? null : _backUp,
            ),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.settings_backup_restore,
              title: 'Restore',
              description: 'Replace everything in the app with the contents of a backup file.',
              buttonLabel: 'Choose backup file',
              outlined: true,
              onPressed: _busy ? null : _restore,
            ),
          ],
        ),
      ),
    );
  }

  String _lastBackupText(BuildContext context) {
    final last = _store.lastBackupAt;
    if (last == null) return 'Never backed up';
    final time = TimeOfDay.fromDateTime(last).format(context);
    return 'Last backup: ${formatDate(last)}, $time';
  }
}

String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Sign-in and live status for automatic cloud backup.
class _CloudCard extends StatelessWidget {
  const _CloudCard({required this.sync});

  final CloudSync sync;

  Future<void> _confirmSignOut(BuildContext context) async {
    final waiting = sync.pendingChanges;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn off cloud backup?'),
        content: Text(
          waiting > 0
              ? '${_count(waiting, 'change')} haven’t reached the cloud yet and won’t be backed up. '
                  'Your data stays on this phone.'
              : 'Your data stays on this phone and in the cloud. New changes won’t be '
                  'backed up until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await sync.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final user = sync.user;

        final (IconData statusIcon, String statusText, Color statusColor) = switch (sync.status) {
          CloudStatus.signedOut || CloudStatus.connecting => (
              Icons.cloud_off_outlined,
              'Off',
              scheme.onSurfaceVariant,
            ),
          CloudStatus.syncing => (
              Icons.cloud_upload_outlined,
              'Backing up ${_count(sync.pendingChanges, 'change')}… '
                  'They upload whenever you’re online.',
              scheme.primary,
            ),
          CloudStatus.upToDate => (
              Icons.cloud_done_outlined,
              'All changes backed up',
              scheme.primary,
            ),
          CloudStatus.failing => (
              Icons.error_outline,
              'Some changes didn’t reach the cloud. Your data is safe on this phone; '
                  'tap Retry to upload them.',
              scheme.error,
            ),
        };

        return _ActionCard(
          icon: Icons.cloud_outlined,
          title: 'Cloud backup',
          description: user == null
              ? 'Sign in with Google and every change is backed up automatically, '
                  'within seconds. It’s free, and only you can see your data.'
              : 'Signed in as ${user.email ?? user.name ?? 'your Google account'}. '
                  'Every change is backed up automatically.',
          statusWidget: user == null && sync.error == null
              ? null
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      user == null ? Icons.error_outline : statusIcon,
                      size: 18,
                      color: user == null ? scheme.error : statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user == null ? sync.error! : statusText,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: user == null ? scheme.error : statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
          buttonLabel: switch (sync.status) {
            CloudStatus.connecting => 'Connecting…',
            CloudStatus.signedOut => 'Sign in with Google',
            CloudStatus.failing => 'Retry backup',
            _ => 'Sign out',
          },
          outlined: sync.status == CloudStatus.syncing || sync.status == CloudStatus.upToDate,
          onPressed: switch (sync.status) {
            CloudStatus.connecting => null,
            CloudStatus.signedOut => sync.signIn,
            CloudStatus.failing => sync.retry,
            _ => () => _confirmSignOut(context),
          },
          secondaryLabel: sync.status == CloudStatus.failing ? 'Sign out' : null,
          onSecondary: () => _confirmSignOut(context),
        );
      },
    );
  }
}

class _BackupSummary extends StatelessWidget {
  const _BackupSummary({required this.backup});

  final Backup backup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = TimeOfDay.fromDateTime(backup.exportedAt).format(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup from ${formatDate(backup.exportedAt)}, $time',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${_count(backup.data.expenses.length, 'expense')} · '
            '${_count(backup.data.accounts.length, 'account')}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.status,
    this.statusWidget,
    this.outlined = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final String? status;

  /// Replaces the plain [status] line when richer content is needed.
  final Widget? statusWidget;
  final bool outlined;

  /// An optional quieter action shown under the main button.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (statusWidget != null) ...[
              const SizedBox(height: 12),
              statusWidget!,
            ] else if (status != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    status!,
                    style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            if (outlined)
              OutlinedButton(onPressed: onPressed, style: buttonStyle, child: Text(buttonLabel))
            else
              FilledButton(onPressed: onPressed, style: buttonStyle, child: Text(buttonLabel)),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 4),
              Center(child: TextButton(onPressed: onSecondary, child: Text(secondaryLabel!))),
            ],
          ],
        ),
      ),
    );
  }
}
