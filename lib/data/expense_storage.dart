import '../models/account.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/preferences.dart';

/// Everything the app saves, as read back on startup.
class StoredData {
  const StoredData({
    this.accounts = const [],
    this.categories = const [],
    this.expenses = const [],
    this.lastUsedAccountId,
    this.preferences,
    this.lastBackupAt,
    this.themeChoice = ThemeChoice.system,
  });

  /// User-added accounts in the order they were created; excludes built-in Cash.
  final List<Account> accounts;

  /// In the order they were created.
  final List<ExpenseCategory> categories;
  final List<Expense> expenses;
  final String? lastUsedAccountId;

  /// Null when unknown, e.g. in a backup made before preferences existed;
  /// restoring such a backup keeps the current ones.
  final Preferences? preferences;

  /// When this device last made a backup; not part of the backup itself.
  final DateTime? lastBackupAt;

  /// This phone's theme; not part of backups either.
  final ThemeChoice themeChoice;
}

/// Where expenses and accounts are saved between app launches.
abstract interface class ExpenseStorage {
  Future<StoredData> load();
  /// Inserts the expense, or replaces the one with the same id.
  Future<void> saveExpense(Expense expense);
  Future<void> deleteExpense(String id);
  Future<void> saveAccount(Account account);
  Future<void> deleteAccount(String id);
  Future<void> saveCategory(ExpenseCategory category);
  Future<void> deleteCategory(String id);
  Future<void> saveLastUsedAccountId(String id);
  Future<void> saveLastBackupAt(DateTime time);
  Future<void> savePreferences(Preferences preferences);
  Future<void> saveThemeChoice(ThemeChoice choice);

  /// Swaps all accounts and expenses for [data] in one step (for restore).
  Future<void> replaceAll(StoredData data);
}

/// Keeps nothing; used by tests and the web preview, where SQLite isn't available.
class InMemoryStorage implements ExpenseStorage {
  @override
  Future<StoredData> load() async => const StoredData();

  @override
  Future<void> saveExpense(Expense expense) async {}

  @override
  Future<void> deleteExpense(String id) async {}

  @override
  Future<void> saveAccount(Account account) async {}

  @override
  Future<void> deleteAccount(String id) async {}

  @override
  Future<void> saveCategory(ExpenseCategory category) async {}

  @override
  Future<void> deleteCategory(String id) async {}

  @override
  Future<void> saveLastUsedAccountId(String id) async {}

  @override
  Future<void> saveLastBackupAt(DateTime time) async {}

  @override
  Future<void> savePreferences(Preferences preferences) async {}

  @override
  Future<void> saveThemeChoice(ThemeChoice choice) async {}

  @override
  Future<void> replaceAll(StoredData data) async {}
}
