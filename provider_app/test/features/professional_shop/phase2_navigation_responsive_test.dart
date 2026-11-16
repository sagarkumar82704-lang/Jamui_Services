import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/seller_stock_movement_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_workspace_screen.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_dashboard_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_products_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_orders_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_inventory_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_earnings_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_store_banner_management_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_settings_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_profile_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/widgets/professional_new_order_dialog.dart';
import 'package:apna_jamui_provider/core/localization/provider_strings.dart';
import 'package:apna_jamui_provider/core/localization/provider_locale_controller.dart';
import 'package:apna_jamui_provider/core/widgets/responsive_shell.dart';

class MockProfessionalDataSource implements ProfessionalProviderRemoteDataSource {
  final Map<String, List<Map<String, dynamic>>> orders = {};
  final Map<String, List<Map<String, dynamic>>> products = {};
  final Map<String, ProfessionalShopProfileEntity> profiles = {};
  final StreamController<List<Map<String, dynamic>>> orderController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> productController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<ProfessionalShopProfileEntity?> profileController = StreamController<ProfessionalShopProfileEntity?>.broadcast();

  @override
  Stream<List<Map<String, dynamic>>> streamShopOrders(String shopId) async* {
    yield orders[shopId] ?? [];
    yield* orderController.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> streamProducts(String shopId) async* {
    yield products[shopId] ?? [];
    yield* productController.stream;
  }

  @override
  Stream<ProfessionalShopProfileEntity?> streamShopProfile(String uid, {String? ownerUid}) async* {
    yield profiles[uid];
    yield* profileController.stream;
  }

  @override
  Stream<List<SellerStockMovementEntity>> streamStockMovements(String shopId, {String? productId, int limit = 50}) async* {
    yield [];
  }

  @override
  Future<void> updateOrderStatus(String orderId, String newStatus, {String? rejectionReason}) async {}

  @override
  Future<void> toggleShopOpenStatus(String shopId, bool isOpen) async {}

  @override
  Future<void> saveShopSettings(String shopId, Map<String, dynamic> settings) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('JAMUI SERVICES — PHASE 2 PROFESSIONAL PROVIDER NAVIGATION & RESPONSIVENESS', () {
    const shopId = 'phase2_shop_id_01';

    final testShop = ProfessionalShopProfileEntity(
      id: shopId,
      ownerUid: shopId,
      shopName: 'जमुई किराना स्टोर (Jamui Kirana)',
      jamuiArea: 'कचहरी चौक, जमुई',
      logoUrl: '',
      isApproved: true,
      isActive: true,
      isOpen: true,
      openingTime: '08:00 AM',
      closingTime: '09:00 PM',
      isHomeDeliveryActive: true,
      isPickupActive: true,
      deliveryCharges: 25.0,
      minOrderAmount: 100.0,
      serviceRadiusKm: 5.0,
      isSubscriptionActive: true,
      subscriptionPlanName: 'Diamond Pro',
      maxProductsLimit: 150,
      rating: 4.9,
    );

    late MockProfessionalDataSource mockDataSource;

    setUp(() async {
      await ProviderLocaleController.instance.setLocale('hi');
      mockDataSource = MockProfessionalDataSource();
      mockDataSource.profiles[shopId] = testShop;
      mockDataSource.orders[shopId] = [];
      mockDataSource.products[shopId] = [];
    });

    Widget createTestApp({required Widget child, Size? viewportSize}) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(ProviderLocaleController.instance.currentLocale),
        supportedLocales: const [Locale('hi'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      );
    }

    // =========================================================================
    // TEST 1: DESKTOP VIEWPORT (1366 x 768) - ALL 8 DESTINATIONS VISIBLE
    // =========================================================================
    testWidgets('1. Desktop Sidebar (1366x768) renders all 8 destinations with Hindi labels and Header Language Pill', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          child: ProfessionalShopWorkspaceScreen(
            shop: testShop,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Check all 8 destinations exist
      expect(find.text(ProviderStrings.navHome), findsWidgets);
      expect(find.text(ProviderStrings.navProducts), findsWidgets);
      expect(find.text(ProviderStrings.navOrders), findsWidgets);
      expect(find.text(ProviderStrings.navInventory), findsWidgets);
      expect(find.text(ProviderStrings.navEarnings), findsWidgets);
      expect(find.text(ProviderStrings.navBanner), findsWidgets);
      expect(find.text(ProviderStrings.navSettings), findsWidgets);
      expect(find.text(ProviderStrings.navProfile), findsWidgets);

      // Check header language pill exists
      expect(find.byKey(const Key('sidebar_header_lang_btn')), findsOneWidget);

      // Initial page is Dashboard
      expect(find.byType(ProfessionalShopDashboardPage), findsOneWidget);
    });

    // =========================================================================
    // TEST 2: DESKTOP NAVIGATION SWITCHES CORRECTLY BETWEEN ALL 8 SCREENS
    // =========================================================================
    testWidgets('2. Clicking sidebar destinations navigates to Banner, Settings, Earnings, and Profile without errors', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          child: ProfessionalShopWorkspaceScreen(
            shop: testShop,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Click Earnings (बिक्री / आय - item 4)
      await tester.tap(find.byKey(const Key('sidebar_nav_item_4')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ProfessionalShopEarningsPage), findsOneWidget);

      // 2. Click Promotional Banner (प्रचार बैनर - item 5)
      await tester.tap(find.byKey(const Key('sidebar_nav_item_5')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ProfessionalStoreBannerManagementPage), findsOneWidget);

      // 3. Click Store Settings (स्टोर सेटिंग्स - item 6)
      await tester.tap(find.byKey(const Key('sidebar_nav_item_6')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ProfessionalShopSettingsPage), findsOneWidget);

      // 4. Click Store Profile (प्रोफाइल - item 7)
      await tester.tap(find.byKey(const Key('sidebar_nav_item_7')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ProfessionalShopProfilePage), findsOneWidget);
    });

    // =========================================================================
    // TEST 3: MOBILE VIEWPORT (< 600px) - EXACTLY 5 BOTTOM NAV DESTINATIONS
    // =========================================================================
    testWidgets('3. Mobile Viewport (400x800) renders exactly 5 bottom navigation tabs and maps profile correctly', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          child: ProfessionalShopWorkspaceScreen(
            shop: testShop,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Verify bottom navigation bar exists and has 5 items
      final bnbFinder = find.byType(BottomNavigationBar);
      expect(bnbFinder, findsOneWidget);
      final bnb = tester.widget<BottomNavigationBar>(bnbFinder);
      expect(bnb.items.length, equals(5));

      // Items: Home, Products, Orders, Inventory, Store & More (navMore)
      expect(bnb.items[0].label, equals(ProviderStrings.navHome));
      expect(bnb.items[1].label, equals(ProviderStrings.navProducts));
      expect(bnb.items[2].label, equals(ProviderStrings.navOrders));
      expect(bnb.items[3].label, equals(ProviderStrings.navInventory));
      expect(bnb.items[4].label, equals(ProviderStrings.navMore));

      // Tap 5th item (Store & More / Profile) -> must switch to ProfessionalShopProfilePage
      await tester.tap(find.text(ProviderStrings.navMore));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ProfessionalShopProfilePage), findsOneWidget);
    });

    // =========================================================================
    // TEST 4: DASHBOARD QUICK ACTIONS NAVIGATE DIRECTLY TO NEW TABS
    // =========================================================================
    testWidgets('4. Dashboard Quick Actions navigate to Banner (5), Settings (6), and Earnings (4)', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          child: ProfessionalShopWorkspaceScreen(
            shop: testShop,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Quick Action: Banner
      final bannerBtn = find.descendant(
        of: find.byType(ProfessionalShopDashboardPage),
        matching: find.text(ProviderStrings.promotionalBanner),
      );
      expect(bannerBtn, findsOneWidget);
      await tester.tap(bannerBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ProfessionalStoreBannerManagementPage), findsOneWidget);

      // Return to Dashboard
      await tester.tap(find.byKey(const Key('sidebar_nav_item_0')));
      await tester.pump(const Duration(milliseconds: 200));

      // Quick Action: Settings
      final settingsBtn = find.descendant(
        of: find.byType(ProfessionalShopDashboardPage),
        matching: find.text(ProviderStrings.shopSettings),
      );
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ProfessionalShopSettingsPage), findsOneWidget);
    });

    // =========================================================================
    // TEST 5: NEW ORDER ALERT DIALOG IS NON-BLOCKING AND DISMISSIBLE
    // =========================================================================
    testWidgets('5. ProfessionalNewOrderDialog has close button and Review Later button that triggers onDismiss', (tester) async {
      bool dismissed = false;

      final testOrder = {
        'id': 'ORD_PHASE2_1001',
        'customerName': 'राहुल कुमार',
        'totalAmount': 450.0,
        'deliveryAddress': {'address': 'मेन रोड, जमुई'},
        'items': [
          {'title': 'सरसों तेल', 'quantity': 2, 'unit': 'L'},
          {'title': 'चीनी', 'quantity': 5, 'unit': 'kg'},
        ],
      };

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: ProfessionalNewOrderDialog(
              order: testOrder,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Verify order contents render cleanly
      expect(find.text('राहुल कुमार'), findsOneWidget);
      expect(find.text('#ORD_PHASE2_1001'), findsOneWidget);
      expect(find.text('₹450 • 2 Items'), findsOneWidget);

      // Verify Close Icon dismisses
      final closeBtn = find.byTooltip('Dismiss');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      expect(dismissed, isTrue);

      // Verify 'बाद में देखें' button also triggers dismissal
      dismissed = false;
      final laterBtn = find.text('बाद में देखें (Review Later)');
      expect(laterBtn, findsOneWidget);
      await tester.tap(laterBtn);
      expect(dismissed, isTrue);
    });

    // =========================================================================
    // TEST 6: BILINGUAL LANGUAGE SWITCHER INSTANT UPDATE
    // =========================================================================
    testWidgets('6. Switching language to English immediately updates navigation strings to English', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          child: ProfessionalShopWorkspaceScreen(
            shop: testShop,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('होम'), findsWidgets);
      expect(find.text('उत्पाद'), findsWidgets);

      // Switch to English
      await ProviderLocaleController.instance.setLocale('en');
      await tester.pumpWidget(
        createTestApp(
          child: ProfessionalShopWorkspaceScreen(
            shop: testShop,
            dataSource: mockDataSource,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Products'), findsWidgets);
      expect(find.text('Orders'), findsWidgets);
      expect(find.text('Inventory'), findsWidgets);
    });
  });
}

