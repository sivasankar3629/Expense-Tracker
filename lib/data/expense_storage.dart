import '../models/account.dart';
import '../models/expense.dart';

/// Everything the app saves, as read back on startup.
class StoredData {
  const StoredData({
    this.accounts = const [],
    this.expenses = const [],
    this.lastUsedAccountId,
  });

  /// User-added accounts in the order they were created; excludes built-in Cash.
  final List<Account> accounts;
  final List<Expense> expenses;
  final String? lastUsedAccountId;
}

/// Where expenses and accounts are saved between app launches.
abstract interface class ExpenseStorage {
  Future<StoredData> load();
  Future<void> saveExpense(Expense expense);
  Future<void> saveAccount(Account account);
  Future<void> deleteAccount(String id);
  Future<void> saveLastUsedAccountId(String id);
}

/// Keeps nothing; used by tests and the web preview, where SQLite isn't available.
class InMemoryStorage implements ExpenseStorage {
  @override
  Future<StoredData> load() async => const StoredData();

  @override
  Future<void> saveExpense(Expense expense) async {}

  @override
  Future<void> saveAccount(Account account) async {}

  @override
  Future<void> deleteAccount(String id) async {}

  @override
  Future<void> saveLastUsedAccountId(String id) async {}
}
