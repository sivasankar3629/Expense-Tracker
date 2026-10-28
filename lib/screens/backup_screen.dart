import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/backup.dart';
import '../data/backup_files.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.store,
    this.files = const SystemBackupFiles(),
  });

  final ExpenseStore store;
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
              '${_count(current.accounts.length, 'account')} in the app now. '
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
            _ActionCard(
              icon: Icons.cloud_upload_outlined,
              title: 'Back up',
              description: 'Save all expenses, accounts and cards to a file. '
                  'Keep it somewhere safe, like Google Drive, so you can restore it '
                  'on a new phone.',
              status: _lastBackupText(context),
              buttonLabel: 'Back up now',
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
    this.outlined = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final String? status;
  final bool outlined;

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
            if (status != null) ...[
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
          ],
        ),
      ),
    );
  }
}
