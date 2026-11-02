import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// [DefaultFirebaseOptions] JAMUI SERVICES Provider App के लिए फ़ायरबेस कॉन्फ़िगरेशन
/// Project ID: jamui-services
/// Package Name: com.jamuiservice.provider
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
    apiKey: 'AIzaSyAN5a34LUB1x7Qno38ERMvCF7H-qglS8uc',
    appId: '1:953708304881:android:353544e835ce46456d8c50',
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
    apiKey: 'AIzaSyAN5a34LUB1x7Qno38ERMvCF7H-qglS8uc',
    appId: '1:953708304881:ios:353544e835ce46456d8c50',
    messagingSenderId: '953708304881',
    projectId: 'jamui-services',
    storageBucket: 'jamui-services.firebasestorage.app',
    iosBundleId: 'com.jamuiservice.provider',
  );
}
