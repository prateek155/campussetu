// lib/firebase_options.dart
// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER — Replace with your actual Firebase config!
// Run: flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
// This will generate the real firebase_options.dart file automatically.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not configured for this project');
      default:
        throw UnsupportedError('Unsupported platform: $defaultTargetPlatform');
    }
  }

  // ── WEB — Replace with real values ───────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB1-xwN3rPZrbQcU3zxvhmr0WHclIryNiU',
    appId: '1:895097267765:web:ad1b09f197f09093a2b37c',
    messagingSenderId: '895097267765',
    projectId: 'campussetu-dba25',
    authDomain: 'campussetu-dba25.firebaseapp.com',
    storageBucket: 'campussetu-dba25.firebasestorage.app',
    measurementId: 'G-0YS6S3GGT0',
  );

  // ── ANDROID — Replace with real values ───────────────
  // Also put the real google-services.json in android/app/
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgDgsWcVyb1c7kyrF6iH9xtctOL8stNak',
    appId: '1:895097267765:android:87c3178a5d557836a2b37c',
    messagingSenderId: '895097267765',
    projectId: 'campussetu-dba25',
    storageBucket: 'campussetu-dba25.firebasestorage.app',
  );
}
