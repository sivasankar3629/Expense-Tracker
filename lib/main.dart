import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'data/expense_storage.dart';
import 'data/sqlite_storage.dart';
import 'screens/home_screen.dart';
import 'state/expense_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SQLite isn't available on web, so the web preview keeps data in memory only.
  final ExpenseStorage storage = kIsWeb ? InMemoryStorage() : await SqliteStorage.open();
  final info = await PackageInfo.fromPlatform();
  runApp(ExpenseTrackerApp(
    store: await ExpenseStore.open(storage),
    versionLabel: 'Version ${info.version} (build ${info.buildNumber})',
  ));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key, required this.store, this.versionLabel});

  final ExpenseStore store;

  /// e.g. "Version 0.1.0 (build 7)"; shown in the home screen's menu.
  final String? versionLabel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(store: store, versionLabel: versionLabel),
    );
  }
}
