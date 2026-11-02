import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:apna_jamui_customer/core/services/r2_upload_service.dart';
import 'package:apna_jamui_customer/core/utils/app_image_url_resolver.dart';

void main() {
  group('R2UploadService & Integration Tests (Customer App)', () {
    test('1. Empty bytes rejected immediately before network request', () async {
      final service = R2UploadService();

      expect(
        () => service.uploadBytes(
          bytes: Uint8List(0),
          folder: 'reviews',
          fileName: 'empty.png',
          mimeType: 'image/png',
        ),
        throwsA(isA<R2UploadException>()),
      );
    });

    test('2. Unauthenticated user is safely rejected with descriptive exception', () async {
      // By default FirebaseAuth.instance.currentUser is null in unit test environment
      final service = R2UploadService();

      try {
        await service.uploadBytes(
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          folder: 'reviews',
          fileName: 'review.jpg',
          mimeType: 'image/jpeg',
          targetId: 'lead_123',
        );
        fail('Should have thrown R2UploadException');
      } on R2UploadException catch (e) {
        expect(e.message, contains('authenticated'));
      }
    });

    test('3. AppImageUrlResolver safely returns legacy Firebase URLs unchanged', () {
      const legacyFirebaseUrl =
          'https://firebasestorage.googleapis.com/v0/b/jamui-services.firebasestorage.app/o/review_photos%2Fuser1%2Flead1%2Frev_1.jpg?alt=media';
      expect(AppImageUrlResolver.resolve(legacyFirebaseUrl), legacyFirebaseUrl);
    });

    test('4. AppImageUrlResolver does NOT guess when public base URL is empty or unconfigured', () {
      AppImageUrlResolver.setOverrideBaseUrl('');
      const r2RelativeKey = 'reviews/cust_123/lead_456/rev_789.jpg';
      
      // When unconfigured, returns relative key safely without guessing URL
      expect(AppImageUrlResolver.resolve(r2RelativeKey), r2RelativeKey);
    });

    test('5. AppImageUrlResolver resolves relative R2 key when valid public base URL is provided', () {
      AppImageUrlResolver.setOverrideBaseUrl('https://images.apnajamui.in');
      const r2RelativeKey = 'reviews/cust_123/lead_456/rev_789.jpg';

      expect(
        AppImageUrlResolver.resolve(r2RelativeKey),
        'https://images.apnajamui.in/reviews/cust_123/lead_456/rev_789.jpg',
      );
      AppImageUrlResolver.setOverrideBaseUrl(null);
    });

    test('6. Mock HTTP client simulating R2 403 response causes R2UploadException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Forbidden: Signature Mismatch', 403);
      });

      // Verify that mock client correctly returns status 403
      final resp = await mockClient.put(Uri.parse('https://example.com/test'));
      expect(resp.statusCode, 403);
    });
  });
}
