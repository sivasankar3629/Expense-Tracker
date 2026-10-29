import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/cloud/firestore_backup.dart';
import 'package:expense_tracker/data/backup.dart';
import 'package:expense_tracker/data/expense_storage.dart';
import 'package:expense_tracker/data/sqlite_storage.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/state/expense_store.dart';
import 'package:expense_tracker/widgets/budget.dart';

Expense _expense(String title, double amount, {String? categoryId, String accountId = 'cash'}) =>
    Expense(
      title: title,
      amount: amount,
      dateTime: DateTime.now(),
      accountId: accountId,
      categoryId: categoryId,
    );

void main() {
  group('Budgets', () {
    test('levels: fine below 80%, near from 80% up to the limit, over beyond it', () {
      expect(BudgetLevel.of(799, 1000), BudgetLevel.ok);
      expect(BudgetLevel.of(800, 1000), BudgetLevel.near);
      expect(BudgetLevel.of(1000, 1000), BudgetLevel.near);
      expect(BudgetLevel.of(1000.01, 1000), BudgetLevel.over);
    });

    testWidgets('say when the budget is used up exactly', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BudgetProgress(spent: 500, budget: 500, color: Colors.green)),
      ));
      expect(find.text('Budget used up'), findsOneWidget);
    });

    test('can be set, changed and removed', () {
      final store = ExpenseStore();
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);

      store.setCategoryBudget(food, 5000);
      expect(store.categoryById(food.id)!.monthlyBudget, 5000);
      store.setCategoryBudget(food, 6500.5);
      expect(store.categoryById(food.id)!.monthlyBudget, 6500.5);
      store.setCategoryBudget(food, null);
      expect(store.categoryById(food.id)!.monthlyBudget, isNull);
    });

    test('survive a relaunch, including a database upgraded from before budgets', () async {
      sqfliteFfiInit();
      final dir = Directory.systemTemp.createTempSync('kipto_budget');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/test.db';

      var storage = await SqliteStorage.open(factory: databaseFactoryFfi, path: path);
      var store = await ExpenseStore.open(storage);
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      store.setCategoryBudget(food, 4999.99);
      await store.saved;
      await storage.close();

      storage = await SqliteStorage.open(factory: databaseFactoryFfi, path: path);
      store = await ExpenseStore.open(storage);
      expect(store.categories.single.monthlyBudget, 4999.99);
      await storage.close();
    });

    test('are kept in backup files and the cloud', () async {
      const food = ExpenseCategory(
        id: 'c1',
        name: 'Food',
        iconKey: 'food',
        colorValue: 0xFFE53935,
        monthlyBudget: 5000,
      );
      const rent = ExpenseCategory(id: 'c2', name: 'Rent', iconKey: 'home', colorValue: 0xFF43A047);
      const data = StoredData(categories: [food, rent]);

      final fromFile = Backup.decode(Backup(data: data, exportedAt: DateTime(2026)).encode());
      expect(fromFile.data.categories.map((c) => c.monthlyBudget), [5000, null]);

      final cloud = FirestoreBackup(FakeFirebaseFirestore(), 'u1');
      await cloud.replaceAll(data);
      final fromCloud = await cloud.fetch();
      expect({for (final c in fromCloud.categories) c.name: c.monthlyBudget}, {'Food': 5000, 'Rent': null});
    });
  });

  test('things made in the same instant still get their own ids', () {
    final store = ExpenseStore();
    final categories = [
      for (var i = 0; i < 50; i++) store.addCategory(name: 'C$i', iconKey: 'food', colorValue: 0),
    ];
    final accounts = [for (var i = 0; i < 50; i++) store.addAccount('A$i', AccountType.bank)];
    final expenses = [for (var i = 0; i < 50; i++) _expense('E$i', 1)];
    expect(categories.map((c) => c.id).toSet(), hasLength(50));
    expect(accounts.map((a) => a.id).toSet(), hasLength(50));
    expect(expenses.map((e) => e.id).toSet(), hasLength(50));
  });

  group('Home', () {
    testWidgets('shows a card per category with this month’s spending and budget', (tester) async {
      final store = ExpenseStore();
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      store
        ..setCategoryBudget(food, 1000)
        ..addExpense(_expense('Lunch', 900, categoryId: food.id));
      await tester.pumpWidget(ExpenseTrackerApp(store: store));

      expect(find.text('Food'), findsOneWidget);
      expect(find.text('₹100 left'), findsOneWidget);
      // No uncategorised expenses, so no Uncategorised card.
      expect(find.text('Uncategorised'), findsNothing);
      expect(find.text('New category'), findsOneWidget);
    });

    testWidgets('until a category exists, invites you to create one', (tester) async {
      await tester.pumpWidget(ExpenseTrackerApp(store: ExpenseStore()));
      expect(find.text('Group your spending'), findsOneWidget);
      expect(find.text('Create a category'), findsOneWidget);
    });

    testWidgets('groups expenses without a category under Uncategorised', (tester) async {
      final store = ExpenseStore()..addExpense(_expense('Tea', 12));
      await tester.pumpWidget(ExpenseTrackerApp(store: store));
      expect(find.text('Uncategorised'), findsOneWidget);
    });
  });

  group('Category screen', () {
    testWidgets('lists its expenses, sets a budget, and pre-fills new ones', (tester) async {
      final store = ExpenseStore();
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      store
        ..addExpense(_expense('Lunch', 200, categoryId: food.id))
        ..addExpense(_expense('Taxi', 300));
      await tester.pumpWidget(ExpenseTrackerApp(store: store));

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Taxi'), findsNothing);

      await tester.tap(find.text('Set a monthly budget'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Budget'), '1000');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(store.categoryById(food.id)!.monthlyBudget, 1000);
      expect(find.text('₹800 left of ₹1,000'), findsOneWidget);

      await tester.tap(find.byTooltip('Add expense'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '50');
      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Snacks');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(store.expenses.firstWhere((e) => e.title == 'Snacks').categoryId, food.id);
      expect(find.text('₹750 left of ₹1,000'), findsOneWidget);
    });
  });

  group('History', () {
    testWidgets('filters by category and payment method', (tester) async {
      final store = ExpenseStore();
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      final card = store.addAccount('HDFC Millennia', AccountType.creditCard);
      store
        ..addExpense(_expense('Lunch', 200, categoryId: food.id))
        ..addExpense(_expense('Dinner', 650, categoryId: food.id, accountId: card.id))
        ..addExpense(_expense('Taxi', 300, accountId: card.id));
      await tester.pumpWidget(ExpenseTrackerApp(store: store));

      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      expect(find.text('3 expenses · ₹1,150'), findsOneWidget);

      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Food'));
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();
      expect(find.text('2 expenses · ₹850'), findsOneWidget);
      expect(find.text('Taxi'), findsNothing);

      await tester.tap(find.text('Paid from'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'HDFC Millennia'));
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();
      expect(find.text('1 expense · ₹650'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('3 expenses · ₹1,150'), findsOneWidget);
    });

    testWidgets('searches title, notes, category, payment method and amount', (tester) async {
      final store = ExpenseStore();
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      final card = store.addAccount('HDFC Millennia', AccountType.creditCard);
      store
        ..addExpense(_expense('Lunch', 200, categoryId: food.id))
        ..addExpense(_expense('Dinner', 650, categoryId: food.id, accountId: card.id))
        ..addExpense(Expense(
          title: 'Taxi',
          amount: 300,
          dateTime: DateTime.now(),
          accountId: 'cash',
          notes: 'Airport drop',
        ));
      await tester.pumpWidget(ExpenseTrackerApp(store: store));
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();

      Future<void> search(String text) async {
        await tester.enterText(find.byType(TextField), text);
        await tester.pumpAndSettle();
      }

      await search('lun');
      expect(find.text('1 expense · ₹200'), findsOneWidget);
      await search('airport');
      expect(find.text('Taxi'), findsOneWidget);
      await search('food');
      expect(find.text('2 expenses · ₹850'), findsOneWidget);
      await search('hdfc');
      expect(find.text('1 expense · ₹650'), findsOneWidget);
      await search('65');
      expect(find.text('Dinner'), findsOneWidget);
      // Every word has to match.
      await search('food cash');
      expect(find.text('1 expense · ₹200'), findsOneWidget);
      await search('dinner cash');
      expect(find.text('No matches'), findsOneWidget);

      // Search and filters narrow each other down.
      await search('food');
      await tester.tap(find.text('Paid from'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cash'));
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();
      expect(find.text('1 expense · ₹200'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('2 expenses · ₹500'), findsOneWidget);
    });

    testWidgets('can show only uncategorised expenses', (tester) async {
      final store = ExpenseStore();
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      store
        ..addExpense(_expense('Lunch', 200, categoryId: food.id))
        ..addExpense(_expense('Taxi', 300));
      await tester.pumpWidget(ExpenseTrackerApp(store: store));
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Uncategorised'));
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();

      expect(find.text('Taxi'), findsOneWidget);
      expect(find.text('Lunch'), findsNothing);
    });
  });
}
