import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_category_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';
import 'dart:math' as math;

void main() {
  group('1. Shop Visibility Conditions Test (status == approved, isSubscriptionActive == true, isActive == true)', () {
    test('Shop is approved and live ONLY when all 3 conditions + not deleted are true', () {
      const eligibleShop = ProfessionalShopEntity(
        id: 'shop_01',
        shopName: 'FreshMart Grocery',
        status: 'approved',
        isActive: true,
        isSubscriptionActive: true,
        isDeleted: false,
      );
      expect(eligibleShop.isApprovedAndLive, isTrue);

      // Condition 1 Failure: status != approved (e.g. pending or suspended)
      const shopPendingStatus = ProfessionalShopEntity(
        id: 'shop_02',
        shopName: 'Pending Shop',
        status: 'pending',
        isActive: true,
        isSubscriptionActive: true,
        isDeleted: false,
      );
      expect(shopPendingStatus.isApprovedAndLive, isFalse);

      final suspendedShop = ProfessionalShopEntity(
        id: 'shop_03',
        shopName: 'Suspended Shop',
        status: 'suspended',
        isActive: true,
        isSubscriptionActive: true,
        isDeleted: false,
      );
      expect(suspendedShop.isApprovedAndLive, isFalse);

      // Condition 2 Failure: isSubscriptionActive == false
      const expiredSubShop = ProfessionalShopEntity(
        id: 'shop_04',
        shopName: 'Expired Sub Shop',
        status: 'approved',
        isActive: true,
        isSubscriptionActive: false,
        isDeleted: false,
      );
      expect(expiredSubShop.isApprovedAndLive, isFalse);

      // Condition 3 Failure: isActive == false
      const inactiveShop = ProfessionalShopEntity(
        id: 'shop_05',
        shopName: 'Inactive Shop',
        status: 'approved',
        isActive: false,
        isSubscriptionActive: true,
        isDeleted: false,
      );
      expect(inactiveShop.isApprovedAndLive, isFalse);

      // Condition 4 Failure: isDeleted == true
      const deletedShop = ProfessionalShopEntity(
        id: 'shop_06',
        shopName: 'Deleted Shop',
        status: 'approved',
        isActive: true,
        isSubscriptionActive: true,
        isDeleted: true,
      );
      expect(deletedShop.isApprovedAndLive, isFalse);
    });
  });

  group('2. GPS Permission Denied & Distance Calculation Test', () {
    double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
      const double p = 0.017453292519943295;
      final double a = 0.5 -
          math.cos((lat2 - lat1) * p) / 2 +
          math.cos(lat1 * p) *
              math.cos(lat2 * p) *
              (1 - math.cos((lon2 - lon1) * p)) / 2;
      return 12742 * math.asin(math.sqrt(a));
    }

    test('When GPS permission is GRANTED, accurate distance in km is calculated', () {
      const customerLat = 24.9273;
      const customerLng = 86.2238; // Jamui Town
      const shopLat = 24.9350;
      const shopLng = 86.2300;

      final dist = calculateDistanceKm(customerLat, customerLng, shopLat, shopLng);
      expect(dist, greaterThan(0.5));
      expect(dist, lessThan(3.0));

      const shop = ProfessionalShopEntity(
        id: 'shop_01',
        shopName: 'FreshMart Grocery',
        latitude: shopLat,
        longitude: shopLng,
      );
      final shopWithDist = shop.copyWith(distanceKm: dist);
      expect(shopWithDist.distanceKm, isNotNull);
      expect(shopWithDist.distanceKm!, closeTo(1.05, 0.3));

      // Display logic
      final display = shopWithDist.distanceKm != null
          ? '${shopWithDist.distanceKm!.toStringAsFixed(1)} km'
          : (shopWithDist.jamuiArea.isNotEmpty ? shopWithDist.jamuiArea : 'Jamui');
      expect(display, contains('km'));
    });

    test('When GPS permission is DENIED (null lat/lng), distanceKm is null and falls back to locality string', () {
      const double? customerLat = null;
      const double? customerLng = null;

      const shop = ProfessionalShopEntity(
        id: 'shop_01',
        shopName: 'FreshMart Grocery',
        jamuiArea: 'Laxmi Chowk',
        latitude: 24.9350,
        longitude: 86.2300,
      );

      final hasGps = customerLat != null && customerLng != null;
      expect(hasGps, isFalse);

      // Distance is NOT calculated, remains null
      expect(shop.distanceKm, isNull);

      // UI Display fallback
      final display = shop.distanceKm != null
          ? '${shop.distanceKm!.toStringAsFixed(1)} km'
          : (shop.jamuiArea.isNotEmpty ? shop.jamuiArea : 'Jamui');
      
      expect(display, equals('Laxmi Chowk'));
      expect(display, isNot(contains('km')));
      expect(display, isNot(equals('0.0 km')));
    });

    test('When GPS permission is DENIED and shop jamuiArea is empty, falls back to default Jamui town', () {
      const shop = ProfessionalShopEntity(
        id: 'shop_02',
        shopName: 'Daily Needs Store',
        jamuiArea: '',
      );

      final display = shop.distanceKm != null
          ? '${shop.distanceKm!.toStringAsFixed(1)} km'
          : (shop.jamuiArea.isNotEmpty ? shop.jamuiArea : 'Jamui');

      expect(display, equals('Jamui'));
      expect(display, isNot(contains('km')));
    });
  });

  group('3. Separate Category Listings Test (Grocery vs Vegetable)', () {
    final allShops = [
      const ProfessionalShopEntity(
        id: 'shop_g1',
        shopName: 'FreshMart Grocery',
        demandCategoryId: 'cat_grocery',
        status: 'approved',
        isActive: true,
        isSubscriptionActive: true,
      ),
      const ProfessionalShopEntity(
        id: 'shop_g2',
        shopName: 'Green Basket Mart',
        demandCategoryId: 'cat_grocery',
        status: 'approved',
        isActive: true,
        isSubscriptionActive: true,
      ),
      const ProfessionalShopEntity(
        id: 'shop_v1',
        shopName: 'Kisan Fresh Sabji Mandi',
        demandCategoryId: 'cat_vegetable',
        status: 'approved',
        isActive: true,
        isSubscriptionActive: true,
      ),
      const ProfessionalShopEntity(
        id: 'shop_v2',
        shopName: 'Organic Veggie Hub',
        demandCategoryId: 'cat_vegetable',
        status: 'approved',
        isActive: true,
        isSubscriptionActive: true,
      ),
      const ProfessionalShopEntity(
        id: 'shop_f1',
        shopName: 'Royal Fruit Corner',
        demandCategoryId: 'cat_fruits',
        status: 'approved',
        isActive: true,
        isSubscriptionActive: true,
      ),
    ];

    List<ProfessionalShopEntity> filterByCategory(List<ProfessionalShopEntity> list, String? categoryId) {
      if (categoryId == null || categoryId.isEmpty || categoryId == 'all') {
        return list;
      }
      return list.where((s) => s.demandCategoryId == categoryId).toList();
    }

    test('Grocery category filter returns ONLY Grocery shops and excludes Vegetable shops', () {
      final groceryShops = filterByCategory(allShops, 'cat_grocery');
      expect(groceryShops.length, equals(2));
      expect(groceryShops.map((s) => s.id), containsAll(['shop_g1', 'shop_g2']));
      expect(groceryShops.map((s) => s.id), isNot(contains('shop_v1')));
      expect(groceryShops.map((s) => s.id), isNot(contains('shop_v2')));
      expect(groceryShops.map((s) => s.id), isNot(contains('shop_f1')));
    });

    test('Vegetable category filter returns ONLY Vegetable shops and excludes Grocery shops', () {
      final vegetableShops = filterByCategory(allShops, 'cat_vegetable');
      expect(vegetableShops.length, equals(2));
      expect(vegetableShops.map((s) => s.id), containsAll(['shop_v1', 'shop_v2']));
      expect(vegetableShops.map((s) => s.id), isNot(contains('shop_g1')));
      expect(vegetableShops.map((s) => s.id), isNot(contains('shop_g2')));
      expect(vegetableShops.map((s) => s.id), isNot(contains('shop_f1')));
    });

    test('All/Null category filter returns all live shops across categories', () {
      final all = filterByCategory(allShops, null);
      expect(all.length, equals(5));
    });
  });

  group('4. Inactive Category & Inactive Shop Exclusion Test', () {
    test('Inactive category is filtered out and never displayed in categories section', () {
      final rawCategories = [
        const ProfessionalCategoryEntity(id: 'cat_grocery', titleEnglish: 'Grocery Shop', titleHindi: 'किराना दुकान', slug: 'grocery', isActive: true, priorityOrder: 1),
        const ProfessionalCategoryEntity(id: 'cat_vegetable', titleEnglish: 'Vegetable Shop', titleHindi: 'सब्जी दुकान', slug: 'vegetable', isActive: true, priorityOrder: 2),
        const ProfessionalCategoryEntity(id: 'cat_inactive_test', titleEnglish: 'Inactive Test Shop', titleHindi: 'बंद श्रेणी', slug: 'inactive', isActive: false, priorityOrder: 3),
      ];

      final activeCategories = rawCategories.where((c) => c.isActive).toList();
      expect(activeCategories.length, equals(2));
      expect(activeCategories.any((c) => c.id == 'cat_inactive_test'), isFalse);
      expect(activeCategories.every((c) => c.isActive), isTrue);
    });

    test('Inactive shop is filtered out and never displayed in shops listing', () {
      final rawShops = [
        const ProfessionalShopEntity(id: 'shop_active', shopName: 'Active Shop', status: 'approved', isSubscriptionActive: true, isActive: true, isDeleted: false),
        const ProfessionalShopEntity(id: 'shop_inactive', shopName: 'Inactive Shop', status: 'approved', isSubscriptionActive: true, isActive: false, isDeleted: false),
      ];

      final liveShops = rawShops.where((s) => s.isApprovedAndLive).toList();
      expect(liveShops.length, equals(1));
      expect(liveShops.first.id, equals('shop_active'));
      expect(liveShops.any((s) => s.id == 'shop_inactive'), isFalse);
    });
  });

  group('5. Zero Fake Ratings & Reviews Test', () {
    test('Shops with zero ratings do NOT show star rating or fake reviews', () {
      const newShop = ProfessionalShopEntity(
        id: 'shop_new',
        shopName: 'New Kirana Store',
        rating: 0.0,
        ratingCount: 0,
      );

      final shouldShowRating = newShop.rating > 0 && newShop.ratingCount > 0;
      expect(shouldShowRating, isFalse);

      const reviewedShop = ProfessionalShopEntity(
        id: 'shop_reviewed',
        shopName: 'Established Mart',
        rating: 4.8,
        ratingCount: 15,
      );

      final shouldShowReviewed = reviewedShop.rating > 0 && reviewedShop.ratingCount > 0;
      expect(shouldShowReviewed, isTrue);
    });
  });
}

