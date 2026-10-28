import 'package:sqflite/sqflite.dart';

import '../models/account.dart';
import '../models/expense.dart';
import 'expense_storage.dart';

/// Saves data in a SQLite database on the device.
class SqliteStorage implements ExpenseStorage {
  SqliteStorage._(this._db);

  final Database _db;

  static const _lastUsedAccountKey = 'last_used_account_id';
  static const _lastBackupAtKey = 'last_backup_at';

  /// [factory] and [path] are overridable so tests can use a desktop SQLite.
  static Future<SqliteStorage> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? '${await dbFactory.getDatabasesPath()}/expense_tracker.db';
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 1, onCreate: _createTables),
    );
    return SqliteStorage._(db);
  }

  static Future<void> _createTables(Database db, int version) async {
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

  Future<void> close() => _db.close();

  @override
  Future<StoredData> load() async {
    final accountRows = await _db.query('accounts', orderBy: 'rowid');
    final expenseRows = await _db.query('expenses', orderBy: 'date_time DESC, id DESC');
    final settings = {
      for (final row in await _db.query('settings')) row['key'] as String: row['value'] as String,
    };
    final lastBackupAt = settings[_lastBackupAtKey];
    return StoredData(
      accounts: [
        for (final row in accountRows)
          Account(
            id: row['id'] as String,
            nickname: row['nickname'] as String,
            type: AccountType.values.byName(row['type'] as String),
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
            notes: row['notes'] as String,
          ),
      ],
      lastUsedAccountId: settings[_lastUsedAccountKey],
      lastBackupAt: lastBackupAt == null ? null : DateTime.parse(lastBackupAt),
    );
  }

  static Map<String, Object?> _expenseRow(Expense expense) => {
        'id': expense.id,
        'title': expense.title,
        'amount_paise': (expense.amount * 100).round(),
        'date_time': expense.dateTime.millisecondsSinceEpoch,
        'account_id': expense.accountId,
        'notes': expense.notes,
      };

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
  Future<void> saveLastUsedAccountId(String id) => _saveSetting(_lastUsedAccountKey, id);

  @override
  Future<void> saveLastBackupAt(DateTime time) =>
      _saveSetting(_lastBackupAtKey, time.toIso8601String());

  Future<void> _saveSetting(String key, String value) async {
    await _db.insert(
      'settings',
      {'key': key, 'value': value},
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
        ..delete('settings', where: 'key = ?', whereArgs: [_lastUsedAccountKey]);
      for (final account in data.accounts) {
        batch.insert('accounts', _accountRow(account));
      }
      for (final expense in data.expenses) {
        batch.insert('expenses', _expenseRow(expense));
      }
      final lastUsed = data.lastUsedAccountId;
      if (lastUsed != null) {
        batch.insert('settings', {'key': _lastUsedAccountKey, 'value': lastUsed});
      }
      await batch.commit(noResult: true);
    });
  }
}
