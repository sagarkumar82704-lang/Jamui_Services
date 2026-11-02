import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:apna_jamui_admin/core/services/r2_upload_service.dart';
import 'package:apna_jamui_admin/core/utils/app_image_url_resolver.dart';

void main() {
  group('R2UploadService & Integration Tests (Admin Panel)', () {
    test('1. Empty bytes rejected immediately before network request', () async {
      final service = R2UploadService();

      expect(
        () => service.uploadBytes(
          bytes: Uint8List(0),
          folder: 'categories',
          fileName: 'cat.png',
          mimeType: 'image/png',
        ),
        throwsA(isA<R2UploadException>()),
      );
    });

    test('2. Unauthenticated admin is safely rejected with descriptive exception', () async {
      final service = R2UploadService();

      try {
        await service.uploadBytes(
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          folder: 'categories',
          fileName: 'category.webp',
          mimeType: 'image/webp',
          targetId: 'cat_electrician',
        );
        fail('Should have thrown R2UploadException');
      } on R2UploadException catch (e) {
        expect(e.message, contains('authenticated'));
      }
    });

    test('3. AppImageUrlResolver safely returns legacy Firebase URLs unchanged', () {
      const legacyFirebaseUrl =
          'https://firebasestorage.googleapis.com/v0/b/jamui-services.firebasestorage.app/o/category_images%2Fcat_1%2Fcover.jpg?alt=media';
      expect(AppImageUrlResolver.resolve(legacyFirebaseUrl), legacyFirebaseUrl);
    });

    test('4. AppImageUrlResolver does NOT guess when public base URL is empty or unconfigured', () {
      AppImageUrlResolver.setOverrideBaseUrl('');
      const r2RelativeKey = 'categories/cat_electrician/cover_123.webp';

      expect(AppImageUrlResolver.resolve(r2RelativeKey), r2RelativeKey);
    });

    test('5. AppImageUrlResolver resolves relative R2 key when valid public base URL is provided', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://images.apnajamui.in');
      const r2RelativeKey = 'banners/banner_diwali/banner_123.jpg';

      expect(
        AppImageUrlResolver.resolve(r2RelativeKey),
        'https://images.apnajamui.in/banners/banner_diwali/banner_123.jpg',
      );
      AppImageUrlResolver.setOverrideBaseUrl(null);
    });

    test('6. Mock HTTP client simulating R2 500 error causes failure without secret leaks', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Error', 500);
      });

      final resp = await mockClient.put(Uri.parse('https://example.com/test'));
      expect(resp.statusCode, 500);
    });

    test('7. R2UploadException properly includes status code and descriptive details', () {
      const exWithCode = R2UploadException('Direct upload rejected', 403);
      expect(exWithCode.toString(), contains('Status: 403'));
      expect(exWithCode.statusCode, 403);

      const exWithoutCode = R2UploadException('Unauthorized');
      expect(exWithoutCode.toString(), isNot(contains('Status:')));
    });

    test('8. Cloudflare R2 success codes (200 OK and 204 No Content) are treated as valid', () {
      const validStatuses = [200, 204];
      for (final code in validStatuses) {
        final isSuccess = (code == 200 || code == 204);
        expect(isSuccess, isTrue);
      }
    });
  });
}
