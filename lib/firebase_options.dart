// Firebase settings for Find Doctor (project: see projectId below).
// Filled in from the Firebase console: Project settings > Your apps.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        // Windows and other desktops use the web app's settings.
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    authDomain: 'TODO',
    storageBucket: 'TODO',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    storageBucket: 'TODO',
  );
}
