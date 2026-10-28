import 'package:firebase_core/firebase_core.dart';

/// Firebase project settings, copied from the project's google-services.json.
///
/// None of these are secrets: they identify the app to Firebase, and the
/// Firestore security rules are what keep each user's data private.
class FirebaseConfig {
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyARo3ExgkMH4521szJYuQpBt74jSVMLRjI',
    appId: '1:450898447996:android:c4c64cd21bcf38e73a83f9',
    messagingSenderId: '450898447996',
    projectId: 'kipto-9967a',
    storageBucket: 'kipto-9967a.firebasestorage.app',
  );

  /// The OAuth client with `"client_type": 3` in google-services.json.
  static const webClientId =
      '450898447996-e5ke8flpm6hbb02p178h69in1fno8snr.apps.googleusercontent.com';
}
