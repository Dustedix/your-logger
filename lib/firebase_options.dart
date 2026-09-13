import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCY-qdseuu2ZNoENWNk439pK0Lxmm7fIew',
    appId: '1:98118822213:web:84d6843045c2f6b838762c',
    messagingSenderId: '98118822213',
    projectId: 'workout-tracker-171d1',
    authDomain: 'workout-tracker-171d1.firebaseapp.com',
    storageBucket: 'workout-tracker-171d1.firebasestorage.app',
    measurementId: 'G-HLKN7M2QW4',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBbT0-ytjNkCgE6K38IIM-5nvylYajJJf8',
    appId: '1:98118822213:android:c21924ec9b922a9538762c',
    messagingSenderId: '98118822213',
    projectId: 'workout-tracker-171d1',
    storageBucket: 'workout-tracker-171d1.firebasestorage.app',
  );
}
