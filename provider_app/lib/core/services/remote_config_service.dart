import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/remote_config_keys.dart';

/// Production-ready Direct Firestore & Remote Config Service for Jamui Services (Provider App)
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  FirebaseRemoteConfig? _remoteConfig;
  Map<String, dynamic> _firestoreConfig = {};
  bool _isInitialized = false;

  /// Optional fake/mock stream for widget/unit tests to avoid uninitialized Firebase exceptions
  @visibleForTesting
  static Stream<bool>? mockForceUpdateStream;

  /// Optional fake/mock return value for isForceUpdateRequired in tests
  @visibleForTesting
  static bool? mockIsForceUpdateRequired;

  /// Direct Realtime Stream of Provider App Force Update Requirement (Realtime from Firestore)
  Stream<bool> get forceUpdateStream {
    if (mockForceUpdateStream != null) {
      return mockForceUpdateStream!;
    }
    try {
      return FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_control')
          .snapshots()
          .asyncMap((snapshot) async {
        if (snapshot.exists && snapshot.data() != null) {
          _firestoreConfig = snapshot.data()!;
        }
        return isForceUpdateRequired();
      });
    } catch (e) {
      debugPrint('⚠️ [Provider RemoteConfigService] Firestore unavailable for forceUpdateStream: $e');
      return const Stream<bool>.empty();
    }
  }

  /// Initializes Firestore Version Check & Remote Config with sensible defaults
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // 1. Direct Realtime Firestore Read (Instant, authoritative, zero cache delay)
      try {
        final doc = await FirebaseFirestore.instance
            .collection('app_config')
            .doc('version_control')
            .get()
            .timeout(const Duration(seconds: 4));
        if (doc.exists && doc.data() != null) {
          _firestoreConfig = doc.data()!;
          debugPrint('⚡ [Provider RemoteConfigService] Firestore version_control loaded: $_firestoreConfig');
        }
      } catch (fsErr) {
        debugPrint('⚠️ [Provider RemoteConfigService] Firestore read notice: $fsErr');
      }

      _remoteConfig = FirebaseRemoteConfig.instance;
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: Duration.zero,
      ));

      // Set local safe defaults
      await _remoteConfig!.setDefaults(RemoteConfigKeys.defaults);
      await _remoteConfig!.fetchAndActivate();
      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [RemoteConfigService] Provider App Remote Config fetch error: $e');
      _isInitialized = true;
    }
  }

  // --- Parameter Getters (Firestore first -> Remote Config fallback) ---
  String get minRequiredVersion {
    final fsVal = _firestoreConfig['min_required_provider_app_version'] ??
        _firestoreConfig['provider_min_required_version'] ??
        _firestoreConfig['provider_minimum_supported_version'];
    if (fsVal != null && fsVal.toString().trim().isNotEmpty) {
      return fsVal.toString().replaceAll('"', '').replaceAll("'", '').trim();
    }
    final rcVal = _remoteConfig?.getString(RemoteConfigKeys.minRequiredProviderAppVersion);
    if (rcVal != null && rcVal.trim().isNotEmpty) {
      return rcVal.replaceAll('"', '').replaceAll("'", '').trim();
    }
    return (RemoteConfigKeys.defaults[RemoteConfigKeys.minRequiredProviderAppVersion] as String);
  }

  String get latestVersion {
    final fsVal = _firestoreConfig['latest_provider_app_version'] ??
        _firestoreConfig['provider_latest_version'];
    if (fsVal != null && fsVal.toString().trim().isNotEmpty) {
      return fsVal.toString().replaceAll('"', '').replaceAll("'", '').trim();
    }
    return _remoteConfig?.getString(RemoteConfigKeys.latestProviderAppVersion) ??
        (RemoteConfigKeys.defaults[RemoteConfigKeys.latestProviderAppVersion] as String);
  }

  bool get isProviderForceUpdateEnabled {
    final fsVal = _firestoreConfig['provider_force_update_enabled'] ??
        _firestoreConfig['provider_force_update'];
    if (fsVal != null) {
      if (fsVal is bool) return fsVal;
      final str = fsVal.toString().trim().toLowerCase();
      if (str == 'true' || str == '1' || str == 'yes') return true;
      if (str == 'false' || str == '0' || str == 'no') return false;
    }
    return false;
  }

  String get updateAppUrl =>
      _remoteConfig?.getString(RemoteConfigKeys.updateAppUrl) ??
      (RemoteConfigKeys.defaults[RemoteConfigKeys.updateAppUrl] as String);

  bool get isMaintenanceMode =>
      _remoteConfig?.getBool(RemoteConfigKeys.providerMaintenanceMode) ?? false;

  String get maintenanceMessage =>
      _remoteConfig?.getString(RemoteConfigKeys.providerMaintenanceMessage) ??
      (RemoteConfigKeys.defaults[RemoteConfigKeys.providerMaintenanceMessage] as String);

  bool get isRealtimeTrackingEnabled =>
      _remoteConfig?.getBool(RemoteConfigKeys.enableProviderRealtimeTracking) ?? true;

  String get supportPhoneNumber =>
      _remoteConfig?.getString(RemoteConfigKeys.supportPhoneNumber) ??
      (RemoteConfigKeys.defaults[RemoteConfigKeys.supportPhoneNumber] as String);

  String get supportWhatsappNumber =>
      _remoteConfig?.getString(RemoteConfigKeys.supportWhatsappNumber) ??
      (RemoteConfigKeys.defaults[RemoteConfigKeys.supportWhatsappNumber] as String);

  /// Configured CDN / R2 image base URL (Firestore first, Remote Config fallback, empty default)
  String get imageBaseUrl {
    final fsVal = _firestoreConfig['image_base_url'] ??
        _firestoreConfig['imageBaseUrl'];
    if (fsVal != null && fsVal.toString().trim().isNotEmpty) {
      return fsVal.toString().trim();
    }
    return _remoteConfig?.getString(RemoteConfigKeys.imageBaseUrl) ??
        (RemoteConfigKeys.defaults[RemoteConfigKeys.imageBaseUrl] as String? ?? '');
  }

  /// Checks if current app version is strictly lower than minimum required version
  Future<bool> isForceUpdateRequired() async {
    if (mockIsForceUpdateRequired != null) {
      return mockIsForceUpdateRequired!;
    }
    try {
      if (_firestoreConfig.isEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('app_config').doc('version_control').get();
          if (doc.exists && doc.data() != null) {
            _firestoreConfig = doc.data()!;
          }
        } catch (_) {}
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final isLower = isVersionLowerThan(currentVersion, minRequiredVersion);
      final isLatestLower = isVersionLowerThan(currentVersion, latestVersion);
      return isLower || (isProviderForceUpdateEnabled && isLatestLower);
    } catch (e) {
      debugPrint('⚠️ [RemoteConfigService] Provider Version check failed: $e');
      return false;
    }
  }

  static bool isVersionLowerThan(String current, String required) {
    try {
      final currentClean = current.replaceAll('"', '').replaceAll("'", '').split('-').first.split('+').first.trim();
      final requiredClean = required.replaceAll('"', '').replaceAll("'", '').split('-').first.split('+').first.trim();

      final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final requiredParts = requiredClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (requiredParts.length < 3) {
        requiredParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (currentParts[i] < requiredParts[i]) return true;
        if (currentParts[i] > requiredParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
