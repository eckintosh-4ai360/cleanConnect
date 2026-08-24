

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'Firebase is not configured for Apple platforms yet — add '
          'ios/Runner/GoogleService-Info.plist and fill in the `ios` block in '
          'lib/firebase_options.dart.',
        );
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBz7SW7jM3cU1o6fJtQBDUMPBIqNLbnaYM',
    appId: '1:718487738924:android:13622e7eefc6994e590f89',
    messagingSenderId: '718487738924',
    projectId: 'cleanconnect-5a323',
    storageBucket: 'cleanconnect-5a323.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCiXCzwhOVG97hb2zyE6Xw5-gHh7UUI0uU',
    appId: '1:718487738924:web:f81cdc6ef768fcec590f89',
    messagingSenderId: '718487738924',
    projectId: 'cleanconnect-5a323',
    authDomain: 'cleanconnect-5a323.firebaseapp.com',
    storageBucket: 'cleanconnect-5a323.firebasestorage.app',
    measurementId: 'G-HMD5MGE2N3',
  );
}
