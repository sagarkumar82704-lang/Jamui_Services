import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/datasources/professional_shop_cache_manager.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/datasources/professional_shop_remote_data_source.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';

void main() {
  group('Verification Point 2: Cache Dynamic Revalidation & Invalidation Rules', () {
    late ProfessionalShopCacheManager cacheManager;

    setUp(() {
      cacheManager = ProfessionalShopCacheManager();
    });

    test('Cache stores raw shops; dynamic re-evaluation recalculates delivery eligibility on lookup', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final pastDate = DateTime.now().subtract(const Duration(days: 1));

      // Shop A: 2.0 km radius, delivery active
      final shopA = ProfessionalShopEntity(
        id: 's1',
        shopName: 'Fresh Mart',
        latitude: 24.92,
        longitude: 86.22,
        serviceRadiusKm: 2.0,
        isHomeDeliveryActive: true,
        isPickupActive: true,
        isSubscriptionActive: true,
        subscriptionExpiresAt: futureDate,
      );

      // Shop B: Subscription expired pre-scheduler
      final shopB = ProfessionalShopEntity(
        id: 's2',
        shopName: 'Expired Shop',
        latitude: 24.92,
        longitude: 86.22,
        serviceRadiusKm: 5.0,
        isHomeDeliveryActive: true,
        isPickupActive: true,
        isSubscriptionActive: true,
        subscriptionExpiresAt: pastDate,
      );

      cacheManager.put(
        categoryId: 'groceries',
        lat: 24.92,
        lng: 86.22,
        rawShops: [shopA, shopB],
        hasMore: false,
      );

      final entry = cacheManager.get(categoryId: 'groceries', lat: 24.92, lng: 86.22);
      expect(entry, isNotNull);

      // Re-evaluation for Customer at 1.5 km (within shopA radius)
      final retrievedA = entry!.rawShops.first;
      expect(retrievedA.isDeliveryEligibleForDistance(1.5), isTrue);

      // Re-evaluation for Customer at 2.5 km (outside shopA radius) -> Delivery becomes FALSE
      expect(retrievedA.isDeliveryEligibleForDistance(2.5), isFalse);

      // Expired shop B dynamically evaluates to isSubscriptionValid == false
      final retrievedB = entry.rawShops[1];
      expect(retrievedB.isSubscriptionValid, isFalse);
    });

    test('Pull-to-refresh forceEvict immediately removes cached category entries', () {
      cacheManager.put(
        categoryId: 'electronics',
        lat: 24.92,
        lng: 86.22,
        rawShops: [const ProfessionalShopEntity(id: 'e1', shopName: 'Tech Shop')],
        hasMore: false,
      );
      expect(cacheManager.size, equals(1));

      // Force eviction on refresh
      cacheManager.forceEvict('electronics');
      expect(cacheManager.get(categoryId: 'electronics', lat: 24.92, lng: 86.22), isNull);
      expect(cacheManager.size, equals(0));
    });
  });

  group('Verification Point 3 & 4: Search Drain Ceiling and Pagination State Isolation', () {
    test('Deduplication preserves stable shop IDs and rejects duplicate documents across pages', () {
      const page1 = [
        ProfessionalShopEntity(id: 's1', shopName: 'Shop 1'),
        ProfessionalShopEntity(id: 's2', shopName: 'Shop 2'),
      ];

      const page2Overlapping = [
        ProfessionalShopEntity(id: 's2', shopName: 'Shop 2 (Duplicate)'),
        ProfessionalShopEntity(id: 's3', shopName: 'Shop 3'),
      ];

      final accumulated = ProfessionalShopRemoteDataSource.deduplicateShops(page1, page2Overlapping);
      expect(accumulated.length, equals(3));
      expect(accumulated.map((s) => s.id).toList(), equals(['s1', 's2', 's3']));
    });

    test('Tab filter strictly isolates delivery-only shops when GPS is unavailable', () {
      const deliveryOnlyShop = ProfessionalShopEntity(
        id: 'd1',
        shopName: 'Delivery Only Ghost Kitchen',
        isHomeDeliveryActive: true,
        isPickupActive: false, // Pickup is OFF
        jamuiArea: 'Main Bazaar',
      );

      const pickupShop = ProfessionalShopEntity(
        id: 'p1',
        shopName: 'Walk-in Store',
        isHomeDeliveryActive: false,
        isPickupActive: true,
        jamuiArea: 'Main Bazaar',
      );

      final resultAllNoGps = ProfessionalShopRemoteDataSource.filterShopsByTab(
        shops: [deliveryOnlyShop, pickupShop],
        activeTab: 'all',
        hasGps: false,
      );

      // Delivery-only shop must NEVER leak into fallback view
      expect(resultAllNoGps.map((s) => s.id).toList(), equals(['p1']));
      expect(resultAllNoGps.any((s) => s.id == 'd1'), isFalse);
    });
  });

  group('Verification Point 5: Cache Category and Geohash Isolation', () {
    test('Different categories never share or collide cache keys', () {
      final manager = ProfessionalShopCacheManager();
      final keyGrocery = manager.buildCacheKey('grocery', 24.92, 86.22);
      final keyElectronics = manager.buildCacheKey('electronics', 24.92, 86.22);

      expect(keyGrocery, isNot(equals(keyElectronics)));
      expect(keyGrocery, startsWith('grocery_'));
      expect(keyElectronics, startsWith('electronics_'));
    });

    test('Different locations (> 200m) never share or collide cache keys', () {
      final manager = ProfessionalShopCacheManager();
      // Jamui Station vs Malaypur (~4 km apart)
      final keyStation = manager.buildCacheKey('grocery', 24.919, 86.223);
      final keyMalaypur = manager.buildCacheKey('grocery', 24.945, 86.248);

      expect(keyStation, isNot(equals(keyMalaypur)));
    });
  });
}

