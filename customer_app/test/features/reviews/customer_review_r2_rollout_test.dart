import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/models/customer_app_settings.dart';
import 'package:apna_jamui_customer/core/services/r2_upload_service.dart';
import 'package:apna_jamui_customer/core/utils/app_image_url_resolver.dart';
import 'package:apna_jamui_customer/features/reviews/domain/entities/customer_review_entity.dart';

void main() {
  group('Customer Review R2 Rollout Preparation Unit Tests', () {
    const publicBaseUrl = 'https://pub-890d33c064214a2cb631bf960b479923.r2.dev';
    const customerId = 'test_cust_uid_456';
    const bookingId = 'lead_booking_789';

    setUp(() {
      AppImageUrlResolver.setOverrideBaseUrl(publicBaseUrl);
    });

    tearDown(() {
      AppImageUrlResolver.setOverrideBaseUrl(null);
    });

    test('1. R2 upload yields canonical relative objectKey for reviews folder', () {
      const canonicalKey = 'reviews/$customerId/$bookingId/rev_1730000000000_a1b2c3d4.jpg';
      const result = R2UploadResult(
        objectKey: canonicalKey,
        byteLength: 2048,
      );

      expect(result.objectKey, startsWith('reviews/$customerId/$bookingId/'));
      expect(result.objectKey, endsWith('.jpg'));
      expect(result.byteLength, equals(2048));
    });

    test('2. CustomerReviewEntity serializes strictly relative objectKeys in photoUrls', () {
      final review = CustomerReviewEntity(
        id: 'rev_doc_123',
        bookingId: bookingId,
        providerId: 'provider_999',
        providerName: 'Sunil Kumar',
        customerId: customerId,
        customerDisplayName: 'Amit S.',
        rating: 5,
        comment: 'उत्कृष्ट सेवा! समय पर काम पूरा हुआ।',
        tags: const ['समय के पाबंद', 'पेशेवर कार्य'],
        photoUrls: const [
          'reviews/test_cust_uid_456/lead_booking_789/rev_1.jpg',
          'reviews/test_cust_uid_456/lead_booking_789/rev_2.png',
        ],
        createdAt: DateTime.now(),
      );

      final map = review.toMap();
      final photoUrls = map['photoUrls'] as List;

      expect(photoUrls.length, equals(2));
      for (final url in photoUrls) {
        expect(url, isA<String>());
        expect((url as String).startsWith('http'), isFalse,
            reason: 'Firestore must store relative key, never absolute domain');
        expect(url.startsWith('reviews/$customerId/'), isTrue);
      }
    });

    test('3. AppImageUrlResolver resolves review relative objectKey with configured public base URL', () {
      const relativeKey = 'reviews/test_cust_uid_456/lead_booking_789/rev_1.jpg';
      final resolved = AppImageUrlResolver.resolve(relativeKey);

      expect(resolved, '$publicBaseUrl/$relativeKey');
      expect(resolved.contains('//reviews'), isFalse, reason: 'Duplicate slashes must be stripped');
    });

    test('4. AppImageUrlResolver preserves legacy Firebase Storage download URLs unchanged', () {
      const legacyStorageUrl =
          'https://firebasestorage.googleapis.com/v0/b/jamui-services.appspot.com/o/review_photos%2Fcust_1%2Fbooking_1%2Frev_old.jpg?alt=media&token=legacy-token';
      final resolved = AppImageUrlResolver.resolve(legacyStorageUrl);

      expect(resolved, legacyStorageUrl);
    });

    test('5. AppImageUrlResolver gracefully returns relative key when base URL is unconfigured', () {
      AppImageUrlResolver.setOverrideBaseUrl('');
      const relativeKey = 'reviews/test_cust_uid_456/lead_booking_789/rev_1.jpg';
      final resolved = AppImageUrlResolver.resolve(relativeKey);

      expect(resolved, relativeKey);
    });

    test('6. CustomerAppSettings parses imageBaseUrl from Firestore app_settings/customer_app', () {
      final docMap = {
        'imageBaseUrl': publicBaseUrl,
        'forceUpdateEnabled': true,
        'latestVersion': '1.2.5',
      };

      final settings = CustomerAppSettings.fromMap(docMap);
      expect(settings.imageBaseUrl, publicBaseUrl);
    });

    test('7. Empty bytes validation prevents unneeded network calls before R2 upload', () {
      final r2Service = R2UploadService();
      expect(
        () => r2Service.uploadBytes(
          bytes: Uint8List(0),
          folder: 'reviews',
          fileName: 'empty.jpg',
          mimeType: 'image/jpeg',
          targetId: bookingId,
        ),
        throwsA(isA<R2UploadException>()),
      );
    });
  });
}
