import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_sync.dart';

/// Signs in to Firebase with the user's Google account.
class GoogleCloudAuth implements CloudAuth {
  GoogleCloudAuth({required this.webClientId});

  /// The "Web client" OAuth id from google-services.json, which Google needs
  /// to issue a token Firebase accepts.
  final String webClientId;

  /// Must finish before any other call.
  Future<void> initialize() => GoogleSignIn.instance.initialize(serverClientId: webClientId);

  static CloudUser? _toCloudUser(User? user) => user == null
      ? null
      : CloudUser(uid: user.uid, email: user.email, name: user.displayName);

  @override
  CloudUser? get currentUser => _toCloudUser(FirebaseAuth.instance.currentUser);

  @override
  Future<CloudUser?> signIn() async {
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final credential = GoogleAuthProvider.credential(idToken: account.authentication.idToken);
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    return _toCloudUser(result.user);
  }

  @override
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();
  }
}
