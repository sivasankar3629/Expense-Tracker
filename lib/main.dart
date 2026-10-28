import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/expense_storage.dart';
import 'data/sqlite_storage.dart';
import 'screens/home_screen.dart';
import 'state/expense_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SQLite isn't available on web, so the web preview keeps data in memory only.
  final ExpenseStorage storage = kIsWeb ? InMemoryStorage() : await SqliteStorage.open();
  runApp(ExpenseTrackerApp(store: await ExpenseStore.open(storage)));
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
