import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/discovery/data/models/service_provider_model.dart';

void main() {
  group('Premium Provider Eligibility & Regression Verification Suite', () {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final yesterday = now.subtract(const Duration(days: 1));

    // Test 1: Srusu Unisex with eligible Premium subscription plan
    test('1. Srusu Unisex with verified Basic Premium subscription plan is visible in Premium category', () {
      final srusuMap = {
        'businessName': 'srusu unisex',
        'fullName': 'sks',
        'ownerName': 'sks',
        'phoneNumber': '+919999999999',
        'categoryId': 'unisex_salon',
        'primaryCategoryId': 'unisex_salon',
        'selectedCategoryIds': ['unisex_salon'],
        'categoryTitle': 'Unisex Salon',
        'primaryCategoryTitle': 'Unisex Salon',
        'categoryType': 'premium',
        'isPremiumCategory': true,
        'status': 'approved',
        'kycStatus': 'approved',
        'verificationStatus': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isDeleted': false,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'subscriptionPaymentStatus': 'paid',
        'subscriptionApprovalStatus': 'approved',
        'subscriptionPlan': '1nhifE6GzhmgYh28mxZd',
        'subscriptionPlanName': 'Basic Premium',
        'subscriptionPlanTier': 'premium',
        'planLimits': {
          'isPremiumCategoryEligible': true,
          'maxActiveListings': 10,
        },
        'subscriptionExpiry': tomorrow.toIso8601String(),
        // Note: isPremiumEligible boolean field is intentionally omitted (mimicking legacy Firestore state)
      };

      final provider = ServiceProviderModel.fromMap(srusuMap, 'uIT6hYxtt3PuWW9rBx9CIWl36Op1');

      // Verify model resolves premium eligibility strictly from verified plan
      expect(provider.isPremiumEligible, isTrue, reason: 'Must resolve isPremiumEligible from planLimits and tier');
      expect(provider.isApprovedAndLive, isTrue, reason: 'Approved, paid, active and unexpired provider must be live');
      expect(provider.isPremiumApprovedAndLive, isTrue, reason: 'Must be premium approved and live');

      // Simulate category matching in PremiumCategoryProvidersPage
      const targetCategoryId = 'unisex_salon';
      final matchPrimary = provider.categoryId.toLowerCase().trim() == targetCategoryId;
      final matchSelected = provider.selectedCategoryIds.map((s) => s.toLowerCase().trim()).contains(targetCategoryId);
      final matchUnisex = provider.isUnisexSalon;
      final isCategoryMatch = matchPrimary || matchSelected || matchUnisex;

      expect(isCategoryMatch, isTrue, reason: 'Srusu Unisex must match unisex_salon category');
    });

    // Test 2: Normal plan provider in salon category is strictly NOT visible in Premium
    test('2. Provider on Normal plan (even in salon category) is NOT eligible for Premium', () {
      final normalSalonMap = {
        'businessName': 'City Hair Salon',
        'fullName': 'Ramesh Kumar',
        'phoneNumber': '+919876543210',
        'categoryId': 'unisex_salon',
        'primaryCategoryId': 'unisex_salon',
        'selectedCategoryIds': ['unisex_salon'],
        'categoryTitle': 'Unisex Salon',
        'categoryType': 'premium', // Selected premium category during onboarding
        'isPremiumCategory': true,
        'status': 'approved',
        'kycStatus': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isDeleted': false,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'subscriptionPlan': 'jP3p8pl3upBi7b8GShhw',
        'subscriptionPlanName': 'Basic',
        'subscriptionPlanTier': 'normal', // Normal plan tier
        'planLimits': {
          'isPremiumCategoryEligible': false, // Normal plan is not eligible
        },
        'subscriptionExpiry': tomorrow.toIso8601String(),
      };

      final provider = ServiceProviderModel.fromMap(normalSalonMap, 'p_normal_salon');

      expect(provider.isPremiumEligible, isFalse,
          reason: 'Must NOT infer premium eligibility from categoryType or isPremiumCategory');
      expect(provider.isApprovedAndLive, isTrue, reason: 'Normal provider is live for normal listings');
      expect(provider.isPremiumApprovedAndLive, isFalse,
          reason: 'Normal plan provider must NEVER appear in Premium category listing');
    });

    // Test 3: Unpaid provider is NOT visible in Premium
    test('3. Unpaid provider with Premium plan is NOT visible', () {
      final unpaidMap = {
        'businessName': 'Luxury Unisex Salon',
        'fullName': 'Owner',
        'phoneNumber': '+919999999991',
        'categoryId': 'unisex_salon',
        'status': 'approved',
        'kycStatus': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': false, // Subscription inactive / unpaid
        'paymentVerified': false,      // Unverified payment
        'subscriptionPlanTier': 'premium',
        'planLimits': {'isPremiumCategoryEligible': true},
        'subscriptionExpiry': tomorrow.toIso8601String(),
      };

      final provider = ServiceProviderModel.fromMap(unpaidMap, 'p_unpaid');

      expect(provider.isApprovedAndLive, isFalse, reason: 'Unpaid provider must not be live');
      expect(provider.isPremiumApprovedAndLive, isFalse, reason: 'Unpaid provider must not appear in premium listing');
    });

    // Test 4: Subscription expired provider is NOT visible in Premium
    test('4. Subscription expired provider is NOT visible', () {
      final expiredMap = {
        'businessName': 'Expired Unisex Salon',
        'fullName': 'Owner',
        'phoneNumber': '+919999999992',
        'categoryId': 'unisex_salon',
        'status': 'approved',
        'kycStatus': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'subscriptionPlanTier': 'premium',
        'planLimits': {'isPremiumCategoryEligible': true},
        'subscriptionExpiry': yesterday.toIso8601String(), // Expired yesterday
      };

      final provider = ServiceProviderModel.fromMap(expiredMap, 'p_expired');

      expect(provider.isApprovedAndLive, isFalse, reason: 'Expired subscription provider must not be live');
      expect(provider.isPremiumApprovedAndLive, isFalse, reason: 'Expired provider must not appear in premium listing');
    });

    // Test 5: Unapproved provider (pending admin review / KYC) is NOT visible in Premium
    test('5. Unapproved provider is NOT visible', () {
      final unapprovedMap = {
        'businessName': 'New Unisex Salon',
        'fullName': 'New Owner',
        'phoneNumber': '+919999999993',
        'categoryId': 'unisex_salon',
        'status': 'pendingReview', // Not approved by admin
        'kycStatus': 'pendingReview',
        'isVerified': false,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'subscriptionPlanTier': 'premium',
        'planLimits': {'isPremiumCategoryEligible': true},
        'subscriptionExpiry': tomorrow.toIso8601String(),
      };

      final provider = ServiceProviderModel.fromMap(unapprovedMap, 'p_unapproved');

      expect(provider.isApprovedAndLive, isFalse, reason: 'Unapproved provider must not be live');
      expect(provider.isPremiumApprovedAndLive, isFalse, reason: 'Unapproved provider must not appear in premium listing');
    });

    // Test 6: Cross-category regression isolation test (Electrician with premium plan)
    test('6. Premium Electrician does NOT appear in Unisex Salon category listing', () {
      final electricianMap = {
        'businessName': 'Master Electrician',
        'fullName': 'Sunil Verma',
        'phoneNumber': '+919999999994',
        'categoryId': 'electrician',
        'primaryCategoryId': 'electrician',
        'selectedCategoryIds': ['electrician'],
        'categoryTitle': 'इलेक्ट्रीशियन',
        'status': 'approved',
        'kycStatus': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'subscriptionPlanTier': 'premium',
        'planLimits': {'isPremiumCategoryEligible': true},
        'subscriptionExpiry': tomorrow.toIso8601String(),
      };

      final provider = ServiceProviderModel.fromMap(electricianMap, 'p_electrician');

      // Provider is premium eligible in general
      expect(provider.isPremiumApprovedAndLive, isTrue);

      // But category match for unisex_salon must strictly fail
      const targetCategoryId = 'unisex_salon';
      final matchPrimary = provider.categoryId.toLowerCase().trim() == targetCategoryId;
      final matchSelected = provider.selectedCategoryIds.map((s) => s.toLowerCase().trim()).contains(targetCategoryId);
      final matchUnisex = provider.isUnisexSalon;
      final isCategoryMatch = matchPrimary || matchSelected || matchUnisex;

      expect(isCategoryMatch, isFalse, reason: 'Electrician must NOT match unisex_salon category');
    });

    // Test 7: Deleted provider (isDeleted: true) is NOT visible
    test('7. Deleted provider with Premium plan is strictly NOT visible', () {
      final deletedMap = {
        'businessName': 'Deleted Salon',
        'fullName': 'Owner',
        'phoneNumber': '+919999999995',
        'categoryId': 'unisex_salon',
        'status': 'approved',
        'kycStatus': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isDeleted': true, // Soft-deleted
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'subscriptionPlanTier': 'premium',
        'planLimits': {'isPremiumCategoryEligible': true},
        'subscriptionExpiry': tomorrow.toIso8601String(),
      };

      final provider = ServiceProviderModel.fromMap(deletedMap, 'p_deleted');

      expect(provider.isApprovedAndLive, isFalse, reason: 'Deleted provider must not be live');
      expect(provider.isPremiumApprovedAndLive, isFalse, reason: 'Deleted provider must not appear in premium listing');
    });

    // Test 8: Fail-closed on missing or conflicting plan data
    test('8. Missing or conflicting plan data fails closed (isPremiumEligible: false)', () {
      final missingPlanMap = {
        'businessName': 'Mystery Salon',
        'fullName': 'Owner',
        'phoneNumber': '+919999999996',
        'categoryId': 'unisex_salon',
        'status': 'approved',
        'kycStatus': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        // No isPremiumEligible, no planLimits, no subscriptionPlanTier
        'subscriptionPlan': 'unknown_plan',
        'subscriptionExpiry': tomorrow.toIso8601String(),
      };

      final provider = ServiceProviderModel.fromMap(missingPlanMap, 'p_missing_plan');

      expect(provider.isPremiumEligible, isFalse, reason: 'Missing plan data must fail closed to false');
      expect(provider.isPremiumApprovedAndLive, isFalse, reason: 'Must not appear in premium listing without verified plan');
    });

    // Test 9: Plan name having "Premium" word does NOT grant eligibility
    test('9. Plan name containing "Premium" word alone does NOT grant eligibility', () {
      final fakeNameMap = {
        'businessName': 'Fake Premium Salon',
        'fullName': 'Owner',
        'phoneNumber': '+919999999997',
        'categoryId': 'unisex_salon',
        'status': 'approved',
        'kycStatus': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'subscriptionPlanName': 'Special Premium Offer', // Has "Premium" word in name
        'subscriptionPlanTier': 'normal',                 // But tier is normal
        'planLimits': {'isPremiumCategoryEligible': false},
        'subscriptionExpiry': tomorrow.toIso8601String(),
      };

      final provider = ServiceProviderModel.fromMap(fakeNameMap, 'p_fake_name');

      expect(provider.isPremiumEligible, isFalse,
          reason: 'Plan name alone must never grant premium eligibility when plan tier/limits are normal');
      expect(provider.isPremiumApprovedAndLive, isFalse);
    });
  });
}

