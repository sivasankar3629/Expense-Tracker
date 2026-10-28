import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/main.dart';

void main() {
  testWidgets('adding an expense shows it on the home list', (tester) async {
    await tester.pumpWidget(const ExpenseTrackerApp());
    expect(find.text('No expenses yet'), findsOneWidget);

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Tea');
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '12');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Tea'), findsOneWidget);
    // Once on the row, once in the month total.
    expect(find.text('₹12'), findsNWidgets(2));
    expect(find.text('${DateTime.now().day}'), findsOneWidget);
  });

  testWidgets('empty title and amount are rejected', (tester) async {
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();

    expect(find.text('Enter a title'), findsOneWidget);
    expect(find.text('Enter a valid amount'), findsOneWidget);
  });
}
