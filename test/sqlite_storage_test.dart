import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/data/expense_storage.dart';
import 'package:expense_tracker/data/sqlite_storage.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/state/expense_store.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('expense_tracker_test');
    dbPath = '${tempDir.path}/test.db';
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<SqliteStorage> openStorage() =>
      SqliteStorage.open(factory: databaseFactoryFfi, path: dbPath);

  /// Simulates closing the app and launching it again.
  Future<ExpenseStore> relaunch(SqliteStorage previous, ExpenseStore store) async {
    await store.saved;
    await previous.close();
    return ExpenseStore.open(await openStorage());
  }

  test('expenses, accounts and last used account survive a relaunch', () async {
    final storage = await openStorage();
    var store = await ExpenseStore.open(storage);

    final bank = store.addAccount('SBI Savings', AccountType.bank);
    final card = store.addAccount('HDFC Millennia', AccountType.creditCard);
    store.addExpense(Expense(
      title: 'Lunch',
      amount: 180.5,
      dateTime: DateTime(2026, 10, 27, 13, 5),
      accountId: bank.id,
      notes: 'With team',
    ));
    store.addExpense(Expense(
      title: 'Tea',
      amount: 12,
      dateTime: DateTime(2026, 10, 28, 9, 30),
      accountId: card.id,
    ));

    store = await relaunch(storage, store);

    expect(store.accountsOfType(AccountType.bank).single.nickname, 'SBI Savings');
    expect(store.accountsOfType(AccountType.creditCard).single.nickname, 'HDFC Millennia');
    expect(store.expenses.map((e) => e.title), ['Tea', 'Lunch']);

    final lunch = store.expenses.last;
    expect(lunch.amount, 180.5);
    expect(lunch.dateTime, DateTime(2026, 10, 27, 13, 5));
    expect(lunch.notes, 'With team');
    expect(lunch.accountId, bank.id);
    expect(store.lastUsedAccount.id, card.id);
  });

  test('renames keep their place and deletions stick', () async {
    final storage = await openStorage();
    var store = await ExpenseStore.open(storage);

    final first = store.addAccount('Axis', AccountType.bank);
    final second = store.addAccount('ICICI', AccountType.bank);
    final third = store.addAccount('Kotak', AccountType.bank);
    store.updateAccount(first.copyWith(nickname: 'Axis Salary'));
    store.deleteAccount(second);

    store = await relaunch(storage, store);

    expect(
      store.accountsOfType(AccountType.bank).map((a) => a.nickname),
      ['Axis Salary', 'Kotak'],
    );
    expect(store.accountById(third.id), isNotNull);
  });

  test('edits and deletions survive a relaunch', () async {
    final storage = await openStorage();
    var store = await ExpenseStore.open(storage);
    final tea = Expense(
      title: 'Tea',
      amount: 12,
      dateTime: DateTime(2026, 10, 28, 9),
      accountId: Account.cash.id,
    );
    final lunch = Expense(
      title: 'Lunch',
      amount: 180,
      dateTime: DateTime(2026, 10, 28, 13),
      accountId: Account.cash.id,
    );
    store
      ..addExpense(tea)
      ..addExpense(lunch)
      ..updateExpense(Expense(
        id: tea.id,
        title: 'Masala tea',
        amount: 15.5,
        dateTime: tea.dateTime,
        accountId: tea.accountId,
      ))
      ..deleteExpense(lunch);

    store = await relaunch(storage, store);

    expect(store.expenses, hasLength(1));
    expect(store.expenses.single.id, tea.id);
    expect(store.expenses.single.title, 'Masala tea');
    expect(store.expenses.single.amount, 15.5);
  });

  test('a restore replaces everything and survives a relaunch', () async {
    final storage = await openStorage();
    var store = await ExpenseStore.open(storage);
    store
      ..addAccount('Old bank', AccountType.bank)
      ..addExpense(Expense(
        title: 'Old',
        amount: 1,
        dateTime: DateTime(2026, 1, 1),
        accountId: Account.cash.id,
      ))
      ..markBackedUp(DateTime(2026, 10, 28, 10, 32));

    const card = Account(id: 'card-1', nickname: 'HDFC Millennia', type: AccountType.creditCard);
    store.replaceAll(StoredData(
      accounts: const [card],
      expenses: [
        Expense(
          id: 'e1',
          title: 'Restored',
          amount: 99.99,
          dateTime: DateTime(2026, 10, 1, 12),
          accountId: card.id,
        ),
      ],
      lastUsedAccountId: card.id,
    ));

    store = await relaunch(storage, store);

    expect(store.accounts.map((a) => a.nickname), ['Cash', 'HDFC Millennia']);
    expect(store.expenses.single.title, 'Restored');
    expect(store.expenses.single.amount, 99.99);
    expect(store.lastUsedAccount.id, card.id);
    // The device's own backup history isn't overwritten by a restore.
    expect(store.lastBackupAt, DateTime(2026, 10, 28, 10, 32));
  });

  test('amounts add up exactly after a relaunch', () async {
    final storage = await openStorage();
    var store = await ExpenseStore.open(storage);
    for (var i = 0; i < 10; i++) {
      store.addExpense(Expense(
        title: 'Coffee',
        amount: 0.1,
        dateTime: DateTime(2026, 10, 1, 8, i),
        accountId: Account.cash.id,
      ));
    }

    store = await relaunch(storage, store);

    final paise = store.expenses.fold<int>(0, (sum, e) => sum + (e.amount * 100).round());
    expect(paise, 100);
  });
}
