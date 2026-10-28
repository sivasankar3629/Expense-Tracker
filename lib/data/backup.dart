import 'dart:convert';

import '../models/account.dart';
import '../models/expense.dart';
import 'expense_storage.dart';

/// Why a file couldn't be restored, in words fit to show the user.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// A snapshot of all app data, saved to and read from a JSON file.
///
/// The format is versioned so future releases (e.g. with categories) can still
/// read backups made today.
class Backup {
  const Backup({required this.data, required this.exportedAt});

  static const _appId = 'expense_tracker';
  static const currentVersion = 1;

  final StoredData data;
  final DateTime exportedAt;

  /// e.g. "kipto-backup-2026-10-28.json"
  String get fileName {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = exportedAt;
    return 'kipto-backup-${d.year}-${two(d.month)}-${two(d.day)}.json';
  }

  String encode() => const JsonEncoder.withIndent('  ').convert({
        'app': _appId,
        'version': currentVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'lastUsedAccountId': data.lastUsedAccountId,
        'accounts': [
          for (final a in data.accounts)
            {'id': a.id, 'nickname': a.nickname, 'type': a.type.name},
        ],
        'expenses': [
          for (final e in data.expenses)
            {
              'id': e.id,
              'title': e.title,
              // Whole paise, so amounts round-trip exactly.
              'amountPaise': (e.amount * 100).round(),
              'dateTime': e.dateTime.toIso8601String(),
              'accountId': e.accountId,
              'notes': e.notes,
            },
        ],
      });

  /// Parses and checks a whole backup up front, so a bad file never leaves
  /// the app half-restored.
  static Backup decode(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const BackupFormatException('This file isn’t a backup from this app.');
    }
    if (json is! Map<String, Object?> || json['app'] != _appId) {
      throw const BackupFormatException('This file isn’t a backup from this app.');
    }
    final version = json['version'];
    if (version is! int || version > currentVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of the app. Update the app and try again.',
      );
    }

    try {
      final accounts = [
        for (final raw in _list(json, 'accounts'))
          if (_string(raw, 'id') != Account.cash.id)
            Account(
              id: _string(raw, 'id'),
              nickname: _string(raw, 'nickname'),
              type: AccountType.values.byName(_string(raw, 'type')),
            ),
      ];
      final knownAccountIds = {Account.cash.id, ...accounts.map((a) => a.id)};

      final expenses = [
        for (final raw in _list(json, 'expenses'))
          Expense(
            id: _string(raw, 'id'),
            title: _string(raw, 'title'),
            amount: _int(raw, 'amountPaise') / 100,
            dateTime: DateTime.parse(_string(raw, 'dateTime')),
            // An expense pointing at a missing account falls back to Cash
            // rather than failing the whole restore.
            accountId: knownAccountIds.contains(_string(raw, 'accountId'))
                ? _string(raw, 'accountId')
                : Account.cash.id,
            notes: (raw as Map)['notes'] as String? ?? '',
          ),
      ];

      final lastUsed = json['lastUsedAccountId'];
      return Backup(
        exportedAt: DateTime.parse(_string(json, 'exportedAt')),
        data: StoredData(
          accounts: accounts,
          expenses: expenses,
          lastUsedAccountId:
              lastUsed is String && knownAccountIds.contains(lastUsed) ? lastUsed : null,
        ),
      );
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      // Wrong types, unknown account types, unparseable dates and so on.
      throw const BackupFormatException('This backup file is damaged and can’t be restored.');
    }
  }

  static List<Object?> _list(Object? map, String key) => (map as Map)[key] as List<Object?>;

  static String _string(Object? map, String key) => (map as Map)[key] as String;

  static int _int(Object? map, String key) => (map as Map)[key] as int;
}
