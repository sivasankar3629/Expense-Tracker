import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'cloud/cloud_sync.dart';
import 'cloud/firestore_backup.dart';
import 'cloud/google_cloud_auth.dart';
import 'cloud/synced_storage.dart';
import 'data/expense_storage.dart';
import 'data/sqlite_storage.dart';
import 'firebase_config.dart';
import 'models/preferences.dart';
import 'platform/home_screen_widget.dart';
import 'screens/app_shell.dart';
import 'state/expense_store.dart';
import 'theme.dart';
import 'widgets/currency_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SQLite isn't available on web, so the web preview keeps data in memory only.
  final storage = SyncedStorage(kIsWeb ? InMemoryStorage() : await SqliteStorage.open());
  final store = await ExpenseStore.open(storage);
  final info = await PackageInfo.fromPlatform();
  final homeWidget = HomeScreenWidget.isSupported ? HomeScreenWidget(store) : null;
  await homeWidget?.start();
  runApp(ExpenseTrackerApp(
    store: store,
    cloudSync: await _startCloudSync(storage, store),
    versionLabel: 'Version ${info.version} (build ${info.buildNumber})',
    addRequests: homeWidget?.addRequests,
  ));
}

/// Null on web (the preview build) or if Firebase fails to start; the app
/// then works as before, just without cloud backup.
Future<CloudSync?> _startCloudSync(SyncedStorage storage, ExpenseStore store) async {
  if (kIsWeb) return null;
  try {
    await Firebase.initializeApp(options: FirebaseConfig.android);
    final auth = GoogleCloudAuth(webClientId: FirebaseConfig.webClientId);
    await auth.initialize();
    return CloudSync(
      auth: auth,
      storage: storage,
      store: store,
      backupFor: (uid) => FirestoreBackup(FirebaseFirestore.instance, uid),
    )..start();
  } catch (e, stack) {
    debugPrint('Cloud backup unavailable: $e\n$stack');
    return null;
  }
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({
    super.key,
    required this.store,
    this.cloudSync,
    this.versionLabel,
    this.addRequests,
  });

  final ExpenseStore store;
  final CloudSync? cloudSync;

  /// Taps on the home-screen widget's + button; each opens the add form.
  final Stream<void>? addRequests;

  /// e.g. "Version 0.1.0 (build 7)"; shown in Settings.
  final String? versionLabel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: 'Kipto',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: switch (store.themeChoice) {
          ThemeChoice.system => ThemeMode.system,
          ThemeChoice.light => ThemeMode.light,
          ThemeChoice.dark => ThemeMode.dark,
        },
        // Above the navigator, so every screen and dialog sees the currency.
        builder: (context, child) => CurrencyScope(currency: store.currency, child: child!),
        home: AppShell(
          store: store,
          cloudSync: cloudSync,
          versionLabel: versionLabel,
          addRequests: addRequests,
        ),
      ),
    );
  }
}
