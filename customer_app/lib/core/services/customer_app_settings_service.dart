import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/customer_app_settings.dart';
import 'app_version_comparator.dart';

export '../models/customer_app_settings.dart';

/// Status of the app update requirement
enum AppUpdateStatus {
  /// App is on latest version, no update or banner needed
  upToDate,

  /// App is older than latest, but meets minimum supported version
  optionalUpdate,

  /// App is older than minimum supported version and force update is enabled
  mandatoryForceUpdate,
}

/// Structured decision for app update routing
class AppUpdateDecision {
  final AppUpdateStatus status;
  final String installedVersion;
  final String latestVersion;
  final String minimumSupportedVersion;
  final String updateTitle;
  final String updateMessage;
  final String updateButtonText;
  final String playStoreUrl;
  final bool isBannerEnabled;

  const AppUpdateDecision({
    required this.status,
    required this.installedVersion,
    required this.latestVersion,
    required this.minimumSupportedVersion,
    required this.updateTitle,
    required this.updateMessage,
    required this.updateButtonText,
    required this.playStoreUrl,
    required this.isBannerEnabled,
  });

  bool get isMandatory => status == AppUpdateStatus.mandatoryForceUpdate;
  bool get isOptional => status == AppUpdateStatus.optionalUpdate;
  bool get isUpToDate => status == AppUpdateStatus.upToDate;

  @override
  String toString() =>
      'AppUpdateDecision(status: $status, installed: $installedVersion, min: $minimumSupportedVersion, latest: $latestVersion)';
}

/// Production-ready Cloud Firestore App Settings & Version Control Service
/// Exclusively powered by Cloud Firestore document: `app_settings/customer_app`
/// with realtime stream and offline fail-safe defaults.
class CustomerAppSettingsService {
  static final CustomerAppSettingsService _instance =
      CustomerAppSettingsService._internal();
  factory CustomerAppSettingsService() => _instance;
  CustomerAppSettingsService._internal();

  static const String settingsDocPath = 'app_settings/customer_app';

  CustomerAppSettings _currentSettings = CustomerAppSettings.fallback();
  bool _isInitialized = false;

  Stream<CustomerAppSettings>? _settingsStream;
  Stream<AppUpdateDecision>? _updateDecisionStream;
  Stream<bool>? _maintenanceStream;
  StreamSubscription<CustomerAppSettings>? _internalSubscription;
  StreamController<CustomerAppSettings>? _streamController;

  /// Checks whether Firebase default app is initialized before calling Firestore
  static bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Cached active settings
  CustomerAppSettings get currentSettings => _currentSettings;

