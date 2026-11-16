import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/services/professional_checkout_idempotency_manager.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_order_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/datasources/professional_shop_remote_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Professional Marketplace Checkout Idempotency & Retry Safety Suite', () {
    late ProfessionalCheckoutIdempotencyManager idempotencyManager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      idempotencyManager = ProfessionalCheckoutIdempotencyManager();
    });

    test('1. Generates stable attempt identifier and persists to local storage', () async {
      const customerId = 'cust_sagar_123';
      const shopId = 'shop_jamui_1';
      final items = <ProfessionalOrderItem>[
        const ProfessionalOrderItem(
          productId: 'prod_potato',
          title: 'Potato',
          unit: 'kg',
          price: 15.0,
          quantity: 4,
          total: 60.0,
        ),
      ];

      final fingerprint = ProfessionalCheckoutIdempotencyManager.computeFingerprint(
        shopId: shopId,
        deliveryMethod: 'delivery',
        items: items,
        deliveryAddress: {'address': 'SubCentre, Bela, Jamui'},
      );

      final attempt = await idempotencyManager.getOrCreateAttempt(
        customerId: customerId,
        shopId: shopId,
        payloadFingerprint: fingerprint,
        orderPayload: {'totalAmount': 60.0},
      );

      expect(attempt.isReused, isFalse);
      expect(attempt.hasPayloadMismatch, isFalse);
      expect(attempt.idempotencyKey.startsWith('chk_cust_sagar_123_shop_jamui_1_'), isTrue);

      // Verify persistence in SharedPreferences
      final stored = await idempotencyManager.getUnresolvedAttempt(
        customerId: customerId,
        shopId: shopId,
      );
      expect(stored, isNotNull);
      expect(stored!.idempotencyKey, equals(attempt.idempotencyKey));
      expect(stored.payloadFingerprint, equals(fingerprint));
      expect(stored.isPending, isTrue);
    });

    test('2. Network timeout before or after commit: Same-key retry reuses identical identifier', () async {
      const customerId = 'cust_sagar_123';
      const shopId = 'shop_jamui_1';
      final items = <ProfessionalOrderItem>[
        const ProfessionalOrderItem(
          productId: 'prod_tea',
          variantId: 'var_500g',
          variantTitle: '500g',
          title: 'Tata Tea Gold',
          unit: '500g',
          price: 49.50,
          quantity: 2,
          total: 99.0,
        ),
      ];

      final fingerprint = ProfessionalCheckoutIdempotencyManager.computeFingerprint(
        shopId: shopId,
        deliveryMethod: 'delivery',
        items: items,
        deliveryAddress: {'address': 'Main Market Jamui'},
      );

      // Attempt 1 (e.g. times out)
      final attempt1 = await idempotencyManager.getOrCreateAttempt(
        customerId: customerId,
        shopId: shopId,
        payloadFingerprint: fingerprint,
        orderPayload: {'totalAmount': 99.0},
      );

      // Attempt 2 (Retry from UI after network timeout)
      final attempt2 = await idempotencyManager.getOrCreateAttempt(
        customerId: customerId,
        shopId: shopId,
        payloadFingerprint: fingerprint,
        orderPayload: {'totalAmount': 99.0},
      );

      expect(attempt2.isReused, isTrue);
      expect(attempt2.hasPayloadMismatch, isFalse);
      expect(attempt2.idempotencyKey, equals(attempt1.idempotencyKey),
          reason: 'Retry after timeout must reuse exact same attempt key');
    });

    test('3. App restart after uncertain result preserves pending attempt in SharedPreferences', () async {
      const customerId = 'cust_sagar_123';
      const shopId = 'shop_jamui_1';
      final items = <ProfessionalOrderItem>[
        const ProfessionalOrderItem(
          productId: 'prod_potato',
          title: 'Potato',
          unit: 'kg',
          price: 15.0,
          quantity: 2,
          total: 30.0,
        ),
      ];

      final fingerprint = ProfessionalCheckoutIdempotencyManager.computeFingerprint(
        shopId: shopId,
        deliveryMethod: 'pickup',
        items: items,
      );

      final attempt = await idempotencyManager.getOrCreateAttempt(
        customerId: customerId,
        shopId: shopId,
        payloadFingerprint: fingerprint,
        orderPayload: {'totalAmount': 30.0},
      );

      // Simulate full app restart: create a new manager instance reading from SharedPreferences
      final freshAppIdempotencyManager = ProfessionalCheckoutIdempotencyManager();
      final recoveredAttempt = await freshAppIdempotencyManager.getUnresolvedAttempt(
        customerId: customerId,
        shopId: shopId,
      );

      expect(recoveredAttempt, isNotNull);
      expect(recoveredAttempt!.idempotencyKey, equals(attempt.idempotencyKey));
      expect(recoveredAttempt.payloadFingerprint, equals(fingerprint));
    });

    test('4. Cart modification after uncertain result flags payload mismatch for reconciliation', () async {
      const customerId = 'cust_sagar_123';
      const shopId = 'shop_jamui_1';
      final originalItems = [
        const ProfessionalOrderItem(
          productId: 'prod_potato',
          title: 'Potato',
          unit: 'kg',
          price: 15.0,
          quantity: 4,
          total: 60.0,
        ),
      ];

      final originalFingerprint = ProfessionalCheckoutIdempotencyManager.computeFingerprint(
        shopId: shopId,
        deliveryMethod: 'delivery',
        items: originalItems,
        deliveryAddress: {'address': 'Bela Jamui'},
      );

      // Pending attempt created
      await idempotencyManager.getOrCreateAttempt(
        customerId: customerId,
        shopId: shopId,
        payloadFingerprint: originalFingerprint,
        orderPayload: {'totalAmount': 60.0},
      );

      // User modified cart quantity: 4 -> 5
      final modifiedItems = [
        const ProfessionalOrderItem(
          productId: 'prod_potato',
          title: 'Potato',
          unit: 'kg',
          price: 15.0,
          quantity: 5, // Modified!
          total: 75.0,
        ),
      ];

      final modifiedFingerprint = ProfessionalCheckoutIdempotencyManager.computeFingerprint(
        shopId: shopId,
        deliveryMethod: 'delivery',
        items: modifiedItems,
        deliveryAddress: {'address': 'Bela Jamui'},
      );

      final modifiedAttempt = await idempotencyManager.getOrCreateAttempt(
        customerId: customerId,
        shopId: shopId,
        payloadFingerprint: modifiedFingerprint,
        orderPayload: {'totalAmount': 75.0},
      );

      // Conflict must be flagged!
      expect(modifiedAttempt.hasPayloadMismatch, isTrue);
      expect(modifiedAttempt.isReused, isFalse);
    });

    test('5. Confirmed resolution safely clears attempt from storage', () async {
      const customerId = 'cust_sagar_123';
      const shopId = 'shop_jamui_1';
      final items = <ProfessionalOrderItem>[
        const ProfessionalOrderItem(
          productId: 'prod_salt',
          title: 'Tata Salt',
          unit: 'kg',
          price: 40.0,
          quantity: 1,
          total: 40.0,
        ),
      ];

      final fingerprint = ProfessionalCheckoutIdempotencyManager.computeFingerprint(
        shopId: shopId,
        deliveryMethod: 'delivery',
        items: items,
      );

      await idempotencyManager.getOrCreateAttempt(
        customerId: customerId,
        shopId: shopId,
        payloadFingerprint: fingerprint,
        orderPayload: {'totalAmount': 40.0},
      );

      // Clear attempt on successful order completion
      await idempotencyManager.clearAttempt(
        customerId: customerId,
        shopId: shopId,
      );

      final stored = await idempotencyManager.getUnresolvedAttempt(
        customerId: customerId,
        shopId: shopId,
      );
      expect(stored, isNull, reason: 'Attempt must be purged after resolution');
    });

    test('6. PlaceOrderResult handles isDuplicate flag cleanly', () {
      const result = PlaceOrderResult(
        orderId: 'aCIV96l6JlaM98tAkU8S',
        orderNumber: 'JS-284731',
        sellerOrderNumber: 'SGJ-001',
        channelId: 'JAMUI_SERVICES',
        isDuplicate: true,
      );

      expect(result.isDuplicate, isTrue);
      expect(result.orderNumber, equals('JS-284731'));
      expect(result.sellerOrderNumber, equals('SGJ-001'));
    });

    test('7. ProfessionalOrderEntity serializes and preserves idempotencyKey across models', () {
      final order = ProfessionalOrderEntity(
        orderId: 'ord_123',
        orderNumber: 'JS-284731',
        sellerOrderNumber: 'SGJ-001',
        customerId: 'cust_sagar',
        shopId: 'shop_1',
        shopName: 'Sagar Grocery',
        totalAmount: 609.0,
        subtotal: 609.0,
        createdAt: DateTime(2026, 11, 9, 18, 0),
        idempotencyKey: 'chk_cust_sagar_shop_1_1731165000000',
      );

      expect(order.idempotencyKey, equals('chk_cust_sagar_shop_1_1731165000000'));
      final map = order.toMap();
      expect(map['idempotencyKey'], equals('chk_cust_sagar_shop_1_1731165000000'));

      final deserialized = ProfessionalOrderEntity.fromMap(map, 'ord_123');
      expect(deserialized.idempotencyKey, equals('chk_cust_sagar_shop_1_1731165000000'));

      final copied = order.copyWith(status: 'accepted');
      expect(copied.idempotencyKey, equals('chk_cust_sagar_shop_1_1731165000000'));
    });

    test('8. Client SHA-256 fingerprint byte-for-byte matches Node.js crypto canonical hash', () {
      const expectedNodeSha256 =
          '4ac4c2142947de46b0b8e7c37a3b632ea404524f9321db30bf2fcd1518eb943f';

      final items = <ProfessionalOrderItem>[
        const ProfessionalOrderItem(
          productId: 'prod_potato',
          title: 'Potato',
          unit: 'kg',
          price: 15.0,
          quantity: 4,
          total: 60.0,
        ),
        const ProfessionalOrderItem(
          productId: 'prod_tea',
          variantId: 'var_500g',
          variantTitle: '500g',
          title: 'Tata Tea Gold',
          unit: '500g',
          price: 49.50,
          quantity: 2,
          total: 99.0,
        ),
      ];

      final deliveryAddress = {
        'address': 'SubCentre, Bela, SH82',
        'area': 'Khaira',
        'contactPhone': '8521301451',
        'customerName': 'sagar',
        'latitude': 25.1234,
        'longitude': 86.1234,
      };

      final clientFingerprint = ProfessionalCheckoutIdempotencyManager.computeFingerprint(
        shopId: 'shop_jamui_1',
        deliveryMethod: 'delivery',
        items: items,
        deliveryAddress: deliveryAddress,
      );

      expect(clientFingerprint, equals(expectedNodeSha256),
          reason: 'Client SHA-256 fingerprint MUST exactly match Node.js crypto hash');
    });

    test('9. ReconciliationResult distinguishes confirmedPlaced, definitivelyNotFound, and networkError', () {
      const placed = ReconciliationResult(
        status: ReconciliationResultStatus.confirmedPlaced,
      );
      expect(placed.isConfirmedPlaced, isTrue);
      expect(placed.isDefinitivelyNotFound, isFalse);
      expect(placed.isNetworkError, isFalse);

      const notFound = ReconciliationResult(
        status: ReconciliationResultStatus.definitivelyNotFound,
      );
      expect(notFound.isConfirmedPlaced, isFalse);
      expect(notFound.isDefinitivelyNotFound, isTrue);
      expect(notFound.isNetworkError, isFalse);

      const netErr = ReconciliationResult(
        status: ReconciliationResultStatus.networkError,
        errorMessage: 'SocketException',
      );
      expect(netErr.isConfirmedPlaced, isFalse);
      expect(netErr.isDefinitivelyNotFound, isFalse);
      expect(netErr.isNetworkError, isTrue);
    });
  });
}
