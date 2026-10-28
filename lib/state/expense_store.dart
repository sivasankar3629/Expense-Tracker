import 'package:flutter/foundation.dart';

import '../data/expense_storage.dart';
import '../models/account.dart';
import '../models/expense.dart';

/// Holds all expenses and accounts, notifies listeners on change and saves
/// every change to [ExpenseStorage].
///
/// The UI updates immediately; writes are queued in order behind it, so a
/// slow disk never makes the app feel slow.
class ExpenseStore extends ChangeNotifier {
  ExpenseStore({ExpenseStorage? storage, StoredData data = const StoredData()})
      : _storage = storage ?? InMemoryStorage(),
        _accounts = [Account.cash, ...data.accounts],
        _expenses = [...data.expenses]..sort(_newestFirst),
        _lastUsedAccountId = data.lastUsedAccountId ?? Account.cash.id;

  /// Creates a store pre-filled with everything previously saved in [storage].
  static Future<ExpenseStore> open(ExpenseStorage storage) async =>
      ExpenseStore(storage: storage, data: await storage.load());

  final ExpenseStorage _storage;
  final List<Account> _accounts;
  final List<Expense> _expenses;
  String _lastUsedAccountId;
  Future<void> _pendingWrites = Future.value();

  /// Completes once every change made so far has been saved.
  Future<void> get saved => _pendingWrites;

  void _save(Future<void> Function() write) {
    _pendingWrites = _pendingWrites.then((_) => write()).catchError(
      (Object error, StackTrace stack) => debugPrint('Failed to save: $error\n$stack'),
    );
  }

  /// Newest first; for identical times, the most recently added wins.
  static int _newestFirst(Expense a, Expense b) {
    final byDate = b.dateTime.compareTo(a.dateTime);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  /// Newest first.
  List<Expense> get expenses => List.unmodifiable(_expenses);

  List<Account> get accounts => List.unmodifiable(_accounts);

  List<Account> accountsOfType(AccountType type) =>
      _accounts.where((a) => a.type == type).toList();

  Account? accountById(String id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// Pre-selected when adding an expense, since people tend to pay the same way.
  Account get lastUsedAccount => accountById(_lastUsedAccountId) ?? Account.cash;

  void addExpense(Expense expense) {
    _insert(expense);
    _lastUsedAccountId = expense.accountId;
    notifyListeners();
    _save(() => _storage.saveExpense(expense));
    _save(() => _storage.saveLastUsedAccountId(expense.accountId));
  }

  /// Replaces the expense with the same id, e.g. after editing it.
  void updateExpense(Expense updated) {
    _expenses.removeWhere((e) => e.id == updated.id);
    _insert(updated);
    notifyListeners();
    _save(() => _storage.saveExpense(updated));
  }

  void deleteExpense(Expense expense) {
    _expenses.removeWhere((e) => e.id == expense.id);
    notifyListeners();
    _save(() => _storage.deleteExpense(expense.id));
  }

  /// Puts back a deleted expense (for undo) without changing the last used account.
  void restoreExpense(Expense expense) {
    if (_expenses.any((e) => e.id == expense.id)) return;
    _insert(expense);
    notifyListeners();
    _save(() => _storage.saveExpense(expense));
  }

  void _insert(Expense expense) {
    _expenses
      ..add(expense)
      ..sort(_newestFirst);
  }

  bool isNicknameTaken(String nickname, {String? exceptId}) {
    final wanted = nickname.trim().toLowerCase();
    return _accounts.any(
      (a) => a.id != exceptId && a.nickname.toLowerCase() == wanted,
    );
  }

  Account addAccount(String nickname, AccountType type) {
    final account = Account(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nickname: nickname.trim(),
      type: type,
    );
    _accounts.add(account);
    notifyListeners();
    _save(() => _storage.saveAccount(account));
    return account;
  }

  void updateAccount(Account updated) {
    final index = _accounts.indexWhere((a) => a.id == updated.id);
    if (index == -1) return;
    _accounts[index] = updated;
    notifyListeners();
    _save(() => _storage.saveAccount(updated));
  }

  int expenseCountFor(String accountId) =>
      _expenses.where((e) => e.accountId == accountId).length;

  /// Accounts with expenses can't be deleted, so no expense loses its source.
  bool canDelete(Account account) =>
      account.id != Account.cash.id && expenseCountFor(account.id) == 0;

  void deleteAccount(Account account) {
    if (!canDelete(account)) return;
    _accounts.removeWhere((a) => a.id == account.id);
    notifyListeners();
    _save(() => _storage.deleteAccount(account.id));
  }
}
