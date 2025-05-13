import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: "AIzaSyCQWgtWJVuQjgIKEu7US5kvhwNfqFtmmXU",
    appId: "1:80373758294:android:8c81452b136e60ebfa7ef7",
    messagingSenderId: "80373758294",
    projectId: "mobile-d6a7a",
    storageBucket: "mobile-d6a7a.firebasestorage.app",
  );

  // Helper method to check if Firebase is properly configured
  static bool isConfigured() {
    final options = currentPlatform;
    return options.apiKey != "YOUR_API_KEY" &&
        options.appId != "YOUR_APP_ID" &&
        options.projectId != "YOUR_PROJECT_ID";
  }
}
