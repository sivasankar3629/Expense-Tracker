import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/preferences.dart';
import 'package:expense_tracker/state/expense_store.dart';
import 'package:expense_tracker/widgets/category_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await font.load();
  });

  for (final (size, scale, mode) in [
    (const Size(390, 844), 1.0, ThemeChoice.light),
    (const Size(320, 640), 1.0, ThemeChoice.light),
    (const Size(320, 640), 1.6, ThemeChoice.dark),
  ]) {
    testWidgets('four screens remain usable at $size, text scale $scale, $mode', (tester) async {
      await tester.binding.setSurfaceSize(size);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final store = ExpenseStore()..setThemeChoice(mode);
      final food = store.addCategory(name: 'Food', iconKey: 'food', colorValue: 0xFFE53935);
      store.setCategoryBudget(food, 6000);
      for (final (name, icon, color) in [
        ('Travel', 'travel', 0xFF1E88E5),
        ('Entertainment', 'entertainment', 0xFF8E24AA),
        ('Rent', 'home', 0xFF43A047),
        ('Shopping', 'shopping', 0xFFF9A825),
      ]) {
        store.addCategory(name: name, iconKey: icon, colorValue: color);
      }
      final bank = store.addAccount('SBI Savings', AccountType.bank);
      store.addAccount('HDFC card', AccountType.creditCard);
      store.addExpense(Expense(
        title: 'Groceries', amount: 4220, dateTime: DateTime.now(),
        accountId: Account.cash.id, categoryId: food.id,
      ));

      await tester.pumpWidget(ExpenseTrackerApp(store: store));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('₹4,220'), findsWidgets);

      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      expect(find.text('Groceries'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Add expense'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '250');
      await tester.ensureVisible(find.widgetWithText(TextFormField, 'Title'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Layout lunch');

      final foodChip = find.widgetWithText(FilterChip, 'Food');
      await tester.ensureVisible(foodChip);
      await tester.pumpAndSettle();
      await tester.tap(foodChip);
      // Picking the Bank tab picks its only account.
      final bankTab = find.text('Bank');
      await tester.ensureVisible(bankTab);
      await tester.pumpAndSettle();
      await tester.tap(bankTab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      final saved = store.expenses.singleWhere((expense) => expense.title == 'Layout lunch');
      expect(saved.amount, 250);
      expect(saved.categoryId, food.id);
      expect(saved.accountId, bank.id);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      final foodCard = find.widgetWithText(CategoryCard, 'Food');
      await tester.ensureVisible(foodCard);
      await tester.pumpAndSettle();
      await tester.tap(foodCard);
      await tester.pumpAndSettle();
      expect(find.text('₹1,530 left of ₹6,000'), findsOneWidget);
      expect(find.text('Edit budget'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
