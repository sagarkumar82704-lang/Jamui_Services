import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_admin/core/utils/admin_image_utils.dart';
import 'package:apna_jamui_admin/core/utils/app_image_url_resolver.dart';

void main() {
  group('AdminImageUtils.getImageProvider Unit Tests', () {
    const testBaseUrl = 'https://pub-890d33c064214a2cb631bf960b479923.r2.dev';

    setUp(() {
      AppImageUrlResolver.setOverrideBaseUrl(testBaseUrl);
    });

    tearDown(() {
      AppImageUrlResolver.setOverrideBaseUrl(null);
    });

    test('1. Relative R2 key resolves to NetworkImage with configured CDN base URL', () {
      const r2RelativeKey = 'providers/prov_123/profile/profile_1792940299_abc.png';
      final provider = AdminImageUtils.getImageProvider(r2RelativeKey);

      expect(provider, isNotNull);
      expect(provider, isA<NetworkImage>());
      final networkImage = provider as NetworkImage;
      expect(networkImage.url, '$testBaseUrl/$r2RelativeKey');
    });

    test('2. Legacy Firebase Storage URL is preserved 100% unchanged', () {
      const legacyFirebaseUrl =
          'https://firebasestorage.googleapis.com/v0/b/jamui-services.appspot.com/o/providers%2Fprov_123%2Fprofile.jpg?alt=media&token=123';
      final provider = AdminImageUtils.getImageProvider(legacyFirebaseUrl);

      expect(provider, isNotNull);
      expect(provider, isA<NetworkImage>());
      final networkImage = provider as NetworkImage;
      expect(networkImage.url, legacyFirebaseUrl);
    });

    test('3. External HTTP / HTTPS image URL is preserved unchanged', () {
      const externalUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';
      final provider = AdminImageUtils.getImageProvider(externalUrl);

      expect(provider, isNotNull);
      expect(provider, isA<NetworkImage>());
      final networkImage = provider as NetworkImage;
      expect(networkImage.url, externalUrl);
    });

    test('4. Null, empty, and whitespace strings safely return null (Avatar fallback)', () {
      expect(AdminImageUtils.getImageProvider(null), isNull);
      expect(AdminImageUtils.getImageProvider(''), isNull);
      expect(AdminImageUtils.getImageProvider('   '), isNull);
    });

    test('5. Base64 data URI returns MemoryImage correctly', () {
      // 1x1 transparent PNG in base64
      const base64Png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
      final provider = AdminImageUtils.getImageProvider(base64Png);

      expect(provider, isNotNull);
      expect(provider, isA<MemoryImage>());
    });

    test('6. Local Flutter asset path returns AssetImage', () {
      const assetPath = 'assets/images/placeholder.png';
      final provider = AdminImageUtils.getImageProvider(assetPath);

      expect(provider, isNotNull);
      expect(provider, isA<AssetImage>());
      final assetImage = provider as AssetImage;
      expect(assetImage.assetName, assetPath);
    });

    test('7. Unresolved key when base URL is unconfigured safely returns null on web', () {
      AppImageUrlResolver.setOverrideBaseUrl('');
      const r2Key = 'providers/prov_123/profile/profile.jpg';
      final provider = AdminImageUtils.getImageProvider(r2Key);

      // Without base URL, resolver returns relative key which is not http/assets/data:image -> null
      expect(provider, isNull);
    });

    test('8. Already resolved R2 URL does not cause double base URL concatenation', () {
      const alreadyResolvedUrl =
          '$testBaseUrl/providers/prov_123/profile/profile_1792940299_abc.png';
      final provider = AdminImageUtils.getImageProvider(alreadyResolvedUrl);

      expect(provider, isNotNull);
      expect(provider, isA<NetworkImage>());
      final networkImage = provider as NetworkImage;
      expect(networkImage.url, alreadyResolvedUrl);
    });
  });
}
