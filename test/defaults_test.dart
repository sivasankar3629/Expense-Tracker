import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/screens/expense_form_screen.dart';
import 'package:expense_tracker/state/expense_store.dart';

final now = DateTime(2026, 11, 1, 12);

Expense spend(String title, String accountId, {String? categoryId, int daysAgo = 1}) => Expense(
      title: title,
      amount: 10,
      dateTime: now.subtract(Duration(days: daysAgo)),
      accountId: accountId,
      categoryId: categoryId,
    );

void main() {
  group('Most used', () {
    test('is Cash and no category before the first expense', () {
      final store = ExpenseStore()..addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      expect(store.mostUsedAccount.id, Account.cash.id);
      expect(store.mostUsedCategory, isNull);
    });

    test('counts every expense, not the last one added, and a tie goes to the newest', () {
      final store = ExpenseStore();
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      final travel = store.addCategory(name: 'Travel', iconKey: 'travel', colorValue: 0xFF1E88E5);
      final card = store.addAccount('HDFC Millennia', AccountType.creditCard);
      store
        ..addExpense(spend('Lunch', card.id, categoryId: food.id, daysAgo: 3))
        ..addExpense(spend('Dinner', card.id, categoryId: food.id, daysAgo: 2))
        // A one-off doesn't take over.
        ..addExpense(spend('Taxi', 'cash', categoryId: travel.id, daysAgo: 1));
      expect(store.lastUsedAccount.id, Account.cash.id);
      expect(store.mostUsedAccount.id, card.id);
      expect(store.mostUsedCategory?.id, food.id);

      store.addExpense(spend('Bus', 'cash', categoryId: travel.id, daysAgo: 1));
      expect(store.mostUsedAccount.id, Account.cash.id, reason: 'tied 2–2, and cash was used last');
      expect(store.mostUsedCategory?.id, travel.id);
    });

    test('skips expenses without a category, and categories since deleted', () {
      final store = ExpenseStore();
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      final gone = store.addCategory(name: 'Gone', iconKey: 'food', colorValue: 0xFF1E88E5);
      store
        ..addExpense(spend('A', 'cash'))
        ..addExpense(spend('B', 'cash'))
        ..addExpense(spend('C', 'cash', categoryId: gone.id))
        ..addExpense(spend('D', 'cash', categoryId: gone.id))
        ..addExpense(spend('E', 'cash', categoryId: food.id));
      expect(store.mostUsedCategory?.id, gone.id);
      store.deleteCategory(gone);
      expect(store.mostUsedCategory?.id, food.id);
    });
  });

  group('The add form', () {
    late ExpenseStore store;
    late String foodId, travelId, cardId;

    setUp(() {
      store = ExpenseStore();
      foodId = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935).id;
      travelId = store.addCategory(name: 'Travel', iconKey: 'travel', colorValue: 0xFF1E88E5).id;
      cardId = store.addAccount('HDFC Millennia', AccountType.creditCard).id;
      store
        ..addExpense(spend('Lunch', cardId, categoryId: foodId, daysAgo: 3))
        ..addExpense(spend('Dinner', cardId, categoryId: foodId, daysAgo: 2))
        ..addExpense(spend('Taxi', 'cash', categoryId: travelId, daysAgo: 1));
    });

    Future<Expense> addThrough(WidgetTester tester, ExpenseFormScreen form) async {
      await tester.pumpWidget(ExpenseTrackerApp(store: store));
      final context = tester.element(find.byType(Scaffold).first);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => form));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '50');
      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'New one');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      return store.expenses.firstWhere((e) => e.title == 'New one');
    }

    testWidgets('starts on the most used account and category', (tester) async {
      final added = await addThrough(tester, ExpenseFormScreen(store: store));
      expect((added.accountId, added.categoryId), (cardId, foodId));
    });

    testWidgets('from a category’s screen, starts in that category', (tester) async {
      final added = await addThrough(tester, ExpenseFormScreen(store: store, initialCategoryId: travelId));
      expect(added.categoryId, travelId);
    });

    testWidgets('editing keeps an expense without a category that way', (tester) async {
      final plain = spend('Plain', 'cash');
      store.addExpense(plain);
      await tester.pumpWidget(ExpenseTrackerApp(store: store));
      final context = tester.element(find.byType(Scaffold).first);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseFormScreen(store: store, initial: plain)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(store.expenses.firstWhere((e) => e.id == plain.id).categoryId, isNull);
    });
  });
}
