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
    expect(find.text('Cash'), findsOneWidget);
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

    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add bank account or card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit card'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nickname'), 'HDFC Millennia');
    // The dialog's Add button sits above the form's.
    await tester.tap(find.widgetWithText(FilledButton, 'Add').last);
    await tester.pumpAndSettle();

    await fillAndSubmit(tester, 'Dinner', '650');

    expect(find.text('HDFC Millennia'), findsOneWidget);
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

    await tester.tap(find.text('Tea'));
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

    await tester.drag(find.text('Tea'), const Offset(-600, 0));
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

    await tester.tap(find.text('Tea'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(store.expenses, isEmpty);
    expect(find.text('Deleted "Tea"'), findsOneWidget);
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
