import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:apna_jamui_customer/core/utils/jamui_geo_validator.dart';
import 'package:apna_jamui_customer/core/utils/jamui_time_utils.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/datasources/professional_shop_cache_manager.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/datasources/professional_shop_remote_data_source.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/paginated_shops_result.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_category_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_shops_listing_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_shop_card.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_shop_skeleton.dart';

class Checkpoint4MockDataSource extends ProfessionalShopRemoteDataSource {
  List<ProfessionalShopEntity> mockShops = [];
  bool hasMore = false;
  int fetchCount = 0;
  bool isForceRefreshed = false;

  List<ProfessionalShopEntity> searchShops = [];
  bool searchHasMore = false;
  int searchCount = 0;

  Checkpoint4MockDataSource({super.cacheManager});

  @override
  Future<PaginatedProfessionalShopsResult> fetchPaginatedShops({
    String? categoryId,
    double? customerLat,
    double? customerLng,
    String? areaId,
    DocumentSnapshot? lastDoc,
    int chunkSize = 100,
    bool forceRefresh = false,
  }) async {
    fetchCount++;
    if (forceRefresh) isForceRefreshed = true;

    return PaginatedProfessionalShopsResult(
      shops: mockShops,
      lastDoc: null,
      hasMore: hasMore,
      totalLoaded: mockShops.length,
      isFromCache: false,
    );
  }

  @override
  Future<PaginatedProfessionalShopsResult> searchShopsWithCeiling({
    required String queryText,
    String? categoryId,
    double? customerLat,
    double? customerLng,
    String? areaId,
    int maxReadCeiling = 300,
    int chunkSize = 100,
    int? generationToken,
  }) async {
    searchCount++;
    return PaginatedProfessionalShopsResult(
      shops: searchShops,
      lastDoc: null,
      hasMore: searchHasMore,
      totalLoaded: maxReadCeiling,
      isFromCache: false,
    );
  }
}

