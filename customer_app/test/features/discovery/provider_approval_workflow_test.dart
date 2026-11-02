import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_provider_entity.dart';
import 'package:apna_jamui_customer/features/discovery/data/models/service_provider_model.dart';

void main() {
  group('Provider Approval & Visibility Workflow Tests', () {
    test('TEST 1 & 7: Provider with pendingReview or missing status is NOT isApprovedAndLive', () {
      const pendingProvider = ServiceProviderEntity(
        id: 'prov_pending_1',
        fullName: 'Pending Provider',
        businessName: 'New Services',
        phoneNumber: '+919999999999',
        categoryId: 'cat_1',
        categoryTitle: 'Electrician',
        visitingCharge: 100.0,
        experienceYears: 2,
        status: 'pendingReview',
        kycStatus: 'pendingReview',
        isVerified: false,
        isAvailable: true,
      );

      expect(pendingProvider.isApprovedAndLive, isFalse);
    });

    test('TEST 2 & 10: Provider tampering with isVerified=true but status=pendingReview is NOT approved', () {
      final tamperedMap = {
        'fullName': 'Hacker Provider',
        'businessName': 'Unapproved Shop',
        'phoneNumber': '+918888888888',
        'categoryId': 'cat_plumber',
        'categoryTitle': 'Plumber',
        'isVerified': true, // Trying to bypass
        'status': 'pendingReview',
        'kycStatus': 'pendingReview',
        'isAvailable': true,
      };

      final model = ServiceProviderModel.fromMap(tamperedMap, 'prov_tampered');
      expect(model.isVerified, isFalse, reason: 'fromMap must guard against status != approved');
      expect(model.isApprovedAndLive, isFalse);
    });

    test('TEST 4 & 8: Approved provider with valid status, kycStatus, verified payment, unexpired subscription and isAvailable=true is LIVE', () {
      final approvedProvider = ServiceProviderEntity(
        id: 'prov_approved_1',
        fullName: 'Ramesh Electrician',
        businessName: 'Ramesh Electricals',
        phoneNumber: '+919876543210',
        categoryId: 'cat_1',
        categoryTitle: 'Electrician',
        visitingCharge: 150.0,
        experienceYears: 5,
        status: 'approved',
        kycStatus: 'approved',
        isVerified: true,
        isAvailable: true,
        paymentVerified: true,
        isSubscriptionActive: true,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(approvedProvider.isApprovedAndLive, isTrue);
    });

    test('TEST 5: Rejected provider is NOT LIVE', () {
      const rejectedProvider = ServiceProviderEntity(
        id: 'prov_rejected_1',
        fullName: 'Rejected Provider',
        businessName: 'Fake Shop',
        phoneNumber: '+919111111111',
        categoryId: 'cat_1',
        categoryTitle: 'Electrician',
        visitingCharge: 100.0,
        experienceYears: 1,
        status: 'rejected',
        kycStatus: 'rejected',
        isVerified: false,
        isAvailable: true,
      );

      expect(rejectedProvider.isApprovedAndLive, isFalse);
    });

    test('TEST 6: Suspended or Unavailable provider is NOT LIVE', () {
      const suspendedProvider = ServiceProviderEntity(
        id: 'prov_suspended_1',
        fullName: 'Suspended Provider',
        businessName: 'Suspended Shop',
        phoneNumber: '+919222222222',
        categoryId: 'cat_1',
        categoryTitle: 'Electrician',
        visitingCharge: 100.0,
        experienceYears: 1,
        status: 'suspended',
        kycStatus: 'approved',
        isVerified: true,
        isAvailable: true,
      );

      const unavailableProvider = ServiceProviderEntity(
        id: 'prov_blocked_1',
        fullName: 'Blocked Provider',
        businessName: 'Blocked Shop',
        phoneNumber: '+919333333333',
        categoryId: 'cat_1',
        categoryTitle: 'Electrician',
        visitingCharge: 100.0,
        experienceYears: 1,
        status: 'approved',
        kycStatus: 'approved',
        isVerified: true,
        isAvailable: false, // Inactive / unavailable
      );

      expect(suspendedProvider.isApprovedAndLive, isFalse);
      expect(unavailableProvider.isApprovedAndLive, isFalse);
    });

    test('TEST 6B: Approved provider with UNPAID or INACTIVE subscription is NOT LIVE', () {
      final unpaidProvider = ServiceProviderEntity(
        id: 'prov_unpaid_1',
        fullName: 'Unpaid Provider',
        businessName: 'Unpaid Shop',
        phoneNumber: '+919444444444',
        categoryId: 'cat_1',
        categoryTitle: 'Electrician',
        visitingCharge: 100.0,
        experienceYears: 2,
        status: 'approved',
        kycStatus: 'approved',
        isVerified: true,
        isAvailable: true,
        paymentVerified: false,
        isSubscriptionActive: false,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      final inactiveSubProvider = ServiceProviderEntity(
        id: 'prov_inactive_sub_1',
        fullName: 'Inactive Sub Provider',
        businessName: 'Inactive Sub Shop',
        phoneNumber: '+919555555555',
        categoryId: 'cat_1',
        categoryTitle: 'Electrician',
        visitingCharge: 100.0,
        experienceYears: 2,
        status: 'approved',
        kycStatus: 'approved',
        isVerified: true,
        isAvailable: true,
        paymentVerified: true,
        isSubscriptionActive: false, // Inactive
        subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(unpaidProvider.isApprovedAndLive, isFalse);
      expect(inactiveSubProvider.isApprovedAndLive, isFalse);
    });

    test('TEST 6C: Approved provider with EXPIRED subscription is NOT LIVE', () {
      final expiredProvider = ServiceProviderEntity(
        id: 'prov_expired_1',
        fullName: 'Expired Provider',
        businessName: 'Expired Shop',
        phoneNumber: '+919666666666',
        categoryId: 'cat_1',
        categoryTitle: 'Electrician',
        visitingCharge: 100.0,
        experienceYears: 2,
        status: 'approved',
        kycStatus: 'approved',
        isVerified: true,
        isAvailable: true,
        paymentVerified: true,
        isSubscriptionActive: true,
        subscriptionExpiry: DateTime.now().subtract(const Duration(hours: 1)), // Expired 1 hr ago
      );

      expect(expiredProvider.isApprovedAndLive, isFalse);
    });

    test('TEST 9: Filtering mixed provider list keeps ONLY approved and active providers', () {
      final list = [
        const ServiceProviderEntity(
          id: '1',
          fullName: 'P1 Pending',
          businessName: 'B1',
          phoneNumber: '1',
          categoryId: 'c1',
          categoryTitle: 'T1',
          visitingCharge: 100,
          experienceYears: 1,
          status: 'pendingReview',
        ),
        ServiceProviderEntity(
          id: '2',
          fullName: 'P2 Approved',
          businessName: 'B2',
          phoneNumber: '2',
          categoryId: 'c2',
          categoryTitle: 'T2',
          visitingCharge: 100,
          experienceYears: 1,
          status: 'approved',
          kycStatus: 'approved',
          isVerified: true,
          isAvailable: true,
          paymentVerified: true,
          isSubscriptionActive: true,
          subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
        ),
        const ServiceProviderEntity(
          id: '3',
          fullName: 'P3 Rejected',
          businessName: 'B3',
          phoneNumber: '3',
          categoryId: 'c3',
          categoryTitle: 'T3',
          visitingCharge: 100,
          experienceYears: 1,
          status: 'rejected',
        ),
        const ServiceProviderEntity(
          id: '4',
          fullName: 'P4 Draft',
          businessName: 'B4',
          phoneNumber: '4',
          categoryId: 'c4',
          categoryTitle: 'T4',
          visitingCharge: 100,
          experienceYears: 1,
          status: 'draft',
        ),
        ServiceProviderEntity(
          id: '5',
          fullName: 'P5 Approved but Expired',
          businessName: 'B5',
          phoneNumber: '5',
          categoryId: 'c5',
          categoryTitle: 'T5',
          visitingCharge: 100,
          experienceYears: 1,
          status: 'approved',
          kycStatus: 'approved',
          isVerified: true,
          isAvailable: true,
          paymentVerified: true,
          isSubscriptionActive: true,
          subscriptionExpiry: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

      final liveProviders = list.where((p) => p.isApprovedAndLive).toList();
      expect(liveProviders.length, equals(1));
      expect(liveProviders.first.id, equals('2'));
    });
  });
}
