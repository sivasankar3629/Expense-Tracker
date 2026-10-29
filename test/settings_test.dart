import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/cloud/cloud_backup.dart';
import 'package:expense_tracker/cloud/firestore_backup.dart';
import 'package:expense_tracker/data/backup.dart';
import 'package:expense_tracker/data/expense_storage.dart';
import 'package:expense_tracker/data/sqlite_storage.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/currency.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/preferences.dart';
import 'package:expense_tracker/state/expense_store.dart';

Expense _expense(String title, double amount, DateTime when) =>
    Expense(title: title, amount: amount, dateTime: when, accountId: 'cash');

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

void main() {
  group('Currency', () {
    testWidgets('changes how every amount is shown', (tester) async {
      final store = ExpenseStore()..addExpense(_expense('Rent', 125000, DateTime.now()));
      await tester.pumpWidget(ExpenseTrackerApp(store: store));
      expect(find.text('₹1,25,000'), findsWidgets);

      await _openSettings(tester);
      await tester.tap(find.text('Currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('US dollar'));
      await tester.pumpAndSettle();
      expect(store.currency.code, 'USD');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(r'$125,000'), findsWidgets);
      expect(find.text('₹1,25,000'), findsNothing);
    });
  });

  group('Month start day', () {
    test('budget months run from the start day to the day before the next one', () {
      final store = ExpenseStore()..setMonthStartDay(25);
      expect(store.budgetMonthOf(DateTime(2026, 10, 29)),
          (start: DateTime(2026, 10, 25), end: DateTime(2026, 11, 25)));
      expect(store.budgetMonthOf(DateTime(2026, 10, 24, 23, 59)),
          (start: DateTime(2026, 9, 25), end: DateTime(2026, 10, 25)));
      // Crosses the year boundary.
      expect(store.budgetMonthOf(DateTime(2027, 1, 3)),
          (start: DateTime(2026, 12, 25), end: DateTime(2027, 1, 25)));
      expect(store.budgetMonthLabel(DateTime(2026, 10, 29)), 'since 25 Oct');
    });

    test('the 1st keeps calendar months', () {
      final store = ExpenseStore();
      expect(store.budgetMonthOf(DateTime(2026, 2, 14)),
          (start: DateTime(2026, 2, 1), end: DateTime(2026, 3, 1)));
      expect(store.budgetMonthLabel(DateTime(2026, 2, 14)), 'in February');
    });

    test('decides which expenses count towards this month', () {
      final store = ExpenseStore()
        ..addExpense(_expense('Before payday', 100, DateTime(2026, 10, 24)))
        ..addExpense(_expense('Payday', 200, DateTime(2026, 10, 25)))
        ..addExpense(_expense('After', 300, DateTime(2026, 11, 2)));
      final now = DateTime(2026, 11, 5);
      expect(store.expensesInBudgetMonth(now).map((e) => e.title), ['After']);

      store.setMonthStartDay(25);
      expect(store.expensesInBudgetMonth(now).map((e) => e.title), ['After', 'Payday']);
    });

    testWidgets('can be picked in settings and shows on the budget dialog', (tester) async {
      final store = ExpenseStore();
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      await tester.pumpWidget(ExpenseTrackerApp(store: store));

      await _openSettings(tester);
      await tester.tap(find.text('Month starts on'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25'));
      await tester.pumpAndSettle();
      expect(store.preferences.monthStartDay, 25);
      expect(find.text('The 25th · budgets reset on this day'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('Spent since '), findsOneWidget);

      await tester.tap(find.text(food.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set a monthly budget'));
      await tester.pumpAndSettle();
      expect(find.text('Starts fresh on the 25th of each month.'), findsOneWidget);
    });
  });

  testWidgets('theme can be forced light or dark', (tester) async {
    final store = ExpenseStore();
    await tester.pumpWidget(ExpenseTrackerApp(store: store));
    ThemeMode mode() => tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    expect(mode(), ThemeMode.system);

    await _openSettings(tester);
    expect(find.text('System default'), findsOneWidget);
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
    expect(store.themeChoice, ThemeChoice.dark);
    expect(mode(), ThemeMode.dark);
    expect(Theme.of(tester.element(find.text('Settings').first)).brightness, Brightness.dark);
  });

  test('settings survive a relaunch', () async {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('kipto_settings');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/test.db';

    var storage = await SqliteStorage.open(factory: databaseFactoryFfi, path: path);
    var store = await ExpenseStore.open(storage);
    expect(store.preferences, const Preferences());
    store
      ..setCurrency(Currency.byCode('EUR'))
      ..setMonthStartDay(25)
      ..setThemeChoice(ThemeChoice.light);
    await store.saved;
    await storage.close();

    storage = await SqliteStorage.open(factory: databaseFactoryFfi, path: path);
    store = await ExpenseStore.open(storage);
    expect(store.preferences, const Preferences(currencyCode: 'EUR', monthStartDay: 25));
    expect(store.themeChoice, ThemeChoice.light);
    await storage.close();
  });

  group('Backups', () {
    const euro25 = Preferences(currencyCode: 'EUR', monthStartDay: 25);

    test('carry currency and month start, in files and the cloud', () async {
      const data = StoredData(preferences: euro25);
      final fromFile = Backup.decode(Backup(data: data, exportedAt: DateTime(2026)).encode());
      expect(fromFile.data.preferences, euro25);

      final cloud = FirestoreBackup(FakeFirebaseFirestore(), 'u1');
      expect((await cloud.fetch()).preferences, isNull);
      await cloud.saveLastUsedAccountId('cash');
      await cloud.savePreferences(euro25);
      // Saving one setting doesn't wipe the others.
      await cloud.saveLastUsedAccountId('cash');
      final fetched = await cloud.fetch();
      expect(fetched.preferences, euro25);
      expect(fetched.lastUsedAccountId, 'cash');
    });

    test('made before preferences existed keep the current ones on restore', () {
      final store = ExpenseStore()..setCurrency(Currency.byCode('GBP'));
      store.replaceAll(const StoredData());
      expect(store.currency.code, 'GBP');
      store.replaceAll(const StoredData(preferences: euro25));
      expect(store.preferences, euro25);
    });

    test('a new phone signing in takes the cloud’s preferences', () {
      final cloud = StoredData(
        expenses: [_expense('Tea', 12, DateTime(2026))],
        preferences: euro25,
      );
      expect(
        mergeForSignIn(phone: const StoredData(preferences: Preferences()), cloud: cloud).preferences,
        euro25,
      );
      // A phone already in use keeps its own.
      final used = StoredData(
        expenses: [_expense('Lunch', 200, DateTime(2026))],
        preferences: const Preferences(currencyCode: 'USD'),
      );
      expect(mergeForSignIn(phone: used, cloud: cloud).preferences!.currencyCode, 'USD');
    });

    test('ignore odd values instead of failing', () {
      expect(
        Preferences.fromJson({'currency': 'XYZ', 'monthStartDay': 31}),
        const Preferences(),
      );
    });
  });
}
