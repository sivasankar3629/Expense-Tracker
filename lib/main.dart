import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'state/expense_store.dart';
import 'theme.dart';

void main() {
  runApp(ExpenseTrackerApp(store: ExpenseStore()));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key, required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(store: store),
    );
  }
}
