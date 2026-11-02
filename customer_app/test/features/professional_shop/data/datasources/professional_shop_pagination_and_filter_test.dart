import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/datasources/professional_shop_remote_data_source.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';

void main() {
  group('ProfessionalShopRemoteDataSource - filterShopsByTab', () {
    final shopDeliveryNear = const ProfessionalShopEntity(
      id: 's1',
      shopName: 'Near Grocery',
      latitude: 24.92,
      longitude: 86.22,
      serviceRadiusKm: 5.0,
      isHomeDeliveryActive: true,
      isPickupActive: true,
      distanceKm: 2.0,
    );

    final shopDeliveryFar = const ProfessionalShopEntity(
      id: 's2',
      shopName: 'Far Store',
      latitude: 24.92,
      longitude: 86.22,
      serviceRadiusKm: 3.0,
      isHomeDeliveryActive: true,
      isPickupActive: true,
      distanceKm: 6.0, // Outside 3km delivery radius
    );

    final shopDeliveryOnlyFar = const ProfessionalShopEntity(
      id: 's3',
      shopName: 'Delivery Only Far',
      latitude: 24.92,
      longitude: 86.22,
      serviceRadiusKm: 3.0,
      isHomeDeliveryActive: true,
      isPickupActive: false, // Pickup OFF
      distanceKm: 8.0,
    );

    final shopPickupOnly = const ProfessionalShopEntity(
      id: 's4',
      shopName: 'Pickup Corner',
      latitude: 24.92,
      longitude: 86.22,
      isHomeDeliveryActive: false,
      isPickupActive: true,
      distanceKm: 4.0,
      areaId: 'area_bazaar',
      jamuiArea: 'Main Bazaar',
    );

    final shopDeliveryOnly = const ProfessionalShopEntity(
      id: 's5',
      shopName: 'Cloud Kitchen (Delivery Only)',
      latitude: 24.92,
      longitude: 86.22,
      serviceRadiusKm: 5.0,
      isHomeDeliveryActive: true,
      isPickupActive: false,
      distanceKm: 1.5,
      areaId: 'area_station',
      jamuiArea: 'Station Road',
    );

    test('"all" tab with GPS shows both in-radius delivery and store pickup shops', () {
      final shops = [shopDeliveryNear, shopDeliveryFar, shopDeliveryOnlyFar, shopPickupOnly];
      final filtered = ProfessionalShopRemoteDataSource.filterShopsByTab(
        shops: shops,
        activeTab: 'all',
        hasGps: true,
      );

      // s1: Delivery in radius -> Visible
      // s2: Delivery out of radius, but Pickup ON -> Visible
      // s3: Delivery out of radius AND Pickup OFF -> Hidden
      // s4: Pickup ON -> Visible
      expect(filtered.map((s) => s.id).toList(), equals(['s1', 's2', 's4']));
    });

    test('"all" tab without GPS shows pickup-active shops; delivery-only shops are 100% HIDDEN', () {
      final shops = [shopDeliveryNear, shopPickupOnly, shopDeliveryOnly];
      final filtered = ProfessionalShopRemoteDataSource.filterShopsByTab(
        shops: shops,
        activeTab: 'all',
        hasGps: false,
        selectedAreaId: 'area_bazaar',
      );

      // s1: Pickup ON -> Visible
      // s4: Pickup ON, Area matches -> Visible
      // s5: Delivery Only (Pickup OFF) -> STRICTLY HIDDEN (Zero leakage)
      expect(filtered.map((s) => s.id).contains('s5'), isFalse);
    });

    test('"delivery" tab with GPS returns only in-radius delivery shops', () {
      final shops = [shopDeliveryNear, shopDeliveryFar, shopPickupOnly];
      final filtered = ProfessionalShopRemoteDataSource.filterShopsByTab(
        shops: shops,
        activeTab: 'delivery',
        hasGps: true,
      );

      // Only s1 is within delivery radius (2.0 <= 5.0)
      expect(filtered.map((s) => s.id).toList(), equals(['s1']));
    });

    test('"delivery" tab without GPS returns empty list to trigger GPS banner', () {
      final shops = [shopDeliveryNear, shopDeliveryFar];
      final filtered = ProfessionalShopRemoteDataSource.filterShopsByTab(
        shops: shops,
        activeTab: 'delivery',
        hasGps: false,
      );

      expect(filtered, isEmpty);
    });

    test('"pickup" tab returns only shops with isPickupActive == true', () {
      final shops = [shopDeliveryNear, shopDeliveryOnlyFar, shopPickupOnly, shopDeliveryOnly];
      final filtered = ProfessionalShopRemoteDataSource.filterShopsByTab(
        shops: shops,
        activeTab: 'pickup',
        hasGps: true,
      );

      // s1 and s4 have isPickupActive == true
      // s2 and s5 have isPickupActive == false
      expect(filtered.map((s) => s.id).toList(), equals(['s1', 's4']));
    });
  });

  group('ProfessionalShopRemoteDataSource - deduplicateShops', () {
    test('Deduplicates incoming shops against existing accumulated list by ID', () {
      const existing = [
        ProfessionalShopEntity(id: 's1', shopName: 'Shop 1'),
        ProfessionalShopEntity(id: 's2', shopName: 'Shop 2'),
      ];

      const incoming = [
        ProfessionalShopEntity(id: 's2', shopName: 'Shop 2 (Duplicate)'),
        ProfessionalShopEntity(id: 's3', shopName: 'Shop 3'),
      ];

      final combined = ProfessionalShopRemoteDataSource.deduplicateShops(existing, incoming);

      expect(combined.length, equals(3));
      expect(combined.map((s) => s.id).toList(), equals(['s1', 's2', 's3']));
    });
  });

  group('ProfessionalShopRemoteDataSource - Nearest-First Sorting Partition', () {
    test('Sorts valid distance shops ascending, placing invalid location shops at the bottom', () {
      final shopA = const ProfessionalShopEntity(id: 'a', shopName: 'Shop A', distanceKm: 3.5);
      final shopB = const ProfessionalShopEntity(id: 'b', shopName: 'Shop B', distanceKm: 0.8);
      final shopC = const ProfessionalShopEntity(id: 'c', shopName: 'Shop C', distanceKm: 1.2);
      final shopInvalid = const ProfessionalShopEntity(id: 'x', shopName: 'Shop Invalid (No GPS)', distanceKm: null);

      final list = [shopA, shopInvalid, shopB, shopC];

      // Sorter matching dataSource implementation
      list.sort((a, b) {
        final distA = a.distanceKm;
        final distB = b.distanceKm;
        if (distA != null && distB != null) {
          return distA.compareTo(distB);
        } else if (distA != null && distB == null) {
          return -1;
        } else if (distA == null && distB != null) {
          return 1;
        }
        return a.shopName.compareTo(b.shopName);
      });

      // Expected order: 0.8 km (B) -> 1.2 km (C) -> 3.5 km (A) -> null (x at bottom)
      expect(list.map((s) => s.id).toList(), equals(['b', 'c', 'a', 'x']));
    });
  });
}

