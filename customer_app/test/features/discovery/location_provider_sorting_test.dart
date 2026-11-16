import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_provider_entity.dart';
import 'package:apna_jamui_customer/features/discovery/data/models/service_provider_model.dart';
import 'package:apna_jamui_customer/features/discovery/data/datasources/firebase_customer_discovery_remote_data_source.dart';

void main() {
  group('Jamui Services Customer App — Location-Based Nearest Provider Sorting Tests', () {
    // Reference coordinates in Jamui district, Bihar
    // Jamui town center: ~24.9213° N, 86.2238° E
    const double customerLat = 24.9213;
    const double customerLng = 86.2238;

    // Helper to create a valid approved provider
    ServiceProviderModel createProvider({
      required String id,
      required String name,
      required double lat,
      required double lng,
      required double radiusKm,
      String village = '',
      String block = '',
      String jamuiArea = 'जमुई',
      double rating = 4.8,
      int experienceYears = 5,
      String status = 'approved',
      String kycStatus = 'approved',
      bool isVerified = true,
      bool isAvailable = true,
      bool paymentVerified = true,
      bool isSubscriptionActive = true,
      DateTime? subscriptionExpiry,
    }) {
      return ServiceProviderModel(
        id: id,
        fullName: name,
        businessName: '$name Business',
        phoneNumber: '+919876543210',
        categoryId: 'cat_electrician',
        categoryTitle: 'इलेक्ट्रीशियन (Electrician)',
        visitingCharge: 150.0,
        experienceYears: experienceYears,
        jamuiArea: jamuiArea,
        village: village,
        block: block,
        latitude: lat,
        longitude: lng,
        serviceRadiusKm: radiusKm,
        rating: rating,
        ratingCount: 15,
        status: status,
        kycStatus: kycStatus,
        isVerified: isVerified,
        isAvailable: isAvailable,
        paymentVerified: paymentVerified,
        isSubscriptionActive: isSubscriptionActive,
        subscriptionExpiry: subscriptionExpiry ?? DateTime.now().add(const Duration(days: 60)),
      );
    }

    test('TEST 1: Nearest provider comes first (ascending distance order)', () {
      // Provider A: ~500m away (24.9250, 86.2238)
      final providerClose = createProvider(
        id: 'prov_close',
        name: 'Nearby Ram',
        lat: 24.9250,
        lng: 86.2238,
        radiusKm: 10.0,
        rating: 4.5, // Slightly lower rating
      );

      // Provider B: ~3.5km away (24.9500, 86.2300)
      final providerMid = createProvider(
        id: 'prov_mid',
        name: 'Mid-distance Shyam',
        lat: 24.9500,
        lng: 86.2300,
        radiusKm: 10.0,
        rating: 5.0, // Higher rating but farther
      );

      // Provider C: ~7.0km away (24.9800, 86.2400)
      final providerFar = createProvider(
        id: 'prov_far',
        name: 'Far Hari',
        lat: 24.9800,
        lng: 86.2400,
        radiusKm: 10.0,
        rating: 4.9,
      );

      final dataSource = FirebaseCustomerDiscoveryRemoteDataSource();
      final processed = dataSource.filterAndSortProviders(
        providers: [providerFar, providerClose, providerMid],
        customerLatitude: customerLat,
        customerLongitude: customerLng,
      );

      expect(processed.length, equals(3));
      expect(processed[0].id, equals('prov_close'), reason: 'Nearest provider must be ranked #1');
      expect(processed[1].id, equals('prov_mid'), reason: 'Second nearest provider must be ranked #2');
      expect(processed[2].id, equals('prov_far'), reason: 'Farthest provider must be ranked #3');

      expect(processed[0].distanceKm! < processed[1].distanceKm!, isTrue);
      expect(processed[1].distanceKm! < processed[2].distanceKm!, isTrue);
    });

    test('TEST 2: Provider outside configured service radius is strictly EXCLUDED', () {
      // Provider A: ~3.5km away with 5.0km service radius (ELIGIBLE)
      final providerWithinRadius = createProvider(
        id: 'prov_inside',
        name: 'Inside Radius Provider',
        lat: 24.9500,
        lng: 86.2300,
        radiusKm: 5.0,
      );

      // Provider B: ~12km away with 10.0km service radius (OUTSIDE RADIUS -> EXCLUDED)
      final providerOutsideRadius = createProvider(
        id: 'prov_outside',
        name: 'Outside Radius Provider',
        lat: 25.0200,
        lng: 86.2500,
        radiusKm: 10.0,
      );

      final dataSource = FirebaseCustomerDiscoveryRemoteDataSource();
      final processed = dataSource.filterAndSortProviders(
        providers: [providerWithinRadius, providerOutsideRadius],
        customerLatitude: customerLat,
        customerLongitude: customerLng,
      );

      expect(processed.any((p) => p.id == 'prov_inside'), isTrue);
      expect(processed.any((p) => p.id == 'prov_outside'), isFalse,
          reason: 'Provider outside service radius must be excluded');
    });

    test('TEST 3: Pending, rejected, suspended, or inactive providers are excluded', () {
      final validProvider = createProvider(
        id: 'prov_valid',
        name: 'Valid Approved',
        lat: 24.9250,
        lng: 86.2238,
        radiusKm: 10.0,
      );

      final pendingProvider = createProvider(
        id: 'prov_pending',
        name: 'Pending Review',
        lat: 24.9250,
        lng: 86.2238,
        radiusKm: 10.0,
        status: 'pendingReview',
        kycStatus: 'pendingReview',
        isVerified: false,
      );

      final rejectedProvider = createProvider(
        id: 'prov_rejected',
        name: 'Rejected Provider',
        lat: 24.9250,
        lng: 86.2238,
        radiusKm: 10.0,
        status: 'rejected',
        kycStatus: 'rejected',
      );

      final unpaidProvider = createProvider(
        id: 'prov_unpaid',
        name: 'Unpaid Subscription',
        lat: 24.9250,
        lng: 86.2238,
        radiusKm: 10.0,
        paymentVerified: false,
        isSubscriptionActive: false,
      );

      final dataSource = FirebaseCustomerDiscoveryRemoteDataSource();
      final processed = dataSource.filterAndSortProviders(
        providers: [validProvider, pendingProvider, rejectedProvider, unpaidProvider],
        customerLatitude: customerLat,
        customerLongitude: customerLng,
      );

      expect(processed.length, equals(1));
      expect(processed.first.id, equals('prov_valid'));
    });

    test('TEST 4: Provider with missing/invalid coordinates (0.0, 0.0) or invalid radius is excluded from nearest results', () {
      final validProvider = createProvider(
        id: 'prov_valid',
        name: 'Valid Provider',
        lat: 24.9250,
        lng: 86.2238,
        radiusKm: 10.0,
      );

      final zeroCoordsProvider = createProvider(
        id: 'prov_zero_coords',
        name: 'Zero Coords Provider',
        lat: 0.0,
        lng: 0.0,
        radiusKm: 10.0,
      );

      final invalidRadiusProvider = createProvider(
        id: 'prov_bad_radius',
        name: 'Negative Radius Provider',
        lat: 24.9250,
        lng: 86.2238,
        radiusKm: -5.0,
      );

      final dataSource = FirebaseCustomerDiscoveryRemoteDataSource();
      final processed = dataSource.filterAndSortProviders(
        providers: [validProvider, zeroCoordsProvider, invalidRadiusProvider],
        customerLatitude: customerLat,
        customerLongitude: customerLng,
      );

      expect(processed.length, equals(1));
      expect(processed.first.id, equals('prov_valid'));
    });

    test('TEST 5: Location permission denied / null coordinates fallback gracefully without fake distances', () {
      final provider1 = createProvider(
        id: 'prov_1',
        name: 'Top Rated Ram',
        lat: 24.9250,
        lng: 86.2238,
        radiusKm: 10.0,
        rating: 4.9,
        experienceYears: 6,
      );

      final provider2 = createProvider(
        id: 'prov_2',
        name: 'Normal Rated Shyam',
        lat: 24.9300,
        lng: 86.2250,
        radiusKm: 10.0,
        rating: 4.2,
        experienceYears: 2,
      );

      final dataSource = FirebaseCustomerDiscoveryRemoteDataSource();
      // Customer location is NULL (denied / failed)
      final processed = dataSource.filterAndSortProviders(
        providers: [provider2, provider1],
        customerLatitude: null,
        customerLongitude: null,
      );

      expect(processed.length, equals(2));
      // Strictly no fake distance badge
      expect(processed[0].distanceKm, isNull);
      expect(processed[1].distanceKm, isNull);

      // Fallback sorted by rating descending
      expect(processed[0].id, equals('prov_1'));
      expect(processed[1].id, equals('prov_2'));
    });

    test('TEST 6: Pagination merges preserve overall global nearest-first order', () {
      final page1Providers = [
        createProvider(id: 'p_1000m', name: '1000m', lat: 24.9303, lng: 86.2238, radiusKm: 15.0)
            .copyWith(distanceKm: 1.0),
        createProvider(id: 'p_3000m', name: '3000m', lat: 24.9483, lng: 86.2238, radiusKm: 15.0)
            .copyWith(distanceKm: 3.0),
      ];

      // Next page returns an item that is closer than p_3000m (e.g. 1.8km) and one farther (5.0km)
      final page2Providers = [
        createProvider(id: 'p_1800m', name: '1800m', lat: 24.9375, lng: 86.2238, radiusKm: 15.0)
            .copyWith(distanceKm: 1.8),
        createProvider(id: 'p_5000m', name: '5000m', lat: 24.9663, lng: 86.2238, radiusKm: 15.0)
            .copyWith(distanceKm: 5.0),
      ];

      final existingIds = page1Providers.map((p) => p.id).toSet();
      final newUnique = page2Providers.where((p) => !existingIds.contains(p.id)).toList();
      final merged = List<ServiceProviderEntity>.from(page1Providers)..addAll(newUnique);

      merged.sort((a, b) {
        final distA = a.distanceKm ?? double.infinity;
        final distB = b.distanceKm ?? double.infinity;
        final cmp = distA.compareTo(distB);
        if (cmp != 0) return cmp;
        return b.rating.compareTo(a.rating);
      });

      expect(merged.map((p) => p.id).toList(), equals(['p_1000m', 'p_1800m', 'p_3000m', 'p_5000m']));
      expect(merged[0].distanceKm, equals(1.0));
      expect(merged[1].distanceKm, equals(1.8));
      expect(merged[2].distanceKm, equals(3.0));
      expect(merged[3].distanceKm, equals(5.0));
    });

    test('TEST 7: 3-Tier Priority Matching — (1) Same Village + Block -> (2) Same Block -> (3) GPS Distance', () {
      // Customer in Village: "Garsanda", Block: "Khaira" (24.8550, 86.2200)
      const custLat = 24.8550;
      const custLng = 86.2200;

      // Provider 1: Different block ("Jamui"), very close (~1.2km away) -> Tier 3
      final provOtherBlockClose = createProvider(
        id: 'prov_tier3_gps',
        name: 'Other Block Close',
        lat: 24.8650,
        lng: 86.2200,
        radiusKm: 15.0,
        village: 'Maharajganj',
        block: 'Jamui',
      );

      // Provider 2: Same block ("Khaira"), different village ("pakri"), ~2.0km away -> Tier 2
      final provSameBlock = createProvider(
        id: 'prov_tier2_block',
        name: 'Same Block Provider',
        lat: 24.8400,
        lng: 86.2150,
        radiusKm: 15.0,
        village: 'Pakri',
        block: 'Khaira',
      );

      // Provider 3: Same Village ("Garsanda") + Same Block ("Khaira"), ~2.5km away -> Tier 1
      final provSameVillageAndBlock = createProvider(
        id: 'prov_tier1_village_block',
        name: 'Same Village & Block Provider',
        lat: 24.8350,
        lng: 86.2180,
        radiusKm: 15.0,
        village: 'Garsanda',
        block: 'Khaira',
      );

      final dataSource = FirebaseCustomerDiscoveryRemoteDataSource();
      final processed = dataSource.filterAndSortProviders(
        providers: [provOtherBlockClose, provSameBlock, provSameVillageAndBlock],
        customerLatitude: custLat,
        customerLongitude: custLng,
        customerVillage: 'Garsanda',
        customerBlock: 'Khaira',
      );

      expect(processed.length, equals(3));
      expect(processed[0].id, equals('prov_tier1_village_block'),
          reason: 'Priority 1: Same Village + Same Block must come first');
      expect(processed[1].id, equals('prov_tier2_block'),
          reason: 'Priority 2: Same Block must come second');
      expect(processed[2].id, equals('prov_tier3_gps'),
          reason: 'Priority 3: Other nearby eligible providers come third');
    });

    test('TEST 8: Same Block matching (Priority 2) when customer Village is missing, sorted by distance within block', () {
      const custLat = 24.7733;
      const custLng = 86.3778;

      final jhajhaBlockFarther = createProvider(
        id: 'jhajha_farther',
        name: 'Jhajha Block 3km',
        lat: 24.7950,
        lng: 86.3800,
        radiusKm: 15.0,
        block: 'Jhajha',
      );

      final jhajhaBlockCloser = createProvider(
        id: 'jhajha_closer',
        name: 'Jhajha Block 1km',
        lat: 24.7800,
        lng: 86.3780,
        radiusKm: 15.0,
        block: 'Jhajha',
      );

      final sonoBlockProvider = createProvider(
        id: 'sono_block',
        name: 'Sono Block 1.5km',
        lat: 24.7620,
        lng: 86.3750,
        radiusKm: 15.0,
        block: 'Sono',
      );

      final dataSource = FirebaseCustomerDiscoveryRemoteDataSource();
      final processed = dataSource.filterAndSortProviders(
        providers: [sonoBlockProvider, jhajhaBlockFarther, jhajhaBlockCloser],
        customerLatitude: custLat,
        customerLongitude: custLng,
        customerVillage: '',
        customerBlock: 'Jhajha',
      );

      expect(processed.map((e) => e.id).toList(), equals(['jhajha_closer', 'jhajha_farther', 'sono_block']));
    });

    test('TEST 9: Missing Block/Village fields do not fail discovery and return empty list when no providers are in radius', () {
      final farProvider = createProvider(
        id: 'prov_50km_away',
        name: 'Far Away Provider',
        lat: 25.4000,
        lng: 86.6000,
        radiusKm: 10.0,
      );

      final dataSource = FirebaseCustomerDiscoveryRemoteDataSource();
      final emptyResult = dataSource.filterAndSortProviders(
        providers: [farProvider],
        customerLatitude: customerLat,
        customerLongitude: customerLng,
        customerVillage: '',
        customerBlock: '',
      );

      expect(emptyResult, isEmpty, reason: 'No nearby providers within radius must return clean empty list');
    });
  });
}
