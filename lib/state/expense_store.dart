import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/expense.dart';

/// Holds all expenses and accounts in memory and notifies listeners on change.
class ExpenseStore extends ChangeNotifier {
  final List<Expense> _expenses = [];
  final List<Account> _accounts = [Account.cash];
  String _lastUsedAccountId = Account.cash.id;

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
    _expenses
      ..add(expense)
      // Newest first; for identical times, the most recently added wins.
      ..sort((a, b) {
        final byDate = b.dateTime.compareTo(a.dateTime);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    _lastUsedAccountId = expense.accountId;
    notifyListeners();
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
    return account;
  }

  void updateAccount(Account updated) {
    final index = _accounts.indexWhere((a) => a.id == updated.id);
    if (index == -1) return;
    _accounts[index] = updated;
    notifyListeners();
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
  }
}