  /// Single shared broadcast stream for live settings from Firestore
  Stream<CustomerAppSettings> get settingsStream {
    if (!isFirebaseAvailable) {
      _streamController ??= StreamController<CustomerAppSettings>.broadcast();
      return _streamController!.stream;
    }

    if (_settingsStream == null) {
      _settingsStream = FirebaseFirestore.instance
          .doc(settingsDocPath)
          .snapshots()
          .map((snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              _currentSettings = CustomerAppSettings.fromMap(snapshot.data()!);
              debugPrint(
                '⚡ [CustomerAppSettingsService] Realtime Firestore update received: $_currentSettings',
              );
            } else {
              debugPrint(
                'ℹ️ [CustomerAppSettingsService] Document $settingsDocPath does not exist, keeping fallback',
              );
            }
            return _currentSettings;
          })
          .handleError((error, stackTrace) {
            debugPrint(
              '⚠️ [CustomerAppSettingsService] Stream error (using safe fallback): $error',
            );
          })
          .asBroadcastStream();

      // Ensure internal cache stays updated even when no UI listeners are active
      _internalSubscription?.cancel();
      _internalSubscription = _settingsStream!.listen(
        (_) {},
        onError: (_) {},
      );
    }
    return _settingsStream!;
  }

  /// Real-time stream of AppUpdateDecision
  Stream<AppUpdateDecision> get updateDecisionStream {
    _updateDecisionStream ??= settingsStream
        .asyncMap((_) => evaluateUpdateStatus())
        .asBroadcastStream();
    return _updateDecisionStream!;
  }

  /// Real-time stream of maintenance mode
  Stream<bool> get maintenanceStream {
    _maintenanceStream ??= settingsStream
        .map((settings) => settings.maintenanceMode)
        .asBroadcastStream();
    return _maintenanceStream!;
  }

  /// Initializes the service by performing a fast initial fetch and starting the stream
  Future<CustomerAppSettings> initialize({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_isInitialized) return _currentSettings;

    if (!isFirebaseAvailable) {
      _isInitialized = true;
      return _currentSettings;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .doc(settingsDocPath)
          .get()
          .timeout(timeout);

      if (doc.exists && doc.data() != null) {
        _currentSettings = CustomerAppSettings.fromMap(doc.data()!);
        debugPrint(
          '⚡ [CustomerAppSettingsService] Initialized via Firestore doc $settingsDocPath: $_currentSettings',
        );
      } else {
        debugPrint(
          'ℹ️ [CustomerAppSettingsService] Missing $settingsDocPath doc, checking fallback app_config/version_control',
        );
        try {
          final legacyDoc = await FirebaseFirestore.instance
              .collection('app_config')
              .doc('version_control')
              .get()
              .timeout(const Duration(seconds: 2));
          if (legacyDoc.exists && legacyDoc.data() != null) {
            _currentSettings = CustomerAppSettings.fromMap(legacyDoc.data()!);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint(
        '⚠️ [CustomerAppSettingsService] Firestore direct init notice (using safe fallback): $e',
      );
    } finally {
      // Connect realtime stream
      settingsStream;
      _isInitialized = true;
    }

    return _currentSettings;
  }

  /// Refreshes settings on app resume or manual recheck
  Future<CustomerAppSettings> refreshSettings({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!isFirebaseAvailable) return _currentSettings;

    try {
      final doc = await FirebaseFirestore.instance
          .doc(settingsDocPath)
          .get()
          .timeout(timeout);

      if (doc.exists && doc.data() != null) {
        _currentSettings = CustomerAppSettings.fromMap(doc.data()!);
      } else {
        try {
          final legacyDoc = await FirebaseFirestore.instance
              .collection('app_config')
              .doc('version_control')
              .get()
              .timeout(const Duration(seconds: 2));
          if (legacyDoc.exists && legacyDoc.data() != null) {
            _currentSettings = CustomerAppSettings.fromMap(legacyDoc.data()!);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint(
        '⚠️ [CustomerAppSettingsService] refreshSettings notice: $e',
      );
    }
    return _currentSettings;
  }

  /// Evaluates the complete update decision for the current installed version
  Future<AppUpdateDecision> evaluateUpdateStatus({
    String? overrideCurrentVersion,
  }) async {
    String currentVersion = overrideCurrentVersion ?? '';
    if (currentVersion.isEmpty) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (e) {
        debugPrint(
          '⚠️ [CustomerAppSettingsService] PackageInfo read error: $e',
        );
        currentVersion = '1.0.0';
      }
    }

    final minRequired = _currentSettings.minimumSupportedVersion;
    final latest = _currentSettings.latestVersion;
    final forceEnabled = _currentSettings.forceUpdateEnabled;
    final bannerEnabled = _currentSettings.updateBannerEnabled;

    final parsedCurrent = AppVersion.parse(currentVersion);
    final parsedMin = AppVersion.parse(minRequired);
    final parsedLatest = AppVersion.parse(latest);

    final isBelowMin = parsedCurrent < parsedMin;
    final isBelowLatest = parsedCurrent < parsedLatest;

    AppUpdateStatus status;
    if (forceEnabled && isBelowMin) {
      status = AppUpdateStatus.mandatoryForceUpdate;
    } else if (isBelowLatest && bannerEnabled) {
      status = AppUpdateStatus.optionalUpdate;
    } else {
      status = AppUpdateStatus.upToDate;
    }

    debugPrint(
      '🔍 [CustomerAppSettingsService] Version Eval: Current=$currentVersion ($parsedCurrent) | Min=$minRequired ($parsedMin) | Latest=$latest ($parsedLatest) | ForceEnabled=$forceEnabled => Status=$status',
    );

    return AppUpdateDecision(
      status: status,
      installedVersion: currentVersion,
      latestVersion: latest,
      minimumSupportedVersion: minRequired,
      updateTitle: _currentSettings.updateTitle,
      updateMessage: _currentSettings.updateMessage,
      updateButtonText: _currentSettings.updateButtonText,
      playStoreUrl: _currentSettings.playStoreUrl,
      isBannerEnabled: bannerEnabled,
    );
  }

  /// Helper for boolean force update check
  Future<bool> isForceUpdateRequired({String? overrideCurrentVersion}) async {
    final decision =
        await evaluateUpdateStatus(overrideCurrentVersion: overrideCurrentVersion);
    return decision.isMandatory;
  }

  /// Static SemVer comparator exposed for utility
  static bool isVersionLowerThan(String current, String required) {
    return AppVersion.isVersionLower(current, required);
  }

  // --- Convenience Getters forwarding to cached CustomerAppSettings ---
  bool get forceUpdateEnabled => _currentSettings.forceUpdateEnabled;
  String get minimumSupportedVersion => _currentSettings.minimumSupportedVersion;
  String get latestVersion => _currentSettings.latestVersion;
  String get updateTitle => _currentSettings.updateTitle;
  String get updateMessage => _currentSettings.updateMessage;
  String get updateButtonText => _currentSettings.updateButtonText;
  String get playStoreUrl => _currentSettings.playStoreUrl;
  bool get updateBannerEnabled => _currentSettings.updateBannerEnabled;
  bool get isMaintenanceMode => _currentSettings.maintenanceMode;
  String get maintenanceMessage => _currentSettings.maintenanceMessage;
  bool get isGeminiAiSearchEnabled => _currentSettings.isGeminiAiSearchEnabled;
  String get supportPhoneNumber => _currentSettings.supportPhoneNumber;
  String get supportWhatsappNumber => _currentSettings.supportWhatsappNumber;

  @visibleForTesting
  void updateCachedSettingsForTesting(CustomerAppSettings settings) {
    _currentSettings = settings;
    _streamController?.add(settings);
  }
}
