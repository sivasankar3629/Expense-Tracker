import 'package:flutter/foundation.dart';

import '../data/expense_storage.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/currency.dart';
import '../models/expense.dart';
import '../models/preferences.dart';
import '../utils/format.dart';
import '../utils/ids.dart';

/// Holds all expenses and accounts, notifies listeners on change and saves
/// every change to [ExpenseStorage].
///
/// The UI updates immediately; writes are queued in order behind it, so a
/// slow disk never makes the app feel slow.
class ExpenseStore extends ChangeNotifier {
  ExpenseStore({ExpenseStorage? storage, StoredData data = const StoredData()})
      : _storage = storage ?? InMemoryStorage(),
        _accounts = [Account.cash, ...data.accounts],
        _categories = [...data.categories],
        _expenses = [...data.expenses]..sort(_newestFirst),
        _lastUsedAccountId = data.lastUsedAccountId ?? Account.cash.id,
        _preferences = data.preferences ?? const Preferences(),
        _themeChoice = data.themeChoice,
        _lastBackupAt = data.lastBackupAt;

  /// Creates a store pre-filled with everything previously saved in [storage].
  static Future<ExpenseStore> open(ExpenseStorage storage) async =>
      ExpenseStore(storage: storage, data: await storage.load());

  final ExpenseStorage _storage;
  final List<Account> _accounts;
  final List<ExpenseCategory> _categories;
  final List<Expense> _expenses;
  String _lastUsedAccountId;
  Preferences _preferences;
  ThemeChoice _themeChoice;
  DateTime? _lastBackupAt;
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

  /// Everything a backup needs. Built-in Cash is left out; it always exists.
  StoredData get snapshot => StoredData(
        accounts: _accounts.where((a) => a.id != Account.cash.id).toList(),
        categories: List.of(_categories),
        expenses: List.of(_expenses),
        lastUsedAccountId: _lastUsedAccountId,
        preferences: _preferences,
      );

  DateTime? get lastBackupAt => _lastBackupAt;

  void markBackedUp(DateTime time) {
    _lastBackupAt = time;
    notifyListeners();
    _save(() => _storage.saveLastBackupAt(time));
  }

  /// Replaces all accounts and expenses with [data], e.g. from a backup.
  void replaceAll(StoredData data) {
    _accounts
      ..clear()
      ..add(Account.cash)
      ..addAll(data.accounts);
    _categories
      ..clear()
      ..addAll(data.categories);
    _expenses
      ..clear()
      ..addAll(data.expenses)
      ..sort(_newestFirst);
    _lastUsedAccountId = data.lastUsedAccountId ?? Account.cash.id;
    _preferences = data.preferences ?? _preferences;
    notifyListeners();
    _save(() => _storage.replaceAll(data));
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
      id: newId(),
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

  /// In the order they were created.
  List<ExpenseCategory> get categories => List.unmodifiable(_categories);

  ExpenseCategory? categoryById(String? id) {
    if (id == null) return null;
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// Most-used first (then by name), so the likeliest picks lead the list.
  List<ExpenseCategory> get categoriesByUse {
    final uses = <String, int>{};
    for (final e in _expenses) {
      final id = e.categoryId;
      if (id != null) uses[id] = (uses[id] ?? 0) + 1;
    }
    return [..._categories]..sort((a, b) {
        final byUse = (uses[b.id] ?? 0).compareTo(uses[a.id] ?? 0);
        return byUse != 0 ? byUse : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  bool isCategoryNameTaken(String name, {String? exceptId}) {
    final wanted = name.trim().toLowerCase();
    return _categories.any((c) => c.id != exceptId && c.name.toLowerCase() == wanted);
  }

  ExpenseCategory addCategory({
    required String name,
    required String iconKey,
    required int colorValue,
  }) {
    final category = ExpenseCategory(
      id: newId(),
      name: name.trim(),
      iconKey: iconKey,
      colorValue: colorValue,
    );
    _categories.add(category);
    notifyListeners();
    _save(() => _storage.saveCategory(category));
    return category;
  }

  void updateCategory(ExpenseCategory updated) {
    final index = _categories.indexWhere((c) => c.id == updated.id);
    if (index == -1) return;
    _categories[index] = updated;
    notifyListeners();
    _save(() => _storage.saveCategory(updated));
  }

  int expenseCountForCategory(String categoryId) =>
      _expenses.where((e) => e.categoryId == categoryId).length;

  /// Removes the category; its expenses are kept and become uncategorised.
  void deleteCategory(ExpenseCategory category) {
    final affected = [
      for (final e in _expenses)
        if (e.categoryId == category.id) e.copyWith(clearCategory: true),
    ];
    for (final e in affected) {
      _expenses[_expenses.indexWhere((x) => x.id == e.id)] = e;
    }
    _categories.removeWhere((c) => c.id == category.id);
    notifyListeners();
    for (final e in affected) {
      _save(() => _storage.saveExpense(e));
    }
    _save(() => _storage.deleteCategory(category.id));
  }

  /// Expenses in [categoryId], newest first; null gives the uncategorised ones.
  List<Expense> expensesInCategory(String? categoryId) =>
      _expenses.where((e) => e.categoryId == categoryId).toList();

  Preferences get preferences => _preferences;

  Currency get currency => _preferences.currency;

  void setCurrency(Currency currency) => _setPreferences(
        _preferences.copyWith(currencyCode: currency.code),
      );

  void setMonthStartDay(int day) => _setPreferences(
        _preferences.copyWith(monthStartDay: day.clamp(1, Preferences.maxMonthStartDay)),
      );

  void _setPreferences(Preferences preferences) {
    if (preferences == _preferences) return;
    _preferences = preferences;
    notifyListeners();
    _save(() => _storage.savePreferences(preferences));
  }

  ThemeChoice get themeChoice => _themeChoice;

  void setThemeChoice(ThemeChoice choice) {
    if (choice == _themeChoice) return;
    _themeChoice = choice;
    notifyListeners();
    _save(() => _storage.saveThemeChoice(choice));
  }

  /// The budget month holding [day]: from the most recent month start day on
  /// or before it, up to (not including) the next one.
  ({DateTime start, DateTime end}) budgetMonthOf(DateTime day) {
    final startDay = _preferences.monthStartDay;
    final start = DateTime(day.year, day.day >= startDay ? day.month : day.month - 1, startDay);
    return (start: start, end: DateTime(start.year, start.month + 1, startDay));
  }

  /// Expenses in the budget month holding [day], newest first.
  List<Expense> expensesInBudgetMonth(DateTime day) {
    final month = budgetMonthOf(day);
    return [
      for (final e in _expenses)
        if (!e.dateTime.isBefore(month.start) && e.dateTime.isBefore(month.end)) e,
    ];
  }

  /// Completes "Spent …" for the budget month holding [day]: "in October",
  /// or "since 25 Oct" when months start on another day.
  String budgetMonthLabel(DateTime day) {
    if (_preferences.monthStartDay == 1) return 'in ${formatMonthName(day)}';
    return 'since ${formatShortDate(budgetMonthOf(day).start)}';
  }

  /// Sets or, with null, removes the category's monthly budget.
  void setCategoryBudget(ExpenseCategory category, double? amount) {
    final current = categoryById(category.id);
    if (current == null) return;
    updateCategory(
      amount == null ? current.copyWith(clearBudget: true) : current.copyWith(monthlyBudget: amount),
    );
  }
}

/// Total of [expenses]' amounts.
double totalOf(Iterable<Expense> expenses) => expenses.fold(0, (sum, e) => sum + e.amount);
