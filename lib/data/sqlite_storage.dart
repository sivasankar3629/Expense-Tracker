import 'package:sqflite/sqflite.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/preferences.dart';
import '../sms/detection_storage.dart';
import '../sms/sms_parser.dart';
import 'expense_storage.dart';

/// Saves data in a SQLite database on the device.
class SqliteStorage implements ExpenseStorage, DetectionStorage {
  SqliteStorage._(this._db);

  final Database _db;

  static const _lastUsedAccountKey = 'last_used_account_id';
  static const _lastBackupAtKey = 'last_backup_at';
  static const _currencyKey = 'currency';
  static const _monthStartDayKey = 'month_start_day';
  static const _themeKey = 'theme';
  static const _smsEnabledKey = 'sms_enabled';
  static const _smsScannedUntilKey = 'sms_scanned_until';

  /// [factory] and [path] are overridable so tests can use a desktop SQLite.
  static Future<SqliteStorage> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? '${await dbFactory.getDatabasesPath()}/expense_tracker.db';
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await _createVersion1(db);
          await _upgradeToVersion2(db);
          await _upgradeToVersion3(db);
          await _upgradeToVersion4(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _upgradeToVersion2(db);
          if (oldVersion < 3) await _upgradeToVersion3(db);
          if (oldVersion < 4) await _upgradeToVersion4(db);
        },
      ),
    );
    return SqliteStorage._(db);
  }

  /// The original tables. New installs build these and then apply each
  /// upgrade, so every phone ends up with the same schema.
  static Future<void> _createVersion1(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE accounts (
          id TEXT PRIMARY KEY,
          nickname TEXT NOT NULL,
          type TEXT NOT NULL
        )''')
      // Amounts are stored in paise so totals never pick up floating-point drift.
      ..execute('''
        CREATE TABLE expenses (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          amount_paise INTEGER NOT NULL,
          date_time INTEGER NOT NULL,
          account_id TEXT NOT NULL,
          notes TEXT NOT NULL DEFAULT ''
        )''')
      ..execute('CREATE INDEX expenses_date_time ON expenses (date_time)')
      ..execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )''');
    await batch.commit(noResult: true);
  }

  /// Adds categories. Existing expenses simply have none.
  static Future<void> _upgradeToVersion2(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          color INTEGER NOT NULL
        )''')
      ..execute('ALTER TABLE expenses ADD COLUMN category_id TEXT');
    await batch.commit(noResult: true);
  }

  /// Adds monthly budgets, in paise; null means no budget.
  static Future<void> _upgradeToVersion3(Database db) async {
    await db.execute('ALTER TABLE categories ADD COLUMN budget_paise INTEGER');
  }

  /// Adds expenses detected from SMS, waiting for review, and which account
  /// each card or account ending belongs to. Only ever on this phone.
  static Future<void> _upgradeToVersion4(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE sms_detected (
          sms_id TEXT PRIMARY KEY,
          amount_paise INTEGER NOT NULL,
          date_time INTEGER NOT NULL,
          sender TEXT NOT NULL,
          body TEXT NOT NULL,
          merchant TEXT,
          account_hint TEXT,
          is_card INTEGER NOT NULL DEFAULT 0,
          reference TEXT
        )''')
      ..execute('''
        CREATE TABLE sms_account_hints (
          hint TEXT PRIMARY KEY,
          account_id TEXT NOT NULL
        )''');
    await batch.commit(noResult: true);
  }

  Future<void> close() => _db.close();

  @override
  Future<StoredData> load() async {
    final accountRows = await _db.query('accounts', orderBy: 'rowid');
    final categoryRows = await _db.query('categories', orderBy: 'rowid');
    final expenseRows = await _db.query('expenses', orderBy: 'date_time DESC, id DESC');
    final settings = {
      for (final row in await _db.query('settings')) row['key'] as String: row['value'] as String,
    };
    final lastBackupAt = settings[_lastBackupAtKey];
    final theme = settings[_themeKey];
    return StoredData(
      accounts: [
        for (final row in accountRows)
          Account(
            id: row['id'] as String,
            nickname: row['nickname'] as String,
            type: AccountType.values.byName(row['type'] as String),
          ),
      ],
      categories: [
        for (final row in categoryRows)
          ExpenseCategory(
            id: row['id'] as String,
            name: row['name'] as String,
            iconKey: row['icon'] as String,
            colorValue: row['color'] as int,
            monthlyBudget: switch (row['budget_paise']) {
              final int paise => paise / 100,
              _ => null,
            },
          ),
      ],
      expenses: [
        for (final row in expenseRows)
          Expense(
            id: row['id'] as String,
            title: row['title'] as String,
            amount: (row['amount_paise'] as int) / 100,
            dateTime: DateTime.fromMillisecondsSinceEpoch(row['date_time'] as int),
            accountId: row['account_id'] as String,
            categoryId: row['category_id'] as String?,
            notes: row['notes'] as String,
          ),
      ],
      lastUsedAccountId: settings[_lastUsedAccountKey],
      preferences: Preferences.fromJson({
        'currency': settings[_currencyKey],
        'monthStartDay': int.tryParse(settings[_monthStartDayKey] ?? ''),
      }),
      lastBackupAt: lastBackupAt == null ? null : DateTime.parse(lastBackupAt),
      themeChoice: ThemeChoice.values.asNameMap()[theme] ?? ThemeChoice.system,
    );
  }

  static Map<String, Object?> _expenseRow(Expense expense) => {
        'id': expense.id,
        'title': expense.title,
        'amount_paise': (expense.amount * 100).round(),
        'date_time': expense.dateTime.millisecondsSinceEpoch,
        'account_id': expense.accountId,
        'category_id': expense.categoryId,
        'notes': expense.notes,
      };

  static Map<String, Object?> _categoryRow(ExpenseCategory category) => {
        'id': category.id,
        'name': category.name,
        'icon': category.iconKey,
        'color': category.colorValue,
        'budget_paise': _paise(category.monthlyBudget),
      };

  static int? _paise(double? amount) => amount == null ? null : (amount * 100).round();

  static Map<String, Object?> _accountRow(Account account) => {
        'id': account.id,
        'nickname': account.nickname,
        'type': account.type.name,
      };

  @override
  Future<void> saveExpense(Expense expense) async {
    await _db.insert(
      'expenses',
      _expenseRow(expense),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteExpense(String id) async {
    await _db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> saveAccount(Account account) async {
    final values = _accountRow(account)..remove('id');
    // Update in place rather than REPLACE, which would move the account to the
    // end of the list by giving it a new rowid.
    final updated = await _db.update(
      'accounts',
      values,
      where: 'id = ?',
      whereArgs: [account.id],
    );
    if (updated == 0) {
      await _db.insert('accounts', {'id': account.id, ...values});
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> saveCategory(ExpenseCategory category) async {
    final values = _categoryRow(category)..remove('id');
    // Updated in place for the same reason as accounts: keep the list order.
    final updated = await _db.update(
      'categories',
      values,
      where: 'id = ?',
      whereArgs: [category.id],
    );
    if (updated == 0) {
      await _db.insert('categories', {'id': category.id, ...values});
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> saveLastUsedAccountId(String id) => _saveSetting(_lastUsedAccountKey, id);

  @override
  Future<void> saveLastBackupAt(DateTime time) =>
      _saveSetting(_lastBackupAtKey, time.toIso8601String());

  @override
  Future<void> savePreferences(Preferences preferences) async {
    final batch = _db.batch();
    _preferenceRows(preferences).forEach((key, value) {
      batch.insert('settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await batch.commit(noResult: true);
  }

  static Map<String, String> _preferenceRows(Preferences preferences) => {
        _currencyKey: preferences.currencyCode,
        _monthStartDayKey: '${preferences.monthStartDay}',
      };

  @override
  Future<void> saveThemeChoice(ThemeChoice choice) => _saveSetting(_themeKey, choice.name);

  Future<void> _saveSetting(String key, String value) async {
    await _db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<DetectionData> loadDetection() async {
    final settings = {
      for (final row in await _db.query('settings')) row['key'] as String: row['value'] as String,
    };
    final scannedUntil = int.tryParse(settings[_smsScannedUntilKey] ?? '');
    return DetectionData(
      enabled: settings[_smsEnabledKey] == '1',
      scannedUntil: scannedUntil == null ? null : DateTime.fromMillisecondsSinceEpoch(scannedUntil),
      pending: [
        for (final row in await _db.query('sms_detected', orderBy: 'date_time DESC'))
          DetectedTransaction(
            smsId: row['sms_id'] as String,
            amount: (row['amount_paise'] as int) / 100,
            date: DateTime.fromMillisecondsSinceEpoch(row['date_time'] as int),
            sender: row['sender'] as String,
            body: row['body'] as String,
            merchant: row['merchant'] as String?,
            accountHint: row['account_hint'] as String?,
            isCard: row['is_card'] == 1,
            reference: row['reference'] as String?,
          ),
      ],
      accountHints: {
        for (final row in await _db.query('sms_account_hints'))
          row['hint'] as String: row['account_id'] as String,
      },
    );
  }

  @override
  Future<void> saveDetectionEnabled(bool enabled) => _saveSetting(_smsEnabledKey, enabled ? '1' : '0');

  @override
  Future<void> saveScannedUntil(DateTime time) =>
      _saveSetting(_smsScannedUntilKey, '${time.millisecondsSinceEpoch}');

  @override
  Future<void> addDetected(List<DetectedTransaction> transactions) async {
    final batch = _db.batch();
    for (final t in transactions) {
      batch.insert(
        'sms_detected',
        {
          'sms_id': t.smsId,
          'amount_paise': (t.amount * 100).round(),
          'date_time': t.date.millisecondsSinceEpoch,
          'sender': t.sender,
          'body': t.body,
          'merchant': t.merchant,
          'account_hint': t.accountHint,
          'is_card': t.isCard ? 1 : 0,
          'reference': t.reference,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> removeDetected(List<String> smsIds) async {
    if (smsIds.isEmpty) return;
    await _db.delete(
      'sms_detected',
      where: 'sms_id IN (${List.filled(smsIds.length, '?').join(', ')})',
      whereArgs: smsIds,
    );
  }

  @override
  Future<void> saveAccountHint(String hint, String accountId) async {
    await _db.insert(
      'sms_account_hints',
      {'hint': hint, 'account_id': accountId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> replaceAll(StoredData data) async {
    // One transaction: if anything fails, the old data is left untouched.
    await _db.transaction((txn) async {
      final batch = txn.batch()
        ..delete('expenses')
        ..delete('accounts')
        ..delete('categories')
        ..delete('settings', where: 'key = ?', whereArgs: [_lastUsedAccountKey]);
      for (final account in data.accounts) {
        batch.insert('accounts', _accountRow(account));
      }
      for (final category in data.categories) {
        batch.insert('categories', _categoryRow(category));
      }
      for (final expense in data.expenses) {
        batch.insert('expenses', _expenseRow(expense));
      }
      final lastUsed = data.lastUsedAccountId;
      if (lastUsed != null) {
        batch.insert('settings', {'key': _lastUsedAccountKey, 'value': lastUsed});
      }
      if (data.preferences case final preferences?) {
        _preferenceRows(preferences).forEach((key, value) {
          batch.insert('settings', {'key': key, 'value': value},
              conflictAlgorithm: ConflictAlgorithm.replace);
        });
      }
      await batch.commit(noResult: true);
    });
  }
}
