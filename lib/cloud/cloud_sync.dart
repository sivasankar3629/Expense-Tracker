import 'package:flutter/foundation.dart';

import '../data/expense_storage.dart';
import '../state/expense_store.dart';
import 'cloud_backup.dart';
import 'synced_storage.dart';

class CloudUser {
  const CloudUser({required this.uid, this.email, this.name});

  final String uid;
  final String? email;
  final String? name;
}

/// Signing in and out; behind an interface so tests don't need Google.
abstract interface class CloudAuth {
  /// The user still signed in from an earlier launch, if any.
  CloudUser? get currentUser;

  /// Returns null if the user backed out of the sign-in screen.
  Future<CloudUser?> signIn();

  Future<void> signOut();
}

enum CloudStatus { signedOut, connecting, syncing, upToDate, failing }

/// Connects the app's data to the signed-in user's cloud copy.
class CloudSync extends ChangeNotifier {
  CloudSync({
    required this.auth,
    required this.storage,
    required this.store,
    required this.backupFor,
  });

  final CloudAuth auth;
  final SyncedStorage storage;
  final ExpenseStore store;
  final CloudBackup Function(String uid) backupFor;

  CloudUser? _user;
  bool _connecting = false;
  String? _error;

  CloudUser? get user => _user;

  /// Set when the last sign-in attempt failed; shown to the user.
  String? get error => _error;

  int get pendingChanges => storage.pending.value;

  CloudStatus get status {
    if (_connecting) return CloudStatus.connecting;
    if (_user == null) return CloudStatus.signedOut;
    if (storage.pending.value > 0) {
      return storage.lastError.value == null ? CloudStatus.syncing : CloudStatus.failing;
    }
    return storage.lastError.value == null ? CloudStatus.upToDate : CloudStatus.failing;
  }

  /// Resumes backing up for a user who signed in on an earlier launch.
  void start() {
    storage.pending.addListener(notifyListeners);
    storage.lastError.addListener(notifyListeners);
    final user = auth.currentUser;
    if (user != null) {
      _user = user;
      storage.cloud = backupFor(user.uid);
    }
  }

  @override
  void dispose() {
    storage.pending.removeListener(notifyListeners);
    storage.lastError.removeListener(notifyListeners);
    super.dispose();
  }

  /// Signs in, then combines this phone's data with the cloud's so both end
  /// up with everything.
  Future<void> signIn() async {
    if (_connecting) return;
    _connecting = true;
    _error = null;
    notifyListeners();
    try {
      final user = await auth.signIn();
      if (user == null) return;
      final backup = backupFor(user.uid);
      final StoredData cloud;
      try {
        cloud = await backup.fetch(fromServer: true);
      } catch (_) {
        // Without the real cloud copy we can't merge safely, so don't
        // half-connect.
        await auth.signOut();
        _error = 'Couldn’t reach the cloud. Check your internet connection and try again.';
        return;
      }

      final merged = mergeForSignIn(phone: store.snapshot, cloud: cloud);
      storage.cloud = null;
      store.replaceAll(merged);
      await store.saved;
      storage
        ..cloud = backup
        ..lastError.value = null;
      // Uploads only what the cloud is missing.
      storage.mirrorAll(merged);
      _user = user;
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      _error = 'Sign-in didn’t work. Please try again.';
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  /// After a failed upload: compares the cloud with this phone and uploads
  /// whatever is missing.
  void retry() {
    if (_user == null) return;
    storage.mirrorAll(store.snapshot);
  }

  /// Stops backing up. Data on this phone and in the cloud is left as is.
  Future<void> signOut() async {
    storage
      ..cloud = null
      ..lastError.value = null;
    _user = null;
    notifyListeners();
    await auth.signOut();
  }
}
