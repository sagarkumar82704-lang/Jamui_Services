import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/core/config/app_environment.dart';
import 'package:apna_jamui_provider/core/config/remote_config_keys.dart';
import 'package:apna_jamui_provider/core/utils/app_image_url_resolver.dart';

void main() {
  setUp(() {
    AppImageUrlResolver.setOverrideBaseUrl(null);
  });

  tearDown(() {
    AppImageUrlResolver.setOverrideBaseUrl(null);
  });

  group('Provider App AppImageUrlResolver Unit Tests', () {
    test('1. Null, empty, and whitespace strings safely return empty string', () {
      expect(AppImageUrlResolver.resolve(null), '');
      expect(AppImageUrlResolver.resolve(''), '');
      expect(AppImageUrlResolver.resolve('   '), '');
      expect(AppImageUrlResolver.resolve('\t\n'), '');
    });

    test('2. Existing Firebase Storage download URLs are preserved 100% unchanged', () {
      const firebaseUrls = [
        'https://firebasestorage.googleapis.com/v0/b/jamui-services.firebasestorage.app/o/providers%2Fuid123%2Fprofile%2Fpic.jpg?alt=media&token=123-abc',
        'https://firebasestorage.googleapis.com/v0/b/jamui-services.appspot.com/o/providers%2Fuid123%2Fbusiness%2Fbiz.webp?alt=media&token=xyz-789',
        'https://firebasestorage.googleapis.com/v0/b/jamui-services/o/profile_images%2Fuser1%2Fprofile.jpg?alt=media',
      ];

      for (final url in firebaseUrls) {
        expect(AppImageUrlResolver.resolve(url), url);
      }
    });

    test('3. Other valid HTTP / HTTPS external URLs are preserved unchanged', () {
      const externalUrls = [
        'https://images.unsplash.com/photo-1581092918056-0c4c3acd3789?w=600',
        'http://example.com/assets/sample.png',
        'https://cdn.example.org/images/service_123.webp?size=medium&v=2',
      ];

      for (final url in externalUrls) {
        expect(AppImageUrlResolver.resolve(url), url);
      }
    });

    test('4. Inline Base64 data URIs are preserved unchanged', () {
      const b64 = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      expect(AppImageUrlResolver.resolve(b64), b64);
      expect(AppImageUrlResolver.resolve('  $b64  '), b64);
    });

    test('5. Local Flutter asset paths and web blob URIs are preserved unchanged', () {
      expect(AppImageUrlResolver.resolve('assets/images/logo.png'), 'assets/images/logo.png');
      expect(AppImageUrlResolver.resolve('assets/icons/provider_badge.svg'), 'assets/icons/provider_badge.svg');
      expect(AppImageUrlResolver.resolve('blob:http://localhost:5000/123-blob-id'), 'blob:http://localhost:5000/123-blob-id');
    });

    test('6. Relative R2 object key resolves with configured base URL', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev');

      expect(
        AppImageUrlResolver.resolve('providers/uid_123/profile/173000.webp'),
        'https://pub-test-dev.r2.dev/providers/uid_123/profile/173000.webp',
      );
      expect(
        AppImageUrlResolver.resolve('providers/uid_123/business/biz.jpg'),
        'https://pub-test-dev.r2.dev/providers/uid_123/business/biz.jpg',
      );
      expect(
        AppImageUrlResolver.resolve('categories/electrician.webp'),
        'https://pub-test-dev.r2.dev/categories/electrician.webp',
      );
    });

    test('7. Slash handling normalizes leading and trailing slashes correctly', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev///');
      expect(
        AppImageUrlResolver.resolve('providers/uid_123/profile/173000.webp'),
        'https://pub-test-dev.r2.dev/providers/uid_123/profile/173000.webp',
      );

      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev');
      expect(
        AppImageUrlResolver.resolve('///providers/uid_123/profile/173000.webp'),
        'https://pub-test-dev.r2.dev/providers/uid_123/profile/173000.webp',
      );

      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev////');
      expect(
        AppImageUrlResolver.resolve('////providers/uid_123/profile/173000.webp'),
        'https://pub-test-dev.r2.dev/providers/uid_123/profile/173000.webp',
      );
    });

    test('8. When base URL is unconfigured or empty, relative key returns safely without mutation', () {
      AppImageUrlResolver.setOverrideBaseUrl('');
      expect(AppImageUrlResolver.resolve('providers/uid_123/profile/173000.webp'), 'providers/uid_123/profile/173000.webp');
      expect(AppImageUrlResolver.resolve('categories/plumbing.webp'), 'categories/plumbing.webp');
    });

    test('9. Explicit customBaseUrl parameter overrides active base URL', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-active.r2.dev');

      final result = AppImageUrlResolver.resolve(
        'providers/uid_123/profile/173000.webp',
        customBaseUrl: 'https://img.custom-domain.com',
      );
      expect(result, 'https://img.custom-domain.com/providers/uid_123/profile/173000.webp');
    });

    test('10. RemoteConfigKeys defaults includes image_base_url with empty default', () {
      expect(RemoteConfigKeys.imageBaseUrl, 'image_base_url');
      expect(RemoteConfigKeys.defaults[RemoteConfigKeys.imageBaseUrl], '');
    });

    test('11. Resolves with AppEnvironmentConfig.defaultImageBaseUrl when override is null', () {
      AppImageUrlResolver.setOverrideBaseUrl(null);
      const testKey = 'providers/OXBV2Zink6TvWg5VefHPi53QkyV2/products/prod_1794063348925_72bbeafb.jpg';
      final resolved = AppImageUrlResolver.resolve(testKey);
      
      bool isStaging = false;
      try {
        isStaging = AppEnvironmentConfig.isStaging;
      } catch (_) {}

      // If built with APP_ENV=staging, it authoritatively prepends staging R2 public URL
      if (isStaging) {
        expect(
          resolved,
          'https://pub-7ffc4239e37248bd84da9d451086bfe6.r2.dev/providers/OXBV2Zink6TvWg5VefHPi53QkyV2/products/prod_1794063348925_72bbeafb.jpg',
        );
      } else {
        // Without APP_ENV define in generic tests, returns the relative key safely without error
        expect(resolved, testKey);
      }
    });
  });
}
