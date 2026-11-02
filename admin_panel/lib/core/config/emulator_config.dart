import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EmulatorConfig {
  static const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  static const String customHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '');
  static const String emulatorProjectId = 'demo-jamui-services';

  static String get emulatorHost {
    if (customHost.isNotEmpty) return customHost;
    if (kIsWeb) return '127.0.0.1';
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return '127.0.0.1';
  }

  /// Dynamically aligns FirebaseOptions with the emulator's project ID when USE_EMULATOR=true.
  /// When USE_EMULATOR=false, it returns the original production options without modification.
  static FirebaseOptions getEffectiveOptions(FirebaseOptions base) {
    if (!useEmulator) return base;
    return FirebaseOptions(
      apiKey: base.apiKey,
      appId: base.appId,
      messagingSenderId: base.messagingSenderId,
      projectId: emulatorProjectId,
      authDomain: '$emulatorProjectId.firebaseapp.com',
      storageBucket: '$emulatorProjectId.appspot.com',
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

  static bool _isConfigured = false;
  static bool get isConfigured => _isConfigured;

  static Future<void> configureEmulators() async {
    if (!useEmulator) {
      debugPrint('ℹ️ [JAMUI CONFIG] Production Firebase mode active (Project: jamui-services).');
      return;
    }

    final host = emulatorHost;
    debugPrint('🛡️ [JAMUI SAFETY] Connecting Admin Panel to Local Firebase Emulators at $host (Project: $emulatorProjectId)...');

    try {
      FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        sslEnabled: false,
      );
      FirebaseFunctions.instanceFor(region: 'asia-south1').useFunctionsEmulator(host, 5001);
      FirebaseStorage.instance.useStorageEmulator(host, 9199);

      // Strict Health Check probe to confirm emulator is actually running!
      // Queries 'diamond_subscription_plans' which has 'allow read: if true;' in firestore.rules
      // and guarantees both network connectivity and rule compliance without leaking auth.
      await FirebaseFirestore.instance
          .collection('diamond_subscription_plans')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () => throw TimeoutException('Firestore emulator at $host:8080 did not respond within 4s.'),
          );

      _isConfigured = true;
      debugPrint('✅ [JAMUI SAFETY] VERIFIED: Admin Panel connected to Local Emulator ($host, $emulatorProjectId). Production is 100% disconnected.');
    } catch (e) {
      debugPrint('❌ [JAMUI SAFETY HALT] FATAL: Emulator connection failed: $e');
      throw EmulatorSafetyException(
        'CRITICAL SAFETY HALT (Admin Panel):\n'
        'USE_EMULATOR=true is enabled, but the Local Firebase Emulator at $host is unreachable.\n\n'
        'To prevent accidental reads, writes, or modifications to the LIVE PRODUCTION FIREBASE project, '
        'fallback to production is STRICTLY BLOCKED.\n\n'
        'Action Required:\n'
        'Start the local Firebase emulators using:\n'
        'firebase emulators:start --project demo-jamui-services\n\n'
        'Error details: $e',
      );
    }
  }
}

class EmulatorSafetyException implements Exception {
  final String message;
  EmulatorSafetyException(this.message);
  @override
  String toString() => message;
}

class FatalEmulatorHaltApp extends StatelessWidget {
  final String message;
  const FatalEmulatorHaltApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1515),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 36),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'SAFETY HALT: EMULATOR UNREACHABLE',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Production Fallback is strictly BLOCKED to protect live data.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    message,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
