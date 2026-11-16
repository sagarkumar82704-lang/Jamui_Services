import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import '../../core/config/app_environment.dart';

/// [DefaultFirebaseOptions] JAMUI SERVICES Admin Web Panel के लिए फ़ायरबेस कॉन्फ़िगरेशन
/// Authoritatively resolves options based on AppEnvironmentConfig.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (AppEnvironmentConfig.current) {
      case AppEnvironment.production:
        return _productionPlatform;
      case AppEnvironment.staging:
        return _stagingPlatform;
      case AppEnvironment.emulator:
        return _emulatorPlatform;
    }
  }

  static FirebaseOptions get _productionPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static FirebaseOptions get _stagingPlatform {
    if (kIsWeb) {
      return stagingWeb;
    }
    switch (defaultTargetPlatform) {
      default:
        return stagingWeb;
    }
  }

  // ===========================================================================
  // STAGING OPTIONS — GENUINE STAGING CONFIGURATION (694086796929)
  // ===========================================================================
  static const FirebaseOptions stagingWeb = FirebaseOptions(
    apiKey: 'AIzaSyAB35pqPdAuLiVT5XRu_OmEjIT2NqC4zG0',
    appId: '1:694086796929:web:f3a37f9620d9d1df422f80',
    messagingSenderId: '694086796929',
    projectId: 'jamui-services-staging',
    authDomain: 'jamui-services-staging.firebaseapp.com',
    storageBucket: 'jamui-services-staging.firebasestorage.app',
  );

  static FirebaseOptions get _emulatorPlatform {
    final base = _productionPlatform;
    return FirebaseOptions(
      apiKey: base.apiKey,
      appId: base.appId,
      messagingSenderId: base.messagingSenderId,
      projectId: AppEnvironmentConfig.emulatorProjectId,
      authDomain: '${AppEnvironmentConfig.emulatorProjectId}.firebaseapp.com',
      storageBucket: '${AppEnvironmentConfig.emulatorProjectId}.appspot.com',
      measurementId: base.measurementId,
      databaseURL: base.databaseURL,
      trackingId: base.trackingId,
      deepLinkURLScheme: base.deepLinkURLScheme,
      androidClientId: base.androidClientId,
      iosClientId: base.iosClientId,
      iosBundleId: base.iosBundleId,
      appGroupId: base.appGroupId,
    );
  }

  // ===========================================================================
  // PRODUCTION OPTIONS — PRESERVED 100% UNCHANGED
  // ===========================================================================
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyABe__ezf3olYTfuxTKEpYoJZtcI5BncHM',
    appId: '1:953708304881:web:b667134ba9c99cfc6d8c50',
    messagingSenderId: '953708304881',
    projectId: 'jamui-services',
    authDomain: 'jamui-services.firebaseapp.com',
    storageBucket: 'jamui-services.firebasestorage.app',
    measurementId: 'G-BKX7B59GKX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAN5a34LUB1x7Qno38ERMvCF7H-qglS8uc',
    appId: '1:953708304881:android:4fbf1ce84bedbd9f6d8c50',
    messagingSenderId: '953708304881',
    projectId: 'jamui-services',
    storageBucket: 'jamui-services.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAN5a34LUB1x7Qno38ERMvCF7H-qglS8uc',
    appId: '1:953708304881:ios:4fbf1ce84bedbd9f6d8c50',
    messagingSenderId: '953708304881',
    projectId: 'jamui-services',
    storageBucket: 'jamui-services.firebasestorage.app',
  );
}
