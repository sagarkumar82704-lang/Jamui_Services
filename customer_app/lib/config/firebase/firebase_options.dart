import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// [DefaultFirebaseOptions] JAMUI SERVICES Customer App के लिए फ़ायरबेस कॉन्फ़िगरेशन
/// Project ID: jamui-services
/// Package Name: com.jamuiservice.customer
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyABe__ezf3olYTfuxTKEpYoJZtcI5BncHM',
    appId: '1:953708304881:android:4fbf1ce84bedbd9f6d8c50',
    messagingSenderId: '953708304881',
    projectId: 'jamui-services',
    storageBucket: 'jamui-services.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyABe__ezf3olYTfuxTKEpYoJZtcI5BncHM',
    appId: '1:953708304881:web:b667134ba9c99cfc6d8c50',
    messagingSenderId: '953708304881',
    projectId: 'jamui-services',
    storageBucket: 'jamui-services.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyABe__ezf3olYTfuxTKEpYoJZtcI5BncHM',
    appId: '1:953708304881:ios:4fbf1ce84bedbd9f6d8c50',
    messagingSenderId: '953708304881',
    projectId: 'jamui-services',
    storageBucket: 'jamui-services.firebasestorage.app',
    iosBundleId: 'com.jamuiservice.customer',
  );
}
