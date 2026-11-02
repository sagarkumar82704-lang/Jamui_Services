import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';

void main() {
  group('ProfessionalShopEntity - Fail-Closed Service Radius', () {
    test('Evaluates missing, null, zero, negative and NaN radius strictly to null', () {
      final mapNull = {'shopName': 'Test Shop'};
      final shopNull = ProfessionalShopEntity.fromMap(mapNull, 's1');
      expect(shopNull.serviceRadiusKm, isNull);

      final mapZero = {'shopName': 'Test Shop', 'serviceRadiusKm': 0.0};
      final shopZero = ProfessionalShopEntity.fromMap(mapZero, 's2');
      expect(shopZero.serviceRadiusKm, isNull);

      final mapNegative = {'shopName': 'Test Shop', 'serviceRadiusKm': -5.0};
      final shopNegative = ProfessionalShopEntity.fromMap(mapNegative, 's3');
      expect(shopNegative.serviceRadiusKm, isNull);

      final mapNan = {'shopName': 'Test Shop', 'serviceRadiusKm': double.nan};
      final shopNan = ProfessionalShopEntity.fromMap(mapNan, 's4');
      expect(shopNan.serviceRadiusKm, isNull);
    });

    test('Parses valid positive radius and clamps to maximum 25 km', () {
      final mapValid = {'shopName': 'Test Shop', 'serviceRadiusKm': 7.5};
      final shopValid = ProfessionalShopEntity.fromMap(mapValid, 's5');
      expect(shopValid.serviceRadiusKm, equals(7.5));

      final mapLarge = {'shopName': 'Test Shop', 'serviceRadiusKm': 45.0};
      final shopLarge = ProfessionalShopEntity.fromMap(mapLarge, 's6');
      expect(shopLarge.serviceRadiusKm, equals(25.0)); // Clamped to 25.0
    });

    test('Supports legacy deliveryRadiusKm fallback when serviceRadiusKm is absent', () {
      final mapLegacy = {'shopName': 'Test Shop', 'deliveryRadiusKm': 6.0};
      final shopLegacy = ProfessionalShopEntity.fromMap(mapLegacy, 's7');
      expect(shopLegacy.serviceRadiusKm, equals(6.0));
    });
  });

  group('ProfessionalShopEntity - Delivery and Pickup Eligibility', () {
    test('isDeliveryEligibleForDistance returns true only within radius and valid GPS', () {
      final shop = ProfessionalShopEntity(
        id: 's1',
        shopName: 'Fresh Mart',
        latitude: 24.92,
        longitude: 86.22,
        serviceRadiusKm: 5.0,
        isHomeDeliveryActive: true,
        isPickupActive: true,
      );

      // Distance within radius (3.0 km <= 5.0 km)
      expect(shop.isDeliveryEligibleForDistance(3.0), isTrue);

      // Distance at exact boundary (5.0 km <= 5.0 km)
      expect(shop.isDeliveryEligibleForDistance(5.0), isTrue);

      // Distance beyond radius (5.1 km > 5.0 km)
      expect(shop.isDeliveryEligibleForDistance(5.1), isFalse);

      // Null distance
      expect(shop.isDeliveryEligibleForDistance(null), isFalse);
    });

    test('isDeliveryEligibleForDistance returns false when coordinates are invalid sentinel (0,0)', () {
      final shopInvalidCoords = ProfessionalShopEntity(
        id: 's2',
        shopName: 'Ghost Shop',
        latitude: 0.0,
        longitude: 0.0, // Sentinel Null Island
        serviceRadiusKm: 5.0,
        isHomeDeliveryActive: true,
      );

      expect(shopInvalidCoords.hasValidLocation, isFalse);
      expect(shopInvalidCoords.isDeliveryEligibleForDistance(2.0), isFalse);
    });

    test('isDeliveryEligibleForDistance returns false when isHomeDeliveryActive is false', () {
      final shopDeliveryOff = ProfessionalShopEntity(
        id: 's3',
        shopName: 'Pickup Only Store',
        latitude: 24.92,
        longitude: 86.22,
        serviceRadiusKm: 5.0,
        isHomeDeliveryActive: false,
      );

      expect(shopDeliveryOff.isDeliveryEligibleForDistance(1.0), isFalse);
    });

    test('isPickupEligible depends strictly on isPickupActive, independent of distance or radius', () {
      final shopPickupOn = ProfessionalShopEntity(
        id: 's4',
        shopName: 'Pickup Shop',
        latitude: 24.92,
        longitude: 86.22,
        serviceRadiusKm: 2.0,
        isPickupActive: true,
      );
      expect(shopPickupOn.isPickupEligible, isTrue);

      final shopPickupOff = ProfessionalShopEntity(
        id: 's5',
        shopName: 'Delivery Only Shop',
        latitude: 24.92,
        longitude: 86.22,
        serviceRadiusKm: 10.0,
        isPickupActive: false,
      );
      expect(shopPickupOff.isPickupEligible, isFalse);
    });
  });

  group('ProfessionalShopEntity - Subscription Expiry Validation Gate', () {
    test('isSubscriptionValid requires active flag AND unexpired timestamp', () {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final pastDate = DateTime.now().subtract(const Duration(days: 1));

      // Active + Future Expiry -> Valid
      final validShop = ProfessionalShopEntity(
        id: 's1',
        shopName: 'Live Shop',
        isSubscriptionActive: true,
        subscriptionExpiresAt: futureDate,
      );
      expect(validShop.isSubscriptionValid, isTrue);

      // Active + Past Expiry -> Invalid (Expired pre-scheduler)
      final expiredShop = ProfessionalShopEntity(
        id: 's2',
        shopName: 'Expired Shop',
        isSubscriptionActive: true,
        subscriptionExpiresAt: pastDate,
      );
      expect(expiredShop.isSubscriptionValid, isFalse);

      // Inactive flag -> Invalid regardless of expiry
      final inactiveShop = ProfessionalShopEntity(
        id: 's3',
        shopName: 'Inactive Shop',
        isSubscriptionActive: false,
        subscriptionExpiresAt: futureDate,
      );
      expect(inactiveShop.isSubscriptionValid, isFalse);
    });

    test('Parses subscriptionExpiresAt from Firestore Timestamp, String, or DateTime', () {
      final targetDate = DateTime(2027, 1, 1);
      final ts = Timestamp.fromDate(targetDate);

      final mapTs = {'shopName': 'Shop A', 'subscriptionExpiresAt': ts};
      expect(ProfessionalShopEntity.fromMap(mapTs, 'a').subscriptionExpiresAt, equals(targetDate));

      final mapStr = {'shopName': 'Shop B', 'planExpiryDate': targetDate.toIso8601String()};
      expect(ProfessionalShopEntity.fromMap(mapStr, 'b').subscriptionExpiresAt, equals(targetDate));

      // Backward compatible alias
      expect(ProfessionalShopEntity.fromMap(mapTs, 'a').subscriptionExpiry, equals(targetDate));
    });
  });

  group('ProfessionalShopEntity - Structured Location & Schedule Parsing', () {
    test('Parses areaId and districtId accurately', () {
      final map = {
        'shopName': 'Jewellers',
        'areaId': 'area_jamui_bazaar',
        'districtId': 'dist_jamui',
      };
      final shop = ProfessionalShopEntity.fromMap(map, 'j1');
      expect(shop.areaId, equals('area_jamui_bazaar'));
      expect(shop.districtId, equals('dist_jamui'));
    });

    test('Parses weeklySchedule accurately', () {
      final map = {
        'shopName': 'Bakery',
        'weeklySchedule': {
          'monday': {'isOpen': true, 'openTime': '08:00 AM', 'closeTime': '09:00 PM'},
        },
      };
      final shop = ProfessionalShopEntity.fromMap(map, 'b1');
      expect(shop.weeklySchedule, isNotNull);
      expect(shop.weeklySchedule!['monday']['isOpen'], isTrue);
    });
  });
}

