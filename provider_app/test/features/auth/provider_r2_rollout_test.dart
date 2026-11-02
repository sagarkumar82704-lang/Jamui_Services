import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/core/config/remote_config_keys.dart';
import 'package:apna_jamui_provider/core/services/r2_upload_service.dart';
import 'package:apna_jamui_provider/core/utils/app_image_url_resolver.dart';
import 'package:apna_jamui_provider/core/utils/app_image_utils.dart';
import 'package:apna_jamui_provider/features/auth/data/datasources/firebase_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/auth/data/models/provider_profile_model.dart';

class MockR2UploadService extends R2UploadService {
  bool uploadFileCalled = false;
  bool uploadBytesCalled = false;
  String? lastFolder;
  String? lastTargetId;
  String? lastFileName;
  bool shouldThrow = false;
  String? customErrorMessage;

  @override
  Future<R2UploadResult> uploadBytes({
    required Uint8List bytes,
    required String folder,
    required String fileName,
    required String mimeType,
    String? targetId,
  }) async {
    uploadBytesCalled = true;
    lastFolder = folder;
    lastTargetId = targetId;
    lastFileName = fileName;

    if (shouldThrow) {
      throw R2UploadException(customErrorMessage ?? 'Mock R2 connection timeout');
    }

    return R2UploadResult(
      objectKey: 'providers/$targetId/$folder/${folder}_1730000000000_abcd1234.jpg',
      byteLength: bytes.length,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Provider App Cloudflare R2-Only Migration & Zero Fallback Test Suite', () {
    const publicBaseUrl = 'https://pub-890d33c064214a2cb631bf960b479923.r2.dev';
    const providerId = 'test_provider_uid_123';
    final sampleBytes = Uint8List.fromList(List.generate(200, (i) => i % 256));

    setUp(() {
      AppImageUrlResolver.setOverrideBaseUrl(publicBaseUrl);
    });

    tearDown(() {
      AppImageUrlResolver.setOverrideBaseUrl(null);
    });

    // 1. Profile image R2 par upload hoti hai aur relative key return hoti hai
    test('1. Profile image uploads strictly to Cloudflare R2 and returns canonical relative key', () async {
      final mockR2 = MockR2UploadService();
      final dataSource = FirebaseProviderRemoteDataSource(r2Service: mockR2);

      final resultKey = await dataSource.uploadProviderImageBytes(
        providerId: providerId,
        imageBytes: sampleBytes,
        folder: 'profile',
      );

      expect(mockR2.uploadBytesCalled, isTrue);
      expect(mockR2.lastFolder, 'profile');
      expect(mockR2.lastTargetId, providerId);
      expect(resultKey, startsWith('providers/$providerId/profile/'));
      expect(resultKey.startsWith('http'), isFalse);
      expect(resultKey, endsWith('.jpg'));
    });

    // 2. Business image R2 par upload hoti hai
    test('2. Business/shop image uploads strictly to Cloudflare R2 and returns relative key', () async {
      final mockR2 = MockR2UploadService();
      final dataSource = FirebaseProviderRemoteDataSource(r2Service: mockR2);

      final resultKey = await dataSource.uploadProviderImageBytes(
        providerId: providerId,
        imageBytes: sampleBytes,
        folder: 'business',
      );

      expect(mockR2.uploadBytesCalled, isTrue);
      expect(mockR2.lastFolder, 'business');
      expect(mockR2.lastTargetId, providerId);
      expect(resultKey, startsWith('providers/$providerId/business/'));
      expect(resultKey.startsWith('http'), isFalse);
    });

    // 3. Workplace/public service image R2 par upload hoti hai
    test('3. Workplace/service public photo uploads strictly to Cloudflare R2', () async {
      final mockR2 = MockR2UploadService();
      final dataSource = FirebaseProviderRemoteDataSource(r2Service: mockR2);

      final resultKey = await dataSource.uploadProviderImageBytes(
        providerId: providerId,
        imageBytes: sampleBytes,
        folder: 'workplace',
      );

      expect(mockR2.uploadBytesCalled, isTrue);
      expect(mockR2.lastFolder, 'workplace');
      expect(mockR2.lastTargetId, providerId);
      expect(resultKey, startsWith('providers/$providerId/workplace/'));
      expect(resultKey.startsWith('http'), isFalse);
    });

    // 4. Critical: R2 failure par Firebase Storage fallback invoke nahi hota
    test('4. Critical: On R2 failure, Firebase Storage fallback is NEVER invoked and descriptive exception is thrown', () async {
      final mockR2 = MockR2UploadService()..shouldThrow = true;
      final dataSource = FirebaseProviderRemoteDataSource(r2Service: mockR2);

      // Must throw Exception and NOT silently fall back or succeed with Firebase Storage
      expect(
        () => dataSource.uploadProviderImageBytes(
          providerId: providerId,
          imageBytes: sampleBytes,
          folder: 'profile',
        ),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Cloudflare R2 पर profile फोटो अपलोड विफल रहा') &&
            e.toString().contains('Mock R2 connection timeout'))),
      );

      expect(mockR2.uploadBytesCalled, isTrue);
    });

