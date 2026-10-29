import 'package:sqflite/sqflite.dart';

import '../models/account.dart';
import '../models/category.dart';
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
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await _createVersion1(db);
          await _upgradeToVersion2(db);
          await _upgradeToVersion3(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _upgradeToVersion2(db);
          if (oldVersion < 3) await _upgradeToVersion3(db);
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
      lastBackupAt: lastBackupAt == null ? null : DateTime.parse(lastBackupAt),
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
      await batch.commit(noResult: true);
    });
  }
}
