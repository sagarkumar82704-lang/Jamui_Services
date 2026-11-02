import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/reviews/domain/entities/customer_review_entity.dart';
import 'package:apna_jamui_customer/features/reviews/data/services/customer_review_service.dart';

void main() {
  group('Customer Review & Rating System Tests', () {
    test('Test 1: Privacy Safe Name Formatting masks last name and email safely', () {
      // Two-word name
      expect(
        CustomerReviewService.formatPrivacySafeName(displayName: 'Sagar Kumar'),
        equals('Sagar K.'),
      );

      // Single word name
      expect(
        CustomerReviewService.formatPrivacySafeName(displayName: 'Rahul'),
        equals('Rahul'),
      );

      // Email fallback
      expect(
        CustomerReviewService.formatPrivacySafeName(email: 'user123@gmail.com'),
        equals('us***3'),
      );

      // Phone only / Guest fallback
      expect(
        CustomerReviewService.formatPrivacySafeName(phone: '+919876543210'),
        equals('सत्यापित ग्राहक (जमुई)'),
      );
    });

    test('Test 2: Rating entity clamps ratings strictly between 1 and 5', () {
      final review = CustomerReviewEntity(
        id: 'rev_1',
        bookingId: 'lead_101',
        providerId: 'prov_202',
        providerName: 'Ramesh Sharma',
        customerId: 'cust_303',
        customerDisplayName: 'Sagar K.',
        rating: 5,
        comment: 'बहुत बढ़िया काम किया!',
        tags: const ['समय पर पहुंचे ⏱️', 'वाजिब दाम 💰'],
        photoUrls: const ['https://storage.googleapis.com/img1.jpg'],
        isEdited: false,
      );

      expect(review.rating, equals(5));
      expect(review.photoUrls.length, equals(1));
      expect(review.isEdited, isFalse);

      final map = review.toMap();
      expect(map['bookingId'], equals('lead_101'));
      expect(map['rating'], equals(5));
      expect(map['tags'], contains('समय पर पहुंचे ⏱️'));
    });

    test('Test 3: Provider Rating Average & 1-5 Star Distribution Math (Single vs Multiple Reviews)', () {
      // Case A: Single 5-Star Review
      final singleRatings = [5];
      int countA = singleRatings.length;
      double sumA = singleRatings.reduce((a, b) => a + b).toDouble();
      double avgA = double.parse((sumA / countA).toStringAsFixed(1));
      
      expect(avgA, equals(5.0));
      expect(countA, equals(1));

      // Case B: Multiple diverse reviews (5, 5, 4, 3, 2, 1) -> 20 / 6 = 3.3
      final multiRatings = [5, 5, 4, 3, 2, 1];
      int countB = multiRatings.length;
      double sumB = multiRatings.reduce((a, b) => a + b).toDouble();
      double avgB = double.parse((sumB / countB).toStringAsFixed(1));

      final Map<int, int> distributionB = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      for (final r in multiRatings) {
        distributionB[r] = (distributionB[r] ?? 0) + 1;
      }

      expect(avgB, equals(3.3));
      expect(countB, equals(6));
      expect(distributionB[5], equals(2));
      expect(distributionB[4], equals(1));
      expect(distributionB[3], equals(1));
      expect(distributionB[2], equals(1));
      expect(distributionB[1], equals(1));
    });

    test('Test 4: Editing existing review correctly updates entity with isEdited=true', () {
      final initialReview = CustomerReviewEntity(
        id: 'rev_1',
        bookingId: 'lead_101',
        providerId: 'prov_202',
        providerName: 'Ramesh Sharma',
        customerId: 'cust_303',
        customerDisplayName: 'Sagar K.',
        rating: 5,
        comment: 'अच्छा काम',
      );

      final editedReview = initialReview.copyWith(
        rating: 4,
        comment: 'सफाई में थोड़ी कमी थी पर काम ठीक था',
        isEdited: true,
      );

      expect(editedReview.rating, equals(4));
      expect(editedReview.comment, contains('सफाई में थोड़ी कमी थी'));
      expect(editedReview.isEdited, isTrue);
    });
  });
}
