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
import 'screens/home_screen.dart';
import 'state/expense_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SQLite isn't available on web, so the web preview keeps data in memory only.
  final storage = SyncedStorage(kIsWeb ? InMemoryStorage() : await SqliteStorage.open());
  final store = await ExpenseStore.open(storage);
  final info = await PackageInfo.fromPlatform();
  runApp(ExpenseTrackerApp(
    store: store,
    cloudSync: await _startCloudSync(storage, store),
    versionLabel: 'Version ${info.version} (build ${info.buildNumber})',
  ));
}

/// Null when Firebase isn't set up (or fails to start); the app then works
/// exactly as before, just without cloud backup.
Future<CloudSync?> _startCloudSync(SyncedStorage storage, ExpenseStore store) async {
  final options = FirebaseConfig.android;
  final webClientId = FirebaseConfig.webClientId;
  if (kIsWeb || options == null || webClientId == null) return null;
  try {
    await Firebase.initializeApp(options: options);
    final auth = GoogleCloudAuth(webClientId: webClientId);
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
  });

  final ExpenseStore store;
  final CloudSync? cloudSync;

  /// e.g. "Version 0.1.0 (build 7)"; shown in the home screen's menu.
  final String? versionLabel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kipto',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(store: store, cloudSync: cloudSync, versionLabel: versionLabel),
    );
  }
}