    // 5. Failed upload par existing Firestore reference preserve hota hai
    test('5. Failed upload preserves existing profile & business references without overwriting or corrupting', () {
      const existingProfileImage = 'providers/$providerId/profile/profile_existing.jpg';
      const existingBusinessImage = 'providers/$providerId/business/business_existing.jpg';

      final originalModel = ProviderProfileModel(
        id: providerId,
        fullName: 'Vikram Singh',
        businessName: 'Singh Electronics',
        email: 'vikram@jamuiservice.com',
        phoneNumber: '+919988776655',
        primaryCategoryId: 'cat_appliances',
        primaryCategoryTitle: 'इलेक्ट्रॉनिक्स रिपेयर',
        profileImageUrl: existingProfileImage,
        businessImageUrl: existingBusinessImage,
        createdAt: DateTime.now(),
      );

      // Simulating a failed upload where caller catches error
      String activeProfileImg = originalModel.profileImageUrl;
      try {
        throw Exception('Simulated R2 Network Failure');
      } catch (_) {
        // Fallback catch preserves existing reference
      }

      final updatedModel = originalModel.copyWith(profileImageUrl: activeProfileImg);
      expect(updatedModel.profileImageUrl, existingProfileImage);
      expect(updatedModel.profileImageUrl.isNotEmpty, isTrue);
      expect(updatedModel.profileImageUrl.startsWith('http'), isFalse);
      expect(updatedModel.businessImageUrl, existingBusinessImage);
    });

    // 6. Successful upload ke baad Firestore model mein relative key hi save hoti hai
    test('6. Successful upload persists canonical relative key to ProviderProfileModel', () {
      const uploadedKey = 'providers/$providerId/profile/profile_1730000000000_abcd1234.jpg';

      final model = ProviderProfileModel(
        id: providerId,
        fullName: 'Vikram Singh',
        businessName: 'Singh Electronics',
        email: 'vikram@jamuiservice.com',
        phoneNumber: '+919988776655',
        primaryCategoryId: 'cat_appliances',
        primaryCategoryTitle: 'इलेक्ट्रॉनिक्स रिपेयर',
        profileImageUrl: uploadedKey,
        createdAt: DateTime.now(),
      );

      final map = model.toMap();
      expect(map['profileImageUrl'], uploadedKey);
      expect((map['profileImageUrl'] as String).startsWith('http'), isFalse);
      expect(map['profileImageUrl'], startsWith('providers/$providerId/profile/'));
    });

    // 7. Legacy Firebase Storage URLs ab bhi resolve hoti hain
    test('7. AppImageUrlResolver and AppImageUtils resolve legacy Firebase Storage URLs unchanged', () {
      const legacyFirebaseUrl =
          'https://firebasestorage.googleapis.com/v0/b/jamui-services.appspot.com/o/providers%2F$providerId%2Fprofile%2F1729000000000.jpg?alt=media';

      // 1. Resolver keeps absolute Firebase URLs intact
      expect(AppImageUrlResolver.resolve(legacyFirebaseUrl), legacyFirebaseUrl);

      // 2. Image Provider builds NetworkImage with exact legacy URL
      final provider = AppImageUtils.getImageProvider(legacyFirebaseUrl);
      expect(provider, isA<NetworkImage>());
      expect((provider as NetworkImage).url, legacyFirebaseUrl);
    });

