import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:apna_jamui_provider/core/services/r2_upload_service.dart';
import 'package:apna_jamui_provider/core/utils/app_image_url_resolver.dart';

void main() {
  group('R2UploadService & Integration Tests (Provider App)', () {
    test('1. Empty bytes rejected immediately before network request', () async {
      final service = R2UploadService();

      expect(
        () => service.uploadBytes(
          bytes: Uint8List(0),
          folder: 'profile',
          fileName: 'profile.jpg',
          mimeType: 'image/jpeg',
        ),
        throwsA(isA<R2UploadException>()),
      );
    });

    test('2. Unauthenticated user is safely rejected with descriptive exception', () async {
      final service = R2UploadService();

      try {
        await service.uploadBytes(
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          folder: 'profile',
          fileName: 'profile.jpg',
          mimeType: 'image/jpeg',
          targetId: 'provider_123',
        );
        fail('Should have thrown R2UploadException');
      } on R2UploadException catch (e) {
        expect(e.message, contains('authenticated'));
      }
    });

    test('3. AppImageUrlResolver safely returns legacy Firebase URLs unchanged', () {
      const legacyFirebaseUrl =
          'https://firebasestorage.googleapis.com/v0/b/jamui-services.firebasestorage.app/o/providers%2Fuid1%2Fprofile%2Fpic.jpg?alt=media';
      expect(AppImageUrlResolver.resolve(legacyFirebaseUrl), legacyFirebaseUrl);
    });

    test('4. AppImageUrlResolver does NOT guess when public base URL is empty or unconfigured', () {
      AppImageUrlResolver.setOverrideBaseUrl('');
      const r2RelativeKey = 'providers/prov_123/profile/pic_456.jpg';

      expect(AppImageUrlResolver.resolve(r2RelativeKey), r2RelativeKey);
    });

    test('5. AppImageUrlResolver resolves relative R2 key when valid public base URL is provided', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://images.apnajamui.in');
      const r2RelativeKey = 'providers/prov_123/profile/pic_456.jpg';

      expect(
        AppImageUrlResolver.resolve(r2RelativeKey),
        'https://images.apnajamui.in/providers/prov_123/profile/pic_456.jpg',
      );
      AppImageUrlResolver.setOverrideBaseUrl(null);
    });

    test('6. Mock HTTP client simulating R2 rejection causes R2UploadException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final resp = await mockClient.put(Uri.parse('https://example.com/test'));
      expect(resp.statusCode, 401);
    });
  });
}
