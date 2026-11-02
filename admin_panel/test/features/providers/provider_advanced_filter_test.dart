import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_admin/features/providers/data/models/provider_filter_criteria.dart';

void main() {
  group('ProviderFilterEvaluator Unit Tests', () {
    final now = DateTime(2026, 10, 27, 12, 0, 0);

    // Sample Mock Providers
    final mockApprovedElectrician = {
      'id': 'prov_001',
      'fullName': 'Rajesh Sharma',
      'businessName': 'Sharma Electricals & Repair',
      'phoneNumber': '+91 98765 43210',
      'email': 'rajesh.electric@jamui.com',
      'primaryCategoryId': 'electrician',
      'primaryCategoryTitle': 'इलेक्ट्रीशियन',
      'selectedCategoryIds': ['electrician', 'appliance_repair'],
      'jamuiArea': 'झाझा (Jhajha)',
      'fullAddress': 'Station Road, Jhajha, Jamui, Bihar 811308',
      'latitude': 24.7735,
      'longitude': 86.3820,
      'status': 'approved',
      'verificationStatus': 'approved',
      'kycStatus': 'approved',
      'isVerified': true,
      'isActive': true,
      'isDeleted': false,
      'isSubscriptionActive': true,
      'subscriptionPlan': 'PRO_ANNUAL',
      'subscriptionExpiry': now.add(const Duration(days: 90)),
      'paymentVerified': true,
      'createdAt': now.subtract(const Duration(days: 5)),
    };

    final mockPendingPlumber = {
      'id': 'prov_002',
      'fullName': 'Manoj Kumar',
      'businessName': 'Manoj Plumbing Works',
      'phoneNumber': '09812345678',
      'email': 'manoj@apnajamui.in',
      'primaryCategoryId': 'plumber',
      'primaryCategoryTitle': 'प्लम्बर',
      'selectedCategoryIds': ['plumber'],
      'jamuiArea': 'जमुई मुख्य बाजार',
      'fullAddress': 'Main Market, Jamui 811307',
      'latitude': 24.9197,
      'longitude': 86.2238,
      'status': 'pendingReview',
      'verificationStatus': 'pending',
      'kycStatus': 'pendingReview',
      'isVerified': false,
      'isActive': true,
      'isDeleted': false,
      'isSubscriptionActive': false,
      'subscriptionPlan': 'free_trial',
      'paymentVerified': false,
      'createdAt': now.subtract(const Duration(hours: 4)), // Today
    };

    final mockRejectedCarpenter = {
      'id': 'prov_003',
      'fullName': 'Suresh Mistri',
      'businessName': 'Suresh Furniture House',
      'phoneNumber': '9123456780',
      'email': 'suresh@carpenter.com',
      'primaryCategoryId': 'carpenter',
      'primaryCategoryTitle': 'बढ़ई / कारपेंटर',
      'selectedCategoryIds': ['carpenter'],
      'jamuiArea': 'सोनो (Sono)',
      'fullAddress': 'Sono Bazar, Jamui',
      'latitude': 24.7410,
      'longitude': 86.4120,
      'status': 'rejected',
      'verificationStatus': 'rejected',
      'kycStatus': 'rejected',
      'isVerified': false,
      'isActive': true,
      'isDeleted': false,
      'isSubscriptionActive': false,
      'subscriptionPlan': 'free_trial',
      'paymentVerified': false,
      'createdAt': now.subtract(const Duration(days: 15)),
    };

    final mockSuspendedPainter = {
      'id': 'prov_004',
      'fullName': 'Amit Verma',
      'businessName': 'Verma Painting Services',
      'phoneNumber': '+919988776655',
      'email': 'amit.paints@gmail.com',
      'primaryCategoryId': 'painter',
      'primaryCategoryTitle': 'पेंटर',
      'selectedCategoryIds': ['painter'],
      'jamuiArea': 'खैरा (Khaira)',
      'fullAddress': 'Khaira More, Jamui',
      'latitude': 24.8510,
      'longitude': 86.1950,
      'status': 'suspended',
      'verificationStatus': 'approved',
      'kycStatus': 'approved',
      'isVerified': true,
      'isActive': true,
      'isDeleted': false,
      'isSubscriptionActive': false,
      'subscriptionPlan': 'BASIC_MONTHLY',
      'subscriptionExpiry': now.subtract(const Duration(days: 10)), // Expired
      'paymentVerified': true,
      'createdAt': now.subtract(const Duration(days: 45)),
    };

    final mockInactiveProvider = {
      'id': 'prov_005',
      'fullName': 'Deepak Singh',
      'businessName': 'Deepak Appliance Repair',
      'phoneNumber': '9876500000',
      'email': 'deepak@repair.com',
      'primaryCategoryId': 'appliance_repair',
      'primaryCategoryTitle': 'होम अप्लायंसेज रिपेयर',
      'selectedCategoryIds': ['appliance_repair'],
      'jamuiArea': 'सिकंदरा (Sikandra)',
      'fullAddress': 'Sikandra Chowk, Jamui',
      'latitude': 24.9600,
      'longitude': 86.0100,
      'status': 'approved',
      'verificationStatus': 'approved',
      'kycStatus': 'approved',
      'isVerified': true,
      'isActive': false, // Inactive
      'isDeleted': false,
      'isSubscriptionActive': true,
      'subscriptionPlan': 'PRO_ANNUAL',
      'subscriptionExpiry': now.add(const Duration(days: 30)),
      'paymentVerified': true,
      'createdAt': now.subtract(const Duration(days: 20)),
    };

    final mockDeletedProvider = {
      'id': 'prov_006',
      'fullName': 'Old Deleted Provider',
      'businessName': 'Deleted Business',
      'phoneNumber': '9999988888',
      'email': 'deleted@jamui.com',
      'primaryCategoryId': 'electrician',
      'primaryCategoryTitle': 'इलेक्ट्रीशियन',
      'jamuiArea': 'जमुई मुख्य बाजार',
      'status': 'approved',
      'isVerified': true,
      'isActive': false,
      'isDeleted': true, // Soft Deleted
      'createdAt': now.subtract(const Duration(days: 60)),
    };

    final allMockProviders = [
      mockApprovedElectrician,
      mockPendingPlumber,
      mockRejectedCarpenter,
      mockSuspendedPainter,
      mockInactiveProvider,
      mockDeletedProvider,
    ];

    test('1. Status Filter: Evaluates all required status types correctly', () {
      // All Providers (non-deleted)
      final allNonDeleted = allMockProviders.where((p) => ProviderFilterEvaluator.matchesStatus(p, 'all')).toList();
      expect(allNonDeleted.length, 5);
      expect(allNonDeleted.any((p) => p['id'] == 'prov_006'), isFalse);

      // All with Deleted
      final allWithDeleted = allMockProviders.where((p) => ProviderFilterEvaluator.matchesStatus(p, 'all_with_deleted')).toList();
      expect(allWithDeleted.length, 6);

      // Pending Approval
      final pending = allMockProviders.where((p) => ProviderFilterEvaluator.matchesStatus(p, 'pending_approval')).toList();
      expect(pending.length, 1);
      expect(pending.first['id'], 'prov_002');

      // Approved / Active
      final approvedActive = allMockProviders.where((p) => ProviderFilterEvaluator.matchesStatus(p, 'approved_active')).toList();
      expect(approvedActive.length, 1);
      expect(approvedActive.first['id'], 'prov_001');

      // Rejected
      final rejected = allMockProviders.where((p) => ProviderFilterEvaluator.matchesStatus(p, 'rejected')).toList();
      expect(rejected.length, 1);
      expect(rejected.first['id'], 'prov_003');

      // Suspended / Blocked
      final suspended = allMockProviders.where((p) => ProviderFilterEvaluator.matchesStatus(p, 'suspended_blocked')).toList();
      expect(suspended.length, 1);
      expect(suspended.first['id'], 'prov_004');

      // Inactive
      final inactive = allMockProviders.where((p) => ProviderFilterEvaluator.matchesStatus(p, 'inactive')).toList();
      expect(inactive.length, 1);
      expect(inactive.first['id'], 'prov_005');

      // Deleted
      final deleted = allMockProviders.where((p) => ProviderFilterEvaluator.matchesStatus(p, 'deleted')).toList();
      expect(deleted.length, 1);
      expect(deleted.first['id'], 'prov_006');
    });

    test('2. Category Filter: Matches primary category, selected categories list, and inactive categories', () {
      // Primary category match
      final plumbers = allMockProviders.where((p) => ProviderFilterEvaluator.matchesCategory(p, 'plumber')).toList();
      expect(plumbers.length, 1);
      expect(plumbers.first['id'], 'prov_002');

      // Multi-category match (appliance_repair is in selectedCategoryIds of prov_001 and primary of prov_005)
      final appliance = allMockProviders.where((p) => ProviderFilterEvaluator.matchesCategory(p, 'appliance_repair')).toList();
      expect(appliance.length, 2);
      expect(appliance.map((p) => p['id']).toSet(), {'prov_001', 'prov_005'});

      // Inactive category matching by title fallback
      final carpenterMatch = allMockProviders.where((p) => ProviderFilterEvaluator.matchesCategory(p, 'old_inactive_carpenter_id', categoryTitle: 'बढ़ई / कारपेंटर')).toList();
      expect(carpenterMatch.length, 1);
      expect(carpenterMatch.first['id'], 'prov_003');

      // All categories returns true
      expect(ProviderFilterEvaluator.matchesCategory(mockApprovedElectrician, 'all'), isTrue);
    });

    test('3. Search Filter: Matches name, business, phone with and without spaces/country-code, email, and ID', () {
      // Provider Name
      expect(ProviderFilterEvaluator.matchesSearch(mockApprovedElectrician, 'rajesh'), isTrue);
      expect(ProviderFilterEvaluator.matchesSearch(mockApprovedElectrician, 'SHARMA'), isTrue);

      // Business Name
      expect(ProviderFilterEvaluator.matchesSearch(mockApprovedElectrician, 'Electricals'), isTrue);
      expect(ProviderFilterEvaluator.matchesSearch(mockPendingPlumber, 'Plumbing'), isTrue);

      // Provider ID
      expect(ProviderFilterEvaluator.matchesSearch(mockApprovedElectrician, 'prov_001'), isTrue);

      // Email
      expect(ProviderFilterEvaluator.matchesSearch(mockApprovedElectrician, 'rajesh.electric'), isTrue);
      expect(ProviderFilterEvaluator.matchesSearch(mockPendingPlumber, 'apnajamui.in'), isTrue);

      // Phone Number: Unformatted search against formatted provider (+91 98765 43210)
      expect(ProviderFilterEvaluator.matchesSearch(mockApprovedElectrician, '9876543210'), isTrue);
      expect(ProviderFilterEvaluator.matchesSearch(mockApprovedElectrician, '+919876543210'), isTrue);
      expect(ProviderFilterEvaluator.matchesSearch(mockApprovedElectrician, '98765 43210'), isTrue);
      expect(ProviderFilterEvaluator.matchesSearch(mockApprovedElectrician, '98765'), isTrue);

      // Phone Number: Formatted search against unformatted provider (09812345678)
      expect(ProviderFilterEvaluator.matchesSearch(mockPendingPlumber, '9812345678'), isTrue);
      expect(ProviderFilterEvaluator.matchesSearch(mockPendingPlumber, '+91 98123-45678'), isTrue);

      // Non-matching query
      expect(ProviderFilterEvaluator.matchesSearch(mockApprovedElectrician, 'xyz123nonexistent'), isFalse);
    });

    test('4. Location Filter: Matches Jamui areas and GPS coordinates radius', () {
      // Jamui Area match
      expect(ProviderFilterEvaluator.matchesLocation(mockApprovedElectrician, area: 'झाझा (Jhajha)'), isTrue);
      expect(ProviderFilterEvaluator.matchesLocation(mockApprovedElectrician, area: 'Jhajha'), isTrue);
      expect(ProviderFilterEvaluator.matchesLocation(mockPendingPlumber, area: 'जमुई मुख्य बाजार'), isTrue);
      expect(ProviderFilterEvaluator.matchesLocation(mockPendingPlumber, area: 'खैरा (Khaira)'), isFalse);

      // Coordinates Radius match from Jamui Center (24.9197, 86.2238)
      // prov_002 is at Jamui Center (0 KM distance)
      expect(ProviderFilterEvaluator.matchesLocation(mockPendingPlumber, area: 'all', radiusKm: 5.0), isTrue);

      // prov_001 is in Jhajha (~22 KM from Jamui Center)
      expect(ProviderFilterEvaluator.matchesLocation(mockApprovedElectrician, area: 'all', radiusKm: 10.0), isFalse);
      expect(ProviderFilterEvaluator.matchesLocation(mockApprovedElectrician, area: 'all', radiusKm: 30.0), isTrue);

      // Provider without coordinates is safely rejected from radius filter
      final providerWithoutGps = {'jamuiArea': 'Jamui', 'latitude': 0.0, 'longitude': 0.0};
      expect(ProviderFilterEvaluator.matchesLocation(providerWithoutGps, area: 'all', radiusKm: 10.0), isFalse);
    });

    test('5. Date Filter: Evaluates Today, Last 7 Days, Last 30 Days, and Custom Range', () {
      // Today (prov_002 was created 4 hours ago)
      expect(ProviderFilterEvaluator.matchesDate(mockPendingPlumber, 'today', referenceNow: now), isTrue);
      expect(ProviderFilterEvaluator.matchesDate(mockApprovedElectrician, 'today', referenceNow: now), isFalse); // 5 days ago

      // Last 7 Days (prov_001 [5 days] and prov_002 [4 hours])
      expect(ProviderFilterEvaluator.matchesDate(mockApprovedElectrician, 'last_7_days', referenceNow: now), isTrue);
      expect(ProviderFilterEvaluator.matchesDate(mockRejectedCarpenter, 'last_7_days', referenceNow: now), isFalse); // 15 days ago

      // Last 30 Days (prov_001, prov_002, prov_003 [15 days], prov_005 [20 days])
      expect(ProviderFilterEvaluator.matchesDate(mockRejectedCarpenter, 'last_30_days', referenceNow: now), isTrue);
      expect(ProviderFilterEvaluator.matchesDate(mockSuspendedPainter, 'last_30_days', referenceNow: now), isFalse); // 45 days ago

      // Custom Date Range (10 days ago to 1 day ago)
      final customRange = DateTimeRange(
        start: now.subtract(const Duration(days: 10)),
        end: now.subtract(const Duration(days: 1)),
      );
      expect(ProviderFilterEvaluator.matchesDate(mockApprovedElectrician, 'custom', customRange: customRange, referenceNow: now), isTrue);
      expect(ProviderFilterEvaluator.matchesDate(mockPendingPlumber, 'custom', customRange: customRange, referenceNow: now), isFalse); // today (outside range)
    });

    test('6. Subscription Filter: Evaluates Active, Expired, Trial, and No Subscription', () {
      // Active Subscription
      expect(ProviderFilterEvaluator.matchesSubscription(mockApprovedElectrician, 'active', referenceNow: now), isTrue);
      expect(ProviderFilterEvaluator.matchesSubscription(mockSuspendedPainter, 'active', referenceNow: now), isFalse); // expired

      // Expired Subscription
      expect(ProviderFilterEvaluator.matchesSubscription(mockSuspendedPainter, 'expired', referenceNow: now), isTrue);
      expect(ProviderFilterEvaluator.matchesSubscription(mockApprovedElectrician, 'expired', referenceNow: now), isFalse);

      // Trial
      expect(ProviderFilterEvaluator.matchesSubscription(mockPendingPlumber, 'trial', referenceNow: now), isTrue);
      expect(ProviderFilterEvaluator.matchesSubscription(mockApprovedElectrician, 'trial', referenceNow: now), isFalse);

      // No Subscription (unpaid, not on trial)
      final unpaidNoTrial = {
        'paymentVerified': false,
        'isSubscriptionActive': false,
        'subscriptionPlan': 'none',
      };
      expect(ProviderFilterEvaluator.matchesSubscription(unpaidNoTrial, 'no_subscription', referenceNow: now), isTrue);
    });

    test('7. Combined Multi-Filtering: Combines Status + Category + Area + Subscription + Search seamlessly', () {
      final criteria = ProviderFilterCriteria(
        status: 'approved_active',
        categoryId: 'electrician',
        jamuiArea: 'झाझा (Jhajha)',
        subscriptionFilter: 'active',
        searchQuery: '9876543210',
      );

      final matches = allMockProviders.where((p) => ProviderFilterEvaluator.matches(p, criteria, referenceNow: now)).toList();
      expect(matches.length, 1);
      expect(matches.first['id'], 'prov_001');

      // If we change area to Jamui Main Market, prov_001 is filtered out
      final noMatches = allMockProviders.where((p) => ProviderFilterEvaluator.matches(p, criteria.copyWith(jamuiArea: 'जमुई मुख्य बाजार'), referenceNow: now)).toList();
      expect(noMatches, isEmpty);
    });

    test('8. ProviderFilterCriteria: hasActiveFilters and activeFiltersCount are accurate', () {
      const initial = ProviderFilterCriteria.initial;
      expect(initial.hasActiveFilters, isFalse);
      expect(initial.activeFiltersCount, 0);

      final withFilters = initial.copyWith(
        status: 'pending_approval',
        categoryId: 'plumber',
        searchQuery: 'Manoj',
      );
      expect(withFilters.hasActiveFilters, isTrue);
      expect(withFilters.activeFiltersCount, 3);
    });
  });
}
