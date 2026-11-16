import 'dart:io';
import 'dart:typed_data';
import 'package:apna_jamui_customer/core/config/app_environment.dart';
import 'package:apna_jamui_customer/features/provider_portal/presentation/pages/provider_webview_screen.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/custom_service_application_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/services/provider_app_launcher_service.dart';
import 'package:apna_jamui_customer/features/provider_portal/presentation/pages/provider_native_host_screen.dart';
import 'package:apna_jamui_provider/provider_app.dart';

class FakeProviderRepository implements ProviderRepository {
  @override
  User? getCurrentUser() => null;

  @override
  Future<User?> loginWithEmail({required String email, required String password}) async => null;

  @override
  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async => null;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<ProviderProfileEntity?> getProfile(String providerId) async => null;

  @override
  Future<ProviderProfileEntity?> findRegisteredProviderByPhone(String rawPhoneNumber) async => null;

  @override
  Future<ProviderProfileEntity?> findRegisteredProviderByEmail(String email) async => null;

  @override
  Stream<ProviderProfileEntity?> watchProfile(String providerId) => Stream.value(null);

  @override
  Future<void> saveProfile(ProviderProfileEntity profile) async {}

  @override
  Future<void> updateAvailability(String providerId, bool isAvailable) async {}

  @override
  Future<void> submitKyc({required String providerId}) async {}

  @override
  Future<void> incrementLeadCount({required String providerId, required bool isCall}) async {}

  @override
  Future<String> uploadImage({
    required String providerId,
    required File imageFile,
    required String folder,
  }) async => '';

  @override
  Future<String> uploadImageBytes({
    required String providerId,
    required Uint8List imageBytes,
    required String folder,
    String mimeType = 'image/jpeg',
  }) async => '';

  @override
  Future<CustomServiceApplicationEntity?> getCustomServiceApplication(String providerId) {
    // TODO: implement getCustomServiceApplication
    throw UnimplementedError();
  }

  @override
  Future<void> submitCustomServiceApplication(CustomServiceApplicationEntity application) {
    // TODO: implement submitCustomServiceApplication
    throw UnimplementedError();
  }

  @override
  Future<void> submitCategoryChangeRequest({
    required String providerId,
    required String requestedCategoryId,
    required String requestedCategoryTitle,
    Map<String, dynamic>? customServiceDetails,
  }) async {}

  @override
  Future<void> updatePermittedProfileFields({required String providerId, required Map<String, dynamic> fields}) {
    // TODO: implement updatePermittedProfileFields
    throw UnimplementedError();
  }

  @override
  Stream<CustomServiceApplicationEntity?> watchCustomServiceApplication(String providerId) {
    // TODO: implement watchCustomServiceApplication
    throw UnimplementedError();
  }
}

void main() {
  group('Provider Native Host & Launcher Tests', () {
    setUp(() {
      RemoteConfigService.mockForceUpdateStream = Stream.value(false);
      RemoteConfigService.mockIsForceUpdateRequired = false;
    });

    tearDown(() {
      RemoteConfigService.mockForceUpdateStream = null;
      RemoteConfigService.mockIsForceUpdateRequired = null;
      AppEnvironmentConfig.testOverride = null;
    });

    test('ProviderAppLauncherService resolves URLs based on environment', () {
      AppEnvironmentConfig.testOverride = AppEnvironment.staging;
      expect(
        ProviderAppLauncherService.providerWebUrl,
        equals('https://jamui-services-staging-provider.web.app'),
      );

      AppEnvironmentConfig.testOverride = AppEnvironment.production;
      expect(
        ProviderAppLauncherService.providerWebUrl,
        equals('https://jamui-provider.web.app'),
      );

      AppEnvironmentConfig.testOverride = AppEnvironment.emulator;
      expect(
        ProviderAppLauncherService.providerWebUrl,
        equals('http://10.0.2.2:64343'),
      );

      expect(ProviderAppLauncherService.providerPackageName, equals('com.jamuiservice.provider'));
    });

    test('ProviderWebViewScreen isolates staging and production trusted hosts', () {
      // Staging isolation verification
      AppEnvironmentConfig.testOverride = AppEnvironment.staging;
      expect(
        ProviderWebViewScreen.trustedHostsForTesting,
        equals({
          'jamui-services-staging-provider.web.app',
          'jamui-services-staging-provider.firebaseapp.com',
        }),
      );
      expect(
        ProviderWebViewScreen.isTrustedUrlForTesting('https://jamui-services-staging-provider.web.app/orders'),
        isTrue,
      );
      expect(
        ProviderWebViewScreen.isTrustedUrlForTesting('https://jamui-services-staging-provider.firebaseapp.com/#/dashboard'),
        isTrue,
      );
      // Staging MUST reject production URLs
      expect(
        ProviderWebViewScreen.isTrustedUrlForTesting('https://jamui-provider.web.app/orders'),
        isFalse,
      );
      expect(
        ProviderWebViewScreen.isTrustedUrlForTesting('https://jamui-provider.firebaseapp.com'),
        isFalse,
      );
      expect(
        ProviderWebViewScreen.isTrustedUrlForTesting('https://malicious-site.example.com'),
        isFalse,
      );

      // Production isolation verification
      AppEnvironmentConfig.testOverride = AppEnvironment.production;
      expect(
        ProviderWebViewScreen.trustedHostsForTesting,
        equals({
          'jamui-provider.web.app',
          'jamui-provider.firebaseapp.com',
        }),
      );
      expect(
        ProviderWebViewScreen.isTrustedUrlForTesting('https://jamui-provider.web.app/orders'),
        isTrue,
      );
      // Production MUST reject staging URLs
      expect(
        ProviderWebViewScreen.isTrustedUrlForTesting('https://jamui-services-staging-provider.web.app/orders'),
        isFalse,
      );
      expect(
        ProviderWebViewScreen.isTrustedUrlForTesting('https://jamui-services-staging-provider.firebaseapp.com'),
        isFalse,
      );
    });

    testWidgets('ProviderNativeHostScreen instantiates cleanly with fake repo', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderNativeHostScreen(
              repository: FakeProviderRepository(),
            ),
          ),
        ),
      );

      // Verify the host screen mounts without throwing errors
      expect(find.byType(ProviderNativeHostScreen), findsOneWidget);
    });
  });
}
