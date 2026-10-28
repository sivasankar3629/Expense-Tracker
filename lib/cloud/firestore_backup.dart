import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/expense_storage.dart';
import '../models/account.dart';
import '../models/expense.dart';
import 'cloud_backup.dart';

/// Keeps a user's data under `users/{uid}` in Firestore:
///
/// - `accounts/{id}`: nickname, type
/// - `expenses/{id}`: title, amountPaise, dateTime (ms since epoch), accountId, notes
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
  CollectionReference<Map<String, Object?>> get _expenses => _user.collection('expenses');
  DocumentReference<Map<String, Object?>> get _settings => _user.collection('meta').doc('settings');

  // Firestore refuses batches of more than 500 writes.
  static const _batchLimit = 450;

  static Map<String, Object?> _expenseData(Expense e) => {
        'title': e.title,
        'amountPaise': (e.amount * 100).round(),
        'dateTime': e.dateTime.millisecondsSinceEpoch,
        'accountId': e.accountId,
        'notes': e.notes,
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
        notes: d['notes'] as String? ?? '',
      );

  static Account _accountFrom(String id, Map<String, Object?> d) => Account(
        id: id,
        nickname: d['nickname'] as String,
        type: AccountType.values.byName(d['type'] as String),
      );

  /// Account ids are creation timestamps, so sorting by them keeps the order
  /// accounts were added in.
  static int _byCreation(Account a, Account b) =>
      (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0);

  @override
  Future<StoredData> fetch({bool fromServer = false}) async {
    final options = GetOptions(source: fromServer ? Source.server : Source.serverAndCache);
    final results = await Future.wait([_accounts.get(options), _expenses.get(options)]);
    final settings = await _settings.get(options);
    final accounts = [for (final doc in results[0].docs) _accountFrom(doc.id, doc.data())]
      ..sort(_byCreation);
    return StoredData(
      accounts: accounts,
      expenses: [for (final doc in results[1].docs) _expenseFrom(doc.id, doc.data())],
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
