// File generated manually for Firebase project myframe-b9ba9.
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web in this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAwB8v7wGN0mmFznPrHAOy_au4xMyu8jAA',
    appId: '1:35227816140:android:c186d8802a7b33abad7269',
    messagingSenderId: '35227816140',
    projectId: 'myframe-b9ba9',
    storageBucket: 'myframe-b9ba9.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCYxSVX5inUKUQf3pa3wZjVDilwOAjumng',
    appId: '1:35227816140:ios:678ca23fdeaeda8aad7269',
    messagingSenderId: '35227816140',
    projectId: 'myframe-b9ba9',
    storageBucket: 'myframe-b9ba9.firebasestorage.app',
    iosBundleId: 'com.myframe.minyuex',
  );
}
