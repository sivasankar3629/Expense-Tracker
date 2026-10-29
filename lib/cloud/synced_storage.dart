import 'package:flutter/foundation.dart';

import '../data/expense_storage.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/preferences.dart';
import 'cloud_backup.dart';

/// Saves to the phone first, then copies each change to [cloud] while one is
/// attached.
///
/// Cloud writes are never awaited by the app: offline, they wait in the
/// cloud SDK's own queue and upload later, while the app carries on.
class SyncedStorage implements ExpenseStorage {
  SyncedStorage(this.local);

  final ExpenseStorage local;

  /// Set while signed in; null means changes stay on the phone only.
  CloudBackup? cloud;

  /// Cloud writes sent but not yet confirmed by the server.
  final ValueNotifier<int> pending = ValueNotifier(0);

  /// Set when a cloud write fails. It stays set, even if later writes work,
  /// because the cloud is now missing something; only a full [mirrorAll]
  /// (which re-checks everything) clears it.
  final ValueNotifier<Object?> lastError = ValueNotifier(null);

  void _mirror(Future<void> Function(CloudBackup cloud) write, {bool resyncs = false}) {
    final target = cloud;
    if (target == null) return;
    pending.value++;
    write(target).then(
      (_) {
        if (resyncs) lastError.value = null;
      },
      onError: (Object error, StackTrace stack) {
        lastError.value = error;
        debugPrint('Cloud backup failed: $error\n$stack');
      },
    ).whenComplete(() => pending.value--);
  }

  /// Brings the cloud in line with [data], e.g. right after signing in or to
  /// recover from a failed write. Only differences are uploaded.
  void mirrorAll(StoredData data) => _mirror((c) => c.replaceAll(data), resyncs: true);

  @override
  Future<StoredData> load() => local.load();

  @override
  Future<void> saveExpense(Expense expense) async {
    await local.saveExpense(expense);
    _mirror((c) => c.saveExpense(expense));
  }

  @override
  Future<void> deleteExpense(String id) async {
    await local.deleteExpense(id);
    _mirror((c) => c.deleteExpense(id));
  }

  @override
  Future<void> saveAccount(Account account) async {
    await local.saveAccount(account);
    _mirror((c) => c.saveAccount(account));
  }

  @override
  Future<void> deleteAccount(String id) async {
    await local.deleteAccount(id);
    _mirror((c) => c.deleteAccount(id));
  }

  @override
  Future<void> saveCategory(ExpenseCategory category) async {
    await local.saveCategory(category);
    _mirror((c) => c.saveCategory(category));
  }

  @override
  Future<void> deleteCategory(String id) async {
    await local.deleteCategory(id);
    _mirror((c) => c.deleteCategory(id));
  }

  @override
  Future<void> saveLastUsedAccountId(String id) async {
    await local.saveLastUsedAccountId(id);
    _mirror((c) => c.saveLastUsedAccountId(id));
  }

  /// Device-only; not something to copy between phones.
  @override
  Future<void> saveLastBackupAt(DateTime time) => local.saveLastBackupAt(time);

  @override
  Future<void> savePreferences(Preferences preferences) async {
    await local.savePreferences(preferences);
    _mirror((c) => c.savePreferences(preferences));
  }

  /// Device-only, like [saveLastBackupAt].
  @override
  Future<void> saveThemeChoice(ThemeChoice choice) => local.saveThemeChoice(choice);

  @override
  Future<void> replaceAll(StoredData data) async {
    await local.replaceAll(data);
    _mirror((c) => c.replaceAll(data));
  }
}
