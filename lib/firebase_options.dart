import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDZQ1v4TFTmCQCAKGzwuXLsncP5MbkbdwE',
    appId: '1:36423587341:web:e626f1f08b7b8cb2596744',
    messagingSenderId: '36423587341',
    projectId: 'studymate-5ab8c',
    authDomain: 'studymate-5ab8c.firebaseapp.com',
    storageBucket: 'studymate-5ab8c.appspot.com',
    measurementId: 'G-Q58JYB5LLT',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBJr_09KB2bQTX6Iz6Bnq58mhVNWqPjVn4',
    appId: '1:36423587341:android:cdd1c23b0f14191e596744',
    messagingSenderId: '36423587341',
    projectId: 'studymate-5ab8c',
    storageBucket: 'studymate-5ab8c.appspot.com',
  );
}
