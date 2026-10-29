import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/cloud/cloud_backup.dart';
import 'package:expense_tracker/cloud/cloud_sync.dart';
import 'package:expense_tracker/cloud/firestore_backup.dart';
import 'package:expense_tracker/cloud/synced_storage.dart';
import 'package:expense_tracker/data/expense_storage.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/screens/backup_screen.dart';
import 'package:expense_tracker/state/expense_store.dart';
import 'package:expense_tracker/theme.dart';

/// A cloud kept in memory; can pretend to be offline.
class FakeCloud implements CloudBackup {
  FakeCloud([StoredData initial = const StoredData()])
      : accounts = {for (final a in initial.accounts) a.id: a},
        categories = {for (final c in initial.categories) c.id: c},
        expenses = {for (final e in initial.expenses) e.id: e},
        lastUsedAccountId = initial.lastUsedAccountId;

  final Map<String, Account> accounts;
  final Map<String, ExpenseCategory> categories;
  final Map<String, Expense> expenses;
  String? lastUsedAccountId;
  bool offline = false;

  @override
  Future<StoredData> fetch({bool fromServer = false}) async {
    if (offline && fromServer) throw StateError('offline');
    return StoredData(
      accounts: accounts.values.toList(),
      categories: categories.values.toList(),
      expenses: expenses.values.toList(),
      lastUsedAccountId: lastUsedAccountId,
    );
  }

  @override
  Future<void> saveCategory(ExpenseCategory category) async => categories[category.id] = category;

  @override
  Future<void> deleteCategory(String id) async => categories.remove(id);

  @override
  Future<void> saveExpense(Expense expense) async => expenses[expense.id] = expense;

  @override
  Future<void> deleteExpense(String id) async => expenses.remove(id);

  @override
  Future<void> saveAccount(Account account) async => accounts[account.id] = account;

  @override
  Future<void> deleteAccount(String id) async => accounts.remove(id);

  @override
  Future<void> saveLastUsedAccountId(String id) async => lastUsedAccountId = id;

  @override
  Future<void> replaceAll(StoredData data) async {
    accounts
      ..clear()
      ..addAll({for (final a in data.accounts) a.id: a});
    categories
      ..clear()
      ..addAll({for (final c in data.categories) c.id: c});
    expenses
      ..clear()
      ..addAll({for (final e in data.expenses) e.id: e});
    lastUsedAccountId = data.lastUsedAccountId;
  }
}

class FakeAuth implements CloudAuth {
  FakeAuth({this.currentUser});

  @override
  CloudUser? currentUser;
  bool cancel = false;
  int signOuts = 0;

  @override
  Future<CloudUser?> signIn() async {
    if (cancel) return null;
    return currentUser = const CloudUser(uid: 'u1', email: 'me@example.com');
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    currentUser = null;
  }
}

Expense _expense(String id, String title, {String accountId = 'cash', double amount = 10}) =>
    Expense(
      id: id,
      title: title,
      amount: amount,
      dateTime: DateTime(2026, 10, 28, 9),
      accountId: accountId,
    );

const _sbi = Account(id: '100', nickname: 'SBI Savings', type: AccountType.bank);
const _hdfc = Account(id: '200', nickname: 'HDFC Millennia', type: AccountType.creditCard);

/// Wires a store, mirrored storage and sync together like main() does.
({ExpenseStore store, SyncedStorage storage, CloudSync sync}) _setUp({
  required FakeCloud cloud,
  required FakeAuth auth,
  StoredData phone = const StoredData(),
}) {
  final storage = SyncedStorage(InMemoryStorage());
  final store = ExpenseStore(storage: storage, data: phone);
  final sync = CloudSync(auth: auth, storage: storage, store: store, backupFor: (_) => cloud)
    ..start();
  return (store: store, storage: storage, sync: sync);
}

