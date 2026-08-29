// Generated & configured for Firebase project: dessert-institute
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for ${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDVaNNyALnsrqrqTj371nGn8gbeBWL7fGc',
    appId: '1:400647872169:android:fae72682b4da8841ec93b8',
    messagingSenderId: '400647872169',
    projectId: 'dessert-institute',
    storageBucket: 'dessert-institute.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDVaNNyALnsrqrqTj371nGn8gbeBWL7fGc',
    appId: '1:400647872169:android:fae72682b4da8841ec93b8',
    messagingSenderId: '400647872169',
    projectId: 'dessert-institute',
    storageBucket: 'dessert-institute.firebasestorage.app',
    iosBundleId: 'com.institute.dessert.dessert_app',
  );
}
