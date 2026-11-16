import 'package:flutter/foundation.dart';

/// Supported application environments in Jamui Services
enum AppEnvironment {
  production,
  staging,
  emulator,
}

/// Strict, fail-closed build-time environment configuration resolver.
/// Requires explicit `--dart-define=APP_ENV=production|staging|emulator`.
/// Silent fallback to Production is strictly blocked.
class AppEnvironmentConfig {
  static const String _rawAppEnv = String.fromEnvironment('APP_ENV', defaultValue: '');
  static const bool _useEmulatorLegacyFlag = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);

  /// Production Project Metadata
  static const String productionProjectId = 'jamui-services';
  static const String productionProjectNumber = '953708304881';

  /// Staging Project Metadata
  static const String stagingProjectId = 'jamui-services-staging';
  static const String stagingProjectNumber = '694086796929';

  /// Local Emulator Project Metadata
  static const String emulatorProjectId = 'demo-jamui-services';

  /// Authoritative Environment Resolver
  static AppEnvironment get current {
    final env = _rawAppEnv.trim().toLowerCase();

    // 1. Conflict Detection: Production or Staging cannot coexist with USE_EMULATOR=true
    if (_useEmulatorLegacyFlag && (env == 'production' || env == 'staging')) {
      throw StateError(
        'CONFLICTING ENVIRONMENT FLAGS: APP_ENV="$env" cannot be combined with USE_EMULATOR=true. '
        'For emulator testing, use `--dart-define=APP_ENV=emulator`.',
      );
    }

    // 2. Explicit Emulator Flag
    if (env == 'emulator' || (_useEmulatorLegacyFlag && env.isEmpty)) {
      return AppEnvironment.emulator;
    }

    // 3. Explicit Staging Flag
    if (env == 'staging') {
      return AppEnvironment.staging;
    }

    // 4. Explicit Production Flag
    if (env == 'production') {
      return AppEnvironment.production;
    }

    // 5. Fail-Closed on Missing APP_ENV
    if (env.isEmpty) {
      throw StateError(
        'FATAL ENVIRONMENT ERROR: Missing build-time configuration `--dart-define=APP_ENV`. '
        'Silent fallback to Production is strictly disabled. '
        'You must explicitly build with:\n'
        '  --dart-define=APP_ENV=production (Production)\n'
        '  --dart-define=APP_ENV=staging    (Staging)\n'
        '  --dart-define=APP_ENV=emulator   (Local Emulator)',
      );
    }

    // 6. Fail-Closed on Invalid APP_ENV
    throw StateError(
      'FATAL ENVIRONMENT ERROR: Invalid APP_ENV="$_rawAppEnv". '
      'Permitted values are: "production", "staging", or "emulator".',
    );
  }

  /// Convenience getters
  static bool get isProduction => current == AppEnvironment.production;
  static bool get isStaging => current == AppEnvironment.staging;
  static bool get isEmulator => current == AppEnvironment.emulator;

  /// Expected Firebase Project ID for current environment
  static String get expectedProjectId {
    switch (current) {
      case AppEnvironment.production:
        return productionProjectId;
      case AppEnvironment.staging:
        return stagingProjectId;
      case AppEnvironment.emulator:
        return emulatorProjectId;
    }
  }

  /// Default Public Image CDN / R2 Base URL for current environment
  static String get defaultImageBaseUrl {
    try {
      switch (current) {
        case AppEnvironment.production:
          return 'https://pub-890d33c064214a2cb631bf960b479923.r2.dev';
        case AppEnvironment.staging:
          return 'https://pub-7ffc4239e37248bd84da9d451086bfe6.r2.dev';
        case AppEnvironment.emulator:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  /// Safely logs environment without printing credentials or API keys
  static void logEnvironment(String appName) {
    try {
      final env = current;
      debugPrint('🛡️ [$appName] ENVIRONMENT RESOLVED: ${env.name.toUpperCase()} (Firebase Project: $expectedProjectId)');
    } catch (e) {
      debugPrint('🚨 [$appName] CONFIGURATION HALT: $e');
      rethrow;
    }
  }
}

