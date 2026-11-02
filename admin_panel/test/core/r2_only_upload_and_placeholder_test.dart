import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_admin/core/services/r2_upload_service.dart';
import 'package:apna_jamui_admin/core/utils/admin_placeholder_images.dart';
import 'package:apna_jamui_admin/core/utils/app_image_url_resolver.dart';
import 'package:apna_jamui_admin/features/banners/data/datasources/banner_storage_remote_data_source.dart';
import 'package:apna_jamui_admin/features/categories/data/datasources/category_storage_remote_data_source.dart';

/// Test Fake implementation of R2UploadService to verify R2-only behavior and zero Firebase fallback
class FakeR2UploadService extends R2UploadService {
  final bool shouldFail;
  final String? failureMessage;
  final String fakeObjectKey;
  int uploadCallCount = 0;
  String? lastFolder;
  String? lastTargetId;

  FakeR2UploadService({
    this.shouldFail = false,
    this.failureMessage,
    this.fakeObjectKey = 'test/mock_object.webp',
  });

  @override
  Future<R2UploadResult> uploadBytes({
    required Uint8List bytes,
    required String folder,
    required String fileName,
    required String mimeType,
    String? targetId,
    String? customPath,
  }) async {
    uploadCallCount++;
    lastFolder = folder;
    lastTargetId = targetId;

    if (shouldFail) {
      throw R2UploadException(failureMessage ?? 'R2 network connection timeout (504)');
    }

    final ext = fileName.contains('.') ? fileName.split('.').last : 'webp';
    final key = '$folder/$targetId/cover_test.$ext';

    return R2UploadResult(
      objectKey: key,
      byteLength: bytes.length,
    );
  }
}

