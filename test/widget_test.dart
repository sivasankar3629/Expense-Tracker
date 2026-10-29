import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/state/expense_store.dart';

void main() {
  Future<void> openAddExpense(WidgetTester tester) async {
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(WidgetTester tester, String title, String amount) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), title);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), amount);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
  }

  /// Recent expenses sit below the summary and categories, so scroll the
  /// row into view before touching it.
  Future<Finder> scrollTo(WidgetTester tester, String title) async {
    final row = find.text(title);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    return row;
  }

  testWidgets('adding an expense shows it on the home list', (tester) async {
    await tester.pumpWidget(ExpenseTrackerApp(store: ExpenseStore()));
    expect(find.text('No expenses yet'), findsOneWidget);

    await openAddExpense(tester);
    await fillAndSubmit(tester, 'Tea', '12');

    expect(find.text('Tea'), findsOneWidget);
    // On the row, the month header and the summary card.
    expect(find.text('₹12'), findsNWidgets(3));
    expect(find.text('Today ₹12'), findsOneWidget);
    expect(find.text('${DateTime.now().day}'), findsOneWidget);
    expect(find.textContaining('Cash', findRichText: true), findsOneWidget);
  });

  testWidgets('empty title and amount are rejected', (tester) async {
    await tester.pumpWidget(ExpenseTrackerApp(store: ExpenseStore()));
    await openAddExpense(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();

    expect(find.text('Enter a title'), findsOneWidget);
    expect(find.text('Enter a valid amount'), findsOneWidget);
  });

  testWidgets('a card added while adding an expense is used for it', (tester) async {
    final store = ExpenseStore();
    await tester.pumpWidget(ExpenseTrackerApp(store: store));
    await openAddExpense(tester);

    await tester.tap(find.text('New account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit card'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nickname'), 'HDFC Millennia');
    // The dialog's Add button sits above the form's.
    await tester.tap(find.widgetWithText(FilledButton, 'Add').last);
    await tester.pumpAndSettle();

    await fillAndSubmit(tester, 'Dinner', '650');

    expect(find.textContaining('HDFC Millennia', findRichText: true), findsOneWidget);
    final card = store.accountsOfType(AccountType.creditCard).single;
    expect(store.expenses.single.accountId, card.id);
    expect(store.lastUsedAccount.id, card.id);
  });

  testWidgets('tapping an expense edits it in place', (tester) async {
    final store = ExpenseStore();
    await tester.pumpWidget(ExpenseTrackerApp(store: store));
    await openAddExpense(tester);
    await fillAndSubmit(tester, 'Tea', '12');
    final originalId = store.expenses.single.id;

    await tester.tap(await scrollTo(tester, 'Tea'));
    await tester.pumpAndSettle();
    expect(find.text('Edit expense'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '12'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Masala tea');
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '15.50');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Masala tea'), findsOneWidget);
    expect(find.text('Tea'), findsNothing);
    expect(store.expenses.single.id, originalId);
    expect(store.expenses.single.amount, 15.5);
  });

  testWidgets('swiping deletes an expense and Undo brings it back', (tester) async {
    final store = ExpenseStore();
    await tester.pumpWidget(ExpenseTrackerApp(store: store));
    await openAddExpense(tester);
    await fillAndSubmit(tester, 'Tea', '12');

    await tester.drag(await scrollTo(tester, 'Tea'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(store.expenses, isEmpty);
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(find.text('Deleted "Tea"'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Tea'), findsOneWidget);
    expect(store.expenses, hasLength(1));
  });

  testWidgets('deleting from the edit screen offers Undo too', (tester) async {
    final store = ExpenseStore();
    await tester.pumpWidget(ExpenseTrackerApp(store: store));
    await openAddExpense(tester);
    await fillAndSubmit(tester, 'Tea', '12');

    await tester.tap(await scrollTo(tester, 'Tea'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(store.expenses, isEmpty);
    expect(find.text('Deleted "Tea"'), findsOneWidget);
  });

  testWidgets('settings show which build is installed', (tester) async {
    await tester.pumpWidget(ExpenseTrackerApp(
      store: ExpenseStore(),
      versionLabel: 'Version 0.1.0 (build 7)',
    ));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Backup & restore'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Kipto · Version 0.1.0 (build 7)'), 200);
    expect(find.text('Kipto · Version 0.1.0 (build 7)'), findsOneWidget);
  });

  testWidgets('a category made from the add expense form is used for it', (tester) async {
    final store = ExpenseStore();
    await tester.pumpWidget(ExpenseTrackerApp(store: store));
    await openAddExpense(tester);

    // Nothing exists until the user makes it.
    expect(store.categories, isEmpty);
    await tester.tap(find.text('Create a category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Food');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    await fillAndSubmit(tester, 'Lunch', '200');

    final food = store.categories.single;
    expect(store.expenses.single.categoryId, food.id);
    // On its card in the category grid, and on the expense's row.
    expect(find.textContaining('Food', findRichText: true), findsNWidgets(2));
  });

  testWidgets('tapping the selected category clears it', (tester) async {
    final store = ExpenseStore()..addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
    await tester.pumpWidget(ExpenseTrackerApp(store: store));
    await openAddExpense(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Food'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Food'));
    await tester.pump();
    await fillAndSubmit(tester, 'Tea', '12');

    expect(store.expenses.single.categoryId, isNull);
  });

  testWidgets('categories can be managed from settings', (tester) async {
    final store = ExpenseStore();
    await tester.pumpWidget(ExpenseTrackerApp(store: store));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('No categories yet'), findsOneWidget);

    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Rent');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);

    // Names must be unique, ignoring case.
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'rent');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('You already have this category'), findsOneWidget);
    expect(store.categories, hasLength(1));
  });

  test('deleting a category keeps its expenses, uncategorised', () {
    final store = ExpenseStore();
    final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
    store.addExpense(Expense(
      title: 'Lunch',
      amount: 200,
      dateTime: DateTime(2026, 10, 28),
      accountId: Account.cash.id,
      categoryId: food.id,
    ));

    store.deleteCategory(food);

    expect(store.categories, isEmpty);
    expect(store.expenses.single.title, 'Lunch');
    expect(store.expenses.single.categoryId, isNull);
  });

  test('categories are offered most-used first', () {
    final store = ExpenseStore();
    final a = store.addCategory(name: 'Alpha', iconKey: 'tag', colorValue: 0xFFE53935);
    final b = store.addCategory(name: 'Beta', iconKey: 'tag', colorValue: 0xFFE53935);
    for (var i = 0; i < 2; i++) {
      store.addExpense(Expense(
        title: 'x',
        amount: 1,
        dateTime: DateTime(2026, 1, 1, i),
        accountId: Account.cash.id,
        categoryId: b.id,
      ));
    }
    expect(store.categoriesByUse.map((c) => c.id), [b.id, a.id]);
  });

  test('accounts with expenses cannot be deleted', () {
    final store = ExpenseStore();
    final bank = store.addAccount('SBI Savings', AccountType.bank);
    expect(store.canDelete(bank), isTrue);
    expect(store.canDelete(Account.cash), isFalse);

    store.addExpense(Expense(
      title: 'Rent',
      amount: 15000,
      dateTime: DateTime(2026, 10, 1),
      accountId: bank.id,
    ));
    store.deleteAccount(bank);

    expect(store.accountById(bank.id), isNotNull);
  });

  test('nicknames must be unique, ignoring case', () {
    final store = ExpenseStore();
    final bank = store.addAccount('SBI Savings', AccountType.bank);
    expect(store.isNicknameTaken('sbi savings'), isTrue);
    expect(store.isNicknameTaken('SBI Savings', exceptId: bank.id), isFalse);
  });
}