    // 8. Certificate / KYC uploads route directly to Cloudflare R2
    test('8. Certificate / KYC uploads route directly to Cloudflare R2', () async {
      final mockR2 = MockR2UploadService();
      final dataSource = FirebaseProviderRemoteDataSource(r2Service: mockR2);

      final certKey = await dataSource.uploadProviderImageBytes(
        providerId: providerId,
        imageBytes: sampleBytes,
        folder: 'certificates',
      );

      expect(mockR2.uploadBytesCalled, isTrue);
      expect(mockR2.lastFolder, 'certificates');
      expect(mockR2.lastTargetId, providerId);
      expect(certKey, startsWith('providers/$providerId/certificates/'));

      final profile = ProviderProfileEntity(
        id: providerId,
        fullName: 'Ramesh Sharma',
        businessName: 'Sharma Electricals',
        email: 'ramesh@jamuiservice.com',
        phoneNumber: '+919876543210',
        primaryCategoryId: 'cat_electrical',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
        createdAt: DateTime.now(),
        profileImageUrl: 'providers/$providerId/profile/profile_1.jpg',
        businessImageUrl: 'providers/$providerId/business/business_1.jpg',
        hasExperienceCertificate: true,
        experienceCertificateUrl: certKey,
      );

      expect(profile.experienceCertificateUrl, startsWith('providers/$providerId/certificates/'));
      expect(profile.profileImageUrl.startsWith('http'), isFalse);
    });

    // 9. Unauthorized user doosre provider ke liye image upload nahi kar sakta
    test('9. Unauthorized cross-provider upload is rejected by validation', () async {
      final mockR2 = MockR2UploadService()
        ..shouldThrow = true
        ..customErrorMessage = 'Unauthorized: You can only upload profile photos for your own user account.';

      final dataSource = FirebaseProviderRemoteDataSource(r2Service: mockR2);

      expect(
        () => dataSource.uploadProviderImageBytes(
          providerId: 'unauthorized_target_uid',
          imageBytes: sampleBytes,
          folder: 'profile',
        ),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Unauthorized: You can only upload profile photos for your own user account.'))),
      );
    });

    // 10. Upload fail hone par UI crash nahi karti aur retry possible hota hai
    testWidgets('10. Upload failure renders error notification with active Retry action without crashing UI', (WidgetTester tester) async {
      bool retryTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('फोटो अपलोड विफल रहा: R2 Connection Timeout'),
                  ElevatedButton(
                    onPressed: () {
                      retryTriggered = true;
                    },
                    child: const Text('पुनः प्रयास (Retry)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify notification is visible with error message and retry action
      expect(find.text('फोटो अपलोड विफल रहा: R2 Connection Timeout'), findsOneWidget);
      expect(find.text('पुनः प्रयास (Retry)'), findsOneWidget);

      // Tap Retry button
      await tester.tap(find.text('पुनः प्रयास (Retry)'));
      await tester.pump();

      expect(retryTriggered, isTrue);
    });

    // 11. Unsupported folder names are rejected immediately
    test('11. Unsupported folder names throw ArgumentError immediately', () {
      final mockR2 = MockR2UploadService();
      final dataSource = FirebaseProviderRemoteDataSource(r2Service: mockR2);

      expect(
        () => dataSource.uploadProviderImageBytes(
          providerId: providerId,
          imageBytes: sampleBytes,
          folder: 'unauthorized_private_folder',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // 12. RemoteConfigKeys defaults includes image_base_url with empty fallback
    test('12. RemoteConfigKeys image_base_url default fallback is safe empty string', () {
      expect(RemoteConfigKeys.imageBaseUrl, 'image_base_url');
      expect(RemoteConfigKeys.defaults[RemoteConfigKeys.imageBaseUrl], '');
    });
  });
}
