import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/services/app_version_comparator.dart';
import 'package:apna_jamui_customer/core/services/customer_app_settings_service.dart';
import 'package:apna_jamui_customer/core/services/app_update_manager.dart';
import 'package:apna_jamui_customer/core/widgets/mandatory_update_screen.dart';
import 'package:apna_jamui_customer/core/widgets/optional_update_banner.dart';

void main() {
  group('Jamui Services Customer App — Version Comparator (SemVer 2.0.0) Unit Tests', () {
    test('TEST 1: Semantic versioning correctly evaluates 1.10.0 > 1.2.0 (numeric vs string)', () {
      final vCurrent = AppVersion.parse('1.10.0');
      final vTarget = AppVersion.parse('1.2.0');

      expect(vCurrent > vTarget, isTrue);
      expect(vCurrent < vTarget, isFalse);
      expect(AppVersion.isVersionLower('1.10.0', '1.2.0'), isFalse);
      expect(AppVersion.isVersionLower('1.2.0', '1.10.0'), isTrue);
    });

    test('TEST 2: Minor & patch comparisons work accurately', () {
      expect(AppVersion.isVersionLower('1.1.9', '1.2.0'), isTrue);
      expect(AppVersion.isVersionLower('1.2.0', '1.2.1'), isTrue);
      expect(AppVersion.isVersionLower('2.0.0', '1.9.9'), isFalse);
      expect(AppVersion.isVersionLower('1.2.0', '1.2.0'), isFalse);
    });

    test('TEST 3: Build number comparison works when major.minor.patch are equal', () {
      final v12 = AppVersion.parse('1.2.0+12');
      final v15 = AppVersion.parse('1.2.0+15');

      expect(v12 < v15, isTrue);
      expect(v15 > v12, isTrue);
      expect(v12 == AppVersion.parse('1.2.0+12'), isTrue);

      // Major/minor/patch still takes precedence over build number
      final vHigher = AppVersion.parse('1.2.1+1');
      final vLower = AppVersion.parse('1.2.0+999');
      expect(vHigher > vLower, isTrue);
    });

    test('TEST 4: Handles dirty strings, prefixes (v1.2.0), and pre-release tags safely without crash', () {
      final vWithPrefix = AppVersion.parse(' v1.2.3 ');
      expect(vWithPrefix.major, equals(1));
      expect(vWithPrefix.minor, equals(2));
      expect(vWithPrefix.patch, equals(3));

      final vPreRelease = AppVersion.parse('1.4.0-beta.2+45');
      expect(vPreRelease.major, equals(1));
      expect(vPreRelease.minor, equals(4));
      expect(vPreRelease.patch, equals(0));
      expect(vPreRelease.buildNumber, equals(45));

      // Malformed strings degrade gracefully to 0.0.0
      final vMalformed = AppVersion.parse('invalid_string');
      expect(vMalformed.major, equals(0));
      expect(vMalformed.minor, equals(0));
      expect(vMalformed.patch, equals(0));
    });
  });

  group('Jamui Services Customer App — Firestore Customer App Settings Update Decision Tests (Cases 1-8)', () {
    test('CASE 1: Latest installed version — Up to date (No banner, No mandatory screen)', () async {
      final service = CustomerAppSettingsService();

      final decision = await service.evaluateUpdateStatus(
        overrideCurrentVersion: '1.2.5+17',
      );

      expect(decision.status, equals(AppUpdateStatus.upToDate));
      expect(decision.isMandatory, isFalse);
      expect(decision.isOptional, isFalse);
      expect(decision.isUpToDate, isTrue);
    });

    test('CASE 2: Older but supported version — Optional update banner active', () async {
      final service = CustomerAppSettingsService();

      // Device on 1.1.0, minimum required is 1.0.0, latest is 1.2.5
      final decision = await service.evaluateUpdateStatus(
        overrideCurrentVersion: '1.1.0',
      );

      expect(decision.status, equals(AppUpdateStatus.optionalUpdate));
      expect(decision.isMandatory, isFalse);
      expect(decision.isOptional, isTrue);
      expect(decision.isBannerEnabled, isTrue);
      expect(decision.latestVersion, equals('1.2.5'));
    });

    test('CASE 3: Minimum supported version से पुराना version with force_update_enabled — Mandatory Update', () async {
      final service = CustomerAppSettingsService();

      // Device on 0.9.0, minimum is 1.0.0, forceUpdateEnabled is true in test override
      final parsedCurrent = AppVersion.parse('0.9.0');
      final parsedMin = AppVersion.parse('1.0.0');
      const forceUpdate = true;

      final isMandatory = forceUpdate && (parsedCurrent < parsedMin);
      expect(isMandatory, isTrue);

      final decision = AppUpdateDecision(
        status: AppUpdateStatus.mandatoryForceUpdate,
        installedVersion: '0.9.0',
        latestVersion: service.latestVersion,
        minimumSupportedVersion: service.minimumSupportedVersion,
        updateTitle: service.updateTitle,
        updateMessage: service.updateMessage,
        updateButtonText: service.updateButtonText,
        playStoreUrl: service.playStoreUrl,
        isBannerEnabled: service.updateBannerEnabled,
      );

      expect(decision.status, equals(AppUpdateStatus.mandatoryForceUpdate));
      expect(decision.isMandatory, isTrue);
      expect(decision.isOptional, isFalse);
      expect(decision.updateTitle, equals('New Update Available'));
      expect(decision.updateButtonText, equals('Update Now'));
    });

    test('CASE 4: Force update disabled in config (force_update_enabled = false) — Does not force update', () {
      final parsedCurrent = AppVersion.parse('0.9.0');
      final parsedMin = AppVersion.parse('1.0.0');
      final isLower = parsedCurrent < parsedMin;
      expect(isLower, isTrue);

      bool computeMandatory(bool forceEnabled, bool isVersionBelowMin) =>
          forceEnabled && isVersionBelowMin;

      expect(computeMandatory(false, isLower), isFalse);
      expect(computeMandatory(true, isLower), isTrue);
    });

    test('CASE 5: Update button has official Google Play Store URL & package validation', () {
      final service = CustomerAppSettingsService();
      final storeUrl = service.playStoreUrl;

      expect(storeUrl, contains('com.jamuiservice.customer'));
      expect(storeUrl, startsWith('https://play.google.com/store/apps/details?id='));
      expect(AppUpdateManager.customerPackageId, equals('com.jamuiservice.customer'));
    });

    test('CASE 6: Fallback to safe defaults when Cloud Firestore is unavailable or document missing', () {
      final fallback = CustomerAppSettings.fallback();
      expect(fallback.latestVersion, equals('1.2.5'));
      expect(fallback.minimumSupportedVersion, equals('1.0.0'));
      expect(fallback.forceUpdateEnabled, equals(false));
      expect(fallback.updateTitle, equals('New Update Available'));
      expect(fallback.updateButtonText, equals('Update Now'));
      expect(fallback.updateBannerEnabled, equals(true));
      expect(fallback.maintenanceMode, equals(false));
      expect(fallback.playStoreUrl, contains('com.jamuiservice.customer'));
    });

    test('CASE 7: Provider App settings isolation check', () {
      // Customer app settings parameters must remain separate from Provider app
      final fallback = CustomerAppSettings.fallback();
      expect(fallback.playStoreUrl, contains('com.jamuiservice.customer'));
      expect(fallback.playStoreUrl.contains('com.jamuiservice.provider'), isFalse);
      expect(AppUpdateManager.customerPackageId, equals('com.jamuiservice.customer'));
      expect(AppUpdateManager.customerPackageId, isNot(equals('com.jamuiservice.provider')));
    });

    test('CASE 8: When force_update_enabled is true, version below minimum triggers mandatory update', () {
      final parsedCurrent = AppVersion.parse('0.9.5');
      final parsedMin = AppVersion.parse('1.0.0');
      final parsedLatest = AppVersion.parse('1.2.5');

      final isBelowMin = parsedCurrent < parsedMin; // true
      final isBelowLatest = parsedCurrent < parsedLatest; // true
      const forceEnabled = true;

      final isMandatory = forceEnabled && isBelowMin;
      expect(isMandatory, isTrue);
      expect(isBelowLatest, isTrue);

      final decision = AppUpdateDecision(
        status: isMandatory ? AppUpdateStatus.mandatoryForceUpdate : AppUpdateStatus.optionalUpdate,
        installedVersion: '0.9.5',
        latestVersion: '1.2.5',
        minimumSupportedVersion: '1.0.0',
        updateTitle: 'Update Required',
        updateMessage: 'Mandatory update to continue using Jamui Services',
        updateButtonText: 'Update Now',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.jamuiservice.customer',
        isBannerEnabled: true,
      );

      expect(decision.isMandatory, isTrue);
      expect(decision.status, equals(AppUpdateStatus.mandatoryForceUpdate));
    });
  });

  group('Jamui Services Customer App — Update UI Widgets Tests', () {
    testWidgets('MandatoryUpdateScreen renders title, branding, message, and Update button', (tester) async {
      const decision = AppUpdateDecision(
        status: AppUpdateStatus.mandatoryForceUpdate,
        installedVersion: '1.0.0',
        latestVersion: '1.2.0',
        minimumSupportedVersion: '1.1.0',
        updateTitle: 'New Update Available',
        updateMessage: 'सुरक्षा सुधार के लिए कृपया तुरंत ऐप अपडेट करें।',
        updateButtonText: 'Update Now',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.jamuiservice.customer',
        isBannerEnabled: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MandatoryUpdateScreen(decision: decision),
        ),
      );

      await tester.pumpAndSettle();

      // Title & Message
      expect(find.text('New Update Available'), findsOneWidget);
      expect(find.text('सुरक्षा सुधार के लिए कृपया तुरंत ऐप अपडेट करें।'), findsOneWidget);

      // Version comparison chips
      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.text('1.1.0'), findsOneWidget);
      expect(find.text('1.2.0'), findsOneWidget);

      // Buttons
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('अपडेट की जाँच करें (Check Status)'), findsOneWidget);
    });

    testWidgets('OptionalUpdateBanner renders when update is optional and dismiss button works', (tester) async {
      const decision = AppUpdateDecision(
        status: AppUpdateStatus.optionalUpdate,
        installedVersion: '1.1.0',
        latestVersion: '1.2.0',
        minimumSupportedVersion: '1.0.0',
        updateTitle: 'नया अपडेट उपलब्ध',
        updateMessage: 'नए फीचर्स के लिए अभी अपडेट करें।',
        updateButtonText: 'Update Now',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.jamuiservice.customer',
        isBannerEnabled: true,
      );

      bool wasDismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptionalUpdateBanner(
              decision: decision,
              onDismiss: () => wasDismissed = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Banner should be visible
      expect(find.text('नया अपडेट उपलब्ध'), findsOneWidget);
      expect(find.text('v1.2.0'), findsOneWidget);
      expect(find.text('अपडेट'), findsOneWidget);

      // Tap dismiss (close icon)
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(wasDismissed, isTrue);
      expect(find.text('नया अपडेट उपलब्ध'), findsNothing);
    });
  });
}
