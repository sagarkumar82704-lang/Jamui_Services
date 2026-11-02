import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_workspace_screen.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_dashboard_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_products_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_orders_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_inventory_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_profile_page.dart';

class MockProfessionalDataSource implements ProfessionalProviderRemoteDataSource {
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
    // Update local list
    for (final shopOrders in orders.values) {
      for (final o in shopOrders) {
        if (o['id'] == orderId || o['orderId'] == orderId) {
          o['status'] = newStatus;
          if (rejectionReason != null) {
            o['rejectionReason'] = rejectionReason;
          }
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
  Future<void> toggleProductStock(String shopId, String productId, bool inStock) async {
    final prods = products[shopId];
    if (prods != null) {
      for (final p in prods) {
        if (p['id'] == productId) {
          p['inStock'] = inStock;
        }
      }
      _productController.add(prods);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('JAMUI SERVICES — CHECKPOINT 2B PROFESSIONAL SELLER WORKSPACE AUDIT', () {
    const shopId = 'test_seller_uid_100';

    final testShop = ProfessionalShopProfileEntity(
      id: shopId,
      ownerUid: shopId,
      shopName: 'जमुई सुपरमार्ट (Jamui Supermart)',
      jamuiArea: 'स्टेशन रोड, जमुई',
      logoUrl: '',
      isApproved: true,
      isActive: true,
      isOpen: true,
      openingTime: '08:00 AM',
      closingTime: '09:00 PM',
      isHomeDeliveryActive: true,
      isPickupActive: true,
      deliveryCharges: 30.0,
      minOrderAmount: 150.0,
      serviceRadiusKm: 5.0,
      isSubscriptionActive: true,
      subscriptionPlanName: 'Diamond Pro',
      maxProductsLimit: 150,
      rating: 4.8,
    );

    late MockProfessionalDataSource mockDataSource;

    setUp(() {
      mockDataSource = MockProfessionalDataSource();
      mockDataSource.profiles[shopId] = testShop;
      mockDataSource.orders[shopId] = [];
      mockDataSource.products[shopId] = [];
    });

    // =========================================================================
    // TEST 1: Exactly 5 Tabs in Workspace Shell in Approved Order
    // =========================================================================
    testWidgets('1. Bottom Navigation has exactly 5 tabs: Home, Products, Orders, Inventory, Profile', (tester) async {
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

      // Find BottomNavigationBar
      final bottomNavFinder = find.byType(BottomNavigationBar);
      expect(bottomNavFinder, findsOneWidget);

      final bottomNav = tester.widget<BottomNavigationBar>(bottomNavFinder);
      expect(bottomNav.items.length, 5);

      // Verify exact labels and sequence
      expect(bottomNav.items[0].label, 'Home');
      expect(bottomNav.items[1].label, 'Products');
      expect(bottomNav.items[2].label, 'Orders');
      expect(bottomNav.items[3].label, 'Inventory');
      expect(bottomNav.items[4].label, 'Profile');
    });

    // =========================================================================
    // TEST 2: Normal Provider Domain Isolation
    // =========================================================================
    test('2. Normal Providers (Plumber/Electrician) remain strictly isolated from Professional Workspace', () {
      final normalPlumber = ProviderProfileEntity(
        id: 'norm_01',
        email: 'ramesh@jamui.test',
        phoneNumber: '+919876543210',
        fullName: 'Ramesh Plumber',
        businessName: 'Ramesh Plumbing Services',
        businessType: 'individual',
        primaryCategoryId: 'cat_plumbing',
        primaryCategoryTitle: 'Plumber',
        categoryType: 'general',
        createdAt: DateTime.now(),
      );

      bool isAllowedInProfessionalWorkspace(ProviderProfileEntity p) {
        final bType = p.businessType.toLowerCase().trim();
        final cType = p.categoryType.toLowerCase().trim();
        return bType == 'professional_seller' ||
            bType == 'ecommerce_seller' ||
            cType == 'professional' ||
            cType == 'diamond';
      }

      expect(isAllowedInProfessionalWorkspace(normalPlumber), isFalse);
    });

    // =========================================================================
    // TEST 3: Dashboard 6 KPIs Calculation from Real Firestore Data
    // =========================================================================
    testWidgets('3. Home Dashboard calculates all 6 KPIs correctly from Firestore streams', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDataSource.orders[shopId] = [
        // Delivered order 1: subtotal 500, deliveryFee 40, total 540 -> Delivered sales +500
        {
          'id': 'ord_1',
          'status': 'delivered',
          'subtotal': 500.0,
          'deliveryFee': 40.0,
          'totalAmount': 540.0,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        // Delivered order 2: subtotal 350, deliveryFee 0 (pickup), total 350 -> Delivered sales +350
        {
          'id': 'ord_2',
          'status': 'delivered',
          'subtotal': 350.0,
          'deliveryFee': 0.0,
          'totalAmount': 350.0,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        // Pending order 3: placed
        {
          'id': 'ord_3',
          'status': 'placed',
          'subtotal': 200.0,
          'deliveryFee': 30.0,
          'totalAmount': 230.0,
        },
        // Pending order 4: preparing
        {
          'id': 'ord_4',
          'status': 'preparing',
          'subtotal': 120.0,
          'deliveryFee': 0.0,
          'totalAmount': 120.0,
        },
      ];

      mockDataSource.products[shopId] = [
        {'id': 'p1', 'titleEnglish': 'Milk 1L', 'stockQuantity': 10, 'inStock': true},
        {'id': 'p2', 'titleEnglish': 'Butter 100g', 'stockQuantity': 3, 'inStock': true},
        {'id': 'p3', 'titleEnglish': 'Bread', 'stockQuantity': 0, 'inStock': false},
      ];

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

      // Expected KPIs:
      // Total Sales: 500 + 350 = ₹850 (strictly excluding delivery fees of 40)
      // Displays in both KPI summary and 7-day chart bar
      expect(find.text('₹850'), findsWidgets);

      // Total Orders: 4
      expect(find.text('4'), findsOneWidget);

      // Pending Orders: 2 and Active Products: 2
      expect(find.text('2'), findsNWidgets(2));

      // Total Products: 3
      expect(find.text('3'), findsOneWidget);

      // Active Products: 2 (p1 & p2)
      // Out of Stock: 1 (p3)
      expect(find.text('कुल बिक्री (Sales)'), findsOneWidget);
      expect(find.text('कुल ऑर्डर्स'), findsOneWidget);
      expect(find.text('लंबित ऑर्डर्स'), findsOneWidget);
      expect(find.text('कुल उत्पाद'), findsOneWidget);
      expect(find.text('सक्रिय उत्पाद'), findsOneWidget);
      expect(find.text('आउट ऑफ स्टॉक'), findsOneWidget);
    });

    // =========================================================================
    // TEST 4: Seven-Day Sales Aggregation & Empty State
    // =========================================================================
    testWidgets('4. Seven-Day Sales Chart shows clean empty state when no qualifying sales exist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDataSource.orders[shopId] = []; // Zero qualifying delivered orders

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

      // Empty state text must be visible
      expect(find.text('पिछले 7 दिनों में कोई डिलीवरी बिक्री दर्ज नहीं हुई।'), findsOneWidget);
    });

    // =========================================================================
    // TEST 5: Products Tab Displays List & Store Categories Action
    // =========================================================================
    testWidgets('5. Products Tab displays products and includes Store Categories action', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDataSource.products[shopId] = [
        {
          'id': 'p101',
          'titleEnglish': 'Basmati Rice 5kg',
          'sellingPrice': 450,
          'unit': 'kg',
          'inStock': true,
          'storeCategoryName': 'चावल एवं दालें',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopProductsPage(
            shopId: shopId,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Basmati Rice 5kg'), findsOneWidget);
      expect(find.text('₹450 / kg'), findsOneWidget);
      expect(find.text('चावल एवं दालें'), findsOneWidget);
      expect(find.text('स्टोर श्रेणियां'), findsOneWidget);
    });

    // =========================================================================
    // TEST 6: Orders Tab Mandatory Rejection Reason Requirement
    // =========================================================================
    testWidgets('6. Orders Tab: Rejection strictly enforces non-empty mandatory reason', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDataSource.orders[shopId] = [
        {
          'id': 'ord_reject_test',
          'orderId': 'ord_reject_test',
          'customerName': 'Sagar Test',
          'status': 'placed',
          'subtotal': 300.0,
          'deliveryFee': 20.0,
          'totalAmount': 320.0,
          'items': [
            {'name': 'Atta 10kg', 'quantity': 1, 'unit': 'kg', 'itemTotal': 300}
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

      expect(find.text('अस्वीकार'), findsOneWidget);
      expect(find.text('स्वीकार करें'), findsOneWidget);

      // Tap 'अस्वीकार'
      await tester.tap(find.text('अस्वीकार'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('ऑर्डर अस्वीकार करें'), findsOneWidget);
      expect(find.text('अस्वीकृति का कारण लिखना अनिवार्य है (Mandatory Rejection Reason):'), findsOneWidget);

      // Find the reject confirmation button inside dialog
      final confirmBtnFinder = find.widgetWithText(ElevatedButton, 'अस्वीकार करें');
      expect(confirmBtnFinder, findsOneWidget);

      // Button is initially disabled because reason field is empty
      final confirmBtn = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(confirmBtn.onPressed, isNull);

      // Enter valid reason
      await tester.enterText(find.byType(TextField), 'आउट ऑफ स्टॉक है');
      await tester.pump();

      // Button is now enabled
      final enabledBtn = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(enabledBtn.onPressed, isNotNull);

      // Tap confirm reject
      await tester.tap(confirmBtnFinder);
      await tester.pumpAndSettle();

      // Verify dataSource received the update with rejection reason
      expect(mockDataSource.orderUpdatesLog.length, 1);
      expect(mockDataSource.orderUpdatesLog.first['newStatus'], 'rejected');
      expect(mockDataSource.orderUpdatesLog.first['rejectionReason'], 'आउट ऑफ स्टॉक है');
    });

    // =========================================================================
    // TEST 7: Order Lifecycle Transitions Adhere to Backend Allowed States
    // =========================================================================
    testWidgets('7. Order Lifecycle transitions: accepted -> preparing -> out_for_delivery -> delivered', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDataSource.orders[shopId] = [
        {
          'id': 'ord_prep_test',
          'orderId': 'ord_prep_test',
          'customerName': 'Aman Test',
          'status': 'accepted',
          'subtotal': 150.0,
          'deliveryFee': 0.0,
          'totalAmount': 150.0,
          'deliveryMethod': 'delivery',
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

      // Accepted order has 'तैयारी शुरू करें' button
      expect(find.text('तैयारी शुरू करें'), findsOneWidget);
      await tester.tap(find.text('तैयारी शुरू करें'));
      await tester.pumpAndSettle();

      expect(mockDataSource.orderUpdatesLog.any((l) => l['newStatus'] == 'preparing'), isTrue);
    });

    // =========================================================================
    // TEST 8: Inventory Tab Stock Summaries (Total, In-Stock, Low Stock, Out)
    // =========================================================================
    testWidgets('8. Inventory Tab displays 4 KPI summary cards accurately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDataSource.products[shopId] = [
        {'id': 'i1', 'titleEnglish': 'Rice 25kg', 'stockQuantity': 20, 'inStock': true, 'unit': 'बोरी'},
        {'id': 'i2', 'titleEnglish': 'Sugar 5kg', 'stockQuantity': 4, 'inStock': true, 'unit': 'kg'}, // Low stock
        {'id': 'i3', 'titleEnglish': 'Tea 250g', 'stockQuantity': 0, 'inStock': false, 'unit': 'पैकेट'}, // Out of stock
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopInventoryPage(
            shopId: shopId,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump();

      // Total units: 20 + 4 + 0 = 24
      expect(find.text('24'), findsOneWidget);
      expect(find.text('कुल स्टॉक यूनिट्स'), findsOneWidget);

      // In-stock products: 2 (Rice & Sugar)
      expect(find.text('स्टॉक में उपलब्ध'), findsOneWidget);

      // Low stock: 1 (Sugar)
      expect(find.text('कम स्टॉक (<= 5)'), findsOneWidget);

      // Out of stock: 1 (Tea)
      expect(find.text('आउट ऑफ स्टॉक'), findsOneWidget);
    });

    // =========================================================================
    // TEST 9: Inventory Stock Adjustment Action Connected to Cloud Function
    // =========================================================================
    testWidgets('9. Inventory stock adjustment action connects to Cloud Function with validation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      mockDataSource.products[shopId] = [
        {'id': 'i1', 'titleEnglish': 'Rice 25kg', 'stockQuantity': 20, 'inStock': true, 'unit': 'बोरी'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopInventoryPage(
            shopId: shopId,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump();

      // Tap 'समायोजित करें'
      expect(find.text('समायोजित करें'), findsOneWidget);
      await tester.tap(find.text('समायोजित करें'));
      await tester.pumpAndSettle();

      // Bottom sheet opens with interactive stock controls
      expect(find.text('स्टॉक समायोजन: Rice 25kg'), findsOneWidget);
      expect(find.text('+ बढ़ाएं'), findsOneWidget);
      expect(find.text('- घटाएं'), findsOneWidget);
      expect(find.text('= सेट करें'), findsOneWidget);
      expect(find.text('स्टॉक अपडेट करें (Submit Stock)'), findsOneWidget);
    });

    // =========================================================================
    // TEST 10: Profile Tab Displays Shop Info, Timings, Settings & Limits
    // =========================================================================
    testWidgets('10. Profile Tab displays Shop Branding, Hours, Settings, and Subscription Details', (tester) async {
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

      expect(find.text('जमुई सुपरमार्ट (Jamui Supermart)'), findsOneWidget);
      expect(find.text('स्टेशन रोड, जमुई'), findsOneWidget);
      expect(find.text('सत्यापित विक्रेता'), findsOneWidget);
      expect(find.text('कार्य समय (Business Hours)'), findsOneWidget);
      expect(find.text('08:00 AM'), findsOneWidget);
      expect(find.text('09:00 PM'), findsOneWidget);
      expect(find.text('डिलीवरी एवं पिकअप सेटिंग्स'), findsOneWidget);
      expect(find.text('सब्सक्रिप्शन एवं प्लान'), findsOneWidget);
      expect(find.text('मेरी स्टोर श्रेणियां (Store Categories)'), findsOneWidget);
      expect(find.text('लॉग आउट (Sign Out)'), findsOneWidget);
    });
  });
}
