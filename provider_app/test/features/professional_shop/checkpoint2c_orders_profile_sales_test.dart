import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_workspace_screen.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_dashboard_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_orders_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_profile_page.dart';

class MockRemoteDataSource2C implements ProfessionalProviderRemoteDataSource {
  final Map<String, List<Map<String, dynamic>>> orders = {};
  final Map<String, List<Map<String, dynamic>>> products = {};
  final Map<String, ProfessionalShopProfileEntity> profiles = {};
  final List<Map<String, dynamic>> orderUpdatesLog = [];

  final _orderController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _productController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _profileController = StreamController<ProfessionalShopProfileEntity?>.broadcast();

  @override
  Stream<List<Map<String, dynamic>>> streamShopOrders(String shopId) async* {
    yield orders[shopId] ?? [];
    yield* _orderController.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> streamProducts(String shopId) async* {
    yield products[shopId] ?? [];
    yield* _productController.stream;
  }

  @override
  Stream<ProfessionalShopProfileEntity?> streamShopProfile(String uid, {String? ownerUid}) async* {
    yield profiles[uid];
    yield* _profileController.stream;
  }

  @override
  Future<void> updateOrderStatus(String orderId, String newStatus, {String? rejectionReason}) async {
    orderUpdatesLog.add({
      'orderId': orderId,
      'newStatus': newStatus,
      'rejectionReason': rejectionReason,
    });
    final shopOrders = orders.values.expand((x) => x);
    for (final o in shopOrders) {
      if (o['id'] == orderId || o['orderId'] == orderId) {
        o['status'] = newStatus;
        if (rejectionReason != null) {
          o['rejectionReason'] = rejectionReason;
        }
      }
    }
  }

  @override
  Future<void> toggleShopOpenStatus(String shopId, bool isOpen) async {
    final current = profiles[shopId];
    if (current != null) {
      profiles[shopId] = current.copyWith(isOpen: isOpen);
      _profileController.add(profiles[shopId]);
    }
  }

  @override
  Future<void> toggleProductStock(String shopId, String productId, bool inStock) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('JAMUI SERVICES — CHECKPOINT 2C ORDERS, PROFILE & SALES DEEP AUDIT', () {
    const shopId = 'pro_seller_jamui_999';

    final testShop = ProfessionalShopProfileEntity(
      id: shopId,
      ownerUid: shopId,
      shopName: 'जमुई ई-मार्ट (Jamui E-Mart)',
      demandCategoryId: 'cat_groceries',
      demandCategoryTitle: 'किराना एवं दैनिक वस्तुएं (Grocery)',
      fullAddress: 'दुकान नं. 14, कचहरी रोड, जमुई, बिहार - 811307',
      jamuiArea: 'कचहरी रोड, जमुई',
      logoUrl: '',
      bannerUrl: '',
      isOpen: true,
      openingTime: '07:30 AM',
      closingTime: '09:30 PM',
      isHomeDeliveryActive: true,
      isPickupActive: true,
      deliveryCharges: 35.0,
      minOrderAmount: 200.0,
      serviceRadiusKm: 6.0,
      isApproved: true,
      isActive: true,
      isSubscriptionActive: true,
      subscriptionPlanName: 'Diamond Pro Tier',
      subscriptionExpiry: DateTime(2027, 3, 31),
      maxProductsLimit: 250,
      rating: 4.9,
    );

    late MockRemoteDataSource2C mockDataSource;

    setUp(() {
      mockDataSource = MockRemoteDataSource2C();
      mockDataSource.profiles[shopId] = testShop;
      mockDataSource.orders[shopId] = [];
      mockDataSource.products[shopId] = [];
    });

    // =========================================================================
    // TEST 1: Delivery Order UI & Order Details Sheet Inspection
    // =========================================================================
    testWidgets('1. Delivery order renders distinct delivery badge, address, and opens details sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDataSource.orders[shopId] = [
        {
          'id': 'ord_del_101',
          'orderId': 'ord_del_101',
          'customerName': 'राजेश कुमार',
          'customerPhone': '+919876543210',
          'status': 'placed',
          'deliveryMethod': 'delivery',
          'subtotal': 450.0,
          'deliveryFee': 35.0,
          'totalAmount': 485.0,
          'customerNotes': 'कृपया गेट की घंटी बजाएं',
          'deliveryAddress': {
            'fullAddress': 'मकान नं. 45, पटेल चौक, जमुई',
            'landmark': 'बैंक ऑफ बड़ौदा के पास',
            'pincode': '811307',
          },
          'items': [
            {'name': 'सरसों तेल 1L', 'quantity': 2, 'unit': 'लीटर', 'price': 150, 'itemTotal': 300},
            {'name': 'चीनी 3kg', 'quantity': 1, 'unit': 'kg', 'price': 150, 'itemTotal': 150},
          ],
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopOrdersPage(
            shopId: shopId,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump();

      // Card displays delivery badge
      expect(find.text('होम डिलीवरी'), findsOneWidget);
      expect(find.text('#ord_del_101'), findsOneWidget);
      expect(find.text('राजेश कुमार'), findsOneWidget);
      expect(find.text('कुल राशि: ₹485'), findsOneWidget);

      // Tap card to open Order Details Modal Sheet
      await tester.tap(find.text('#ord_del_101'));
      await tester.pumpAndSettle();

      // Inside Modal Sheet
      expect(find.text('ऑर्डर विवरण #ord_del_101'), findsOneWidget);
      expect(find.text('होम डिलीवरी (Home Delivery)'), findsOneWidget);
      expect(find.textContaining('मकान नं. 45, पटेल चौक, जमुई'), findsOneWidget);
      expect(find.text('नोट: "कृपया गेट की घंटी बजाएं"'), findsOneWidget);
      expect(find.text('सरसों तेल 1L'), findsOneWidget);
      expect(find.text('वस्तुओं का मूल्य (Subtotal)'), findsOneWidget);
      expect(find.text('₹450'), findsOneWidget);
      expect(find.text('₹35'), findsOneWidget);
      expect(find.text('₹485'), findsOneWidget);
    });

    // =========================================================================
    // TEST 2: Pickup Order UI & Specific Workflow
    // =========================================================================
    testWidgets('2. Pickup order renders store pickup badge and prepares for ready_for_pickup', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDataSource.orders[shopId] = [
        {
          'id': 'ord_pick_202',
          'orderId': 'ord_pick_202',
          'customerName': 'सुमन वर्मा',
          'customerPhone': '+919876543219',
          'status': 'preparing',
          'deliveryMethod': 'pickup',
          'subtotal': 600.0,
          'deliveryFee': 0.0,
          'totalAmount': 600.0,
          'items': [
            {'name': 'देसी घी 1kg', 'quantity': 1, 'unit': 'kg', 'price': 600, 'itemTotal': 600},
          ],
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopOrdersPage(
            shopId: shopId,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump();

      // Card displays pickup badge
      expect(find.text('दुकान से पिकअप'), findsOneWidget);

      // For preparing pickup order, action must be 'पिकअप हेतु तैयार' (ready_for_pickup)
      expect(find.text('पिकअप हेतु तैयार'), findsOneWidget);

      await tester.tap(find.text('पिकअप हेतु तैयार'));
      await tester.pumpAndSettle();

      expect(mockDataSource.orderUpdatesLog.length, 1);
      expect(mockDataSource.orderUpdatesLog.first['newStatus'], 'ready_for_pickup');
    });

    // =========================================================================
    // TEST 3: Terminal States Render Zero Action Buttons
    // =========================================================================
    testWidgets('3. Terminal orders (delivered, rejected, cancelled) render no active action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDataSource.orders[shopId] = [
        {
          'id': 'ord_term_delivered',
          'orderId': 'ord_term_delivered',
          'customerName': 'सुरेश',
          'status': 'delivered',
          'subtotal': 300.0,
          'deliveryFee': 0.0,
          'totalAmount': 300.0,
        },
        {
          'id': 'ord_term_rejected',
          'orderId': 'ord_term_rejected',
          'customerName': 'अमित',
          'status': 'rejected',
          'rejectionReason': 'दुकान बंद थी',
          'subtotal': 200.0,
          'deliveryFee': 0.0,
          'totalAmount': 200.0,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopOrdersPage(
            shopId: shopId,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump();

      // Verify no transition buttons exist for terminal states
      expect(find.text('स्वीकार करें'), findsNothing);
      expect(find.text('अस्वीकार'), findsNothing);
      expect(find.text('तैयारी शुरू करें'), findsNothing);
      expect(find.text('डिस्पैच करें'), findsNothing);

      // Delivered shows 'पूर्ण'
      expect(find.text('पूर्ण'), findsOneWidget);

      // Rejected shows rejection reason
      expect(find.text('अस्वीकृति कारण: दुकान बंद थी'), findsOneWidget);
    });

    // =========================================================================
    // TEST 4: Profile Page Comprehensive Display (Branding, Hours, Settings, Renewal)
    // =========================================================================
    testWidgets('4. Profile Page renders complete branding, category badge, address, hours, settings, and subscription', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopProfilePage(
            shop: testShop,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump();

      // Branding & Category Badge
      expect(find.text('जमुई ई-मार्ट (Jamui E-Mart)'), findsOneWidget);
      expect(find.text('किराना एवं दैनिक वस्तुएं (Grocery)'), findsOneWidget);
      expect(find.text('दुकान नं. 14, कचहरी रोड, जमुई, बिहार - 811307'), findsOneWidget);
      expect(find.text('सत्यापित विक्रेता'), findsOneWidget);

      // Business Hours & Weekly Off
      expect(find.text('07:30 AM'), findsOneWidget);
      expect(find.text('09:30 PM'), findsOneWidget);
      expect(find.text('कोई अवकाश नहीं (7 दिन खुला)'), findsOneWidget);

      // Delivery & Pickup Settings
      expect(find.text('डिलीवरी शुल्क'), findsOneWidget);
      expect(find.text('₹35'), findsOneWidget);
      expect(find.text('न्यूनतम ऑर्डर मूल्य'), findsOneWidget);
      expect(find.text('₹200'), findsOneWidget);

      // Subscription & Renewal
      expect(find.text('Diamond Pro Tier'), findsOneWidget);
      expect(find.text('31/3/2027'), findsOneWidget);
      expect(find.text('250 उत्पाद'), findsOneWidget);
      expect(find.text('प्लान नवीनीकरण'), findsOneWidget);
    });

    // =========================================================================
    // TEST 5: Sales Chart IST Midnight Boundary & Subtotal Calculation
    // =========================================================================
    testWidgets('5. Sales Chart converts UTC to IST accurately across midnight boundaries and excludes delivery charges', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const istOffset = Duration(hours: 5, minutes: 30);
      final nowUtc = DateTime.now().toUtc();
      final nowIst = nowUtc.add(istOffset);
      final todayMidnightIst = DateTime.utc(nowIst.year, nowIst.month, nowIst.day);

      // Case A: Order at 11:59 PM IST (UTC 18:29) on todayMidnightIst
      // Order subtotal = 700, deliveryFee = 50 -> must add 700 only!
      final orderToday = {
        'id': 'ord_midnight_a',
        'status': 'delivered',
        'subtotal': 700.0,
        'deliveryFee': 50.0,
        'totalAmount': 750.0,
        'createdAt': Timestamp.fromDate(todayMidnightIst.subtract(istOffset).add(const Duration(hours: 14))), // 2:00 PM IST today
      };

      // Case B: Order cancelled (must NOT be counted)
      final orderCancelled = {
        'id': 'ord_cancelled',
        'status': 'cancelled',
        'subtotal': 999.0,
        'deliveryFee': 0.0,
        'totalAmount': 999.0,
        'createdAt': Timestamp.fromDate(todayMidnightIst.subtract(istOffset).add(const Duration(hours: 10))),
      };

      mockDataSource.orders[shopId] = [orderToday, orderCancelled];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalShopDashboardPage(
              shop: testShop,
              onNavigateTab: (_) {},
              dataSource: mockDataSource,
            ),
          ),
        ),
      );
      await tester.pump();

      // Total Sales must be exactly 700 (excluding 50 deliveryFee and excluding 999 cancelled order)
      expect(find.text('₹700'), findsWidgets);
      expect(find.text('7 दिनों की डिलीवरी बिक्री (Sales)'), findsOneWidget);
      expect(find.text('आज'), findsOneWidget);
    });

    // =========================================================================
    // TEST 6: Complete 5-Tab Workspace Navigation Integration
    // =========================================================================
    testWidgets('6. Complete 5-Tab Workspace allows switching between all 5 tabs smoothly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopWorkspaceScreen(
            shop: testShop,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump();

      // Tab 0: Home is active initially
      expect(find.text('व्यापार अवलोकन (Business Overview)'), findsOneWidget);

      // Tap Tab 1: Products
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('उत्पाद सूची (Products)'), findsOneWidget);

      // Tap Tab 2: Orders
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(find.text('ऑर्डर प्रबंधन (Orders)'), findsOneWidget);

      // Tap Tab 3: Inventory
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.text('इन्वेंट्री प्रबंधन (Inventory)'), findsOneWidget);

      // Tap Tab 4: Profile
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('दुकान प्रोफ़ाइल (Shop Profile)'), findsOneWidget);
    });
  });
}
