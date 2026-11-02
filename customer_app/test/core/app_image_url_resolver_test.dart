import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/models/customer_app_settings.dart';
import 'package:apna_jamui_customer/core/utils/app_image_url_resolver.dart';

void main() {
  setUp(() {
    AppImageUrlResolver.setOverrideBaseUrl(null);
  });

  tearDown(() {
    AppImageUrlResolver.setOverrideBaseUrl(null);
  });

  group('AppImageUrlResolver Unit Tests', () {
    test('1. Null, empty, and whitespace strings safely return empty string', () {
      expect(AppImageUrlResolver.resolve(null), '');
      expect(AppImageUrlResolver.resolve(''), '');
      expect(AppImageUrlResolver.resolve('   '), '');
      expect(AppImageUrlResolver.resolve('\t\n'), '');
    });

    test('2. Existing Firebase Storage download URLs are preserved 100% unchanged', () {
      const firebaseUrls = [
        'https://firebasestorage.googleapis.com/v0/b/jamui-services.firebasestorage.app/o/categories%2Felectrician.jpg?alt=media&token=123-abc',
        'https://firebasestorage.googleapis.com/v0/b/jamui-services.appspot.com/o/banners%2Fpromo.webp?alt=media&token=xyz-789',
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
      expect(AppImageUrlResolver.resolve('assets/icons/service_placeholder.svg'), 'assets/icons/service_placeholder.svg');
      expect(AppImageUrlResolver.resolve('blob:http://localhost:5000/123-blob-id'), 'blob:http://localhost:5000/123-blob-id');
    });

    test('6. Relative R2 object key resolves with configured base URL', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev');

      expect(
        AppImageUrlResolver.resolve('categories/electrician.webp'),
        'https://pub-test-dev.r2.dev/categories/electrician.webp',
      );
      expect(
        AppImageUrlResolver.resolve('banners/diwali_special.jpg'),
        'https://pub-test-dev.r2.dev/banners/diwali_special.jpg',
      );
      expect(
        AppImageUrlResolver.resolve('providers/prov_123/profile/173000.webp'),
        'https://pub-test-dev.r2.dev/providers/prov_123/profile/173000.webp',
      );
    });

    test('7. Slash handling normalizes leading and trailing slashes correctly', () {
      // Trailing slashes on base URL
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev///');
      expect(
        AppImageUrlResolver.resolve('categories/electrician.webp'),
        'https://pub-test-dev.r2.dev/categories/electrician.webp',
      );

      // Leading slashes on object key
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev');
      expect(
        AppImageUrlResolver.resolve('///categories/electrician.webp'),
        'https://pub-test-dev.r2.dev/categories/electrician.webp',
      );

      // Both base and key have excessive slashes
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev////');
      expect(
        AppImageUrlResolver.resolve('////sponsor_banners/banner_1.jpg'),
        'https://pub-test-dev.r2.dev/sponsor_banners/banner_1.jpg',
      );
    });

    test('8. When base URL is unconfigured or empty, relative key returns safely without mutation', () {
      AppImageUrlResolver.setOverrideBaseUrl('');
      expect(AppImageUrlResolver.resolve('categories/electrician.webp'), 'categories/electrician.webp');
      expect(AppImageUrlResolver.resolve('banners/hero.jpg'), 'banners/hero.jpg');
    });

    test('9. Explicit customBaseUrl parameter overrides active base URL', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-active.r2.dev');

      final result = AppImageUrlResolver.resolve(
        'categories/plumbing.webp',
        customBaseUrl: 'https://img.custom-domain.com',
      );
      expect(result, 'https://img.custom-domain.com/categories/plumbing.webp');
    });

    test('10. CustomerAppSettings parses imageBaseUrl and image_base_url correctly', () {
      final mapCamel = {'imageBaseUrl': 'https://pub-cdn.r2.dev'};
      final settingsCamel = CustomerAppSettings.fromMap(mapCamel);
      expect(settingsCamel.imageBaseUrl, 'https://pub-cdn.r2.dev');

      final mapSnake = {'image_base_url': 'https://img.apnajamui.com'};
      final settingsSnake = CustomerAppSettings.fromMap(mapSnake);
      expect(settingsSnake.imageBaseUrl, 'https://img.apnajamui.com');

      final mapEmpty = <String, dynamic>{};
      final settingsEmpty = CustomerAppSettings.fromMap(mapEmpty);
      expect(settingsEmpty.imageBaseUrl, '');
    });
  });
}