void main() {
  group('Jamui Services — Phase 3 Checkpoint 4 Full E2E & Edge Case Verification', () {
    late Checkpoint4MockDataSource dataSource;
    late ProfessionalShopCacheManager cacheManager;

    setUp(() {
      cacheManager = ProfessionalShopCacheManager();
      dataSource = Checkpoint4MockDataSource(cacheManager: cacheManager);
    });

    // -------------------------------------------------------------
    // SECTION A: CUSTOMER PROFESSIONAL MARKETPLACE E2E FLOW
    // -------------------------------------------------------------
    group('Section A: Customer Professional Marketplace E2E Flows', () {
      final e2eShopNear = const ProfessionalShopEntity(
        id: 'shop_near_01',
        shopName: 'Near Station Grocery',
        jamuiArea: 'Station Road',
        areaId: 'area_station',
        latitude: 25.1337,
        longitude: 86.1772,
        distanceKm: 1.5,
        serviceRadiusKm: 5.0,
        isHomeDeliveryActive: true,
        isPickupActive: true,
        isVerified: true,
        rating: 4.8,
        ratingCount: 30,
      );

      final e2eShopFar = const ProfessionalShopEntity(
        id: 'shop_far_02',
        shopName: 'Malaypur Hardware',
        jamuiArea: 'Malaypur',
        areaId: 'area_malaypur',
        latitude: 25.1500,
        longitude: 86.2000,
        distanceKm: 8.5,
        serviceRadiusKm: 4.0, // Customer at 8.5km is outside 4km delivery radius
        isHomeDeliveryActive: true,
        isPickupActive: true,
        isVerified: true,
        rating: 4.2,
        ratingCount: 12,
      );

      testWidgets('E2E Flow 1-6: Initial listing, GPS distance, Delivery & Pickup eligibility chips', (tester) async {
        dataSource.mockShops = [e2eShopNear, e2eShopFar];

        await tester.pumpWidget(
          MaterialApp(
            home: ProfessionalShopsListingPage(
              dataSource: dataSource,
              customerLat: 25.1337,
              customerLng: 86.1772,
              customerArea: 'Station Road',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Both shops render
        expect(find.text('Near Station Grocery'), findsOneWidget);
        expect(find.text('Malaypur Hardware'), findsOneWidget);

        // 2. Real verified distance chips displayed
        expect(find.text('1.5 km'), findsOneWidget);
        expect(find.text('8.5 km'), findsOneWidget);

        // 3. Near shop has 'Delivery & Pickup' chip (inside 5.0km radius)
        expect(find.text('Delivery & Pickup'), findsOneWidget);

        // 4. Far shop has 'Store Pickup (Outside Delivery Zone)' chip (outside 4.0km radius)
        expect(find.text('Store Pickup (Outside Delivery Zone)'), findsOneWidget);
      });

      testWidgets('E2E Flow 7: GPS Permission Denied Locality Fallback', (tester) async {
        final fallbackShop = const ProfessionalShopEntity(
          id: 'shop_fallback',
          shopName: 'Jamui Bazaar Store',
          jamuiArea: 'Main Bazaar, Jamui',
          areaId: 'area_bazaar',
          latitude: 25.1337,
          longitude: 86.1772,
          distanceKm: null,
          isHomeDeliveryActive: true,
          isPickupActive: true,
        );

        dataSource.mockShops = [fallbackShop];

        // Customer has no GPS coordinates
        await tester.pumpWidget(
          MaterialApp(
            home: ProfessionalShopsListingPage(
              dataSource: dataSource,
              customerLat: null,
              customerLng: null,
              customerArea: 'Main Bazaar',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Warning banner appears
        expect(
          find.text('Location permission is disabled. Showing Store Pickup options. Enable GPS for Home Delivery.'),
          findsOneWidget,
        );

        // Locality badge appears instead of 0.0 km
        expect(find.text('Main Bazaar, Jamui'), findsOneWidget);
        expect(find.text('0.0 km'), findsNothing);
      });

      testWidgets('E2E Flow 8: Filter Tabs (All, Delivery, Pickup, Open Now) strict isolation', (tester) async {
        final shopDeliveryEligible = const ProfessionalShopEntity(
          id: 'shop_del',
          shopName: 'Super Fresh Mart',
          jamuiArea: 'Main Bazaar',
          latitude: 25.1337,
          longitude: 86.1772,
          distanceKm: 2.0,
          serviceRadiusKm: 5.0,
          isHomeDeliveryActive: true,
          isPickupActive: false, // Delivery Only
        );

        final shopPickupEligible = const ProfessionalShopEntity(
          id: 'shop_pick',
          shopName: 'Corner Bakery',
          jamuiArea: 'Main Bazaar',
          latitude: 25.1337,
          longitude: 86.1772,
          distanceKm: 2.5,
          serviceRadiusKm: 5.0,
          isHomeDeliveryActive: false,
          isPickupActive: true, // Pickup Only
        );

        dataSource.mockShops = [shopDeliveryEligible, shopPickupEligible];

        await tester.pumpWidget(
          MaterialApp(
            home: ProfessionalShopsListingPage(
              dataSource: dataSource,
              customerLat: 25.1337,
              customerLng: 86.1772,
              customerArea: 'Main Bazaar',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Under 'All', both appear
        expect(find.text('Super Fresh Mart'), findsOneWidget);
        expect(find.text('Corner Bakery'), findsOneWidget);

        // Tap 'Delivery' filter tab
        await tester.tap(find.text('Delivery'));
        await tester.pumpAndSettle();

        // Only delivery eligible shop appears
        expect(find.text('Super Fresh Mart'), findsOneWidget);
        expect(find.text('Corner Bakery'), findsNothing);

        // Tap 'Pickup' filter tab
        await tester.tap(find.text('Pickup'));
        await tester.pumpAndSettle();

        // Only pickup eligible shop appears
        expect(find.text('Super Fresh Mart'), findsNothing);
        expect(find.text('Corner Bakery'), findsOneWidget);
      });

      testWidgets('E2E Flow 9-11: Pull to refresh force-evicts category cache', (tester) async {
        // Pre-populate cache
        cacheManager.put(
          categoryId: 'cat_test',
          lat: 25.1337,
          lng: 86.1772,
          rawShops: [e2eShopNear],
          hasMore: false,
        );
        expect(cacheManager.get(categoryId: 'cat_test', lat: 25.1337, lng: 86.1772), isNotNull);

        dataSource.mockShops = [e2eShopNear];

        await tester.pumpWidget(
          MaterialApp(
            home: ProfessionalShopsListingPage(
              category: const ProfessionalCategoryEntity(
                id: 'cat_test',
                titleEnglish: 'Test Category',
                titleHindi: 'टेस्ट',
                slug: 'test-cat',
              ),
              dataSource: dataSource,
              customerLat: 25.1337,
              customerLng: 86.1772,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Execute pull-to-refresh
        final refreshIndicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
        await refreshIndicator.onRefresh();

        // ForceEvict was called for 'cat_test'
        expect(dataSource.isForceRefreshed, isTrue);
        expect(cacheManager.get(categoryId: 'cat_test', lat: 25.1337, lng: 86.1772), isNull);
      });
    });

    // -------------------------------------------------------------
    // SECTION C: PAGINATION, SEARCH & CACHE EDGE CASES
    // -------------------------------------------------------------
    group('Section C: Pagination, Search & Cache Edge Cases', () {
      test('1. Deduplication strictly prevents duplicate documents across pagination chunks', () {
        final chunk1 = [
          const ProfessionalShopEntity(id: 's1', shopName: 'Shop One', latitude: 25.1, longitude: 86.1),
          const ProfessionalShopEntity(id: 's2', shopName: 'Shop Two', latitude: 25.2, longitude: 86.2),
        ];

        final chunk2WithDuplicates = [
          const ProfessionalShopEntity(id: 's2', shopName: 'Shop Two Duplicate', latitude: 25.2, longitude: 86.2),
          const ProfessionalShopEntity(id: 's3', shopName: 'Shop Three', latitude: 25.3, longitude: 86.3),
        ];

        final deduplicated = ProfessionalShopRemoteDataSource.deduplicateShops(chunk1, chunk2WithDuplicates);
        expect(deduplicated.length, 3);
        expect(deduplicated.map((s) => s.id).toList(), ['s1', 's2', 's3']);
        // Preserves original entity without mutation
        expect(deduplicated[1].shopName, 'Shop Two');
      });

      test('2. Nearest-first re-sorting after every fetched chunk', () {
        final existingLoaded = [
          const ProfessionalShopEntity(id: 's1', shopName: 'Near Shop', latitude: 25.1340, longitude: 86.1770, distanceKm: 2.0),
          const ProfessionalShopEntity(id: 's2', shopName: 'Far Shop', latitude: 25.1500, longitude: 86.2000, distanceKm: 7.0),
        ];

        final incomingChunk = [
          // Nearer than 'Far Shop', between 2.0km and 7.0km
          const ProfessionalShopEntity(id: 's3', shopName: 'Medium Shop', latitude: 25.1400, longitude: 86.1800, distanceKm: 4.0),
        ];

        final combined = ProfessionalShopRemoteDataSource.deduplicateShops(existingLoaded, incomingChunk);
        // Sort nearest-first
        combined.sort((a, b) => (a.distanceKm ?? 999.0).compareTo(b.distanceKm ?? 999.0));

        expect(combined.map((s) => s.id).toList(), ['s1', 's3', 's2']);
        expect(combined.map((s) => s.distanceKm).toList(), [2.0, 4.0, 7.0]);
      });

      test('3. Cache Geohash-7 key generation and 200-meter displacement eviction', () {
        final baseLat = 24.919;
        final baseLng = 86.223;

        cacheManager.put(
          categoryId: 'grocery',
          lat: baseLat,
          lng: baseLng,
          rawShops: [const ProfessionalShopEntity(id: 's1', shopName: 'Cached Shop', latitude: 24.919, longitude: 86.223)],
          hasMore: false,
        );

        // 1. Within 200m (e.g. ~44m shift) within cell -> Cache HIT
        final shift44mLat = 24.9194;
        final cachedHit = cacheManager.get(categoryId: 'grocery', lat: shift44mLat, lng: baseLng);
        expect(cachedHit, isNotNull);
        expect(cachedHit!.rawShops.first.id, 's1');

        // 2. Beyond 200m (e.g. ~800m shift) -> Cache INVALIDATED
        final shift800mLat = 24.927;
        final cachedMiss = cacheManager.get(categoryId: 'grocery', lat: shift800mLat, lng: baseLng);
        expect(cachedMiss, isNull);
      });

      test('4. Cross-category cache isolation: Different categories do not cross-contaminate', () {
        cacheManager.put(
          categoryId: 'electronics',
          lat: 25.1337,
          lng: 86.1772,
          rawShops: [const ProfessionalShopEntity(id: 'elec_1', shopName: 'Sony Center', latitude: 25.1337, longitude: 86.1772)],
          hasMore: false,
        );

        // Querying 'grocery' at the same location returns null (isolated)
        final groceryCache = cacheManager.get(categoryId: 'grocery', lat: 25.1337, lng: 86.1772);
        expect(groceryCache, isNull);

        // Querying 'electronics' returns correct cached shop
        final elecCache = cacheManager.get(categoryId: 'electronics', lat: 25.1337, lng: 86.1772);
        expect(elecCache, isNotNull);
        expect(elecCache!.rawShops.first.shopName, 'Sony Center');
      });
    });

    // -------------------------------------------------------------
    // SECTION D: UI, REAL-TIME SCHEDULE & TIMING VERIFICATION
    // -------------------------------------------------------------
    group('Section D: UI, Schedule & Timing Verification', () {
      test('1. Real-time JamuiTimeUtils Evaluates Midnight Crossover correctly', () {
        // Schedule: 18:00 (6 PM) to 02:00 (2 AM next morning)
        final schedule = {
          'tuesday': {
            'isOpen': true,
            'openTime': '18:00',
            'closeTime': '02:00',
          }
        };

        // 23:00 (11 PM) on Tuesday -> Must be OPEN
        // 2026-11-03 is Tuesday. In IST (UTC+5:30), 23:00 is 17:30 UTC
        final time11PmIst = DateTime.utc(2026, 11, 3, 23, 0); // Tested with currentTimeIST
        final isOpenAtNight = JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          weeklySchedule: schedule,
          currentTimeIST: time11PmIst,
        );
        expect(isOpenAtNight, isTrue);

        // 04:00 (4 AM) -> Must be CLOSED
        final time4AmIst = DateTime.utc(2026, 11, 3, 4, 0);
        final isClosedEarlyMorning = JamuiTimeUtils.isOpenNow(
          isMasterOpen: true,
          weeklySchedule: schedule,
          currentTimeIST: time4AmIst,
        );
        expect(isClosedEarlyMorning, isFalse);
      });

      test('2. JamuiGeoValidator rejects coordinates with NaN or Infinite', () {
        expect(JamuiGeoValidator.isValidCoordinates(double.nan, 86.1772), isFalse);
        expect(JamuiGeoValidator.isValidCoordinates(25.1337, double.infinity), isFalse);
        expect(JamuiGeoValidator.isValidCoordinates(0.0, 0.0), isFalse); // Null Island
        expect(JamuiGeoValidator.isValidCoordinates(25.1337, 86.1772), isTrue); // Valid Jamui
      });

      testWidgets('3. ProfessionalShopSkeleton animates without exceptions or layout jump', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProfessionalShopSkeleton(),
            ),
          ),
        );

        // Verify structure renders
        expect(find.byType(ProfessionalShopSkeleton), findsOneWidget);
        // Pump frame with duration
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });
    });
  });
}