void main() {
  group('mergeForSignIn', () {
    test('keeps everything from both sides; the phone wins on conflicts', () {
      final merged = mergeForSignIn(
        phone: StoredData(
          accounts: const [_sbi],
          expenses: [_expense('1', 'Tea (phone)'), _expense('2', 'Lunch')],
        ),
        cloud: StoredData(
          accounts: const [_hdfc],
          expenses: [_expense('1', 'Tea (cloud)'), _expense('3', 'Fuel')],
        ),
      );

      expect(merged.accounts.map((a) => a.nickname), ['SBI Savings', 'HDFC Millennia']);
      expect(
        {for (final e in merged.expenses) e.id: e.title},
        {'1': 'Tea (phone)', '2': 'Lunch', '3': 'Fuel'},
      );
    });

    test('folds a same-named account from the cloud into the phone’s', () {
      const cloudSbi = Account(id: '999', nickname: 'sbi savings', type: AccountType.bank);
      final merged = mergeForSignIn(
        phone: const StoredData(accounts: [_sbi]),
        cloud: StoredData(
          accounts: const [cloudSbi],
          expenses: [_expense('1', 'Rent', accountId: cloudSbi.id)],
          lastUsedAccountId: cloudSbi.id,
        ),
      );

      expect(merged.accounts.single.id, _sbi.id);
      expect(merged.expenses.single.accountId, _sbi.id);
      expect(merged.lastUsedAccountId, _sbi.id);
    });

    test('folds a same-named category and moves its expenses over', () {
      const phoneFood = ExpenseCategory(id: '1', name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      const cloudFood = ExpenseCategory(id: '9', name: 'food', iconKey: 'tag', colorValue: 0xFF1E88E5);
      const cloudRent = ExpenseCategory(id: '8', name: 'Rent', iconKey: 'home', colorValue: 0xFF43A047);
      final merged = mergeForSignIn(
        phone: const StoredData(categories: [phoneFood]),
        cloud: StoredData(
          categories: const [cloudFood, cloudRent],
          expenses: [
            _expense('a', 'Lunch').copyWith(categoryId: cloudFood.id),
            _expense('b', 'Rent').copyWith(categoryId: cloudRent.id),
          ],
        ),
      );

      expect(merged.categories.map((c) => c.id), ['1', '8']);
      expect({for (final e in merged.expenses) e.id: e.categoryId}, {'a': '1', 'b': '8'});
    });

    test('a new phone takes the cloud’s last used account', () {
      final merged = mergeForSignIn(
        phone: const StoredData(lastUsedAccountId: 'cash'),
        cloud: StoredData(
          accounts: const [_hdfc],
          expenses: [_expense('1', 'Dinner', accountId: _hdfc.id)],
          lastUsedAccountId: _hdfc.id,
        ),
      );
      expect(merged.lastUsedAccountId, _hdfc.id);
    });
  });

  group('SyncedStorage', () {
    test('copies changes to the cloud only while one is attached', () async {
      final cloud = FakeCloud();
      final storage = SyncedStorage(InMemoryStorage());
      final store = ExpenseStore(storage: storage);

      store.addExpense(_expense('1', 'Before sign-in'));
      await store.saved;
      expect(cloud.expenses, isEmpty);

      storage.cloud = cloud;
      store
        ..addExpense(_expense('2', 'Tea'))
        ..updateExpense(_expense('2', 'Masala tea'))
        ..addAccount('SBI Savings', AccountType.bank);
      await store.saved;
      await pumpEventQueue();

      expect(cloud.expenses.keys, ['2']);
      expect(cloud.expenses['2']!.title, 'Masala tea');
      expect(cloud.accounts.values.single.nickname, 'SBI Savings');
      expect(storage.pending.value, 0);

      store.deleteExpense(_expense('2', 'Masala tea'));
      await store.saved;
      await pumpEventQueue();
      expect(cloud.expenses, isEmpty);
    });

    test('a failing cloud never blocks saving on the phone', () async {
      final storage = SyncedStorage(InMemoryStorage())..cloud = _BrokenCloud();
      final store = ExpenseStore(storage: storage);

      store.addExpense(_expense('1', 'Tea'));
      await store.saved;
      await pumpEventQueue();

      expect(store.expenses, hasLength(1));
      // Still flagged even though the "last used account" write after it worked.
      expect(storage.lastError.value, isNotNull);
      expect(storage.pending.value, 0);
    });

    test('Retry uploads what a failed write missed and clears the problem', () async {
      final cloud = _FlakyCloud();
      final s = _setUp(cloud: cloud, auth: FakeAuth());
      await s.sync.signIn();
      await pumpEventQueue();

      cloud.failSaves = true;
      s.store.addExpense(_expense('1', 'Tea'));
      await s.store.saved;
      await pumpEventQueue();
      expect(s.sync.status, CloudStatus.failing);
      expect(cloud.expenses, isEmpty);

      cloud.failSaves = false;
      s.sync.retry();
      await pumpEventQueue();

      expect(s.sync.status, CloudStatus.upToDate);
      expect(cloud.expenses.keys, ['1']);
    });
  });

  group('CloudSync sign-in', () {
    test('uploads this phone’s data when the cloud is empty', () async {
      final cloud = FakeCloud();
      final s = _setUp(
        cloud: cloud,
        auth: FakeAuth(),
        phone: StoredData(accounts: const [_sbi], expenses: [_expense('1', 'Tea')]),
      );

      await s.sync.signIn();
      await pumpEventQueue();

      expect(s.sync.status, CloudStatus.upToDate);
      expect(cloud.expenses.keys, ['1']);
      expect(cloud.accounts.keys, [_sbi.id]);
    });

    test('a new phone gets everything back from the cloud', () async {
      final cloud = FakeCloud(StoredData(
        accounts: const [_hdfc],
        expenses: [_expense('1', 'Dinner', accountId: _hdfc.id)],
        lastUsedAccountId: _hdfc.id,
      ));
      final s = _setUp(cloud: cloud, auth: FakeAuth());

      await s.sync.signIn();

      expect(s.store.expenses.single.title, 'Dinner');
      expect(s.store.accountById(_hdfc.id), isNotNull);
      expect(s.store.lastUsedAccount.id, _hdfc.id);
    });

    test('when both have data, both end up with all of it', () async {
      final cloud = FakeCloud(StoredData(expenses: [_expense('c', 'From cloud')]));
      final s = _setUp(
        cloud: cloud,
        auth: FakeAuth(),
        phone: StoredData(expenses: [_expense('p', 'From phone')]),
      );

      await s.sync.signIn();
      await pumpEventQueue();

      expect(s.store.expenses.map((e) => e.id).toSet(), {'c', 'p'});
      expect(cloud.expenses.keys.toSet(), {'c', 'p'});
    });

    test('later changes go to the cloud automatically', () async {
      final cloud = FakeCloud();
      final s = _setUp(cloud: cloud, auth: FakeAuth());
      await s.sync.signIn();

      s.store.addExpense(_expense('1', 'Tea'));
      await s.store.saved;
      await pumpEventQueue();

      expect(cloud.expenses.keys, ['1']);
    });

    test('offline, sign-in stops safely instead of treating the cloud as empty', () async {
      final cloud = FakeCloud(StoredData(expenses: [_expense('c', 'Precious')]))..offline = true;
      final auth = FakeAuth();
      final s = _setUp(cloud: cloud, auth: auth, phone: StoredData(expenses: [_expense('p', 'Tea')]));

      await s.sync.signIn();
      await pumpEventQueue();

      expect(s.sync.status, CloudStatus.signedOut);
      expect(s.sync.error, contains('internet'));
      expect(auth.signOuts, 1);
      expect(cloud.expenses.keys, ['c']);
      expect(s.store.expenses.single.id, 'p');
    });

    test('backing out of the Google screen changes nothing', () async {
      final s = _setUp(cloud: FakeCloud(), auth: FakeAuth()..cancel = true);
      await s.sync.signIn();
      expect(s.sync.status, CloudStatus.signedOut);
      expect(s.sync.error, isNull);
    });

    test('a user signed in on an earlier launch keeps backing up', () async {
      final cloud = FakeCloud();
      final s = _setUp(
        cloud: cloud,
        auth: FakeAuth(currentUser: const CloudUser(uid: 'u1')),
      );
      expect(s.sync.status, CloudStatus.upToDate);

      s.store.addExpense(_expense('1', 'Tea'));
      await s.store.saved;
      await pumpEventQueue();
      expect(cloud.expenses.keys, ['1']);
    });

    test('signing out stops backing up and keeps data on the phone', () async {
      final cloud = FakeCloud();
      final s = _setUp(cloud: cloud, auth: FakeAuth());
      await s.sync.signIn();
      await s.sync.signOut();

      s.store.addExpense(_expense('1', 'Offline only'));
      await s.store.saved;
      await pumpEventQueue();

      expect(s.sync.status, CloudStatus.signedOut);
      expect(cloud.expenses, isEmpty);
      expect(s.store.expenses, hasLength(1));
    });
  });

  group('FirestoreBackup', () {
    test('stores and reads back everything exactly', () async {
      final backup = FirestoreBackup(FakeFirebaseFirestore(), 'u1');
      await backup.saveAccount(_hdfc);
      await backup.saveAccount(_sbi);
      await backup.saveExpense(Expense(
        id: 'e1',
        title: 'Lunch',
        amount: 180.5,
        dateTime: DateTime(2026, 10, 27, 13, 5),
        accountId: _hdfc.id,
        notes: 'With team',
      ));
      await backup.saveLastUsedAccountId(_hdfc.id);

      final data = await backup.fetch();
      // Accounts come back in the order they were created (ids are timestamps).
      expect(data.accounts.map((a) => a.id), [_sbi.id, _hdfc.id]);
      expect(data.lastUsedAccountId, _hdfc.id);
      final lunch = data.expenses.single;
      expect(lunch.amount, 180.5);
      expect(lunch.dateTime, DateTime(2026, 10, 27, 13, 5));
      expect(lunch.notes, 'With team');
    });

    test('replaceAll makes the cloud match exactly', () async {
      final firestore = FakeFirebaseFirestore();
      final backup = FirestoreBackup(firestore, 'u1');
      await backup.saveAccount(_sbi);
      await backup.saveExpense(_expense('old', 'Old'));
      await backup.saveExpense(_expense('keep', 'Keep'));

      await backup.replaceAll(StoredData(
        accounts: const [_hdfc],
        expenses: [_expense('keep', 'Keep'), _expense('new', 'New')],
        lastUsedAccountId: _hdfc.id,
      ));

      final data = await backup.fetch();
      expect(data.accounts.map((a) => a.id), [_hdfc.id]);
      expect(data.expenses.map((e) => e.id).toSet(), {'keep', 'new'});
      expect(data.lastUsedAccountId, _hdfc.id);
    });

    test('stores categories and an expense’s category', () async {
      final firestore = FakeFirebaseFirestore();
      final backup = FirestoreBackup(firestore, 'u1');
      const food = ExpenseCategory(id: '5', name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      await backup.saveCategory(food);
      await backup.saveExpense(_expense('1', 'Lunch').copyWith(categoryId: food.id));
      await backup.saveExpense(_expense('2', 'Misc'));

      final data = await backup.fetch();
      expect(data.categories.single.name, 'Food');
      expect(data.categories.single.iconKey, 'food');
      expect(data.categories.single.colorValue, 0xFFE53935);
      expect({for (final e in data.expenses) e.id: e.categoryId}, {'1': food.id, '2': null});

      await backup.replaceAll(StoredData(expenses: [_expense('2', 'Misc')]));
      expect((await backup.fetch()).categories, isEmpty);
    });

    test('keeps each user’s data separate', () async {
      final firestore = FakeFirebaseFirestore();
      await FirestoreBackup(firestore, 'alice').saveExpense(_expense('1', 'Alice’s tea'));
      final bob = await FirestoreBackup(firestore, 'bob').fetch();
      expect(bob.expenses, isEmpty);
    });
  });

  group('Backup screen cloud card', () {
    testWidgets('signing in shows the account and backup status', (tester) async {
      final s = _setUp(cloud: FakeCloud(), auth: FakeAuth());
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: BackupScreen(store: s.store, cloudSync: s.sync),
      ));
      expect(find.text('Cloud backup'), findsOneWidget);

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Signed in as me@example.com'), findsOneWidget);
      expect(find.text('All changes backed up'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('a failed sign-in explains why', (tester) async {
      final cloud = FakeCloud()..offline = true;
      final s = _setUp(cloud: cloud, auth: FakeAuth());
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: BackupScreen(store: s.store, cloudSync: s.sync),
      ));

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Check your internet connection'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });
  });
}

class _FlakyCloud extends FakeCloud {
  bool failSaves = false;

  @override
  Future<void> saveExpense(Expense expense) async {
    if (failSaves) throw StateError('permission denied');
    return super.saveExpense(expense);
  }
}

class _BrokenCloud extends FakeCloud {
  @override
  Future<void> saveExpense(Expense expense) async => throw StateError('permission denied');
}
