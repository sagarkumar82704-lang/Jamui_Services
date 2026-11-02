import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/discovery/data/models/service_category_model.dart';
import 'package:apna_jamui_customer/features/discovery/data/models/service_provider_model.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_provider_entity.dart';

void main() {
  group('Jamui Services — Unisex Premium Classification & Customer Isolation Tests', () {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final yesterday = now.subtract(const Duration(days: 1));

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 1: ServiceCategoryModel identifies Unisex Salon as isPremiumCategory
    // ─────────────────────────────────────────────────────────────────────────
    test('1. ServiceCategoryModel recognizes Unisex Salon as isPremiumCategory', () {
      final unisexCatMap = {
        'categoryId': 'unisex_salon',
        'titleEnglish': 'Unisex Salon',
        'titleHindi': 'यूनिसेक्स सैलून',
        'isPremium': true,
        'categoryType': 'premium',
      };

      final cat = ServiceCategoryModel.fromMap(unisexCatMap, 'unisex_salon');

      expect(cat.isPremiumCategory, isTrue);
      expect(cat.isPremium, isTrue);
      expect(cat.categoryType, equals('premium'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 2: ServiceCategoryModel identifies Electrician as NOT isPremiumCategory
    // ─────────────────────────────────────────────────────────────────────────
    test('2. ServiceCategoryModel recognizes Electrician as NOT isPremiumCategory', () {
      final electricianCatMap = {
        'categoryId': 'electrician',
        'titleEnglish': 'Electrician',
        'titleHindi': 'इलेक्ट्रीशियन',
        'isPremium': false,
        'categoryType': 'general',
      };

      final cat = ServiceCategoryModel.fromMap(electricianCatMap, 'electrician');

      expect(cat.isPremiumCategory, isFalse);
      expect(cat.isPremium, isFalse);
      expect(cat.categoryType, equals('general'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 3: Exclude Premium categories from Normal Categories Grid
    // ─────────────────────────────────────────────────────────────────────────
    test('3. Normal categories grid filter (!c.isPremiumCategory) excludes Unisex Salon', () {
      final allCats = [
        ServiceCategoryModel.fromMap({'titleEnglish': 'Electrician', 'categoryType': 'general', 'isActive': true}, 'elec'),
        ServiceCategoryModel.fromMap({'titleEnglish': 'Plumber', 'categoryType': 'general', 'isActive': true}, 'plumb'),
        ServiceCategoryModel.fromMap({'categoryId': 'unisex_salon', 'titleEnglish': 'Unisex Salon', 'categoryType': 'premium', 'isActive': true}, 'unisex_salon'),
      ];

      final normalGridCats = allCats.where((c) => c.isActive && !c.isPremiumCategory).toList();

      expect(normalGridCats.length, equals(2));
      expect(normalGridCats.any((c) => c.id == 'unisex_salon'), isFalse, reason: 'Unisex Salon must be excluded from normal grid');
      expect(normalGridCats.any((c) => c.id == 'elec'), isTrue);
      expect(normalGridCats.any((c) => c.id == 'plumb'), isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 4: Pending Unisex provider remains hidden from Customer App
    // ─────────────────────────────────────────────────────────────────────────
    test('4. Pending Unisex provider (Shrisu A unisex salon) remains HIDDEN from Customer App', () {
      final pendingDoc = {
        'businessName': 'Shrisu A unisex salon',
        'fullName': 'shrisu A unisex salon',
        'categoryId': 'unisex_salon',
        'primaryCategoryId': 'unisex_salon',
        'categoryType': 'premium',
        'isPremiumCategory': true,
        'status': 'pendingReview', // Not approved
        'kycStatus': 'pendingReview',
        'isVerified': false,
        'isSubscriptionActive': false, // Unpaid
        'paymentVerified': false,
        // isPremiumEligible is missing
      };

      final provider = ServiceProviderModel.fromMap(pendingDoc, 'g5nVlXFcuQQq8Pn3TsQ9kEjUGH53');

      expect(provider.isApprovedAndLive, isFalse, reason: 'Pending provider must not be live');
      expect(provider.isPremiumApprovedAndLive, isFalse, reason: 'Pending provider must NEVER appear in Premium listing');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 5: Approved + eligible + paid Unisex provider appears in Premium listing
    // ─────────────────────────────────────────────────────────────────────────
    test('5. Approved + eligible + paid Unisex provider appears in Premium listing', () {
      final eligibleDoc = {
        'businessName': 'Shrisu A unisex salon',
        'fullName': 'shrisu A unisex salon',
        'categoryId': 'unisex_salon',
        'primaryCategoryId': 'unisex_salon',
        'categoryType': 'premium',
        'isPremiumCategory': true,
        'status': 'approved',
        'kycStatus': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'isPremiumEligible': true,
        'subscriptionPlanTier': 'premium',
        'planLimits': {'isPremiumCategoryEligible': true},
        'subscriptionExpiry': tomorrow.toIso8601String(),
      };

      final provider = ServiceProviderModel.fromMap(eligibleDoc, 'g5nVlXFcuQQq8Pn3TsQ9kEjUGH53');

      expect(provider.isApprovedAndLive, isTrue);
      expect(provider.isPremiumApprovedAndLive, isTrue, reason: 'Approved, paid, and eligible unisex provider must appear in Premium listing');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 6: Unisex provider NEVER appears in Normal Category listing
    // ─────────────────────────────────────────────────────────────────────────
    test('6. Unisex provider is strictly excluded from Normal CategoryProvidersPage listing', () {
      final unisexProvider = ServiceProviderModel.fromMap({
        'businessName': 'Style Studio Unisex Salon',
        'categoryId': 'unisex_salon',
        'primaryCategoryId': 'unisex_salon',
        'status': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'isPremiumEligible': true,
        'subscriptionExpiry': tomorrow.toIso8601String(),
      }, 'p_unisex_01');

      final electricianProvider = ServiceProviderModel.fromMap({
        'businessName': 'Gupta Electricals',
        'categoryId': 'electrician',
        'primaryCategoryId': 'electrician',
        'status': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'isPremiumEligible': false,
        'subscriptionExpiry': tomorrow.toIso8601String(),
      }, 'p_elec_01');

      final allProviders = [unisexProvider, electricianProvider];

      // Exact filter from CategoryProvidersPage lines 94-108
      List<ServiceProviderEntity> filterForNormalCategory(String targetCatId) {
        return allProviders.where((p) {
          if (!p.isApprovedAndLive) return false;

          // Strict isolation: Unisex Salon / Premium category providers must never be listed on Normal Category Page
          if (p.isUnisexSalon || p.categoryId.toLowerCase().trim() == 'unisex_salon') {
            return false;
          }

          final pCatId = p.categoryId.toLowerCase().trim();
          return pCatId == targetCatId;
        }).toList();
      }

      // Query for electrician:
      final electricianList = filterForNormalCategory('electrician');
      expect(electricianList.length, equals(1));
      expect(electricianList.first.id, equals('p_elec_01'));

      // If normal page is erroneously queried for unisex_salon:
      final unisexNormalList = filterForNormalCategory('unisex_salon');
      expect(unisexNormalList.isEmpty, isTrue, reason: 'Unisex provider must NEVER appear in Normal Category page');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 7: Normal providers remain unaffected and visible in Normal category
    // ─────────────────────────────────────────────────────────────────────────
    test('7. Normal Electrician provider remains live and unaffected in Normal category', () {
      final electricianDoc = {
        'businessName': 'Sagar Electric',
        'categoryId': 'electrician',
        'primaryCategoryId': 'electrician',
        'status': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'isPremiumEligible': false,
        'subscriptionExpiry': tomorrow.toIso8601String(),
      };

      final provider = ServiceProviderModel.fromMap(electricianDoc, 'p_elec');

      expect(provider.isApprovedAndLive, isTrue);
      expect(provider.isPremiumApprovedAndLive, isFalse, reason: 'Normal provider must NOT be premium eligible');
      expect(provider.isUnisexSalon, isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 8: Subscription expired Unisex provider is strictly HIDDEN
    // ─────────────────────────────────────────────────────────────────────────
    test('8. Subscription expired Unisex provider is strictly HIDDEN from Premium listing', () {
      final expiredDoc = {
        'businessName': 'srusu unisex',
        'categoryId': 'unisex_salon',
        'status': 'approved',
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'isPremiumEligible': true,
        'subscriptionExpiry': yesterday.toIso8601String(), // Expired
      };

      final provider = ServiceProviderModel.fromMap(expiredDoc, 'uIT6hYxtt3PuWW9rBx9CIWl36Op1');

      expect(provider.isApprovedAndLive, isFalse, reason: 'Expired subscription provider must not be live');
      expect(provider.isPremiumApprovedAndLive, isFalse, reason: 'Expired provider must not appear in Premium listing');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 9: Unpaid Unisex provider is strictly HIDDEN from Premium listing
    // ─────────────────────────────────────────────────────────────────────────
    test('9. Unpaid Unisex provider is strictly HIDDEN from Premium listing', () {
      final unpaidDoc = {
        'businessName': 'th',
        'categoryId': 'unisex_salon',
        'status': 'approved', // Even if approved
        'isVerified': true,
        'isActive': true,
        'isAvailable': true,
        'isSubscriptionActive': false, // But unpaid
        'paymentVerified': false,
        'isPremiumEligible': true,
        'subscriptionExpiry': tomorrow.toIso8601String(),
      };

      final provider = ServiceProviderModel.fromMap(unpaidDoc, 'sTDf8c9KrlRosbUaYRgCFqzxMZz1');

      expect(provider.isApprovedAndLive, isFalse, reason: 'Unpaid provider must not be live');
      expect(provider.isPremiumApprovedAndLive, isFalse, reason: 'Unpaid provider must not appear in Premium listing');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 10: Missing category metadata fails safely
    // ─────────────────────────────────────────────────────────────────────────
    test('10. Missing category metadata fails safely to normal non-premium category', () {
      final emptyCat = ServiceCategoryModel.fromMap({}, 'unknown_cat_id');

      expect(emptyCat.isPremiumCategory, isFalse, reason: 'Missing category metadata must fail safe to non-premium');
      expect(emptyCat.isPremium, isFalse);
      expect(emptyCat.categoryType, equals('general'));
    });
  });
}

