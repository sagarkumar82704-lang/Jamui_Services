import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_admin/core/utils/app_image_url_resolver.dart';

void main() {
  setUp(() {
    AppImageUrlResolver.setOverrideBaseUrl(null);
    AppImageUrlResolver.setBaseUrl('');
  });

  tearDown(() {
    AppImageUrlResolver.setOverrideBaseUrl(null);
    AppImageUrlResolver.setBaseUrl('');
  });

  group('Admin Panel AppImageUrlResolver Unit Tests', () {
    test('1. Null, empty, and whitespace strings safely return empty string', () {
      expect(AppImageUrlResolver.resolve(null), '');
      expect(AppImageUrlResolver.resolve(''), '');
      expect(AppImageUrlResolver.resolve('   '), '');
      expect(AppImageUrlResolver.resolve('\t\n'), '');
    });

    test('2. Existing Firebase Storage download URLs are preserved 100% unchanged', () {
      const firebaseUrls = [
        'https://firebasestorage.googleapis.com/v0/b/jamui-services.firebasestorage.app/o/categories%2Fcleaning.jpg?alt=media&token=123-abc',
        'https://firebasestorage.googleapis.com/v0/b/jamui-services.appspot.com/o/sponsor_banners%2Fbanner1.webp?alt=media&token=xyz-789',
        'https://firebasestorage.googleapis.com/v0/b/jamui-services/o/profile_images%2Fadmin%2Favatar.jpg?alt=media',
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
      expect(AppImageUrlResolver.resolve('assets/icons/category_fallback.svg'), 'assets/icons/category_fallback.svg');
      expect(AppImageUrlResolver.resolve('blob:http://localhost:5000/123-blob-id'), 'blob:http://localhost:5000/123-blob-id');
    });

    test('6. Relative R2 object key resolves with configured base URL', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev');

      expect(
        AppImageUrlResolver.resolve('categories/cat_123/cover.webp'),
        'https://pub-test-dev.r2.dev/categories/cat_123/cover.webp',
      );
      expect(
        AppImageUrlResolver.resolve('sponsor_banners/banner_123/banner.jpg'),
        'https://pub-test-dev.r2.dev/sponsor_banners/banner_123/banner.jpg',
      );
      expect(
        AppImageUrlResolver.resolve('providers/uid_123/profile/173000.webp'),
        'https://pub-test-dev.r2.dev/providers/uid_123/profile/173000.webp',
      );
    });

    test('7. Slash handling normalizes leading and trailing slashes correctly', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev///');
      expect(
        AppImageUrlResolver.resolve('categories/cat_123/cover.webp'),
        'https://pub-test-dev.r2.dev/categories/cat_123/cover.webp',
      );

      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev');
      expect(
        AppImageUrlResolver.resolve('///categories/cat_123/cover.webp'),
        'https://pub-test-dev.r2.dev/categories/cat_123/cover.webp',
      );

      AppImageUrlResolver.setOverrideBaseUrl('https://pub-test-dev.r2.dev////');
      expect(
        AppImageUrlResolver.resolve('////categories/cat_123/cover.webp'),
        'https://pub-test-dev.r2.dev/categories/cat_123/cover.webp',
      );
    });

    test('8. When base URL is unconfigured or empty, relative key returns safely without mutation', () {
      AppImageUrlResolver.setOverrideBaseUrl('');
      expect(AppImageUrlResolver.resolve('categories/cat_123/cover.webp'), 'categories/cat_123/cover.webp');
      expect(AppImageUrlResolver.resolve('sponsor_banners/b1.jpg'), 'sponsor_banners/b1.jpg');
    });

    test('9. Explicit customBaseUrl parameter overrides active base URL', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://pub-active.r2.dev');

      final result = AppImageUrlResolver.resolve(
        'categories/cleaning.webp',
        customBaseUrl: 'https://img.custom-domain.com',
      );
      expect(result, 'https://img.custom-domain.com/categories/cleaning.webp');
    });

    test('10. setBaseUrl sets in-memory base URL and activeBaseUrl returns it', () {
      AppImageUrlResolver.setBaseUrl('https://pub-in-memory.r2.dev');
      expect(AppImageUrlResolver.activeBaseUrl, 'https://pub-in-memory.r2.dev');
      expect(
        AppImageUrlResolver.resolve('categories/electrical.webp'),
        'https://pub-in-memory.r2.dev/categories/electrical.webp',
      );
    });
  });
}
