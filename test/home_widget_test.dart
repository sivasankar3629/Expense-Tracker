import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/currency.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/platform/home_screen_widget.dart';
import 'package:expense_tracker/state/expense_store.dart';

void main() {
  test('the widget shows this month’s spending in the chosen currency', () {
    final now = DateTime(2026, 10, 29);
    final store = ExpenseStore()
      ..addExpense(Expense(title: 'Rent', amount: 15000, dateTime: DateTime(2026, 10, 2), accountId: 'cash'))
      ..addExpense(Expense(title: 'Tea', amount: 12, dateTime: DateTime(2026, 10, 29), accountId: 'cash'))
      // Last month: not counted.
      ..addExpense(Expense(title: 'Old', amount: 500, dateTime: DateTime(2026, 9, 30), accountId: 'cash'));

    expect(homeWidgetTexts(store, now), (label: 'Spent in October', total: '₹15,012'));

    store
      ..setCurrency(Currency.byCode('USD'))
      ..setMonthStartDay(25);
    expect(homeWidgetTexts(store, now), (label: 'Spent since 25 Oct', total: r'$12'));
  });

  testWidgets('the widget’s + button opens the add form, at launch and later', (tester) async {
    final requests = StreamController<void>();
    // A tap that launched the app arrives before the app has drawn anything.
    requests.add(null);
    await tester.pumpWidget(ExpenseTrackerApp(store: ExpenseStore(), addRequests: requests.stream));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add expense'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add expense'), findsNothing);

    // A tap while the app is open.
    requests.add(null);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add expense'), findsOneWidget);
    await requests.close();
  });
}
