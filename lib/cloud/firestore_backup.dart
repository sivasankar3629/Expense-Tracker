import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/expense_storage.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/expense.dart';
import 'cloud_backup.dart';

/// Keeps a user's data under `users/{uid}` in Firestore:
///
/// - `accounts/{id}`: nickname, type
/// - `categories/{id}`: name, icon, color, budgetPaise (null if none)
/// - `expenses/{id}`: title, amountPaise, dateTime (ms since epoch), accountId,
///   categoryId (null if none), notes
/// - `meta/settings`: lastUsedAccountId
///
/// Firestore's offline cache queues writes made without internet and sends
/// them when the phone is back online, even after the app restarts.
class FirestoreBackup implements CloudBackup {
  FirestoreBackup(FirebaseFirestore firestore, String uid)
      : _user = firestore.collection('users').doc(uid),
        _firestore = firestore;

  final FirebaseFirestore _firestore;
  final DocumentReference<Map<String, Object?>> _user;

  CollectionReference<Map<String, Object?>> get _accounts => _user.collection('accounts');
  CollectionReference<Map<String, Object?>> get _categories => _user.collection('categories');
  CollectionReference<Map<String, Object?>> get _expenses => _user.collection('expenses');
  DocumentReference<Map<String, Object?>> get _settings => _user.collection('meta').doc('settings');

  // Firestore refuses batches of more than 500 writes.
  static const _batchLimit = 450;

  static Map<String, Object?> _expenseData(Expense e) => {
        'title': e.title,
        'amountPaise': (e.amount * 100).round(),
        'dateTime': e.dateTime.millisecondsSinceEpoch,
        'accountId': e.accountId,
        'categoryId': e.categoryId,
        'notes': e.notes,
      };

  static Map<String, Object?> _categoryData(ExpenseCategory c) => {
        'name': c.name,
        'icon': c.iconKey,
        'color': c.colorValue,
        'budgetPaise': c.monthlyBudget == null ? null : (c.monthlyBudget! * 100).round(),
      };

  static Map<String, Object?> _accountData(Account a) => {
        'nickname': a.nickname,
        'type': a.type.name,
      };

  static Expense _expenseFrom(String id, Map<String, Object?> d) => Expense(
        id: id,
        title: d['title'] as String,
        amount: (d['amountPaise'] as num).toInt() / 100,
        dateTime: DateTime.fromMillisecondsSinceEpoch((d['dateTime'] as num).toInt()),
        accountId: d['accountId'] as String,
        categoryId: d['categoryId'] as String?,
        notes: d['notes'] as String? ?? '',
      );

  static ExpenseCategory _categoryFrom(String id, Map<String, Object?> d) => ExpenseCategory(
        id: id,
        name: d['name'] as String,
        iconKey: d['icon'] as String,
        colorValue: (d['color'] as num).toInt(),
        monthlyBudget: switch (d['budgetPaise']) {
          final num paise => paise.toInt() / 100,
          _ => null,
        },
      );

  static Account _accountFrom(String id, Map<String, Object?> d) => Account(
        id: id,
        nickname: d['nickname'] as String,
        type: AccountType.values.byName(d['type'] as String),
      );

  /// Ids are creation timestamps, so sorting by them keeps the order things
  /// were added in.
  static int _byCreation(String a, String b) =>
      (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0);

  @override
  Future<StoredData> fetch({bool fromServer = false}) async {
    final options = GetOptions(source: fromServer ? Source.server : Source.serverAndCache);
    final results = await Future.wait([
      _accounts.get(options),
      _categories.get(options),
      _expenses.get(options),
    ]);
    final settings = await _settings.get(options);
    final accounts = [for (final doc in results[0].docs) _accountFrom(doc.id, doc.data())]
      ..sort((a, b) => _byCreation(a.id, b.id));
    final categories = [for (final doc in results[1].docs) _categoryFrom(doc.id, doc.data())]
      ..sort((a, b) => _byCreation(a.id, b.id));
    return StoredData(
      accounts: accounts,
      categories: categories,
      expenses: [for (final doc in results[2].docs) _expenseFrom(doc.id, doc.data())],
      lastUsedAccountId: settings.data()?['lastUsedAccountId'] as String?,
    );
  }

  @override
  Future<void> saveExpense(Expense expense) =>
      _expenses.doc(expense.id).set(_expenseData(expense));

  @override
  Future<void> deleteExpense(String id) => _expenses.doc(id).delete();

  @override
  Future<void> saveAccount(Account account) =>
      _accounts.doc(account.id).set(_accountData(account));

  @override
  Future<void> deleteAccount(String id) => _accounts.doc(id).delete();

  @override
  Future<void> saveCategory(ExpenseCategory category) =>
      _categories.doc(category.id).set(_categoryData(category));

  @override
  Future<void> deleteCategory(String id) => _categories.doc(id).delete();

  @override
  Future<void> saveLastUsedAccountId(String id) =>
      _settings.set({'lastUsedAccountId': id});

  @override
  Future<void> replaceAll(StoredData data) async {
    final current = await fetch();
    final writes = <void Function(WriteBatch)>[];

    final currentAccounts = {for (final a in current.accounts) a.id: _accountData(a)};
    for (final a in data.accounts) {
      final wanted = _accountData(a);
      if (!_sameData(currentAccounts.remove(a.id), wanted)) {
        writes.add((b) => b.set(_accounts.doc(a.id), wanted));
      }
    }
    for (final id in currentAccounts.keys) {
      writes.add((b) => b.delete(_accounts.doc(id)));
    }

    final currentCategories = {for (final c in current.categories) c.id: _categoryData(c)};
    for (final c in data.categories) {
      final wanted = _categoryData(c);
      if (!_sameData(currentCategories.remove(c.id), wanted)) {
        writes.add((b) => b.set(_categories.doc(c.id), wanted));
      }
    }
    for (final id in currentCategories.keys) {
      writes.add((b) => b.delete(_categories.doc(id)));
    }

    final currentExpenses = {for (final e in current.expenses) e.id: _expenseData(e)};
    for (final e in data.expenses) {
      final wanted = _expenseData(e);
      if (!_sameData(currentExpenses.remove(e.id), wanted)) {
        writes.add((b) => b.set(_expenses.doc(e.id), wanted));
      }
    }
    for (final id in currentExpenses.keys) {
      writes.add((b) => b.delete(_expenses.doc(id)));
    }

    final lastUsed = data.lastUsedAccountId;
    if (lastUsed != null && lastUsed != current.lastUsedAccountId) {
      writes.add((b) => b.set(_settings, {'lastUsedAccountId': lastUsed}));
    }

    for (var i = 0; i < writes.length; i += _batchLimit) {
      final batch = _firestore.batch();
      for (final write in writes.skip(i).take(_batchLimit)) {
        write(batch);
      }
      await batch.commit();
    }
  }

  static bool _sameData(Map<String, Object?>? a, Map<String, Object?> b) {
    if (a == null || a.length != b.length) return false;
    for (final entry in b.entries) {
      if (a[entry.key] != entry.value) return false;
    }
    return true;
  }
}
