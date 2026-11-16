import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_jamui_provider/main.dart';
import 'package:apna_jamui_provider/core/localization/provider_locale_controller.dart';
import 'package:apna_jamui_provider/core/services/remote_config_service.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/custom_service_application_entity.dart';
import 'package:apna_jamui_provider/features/auth/domain/repositories/provider_repository.dart';
import 'package:apna_jamui_provider/features/auth/presentation/pages/provider_login_page.dart';

class _FakeProviderRepository implements ProviderRepository {
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
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

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
  Future<void> updatePermittedProfileFields({
    required String providerId,
    required Map<String, dynamic> fields,
  }) async {}

  @override
  Future<void> updateAvailability(String providerId, bool isAvailable) async {}

  @override
  Future<void> submitKyc({required String providerId}) async {}

  @override
  Future<void> incrementLeadCount({required String providerId, required bool isCall}) async {}

  @override
  Future<String> uploadImage({required String providerId, required File imageFile, required String folder}) async => '';

  @override
  Future<String> uploadImageBytes({
    required String providerId,
    required Uint8List imageBytes,
    required String folder,
    String mimeType = 'image/jpeg',
  }) async => '';

  @override
  Future<void> submitCustomServiceApplication(CustomServiceApplicationEntity application) async {}

  @override
  Future<void> submitCategoryChangeRequest({
    required String providerId,
    required String requestedCategoryId,
    required String requestedCategoryTitle,
    Map<String, dynamic>? customServiceDetails,
  }) async {}

  @override
  Stream<CustomServiceApplicationEntity?> watchCustomServiceApplication(String providerId) => Stream.value(null);

  @override
  Future<CustomServiceApplicationEntity?> getCustomServiceApplication(String providerId) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    isProviderFirebaseInitialized = true;
    RemoteConfigService.mockForceUpdateStream = const Stream<bool>.empty();
    RemoteConfigService.mockIsForceUpdateRequired = false;
    ProviderLocaleController.instance.resetForTest('hi');
  });

  tearDown(() {
    RemoteConfigService.mockForceUpdateStream = null;
    RemoteConfigService.mockIsForceUpdateRequired = null;
  });

  group('Provider App Root MaterialLocalizations Regression Tests', () {
    testWidgets('1. Fresh launch in Hindi (hi) provides valid MaterialLocalizations to TextField in ProviderLoginPage', (tester) async {
      final fakeRepo = _FakeProviderRepository();

      await tester.pumpWidget(
        JamuiServiceProviderApp(providerRepository: fakeRepo),
      );
      await tester.pumpAndSettle();

      // Verify ProviderLoginPage is mounted
      expect(find.byType(ProviderLoginPage), findsOneWidget);

      // Verify TextFields exist (Email and Password)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      // Verify MaterialLocalizations is found in the element tree for Hindi
      final firstTextFieldElement = tester.element(textFields.first);
      final materialLoc = MaterialLocalizations.of(firstTextFieldElement);
      expect(materialLoc, isNotNull);
      expect(materialLoc.okButtonLabel, isNotEmpty);

      // Verify typing into the email TextField does not throw any assertion/error
      await tester.enterText(textFields.first, 'seller@example.com');
      await tester.pump();
      expect(tester.widget<TextField>(textFields.first).controller?.text, equals('seller@example.com'));

      // Verify typing into the password TextField works cleanly
      await tester.enterText(textFields.last, 'secretPassword123');
      await tester.pump();
      expect(tester.widget<TextField>(textFields.last).controller?.text, equals('secretPassword123'));

      // Verify no Flutter exceptions occurred during pumping
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Switching language to English (en) retains valid MaterialLocalizations and TextField functionality', (tester) async {
      final fakeRepo = _FakeProviderRepository();

      await tester.pumpWidget(
        JamuiServiceProviderApp(providerRepository: fakeRepo),
      );
      await tester.pumpAndSettle();

      // Switch to English dynamically
      await ProviderLocaleController.instance.setLocale('en');
      await tester.pumpAndSettle();

      expect(ProviderLocaleController.instance.isEnglish, isTrue);

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      final firstTextFieldElement = tester.element(textFields.first);
      final materialLoc = MaterialLocalizations.of(firstTextFieldElement);
      expect(materialLoc, isNotNull);
      expect(materialLoc.okButtonLabel, equals('OK'));

      // Test interaction in English
      await tester.enterText(textFields.first, 'english_partner@apnajamui.in');
      await tester.pump();
      expect(tester.widget<TextField>(textFields.first).controller?.text, equals('english_partner@apnajamui.in'));

      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Switching back from English to Hindi retains valid MaterialLocalizations', (tester) async {
      final fakeRepo = _FakeProviderRepository();

      await tester.pumpWidget(
        JamuiServiceProviderApp(providerRepository: fakeRepo),
      );
      await tester.pumpAndSettle();

      // Switch to en, then toggle back to hi
      await ProviderLocaleController.instance.setLocale('en');
      await tester.pumpAndSettle();
      expect(ProviderLocaleController.instance.isEnglish, isTrue);

      await ProviderLocaleController.instance.setLocale('hi');
      await tester.pumpAndSettle();
      expect(ProviderLocaleController.instance.isHindi, isTrue);

      final textFields = find.byType(TextField);
      final element = tester.element(textFields.first);
      final materialLoc = MaterialLocalizations.of(element);
      expect(materialLoc, isNotNull);

      expect(tester.takeException(), isNull);
    });
  });
}