void main() {
  group('Admin Panel — R2 Only Upload & Cost Protection Tests', () {
    test('1. Category cover image uploads strictly to R2 and returns relative object key', () async {
      final fakeR2 = FakeR2UploadService();
      final dataSource = R2CategoryStorageRemoteDataSource(r2Service: fakeR2);

      final dummyBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final result = await dataSource.uploadCategoryImage(
        categoryId: 'cat_appliances_01',
        bytes: dummyBytes,
        fileName: 'cover.webp',
        mimeType: 'image/webp',
      );

      // Verify R2 was called exactly once
      expect(fakeR2.uploadCallCount, equals(1));
      expect(fakeR2.lastFolder, equals('categories'));
      expect(fakeR2.lastTargetId, equals('cat_appliances_01'));

      // Verify result contains ONLY relative R2 key, not full URL or Firebase URL
      expect(result.storagePath, equals('categories/cat_appliances_01/cover_test.webp'));
      expect(result.downloadUrl, equals('categories/cat_appliances_01/cover_test.webp'));
      expect(result.downloadUrl.startsWith('https://firebasestorage'), isFalse);
    });

    test('2. Category upload R2 failure throws clear Hindi error with ZERO Firebase Storage fallback', () async {
      final failingR2 = FakeR2UploadService(
        shouldFail: true,
        failureMessage: 'R2 bucket putObject failed: AccessDenied',
      );
      final dataSource = R2CategoryStorageRemoteDataSource(r2Service: failingR2);

      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      try {
        await dataSource.uploadCategoryImage(
          categoryId: 'cat_plumbing',
          bytes: dummyBytes,
          fileName: 'plumbing.png',
        );
        fail('Should have thrown an exception on R2 failure');
      } catch (e) {
        // Must contain Hindi error explaining R2 failure
        expect(e.toString(), contains('Cloudflare R2 पर कैटेगरी इमेज अपलोड विफल रहा'));
        expect(e.toString(), contains('AccessDenied'));
      }

      // Verify only 1 upload attempt was made (NO stealth fallback to Firebase Storage)
      expect(failingR2.uploadCallCount, equals(1));
    });

    test('3. Banner image uploads strictly to R2 and returns relative object key', () async {
      final fakeR2 = FakeR2UploadService();
      final dataSource = R2BannerStorageRemoteDataSource(r2Service: fakeR2);

      final dummyBytes = Uint8List.fromList([255, 216, 255, 224]);
      final result = await dataSource.uploadBannerImage(
        bannerId: 'banner_festive_2026',
        bytes: dummyBytes,
        fileName: 'festive_promo.jpg',
        mimeType: 'image/jpeg',
      );

      // Verify R2 was called exactly once
      expect(fakeR2.uploadCallCount, equals(1));
      expect(fakeR2.lastFolder, equals('banners'));
      expect(fakeR2.lastTargetId, equals('banner_festive_2026'));

      // Verify result contains ONLY relative R2 key
      expect(result.storagePath, equals('banners/banner_festive_2026/cover_test.jpg'));
      expect(result.downloadUrl, equals('banners/banner_festive_2026/cover_test.jpg'));
      expect(result.downloadUrl.startsWith('https://firebasestorage'), isFalse);
    });

    test('4. Banner upload R2 failure throws clear Hindi error with ZERO Firebase Storage fallback', () async {
      final failingR2 = FakeR2UploadService(
        shouldFail: true,
        failureMessage: 'Presigned URL generation rejected by Cloud Function',
      );
      final dataSource = R2BannerStorageRemoteDataSource(r2Service: failingR2);

      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      try {
        await dataSource.uploadBannerImage(
          bannerId: 'banner_diwali',
          bytes: dummyBytes,
          fileName: 'banner.png',
        );
        fail('Should have thrown an exception on R2 failure');
      } catch (e) {
        expect(e.toString(), contains('Cloudflare R2 पर बैनर इमेज अपलोड विफल रहा'));
        expect(e.toString(), contains('Presigned URL generation rejected'));
      }

      expect(failingR2.uploadCallCount, equals(1));
    });

    test('5. Backward compatibility alias FirebaseCategoryStorageRemoteDataSource points to R2', () {
      final instance = FirebaseCategoryStorageRemoteDataSource();
      expect(instance, isA<R2CategoryStorageRemoteDataSource>());
      expect(instance, isA<CategoryStorageRemoteDataSource>());
    });

    test('6. Backward compatibility alias FirebaseBannerStorageRemoteDataSource points to R2', () {
      final instance = FirebaseBannerStorageRemoteDataSource();
      expect(instance, isA<R2BannerStorageRemoteDataSource>());
      expect(instance, isA<BannerStorageRemoteDataSource>());
    });
  });

  group('Admin Panel — Placeholder Images System Tests', () {
    test('1. AdminPlaceholderImages generates only local/bundled items with zero external URLs', () {
      final catItem = AdminPlaceholderImages.getRandomCategoryPlaceholder();
      final bannerItem = AdminPlaceholderImages.getRandomBannerPlaceholder();

      // Virtual URIs must start with placeholder://
      expect(catItem.virtualUri.startsWith('placeholder://'), isTrue);
      expect(bannerItem.virtualUri.startsWith('placeholder://'), isTrue);

      // Must NOT contain external domains
      expect(catItem.virtualUri.contains('http://'), isFalse);
      expect(catItem.virtualUri.contains('https://'), isFalse);
      expect(bannerItem.virtualUri.contains('http://'), isFalse);
      expect(bannerItem.virtualUri.contains('https://'), isFalse);

      // Must have Hindi & English titles
      expect(catItem.titleHindi.isNotEmpty, isTrue);
      expect(catItem.titleEnglish.isNotEmpty, isTrue);
      expect(bannerItem.titleHindi.isNotEmpty, isTrue);
      expect(bannerItem.titleEnglish.isNotEmpty, isTrue);
    });

    test('2. isPlaceholder correctly identifies placeholder URIs and protects real R2 keys', () {
      // True cases
      expect(AdminPlaceholderImages.isPlaceholder('placeholder://category/home_electric'), isTrue);
      expect(AdminPlaceholderImages.isPlaceholder('placeholder://banner/festival_sale'), isTrue);
      expect(AdminPlaceholderImages.isPlaceholder('demo_placeholder_electrician'), isTrue);

      // False cases (Real R2 keys and legacy Firebase URLs)
      expect(AdminPlaceholderImages.isPlaceholder('categories/cat_123/cover_456.webp'), isFalse);
      expect(AdminPlaceholderImages.isPlaceholder('banners/banner_789/banner_101.jpg'), isFalse);
      expect(AdminPlaceholderImages.isPlaceholder('providers/usr_999/profile/profile_111.jpg'), isFalse);
      expect(AdminPlaceholderImages.isPlaceholder('https://firebasestorage.googleapis.com/...'), isFalse);
      expect(AdminPlaceholderImages.isPlaceholder(null), isFalse);
      expect(AdminPlaceholderImages.isPlaceholder(''), isFalse);
    });

    test('3. AppImageUrlResolver resolves relative R2 keys and preserves legacy Firebase URLs', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-890d33c064214a2cb631bf960b479923.r2.dev');

      // Relative category R2 key
      const catKey = 'categories/cat_electrician/cover_prod.webp';
      expect(
        AppImageUrlResolver.resolve(catKey),
        equals('https://pub-890d33c064214a2cb631bf960b479923.r2.dev/categories/cat_electrician/cover_prod.webp'),
      );

      // Relative banner R2 key
      const bannerKey = 'banners/banner_diwali/banner_prod.jpg';
      expect(
        AppImageUrlResolver.resolve(bannerKey),
        equals('https://pub-890d33c064214a2cb631bf960b479923.r2.dev/banners/banner_diwali/banner_prod.jpg'),
      );

      // Legacy Firebase Storage URL unchanged
      const legacyFirebaseUrl =
          'https://firebasestorage.googleapis.com/v0/b/jamui-services.firebasestorage.app/o/categories%2Fcat_1%2Fcover.jpg?alt=media';
      expect(AppImageUrlResolver.resolve(legacyFirebaseUrl), equals(legacyFirebaseUrl));

      // Provider KYC / Certificate URL (Firebase Storage) unchanged
      const kycCertFirebaseUrl =
          'https://firebasestorage.googleapis.com/v0/b/jamui-services.firebasestorage.app/o/providers%2Fuid123%2Fcertificates%2Fcert.pdf?alt=media';
      expect(AppImageUrlResolver.resolve(kycCertFirebaseUrl), equals(kycCertFirebaseUrl));

      // Virtual placeholder URI returned unchanged (not prefixed with R2 domain)
      const placeholderUri = 'placeholder://category/home_electric';
      expect(AppImageUrlResolver.resolve(placeholderUri), equals(placeholderUri));

      AppImageUrlResolver.setOverrideBaseUrl(null);
    });
  });
}
