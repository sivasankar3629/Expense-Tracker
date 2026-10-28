import 'package:firebase_core/firebase_core.dart';

/// Firebase project settings, copied from android/app/google-services.json.
///
/// While these are null the app runs fine and simply hides cloud backup.
class FirebaseConfig {
  static const FirebaseOptions? android = null;

  /// The OAuth client with `"client_type": 3` in google-services.json.
  static const String? webClientId = null;
}
