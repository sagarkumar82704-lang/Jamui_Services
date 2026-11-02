import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/datasources/professional_shop_cache_manager.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';

void main() {
  late ProfessionalShopCacheManager cacheManager;

  setUp(() {
    cacheManager = ProfessionalShopCacheManager();
  });

  group('ProfessionalShopCacheManager - Key Construction & Storage', () {
    test('Builds deterministic Geohash-7 key with category and valid coordinates', () {
      final key = cacheManager.buildCacheKey('electronics', 24.92, 86.22);
      expect(key, startsWith('electronics_'));
      expect(key.length, equals('electronics_'.length + 7));
    });

    test('Builds "nogps" key for invalid coordinates or (0,0)', () {
      final keyNullIsland = cacheManager.buildCacheKey('groceries', 0.0, 0.0);
      expect(keyNullIsland, equals('groceries_nogps'));

      final keyNan = cacheManager.buildCacheKey('groceries', double.nan, 86.22);
      expect(keyNan, equals('groceries_nogps'));
    });

    test('Puts and gets valid unexpired and undisplaced cache entry', () {
      const shop = ProfessionalShopEntity(
        id: 's1',
        shopName: 'Fresh Mart',
        latitude: 24.92,
        longitude: 86.22,
        serviceRadiusKm: 5.0,
      );

      cacheManager.put(
        categoryId: 'groceries',
        lat: 24.920,
        lng: 86.220,
        rawShops: [shop],
        hasMore: true,
      );

      final entry = cacheManager.get(
        categoryId: 'groceries',
        lat: 24.920,
        lng: 86.220,
      );

      expect(entry, isNotNull);
      expect(entry!.rawShops.length, equals(1));
      expect(entry.rawShops.first.id, equals('s1'));
      expect(entry.hasMore, isTrue);
    });
  });

  group('ProfessionalShopCacheManager - Invalidation Rules', () {
    test('Invalidates and evicts entry when TTL expires', () {
      const shop = ProfessionalShopEntity(id: 's1', shopName: 'Shop A');

      cacheManager.put(
        categoryId: 'bakery',
        lat: 24.92,
        lng: 86.22,
        rawShops: [shop],
        hasMore: false,
      );

      // Lookup with negative duration (simulating elapsed TTL)
      final entry = cacheManager.get(
        categoryId: 'bakery',
        lat: 24.92,
        lng: 86.22,
        ttl: const Duration(seconds: -1),
      );

      expect(entry, isNull);
      expect(cacheManager.size, equals(0));
    });

    test('Invalidates and evicts entry when displacement exceeds 200 meters', () {
      const shop = ProfessionalShopEntity(id: 's1', shopName: 'Shop A');

      // Base coordinate: Jamui Station
      cacheManager.put(
        categoryId: 'clothing',
        lat: 24.919,
        lng: 86.223,
        rawShops: [shop],
        hasMore: false,
      );

      // Customer moved 50 meters -> Cache Hit (within 200m)
      final hitEntry = cacheManager.get(
        categoryId: 'clothing',
        lat: 24.9194,
        lng: 86.223,
        displacementMeters: 200.0,
      );
      expect(hitEntry, isNotNull);

      // Customer moved 800 meters -> Cache Miss & Eviction (> 200m)
      final missEntry = cacheManager.get(
        categoryId: 'clothing',
        lat: 24.927,
        lng: 86.223,
        displacementMeters: 200.0,
      );
      expect(missEntry, isNull);
    });

    test('forceEvict removes all entries matching categoryId', () {
      const shop = ProfessionalShopEntity(id: 's1', shopName: 'Shop A');

      cacheManager.put(
        categoryId: 'jewellery',
        lat: 24.92,
        lng: 86.22,
        rawShops: [shop],
        hasMore: false,
      );
      expect(cacheManager.size, equals(1));

      cacheManager.forceEvict('jewellery');
      expect(cacheManager.size, equals(0));
    });

    test('LRU eviction drops oldest entry when cap (20) is exceeded', () {
      for (var i = 1; i <= 21; i++) {
        cacheManager.put(
          categoryId: 'cat_$i',
          lat: 24.92,
          lng: 86.22,
          rawShops: [ProfessionalShopEntity(id: 's_$i', shopName: 'Shop $i')],
          hasMore: false,
        );
      }

      // Max size capped at 20
      expect(cacheManager.size, equals(20));

      // Oldest entry (cat_1) was evicted
      final oldestEntry = cacheManager.get(
        categoryId: 'cat_1',
        lat: 24.92,
        lng: 86.22,
      );
      expect(oldestEntry, isNull);

      // Latest entry (cat_21) exists
      final latestEntry = cacheManager.get(
        categoryId: 'cat_21',
        lat: 24.92,
        lng: 86.22,
      );
      expect(latestEntry, isNotNull);
    });
  });
}

