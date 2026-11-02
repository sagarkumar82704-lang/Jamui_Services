import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/auth/data/models/provider_profile_model.dart';
import 'package:apna_jamui_provider/features/subscription/data/models/subscription_plan_model.dart';
import 'package:apna_jamui_provider/features/subscription/data/datasources/subscription_remote_data_source.dart';
import 'package:apna_jamui_provider/features/subscription/presentation/pages/subscription_page.dart';

class MockSubscriptionRemoteDataSource implements SubscriptionRemoteDataSource {
  final List<SubscriptionPlanModel> plans;
  MockSubscriptionRemoteDataSource({required this.plans});

  @override
  Future<List<SubscriptionPlanModel>> fetchPlans({String? providerId, String? planTier}) async {
    if (planTier != null && planTier.isNotEmpty) {
      return plans.where((p) => p.planTier == planTier).toList();
    }
    return plans;
  }

  @override
  Future<Map<String, dynamic>> createRazorpayOrder({
    required String planId,
    required String providerId,
    String? phone,
    String? email,
  }) async => {'orderId': 'order_mock_test_123', 'amount': 19900};

  @override
  Future<Map<String, dynamic>> verifyPayment({
    required String providerId,
    required String planId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async => {'message': 'सफल'};

  @override
  Future<Map<String, dynamic>?> getPendingApprovalPayment({required String providerId}) async => null;

  @override
  Future<Map<String, dynamic>> reconcilePayment({required String orderId}) async => {
    'status': 'captured',
  };
}

void main() {
  group('Provider App — Provider Category-Based Subscription Plans Unit & UI Tests', () {
    // -------------------------------------------------------------------------
    // TEST 1: Normal Category Provider resolves to 'normal' tier
    // -------------------------------------------------------------------------
    test('1. Normal Category Provider (Electrician) resolves strictly to "normal" planTier', () {
      final normalProfile = ProviderProfileEntity(
        id: 'prov_normal_1',
        email: 'electrician@jamui.com',
        phoneNumber: '9876543210',
        fullName: 'Amit Kumar',
        businessName: 'Amit Electrical Works',
        primaryCategoryId: 'electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
        categoryType: 'general',
        isPremiumEligible: false,
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        isSubscriptionActive: false,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(normalProfile.isPremiumCategory, isFalse);
      expect(normalProfile.isPremiumEligible, isFalse);
      expect(normalProfile.resolvedPlanTier, equals('normal'));
    });

    // -------------------------------------------------------------------------
    // TEST 2: Premium Category Provider (Unisex Salon) resolves to 'premium' tier
    // -------------------------------------------------------------------------
    test('2. Premium Category Provider (Unisex Salon) resolves strictly to "premium" planTier', () {
      final salonProfile = ProviderProfileEntity(
        id: 'prov_salon_1',
        email: 'salon@jamui.com',
        phoneNumber: '9876543211',
        fullName: 'Rohit Stylist',
        businessName: 'Style Studio Salon',
        primaryCategoryId: 'unisex_salon',
        primaryCategoryTitle: 'Unisex Salon',
        categoryType: 'premium',
        isPremiumEligible: false,
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        isSubscriptionActive: false,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(salonProfile.isPremiumCategory, isTrue);
      expect(salonProfile.resolvedPlanTier, equals('premium'));
    });

    // -------------------------------------------------------------------------
    // TEST 3: Admin Override (isPremiumEligible = true) on General Category resolves to 'premium'
    // -------------------------------------------------------------------------
    test('3. Admin Override (isPremiumEligible = true) on General Category grants "premium" tier', () {
      final adminApprovedProfile = ProviderProfileEntity(
        id: 'prov_approved_1',
        email: 'elite_contractor@jamui.com',
        phoneNumber: '9876543212',
        fullName: 'Vikas Kumar',
        businessName: 'Vikas Contracting',
        primaryCategoryId: 'electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
        categoryType: 'general',
        isPremiumEligible: true, // Explicit Admin Approval override
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        isSubscriptionActive: false,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(adminApprovedProfile.isPremiumEligible, isTrue);
      expect(adminApprovedProfile.resolvedPlanTier, equals('premium'));
    });

    // -------------------------------------------------------------------------
    // TEST 4: Active Subscription Tier overrides category for renewal protection
    // -------------------------------------------------------------------------
    test('4. Active Subscription Tier is strictly verified and preserved for Renewal', () {
      final activeNormalProfile = ProviderProfileEntity(
        id: 'prov_renew_1',
        email: 'carpenter@jamui.com',
        phoneNumber: '9876543213',
        fullName: 'Manoj Sharma',
        businessName: 'Manoj Wood Crafts',
        primaryCategoryId: 'carpenter',
        primaryCategoryTitle: 'बढ़ई',
        subscriptionPlanTier: 'normal',
        isSubscriptionActive: true,
        paymentVerified: true,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(activeNormalProfile.resolvedPlanTier, equals('normal'));

      final activePremiumProfile = ProviderProfileEntity(
        id: 'prov_renew_2',
        email: 'beauty@jamui.com',
        phoneNumber: '9876543214',
        fullName: 'Pooja Kumari',
        businessName: 'Pooja Beauty Lounge',
        primaryCategoryId: 'unisex_salon',
        primaryCategoryTitle: 'Unisex Salon',
        subscriptionPlanTier: 'premium',
        isSubscriptionActive: true,
        paymentVerified: true,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(activePremiumProfile.resolvedPlanTier, equals('premium'));
    });

    // -------------------------------------------------------------------------
    // TEST 4b: Unapproved Provider in Premium Category defaults strictly to 'normal' tier
    // -------------------------------------------------------------------------
    test('4b. Provider in Premium Category (draft/pendingReview) resolves to "premium" planTier so they can purchase premium plans', () {
      final unapprovedSalon = ProviderProfileEntity(
        id: 'prov_unapproved_1',
        email: 'unapproved_salon@jamui.com',
        phoneNumber: '9876543219',
        fullName: 'New Stylist',
        businessName: 'Glamour Salon',
        primaryCategoryId: 'unisex_salon',
        primaryCategoryTitle: 'Unisex Salon',
        categoryType: 'premium',
        isPremiumEligible: false,
        status: ProviderAccountStatus.pendingReview, // NOT approved yet
        kycStatus: ProviderKycStatus.pendingReview,
        isSubscriptionActive: false,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(unapprovedSalon.isPremiumCategory, isTrue);
      expect(unapprovedSalon.isPremiumEligible, isFalse);
      expect(unapprovedSalon.resolvedPlanTier, equals('premium'), reason: 'Pending unisex provider must resolve to premium plan tier to see and buy premium plans');
    });

    // -------------------------------------------------------------------------
    // TEST 4c: Expired Normal Subscription provider retains 'normal' tier even in Salon category
    // -------------------------------------------------------------------------
    test('4c. Expired Normal Subscription provider retains "normal" tier renewal protection', () {
      final expiredNormalProfile = ProviderProfileEntity(
        id: 'prov_expired_1',
        email: 'expired_provider@jamui.com',
        phoneNumber: '9876543220',
        fullName: 'Ramesh Plumber',
        businessName: 'Ramesh Services',
        primaryCategoryId: 'unisex_salon', // Even if category was set to salon
        primaryCategoryTitle: 'Unisex Salon',
        categoryType: 'premium',
        subscriptionPlanTier: 'normal', // Previous tier was normal
        isSubscriptionActive: false, // Subscription expired
        paymentVerified: true,
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(expiredNormalProfile.resolvedPlanTier, equals('normal'), reason: 'Past normal subscription tier locks renewals to normal');
    });

    // -------------------------------------------------------------------------
    // TEST 5: SubscriptionPlanModel serialization and planTier fallback
    // -------------------------------------------------------------------------
    test('5. SubscriptionPlanModel parses planTier correctly and falls back to normal for legacy docs', () {
      // Plan with explicit premium tier
      final premiumMap = {
        'name': 'Premium Salon Plan',
        'price': 499.0,
        'durationDays': 30,
        'planTier': 'premium',
        'features': ['Top Search', 'Gold Badge'],
      };
      final pPlan = SubscriptionPlanModel.fromMap(premiumMap, 'p1');
      expect(pPlan.planTier, equals('premium'));

      // Plan with explicit normal tier
      final normalMap = {
        'name': 'Standard Plan',
        'price': 199.0,
        'durationDays': 30,
        'planTier': 'normal',
        'features': ['Direct Leads'],
      };
      final nPlan = SubscriptionPlanModel.fromMap(normalMap, 'n1');
      expect(nPlan.planTier, equals('normal'));

      // Legacy plan missing planTier
      final legacyMap = {
        'name': 'Legacy Basic Plan',
        'price': 99.0,
        'durationDays': 30,
        'features': ['Basic Access'],
      };
      final lPlan = SubscriptionPlanModel.fromMap(legacyMap, 'l1');
      expect(lPlan.planTier, equals('normal'), reason: 'Missing planTier must fall back to normal');
    });

    // -------------------------------------------------------------------------
    // TEST 6: ProviderProfileModel serialization retains subscriptionPlanTier
    // -------------------------------------------------------------------------
    test('6. ProviderProfileModel serialization correctly persists and deserializes subscriptionPlanTier', () {
      final profile = ProviderProfileEntity(
        id: 'prov_model_test',
        email: 'test@jamui.com',
        phoneNumber: '9876543210',
        fullName: 'Test Provider',
        businessName: 'Test Business',
        primaryCategoryId: 'unisex_salon',
        primaryCategoryTitle: 'Unisex Salon',
        subscriptionPlanTier: 'premium',
        createdAt: DateTime(2026, 1, 1),
      );

      final model = ProviderProfileModel.fromEntity(profile);
      final map = model.toMap();
      expect(map['subscriptionPlanTier'], equals('premium'));

      final reconstructed = ProviderProfileModel.fromMap(map, 'prov_model_test');
      expect(reconstructed.subscriptionPlanTier, equals('premium'));
      expect(reconstructed.resolvedPlanTier, equals('premium'));
    });

    // -------------------------------------------------------------------------
    // TEST 7: UI Layer Tier Segregation: Normal provider gets Normal UI banner & cards
    // -------------------------------------------------------------------------
    testWidgets('7. SubscriptionPage renders Normal Tier banner and strictly excludes Premium plans for Normal Provider', (tester) async {
      final normalProfile = ProviderProfileEntity(
        id: 'prov_ui_norm',
        email: 'electrician@jamui.com',
        phoneNumber: '9876543210',
        fullName: 'Amit Kumar',
        businessName: 'Amit Electrical Works',
        primaryCategoryId: 'electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
        categoryType: 'general',
        isPremiumEligible: false,
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        createdAt: DateTime(2026, 1, 1),
      );

      final mockDs = MockSubscriptionRemoteDataSource(plans: const [
        SubscriptionPlanModel(
          id: 'p_norm_1',
          name: 'Normal Starter',
          price: 199.0,
          durationDays: 30,
          planTier: 'normal',
          features: ['Direct Leads'],
        ),
        SubscriptionPlanModel(
          id: 'p_prem_1',
          name: 'Premium Salon Exclusive ⭐',
          price: 499.0,
          durationDays: 30,
          planTier: 'premium',
          features: ['VIP Priority'],
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionPage(profile: normalProfile, dataSource: mockDs),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that Normal Tier UI banner is visible
      expect(find.text('📦 मानक श्रेणी प्लान्स (Normal Tier)'), findsOneWidget);
      expect(find.textContaining('इलेक्ट्रीशियन'), findsWidgets);
      expect(find.text('Normal Starter'), findsOneWidget);

      // Verify that Premium Tier banner and plans are strictly excluded
      expect(find.text('⭐ प्रीमियम श्रेणी प्लान्स (Premium Tier)'), findsNothing);
      expect(find.text('Premium Salon Exclusive ⭐'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // TEST 8: UI Layer Tier Segregation: Premium provider gets Premium UI banner & cards
    // -------------------------------------------------------------------------
    testWidgets('8. SubscriptionPage renders Premium Tier banner and strictly excludes Normal plans for Salon Provider', (tester) async {
      final salonProfile = ProviderProfileEntity(
        id: 'prov_ui_prem',
        email: 'salon@jamui.com',
        phoneNumber: '9876543211',
        fullName: 'Rohit Stylist',
        businessName: 'Style Studio Unisex Salon',
        primaryCategoryId: 'unisex_salon',
        primaryCategoryTitle: 'Unisex Salon',
        categoryType: 'premium',
        isPremiumEligible: false,
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        createdAt: DateTime(2026, 1, 1),
      );

      final mockDs = MockSubscriptionRemoteDataSource(plans: const [
        SubscriptionPlanModel(
          id: 'p_norm_1',
          name: 'Normal Starter',
          price: 199.0,
          durationDays: 30,
          planTier: 'normal',
          features: ['Direct Leads'],
        ),
        SubscriptionPlanModel(
          id: 'p_prem_1',
          name: 'Premium Salon Exclusive ⭐',
          price: 499.0,
          durationDays: 30,
          planTier: 'premium',
          features: ['VIP Priority'],
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionPage(profile: salonProfile, dataSource: mockDs),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that Premium Tier UI banner is visible
      expect(find.text('⭐ प्रीमियम श्रेणी प्लान्स (Premium Tier)'), findsOneWidget);
      expect(find.textContaining('Unisex Salon'), findsWidgets);
      expect(find.text('Premium Salon Exclusive ⭐'), findsOneWidget);

      // Verify that Normal Tier banner and plans are strictly excluded
      expect(find.text('📦 मानक श्रेणी प्लान्स (Normal Tier)'), findsNothing);
      expect(find.text('Normal Starter'), findsNothing);
    });
  });
}
