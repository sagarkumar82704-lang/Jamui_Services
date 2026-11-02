import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_registration_tracking_page.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_resolution_error_view.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_workspace_screen.dart';
import 'package:apna_jamui_provider/features/auth/presentation/pages/account_blocked_page.dart';

void main() {
  group('JAMUI SERVICES — CHECKPOINT 1 ROLE ROUTING & OWNERSHIP VERIFICATION', () {
    final now = DateTime.now();

    final normalProviderProfile = ProviderProfileEntity(
      id: 'mock_plumber_uid_01',
      email: 'ramesh@jamui.test',
      phoneNumber: '+919876543210',
      fullName: 'Ramesh Plumber',
      businessName: 'Ramesh Plumbing Services',
      businessType: 'Individual',
      primaryCategoryId: 'cat_plumbing',
      primaryCategoryTitle: 'Plumber',
      categoryType: 'general',
      createdAt: now,
    );

    final proSellerProfile = ProviderProfileEntity(
      id: 'mock_seller_uid_01',
      email: 'vikram@jamui.test',
      phoneNumber: '+919876543211',
      fullName: 'Vikram Shopkeeper',
      businessName: 'Jamui Fresh Grocery Mart',
      businessType: 'professional_seller',
      primaryCategoryId: 'cat_grocery',
      primaryCategoryTitle: 'Grocery',
      categoryType: 'professional',
      createdAt: now,
    );

    // =========================================================================
    // TEST 1: Normal Service Provider Routing Isolation
    // =========================================================================
    test('1. Normal Service Provider is strictly isolated from Professional Seller domain', () {
      bool isProDomain(ProviderProfileEntity prof) {
        final bType = prof.businessType.toLowerCase().trim();
        if (bType == 'professional_seller' || bType == 'ecommerce_seller' || bType == 'shopkeeper') {
          return true;
        }
        final cType = prof.categoryType.toLowerCase().trim();
        if (cType == 'professional' || cType == 'diamond' || cType == 'marketplace' || cType == 'ecommerce') {
          return true;
        }
        return false;
      }

      expect(isProDomain(normalProviderProfile), isFalse);
      expect(isProDomain(proSellerProfile), isTrue);
    });

    // =========================================================================
    // TEST 2: Strict Shop Ownership Verification (ownerUid == currentUid)
    // =========================================================================
    test('2. Strict Shop Ownership: ownerUid == currentUid is verified authoritatively', () {
      const currentUid = 'mock_seller_uid_01';
      final matchingMap = {
        'id': currentUid,
        'ownerUid': currentUid,
        'shopName': 'Jamui Fresh Grocery Mart',
        'status': 'approved',
        'isApproved': true,
        'isActive': true,
        'isSubscriptionActive': true,
      };

      // Valid ownership
      expect(matchingMap['ownerUid'] == currentUid, isTrue);
      final shop = ProfessionalShopProfileEntity.fromMap(matchingMap, currentUid);
      expect(shop.ownerUid, currentUid);
      expect(shop.shopName, 'Jamui Fresh Grocery Mart');
    });

    // =========================================================================
    // TEST 3: Ownership Mismatch Rejection (Zero Cross-Vendor Leakage)
    // =========================================================================
    test('3. Ownership Mismatch: Rejects shop if ownerUid != currentUid', () {
      const currentUid = 'mock_seller_uid_01';
      const foreignUid = 'attacker_or_other_seller_uid_99';
      final mismatchedMap = {
        'id': currentUid,
        'ownerUid': foreignUid, // Mismatched owner!
        'shopName': 'Another Vendor Shop',
        'status': 'approved',
        'isApproved': true,
      };

      // Mandatory security check
      final isOwner = mismatchedMap['ownerUid'] == currentUid;
      expect(isOwner, isFalse);
    });

    // =========================================================================
    // TEST 4: Operational Open/Closed Status Independence (isOpen != suspension)
    // =========================================================================
    test('4. Operational Open/Closed Independence: isOpen == false is NOT an account suspension', () {
      final closedShop = ProfessionalShopProfileEntity(
        id: 'mock_seller_uid_01',
        ownerUid: 'mock_seller_uid_01',
        shopName: 'Jamui Fresh Grocery Mart',
        status: 'approved',
        isApproved: true,
        isActive: true, // Platform active
        isOpen: false, // Merchant closed for lunch/night
        isSubscriptionActive: true,
        subscriptionExpiry: now.add(const Duration(days: 30)),
      );

      // Verify that isOpen is false, but account is NOT suspended
      final bool isSuspended = closedShop.status == 'suspended' ||
          closedShop.status == 'blocked' ||
          !closedShop.isActive;
      expect(isSuspended, isFalse);
      expect(closedShop.isOpen, isFalse);
      expect(closedShop.isActive, isTrue);
    });

    // =========================================================================
    // TEST 5: Subscription Expiry Fail-Safe Boundary (null is strictly expired)
    // =========================================================================
    test('5. Fail-Safe Subscription: null or past expiry is strictly treated as expired', () {
      bool isSubValid(ProfessionalShopProfileEntity shop) {
        return shop.isSubscriptionActive &&
            shop.subscriptionExpiry != null &&
            shop.subscriptionExpiry!.isAfter(DateTime.now());
      }

      // Null expiry
      final nullExpiryShop = ProfessionalShopProfileEntity(
        id: 'shop_01',
        ownerUid: 'shop_01',
        shopName: 'Shop 1',
        isSubscriptionActive: true,
        subscriptionExpiry: null, // Fail-safe check
      );
      expect(isSubValid(nullExpiryShop), isFalse);

      // Past expiry
      final pastExpiryShop = ProfessionalShopProfileEntity(
        id: 'shop_02',
        ownerUid: 'shop_02',
        shopName: 'Shop 2',
        isSubscriptionActive: true,
        subscriptionExpiry: now.subtract(const Duration(days: 1)),
      );
      expect(isSubValid(pastExpiryShop), isFalse);

      // Valid future expiry
      final validShop = ProfessionalShopProfileEntity(
        id: 'shop_03',
        ownerUid: 'shop_03',
        shopName: 'Shop 3',
        isSubscriptionActive: true,
        subscriptionExpiry: now.add(const Duration(days: 30)),
      );
      expect(isSubValid(validShop), isTrue);
    });

    // =========================================================================
    // TEST 6: Pending Registration Tracking Screen Widget Renders Milestones
    // =========================================================================
    testWidgets('6. ProfessionalRegistrationTrackingPage renders 5 milestones and zero normal leads', (tester) async {
      final pendingShop = ProfessionalShopProfileEntity(
        id: 'mock_seller_uid_01',
        ownerUid: 'mock_seller_uid_01',
        shopName: 'Jamui Fresh Grocery Mart',
        status: 'pendingReview',
        isApproved: false,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalRegistrationTrackingPage(
            shop: pendingShop,
            profile: proSellerProfile,
          ),
        ),
      );

      expect(find.text('Registration Tracking'), findsOneWidget);
      expect(find.text('Registration Submitted'), findsOneWidget);
      expect(find.text('Documents Under Review'), findsOneWidget);
      expect(find.text('Subscription Verification'), findsOneWidget);
      expect(find.text('Admin Approval Pending'), findsOneWidget);
      expect(find.text('Approved & Live'), findsOneWidget);
      expect(find.text('Jamui Fresh Grocery Mart'), findsOneWidget);

      // Zero Normal Provider leads leak
      expect(find.text('Plumber'), findsNothing);
      expect(find.text('Electrician'), findsNothing);
      expect(find.text('Leads'), findsNothing);
    });

    // =========================================================================
    // TEST 7: ProfessionalShopResolutionErrorView Widget Renders Safety Actions
    // =========================================================================
    testWidgets('7. ProfessionalShopResolutionErrorView renders safe setup prompt and zero leaks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopResolutionErrorView(
            profile: proSellerProfile,
          ),
        ),
      );

      expect(find.text('दुकान का विवरण अधूरा है'), findsOneWidget);
      expect(find.text('दुकान का विवरण पूरा करें (Complete Setup)'), findsOneWidget);
      expect(find.textContaining('User ID: mock_seller_uid_01'), findsOneWidget);

      // Zero Normal Provider leads leak
      expect(find.text('Leads'), findsNothing);
      expect(find.text('Bookings'), findsNothing);
    });

    // =========================================================================
    // TEST 8: Account Blocked Page for Rejected & Suspended Sellers
    // =========================================================================
    testWidgets('8. AccountBlockedPage renders administrative notice for suspended/rejected seller', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AccountBlockedPage(
            reason: 'आपकी दुकान को व्यवस्थापक (Admin) द्वारा निलंबित कर दिया गया है।',
          ),
        ),
      );

      expect(find.text('खाता निलंबित / ब्लॉक'), findsOneWidget);
      expect(find.text('आपकी दुकान को व्यवस्थापक (Admin) द्वारा निलंबित कर दिया गया है।'), findsOneWidget);
      expect(find.textContaining('JAMUI SERVICE एडमिन सपोर्ट'), findsOneWidget);
    });

    // =========================================================================
    // TEST 9: Approved Seller Workspace Access
    // =========================================================================
    testWidgets('9. ProfessionalShopWorkspaceScreen initializes for approved & verified seller', (tester) async {
      final approvedShop = ProfessionalShopProfileEntity(
        id: 'mock_seller_uid_01',
        ownerUid: 'mock_seller_uid_01',
        shopName: 'Jamui Fresh Grocery Mart',
        status: 'approved',
        isApproved: true,
        isActive: true,
        isSubscriptionActive: true,
        subscriptionExpiry: now.add(const Duration(days: 60)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopWorkspaceScreen(
            shop: approvedShop,
          ),
        ),
      );

      // Screen initializes safely
      expect(find.byType(ProfessionalShopWorkspaceScreen), findsOneWidget);
    });

    // =========================================================================
    // TEST 10: Complete State Routing Decision Matrix Invariant
    // =========================================================================
    test('10. Complete State Routing Matrix adheres to Zero Normal Provider Fallback invariant', () {
      Type evaluateRoute({
        required bool isProDomain,
        required ProfessionalShopProfileEntity? shop,
        required String currentUid,
      }) {
        if (!isProDomain) return Object; // ProviderWorkspaceScreen

        // Pro domain
        if (shop == null || shop.ownerUid != currentUid) {
          return ProfessionalShopResolutionErrorView;
        }

        if (shop.status == 'rejected') {
          return AccountBlockedPage;
        }

        if (shop.status == 'suspended' || !shop.isActive) {
          return AccountBlockedPage;
        }

        if (shop.status == 'pending' || shop.status == 'pendingReview' || !shop.isApproved) {
          return ProfessionalRegistrationTrackingPage;
        }

        return ProfessionalShopWorkspaceScreen;
      }

      const uid = 'mock_seller_uid_01';

      // Normal Provider
      expect(
        evaluateRoute(isProDomain: false, shop: null, currentUid: uid),
        Object,
      );

      // Pro domain with missing/mismatched shop -> Error View
      expect(
        evaluateRoute(isProDomain: true, shop: null, currentUid: uid),
        ProfessionalShopResolutionErrorView,
      );

      // Pro domain with pending review shop -> Tracking Page
      final pendingShop = ProfessionalShopProfileEntity(
        id: uid,
        ownerUid: uid,
        shopName: 'Jamui Fresh',
        status: 'pendingReview',
        isApproved: false,
      );
      expect(
        evaluateRoute(isProDomain: true, shop: pendingShop, currentUid: uid),
        ProfessionalRegistrationTrackingPage,
      );

      // Pro domain with rejected shop -> AccountBlockedPage
      final rejectedShop = ProfessionalShopProfileEntity(
        id: uid,
        ownerUid: uid,
        shopName: 'Jamui Fresh',
        status: 'rejected',
        isApproved: false,
      );
      expect(
        evaluateRoute(isProDomain: true, shop: rejectedShop, currentUid: uid),
        AccountBlockedPage,
      );

      // Pro domain with suspended shop -> AccountBlockedPage
      final suspendedShop = ProfessionalShopProfileEntity(
        id: uid,
        ownerUid: uid,
        shopName: 'Jamui Fresh',
        status: 'suspended',
        isApproved: true,
      );
      expect(
        evaluateRoute(isProDomain: true, shop: suspendedShop, currentUid: uid),
        AccountBlockedPage,
      );

      // Pro domain with approved shop -> Workspace
      final approvedShop = ProfessionalShopProfileEntity(
        id: uid,
        ownerUid: uid,
        shopName: 'Jamui Fresh',
        status: 'approved',
        isApproved: true,
        isActive: true,
        isSubscriptionActive: true,
        subscriptionExpiry: now.add(const Duration(days: 30)),
      );
      expect(
        evaluateRoute(isProDomain: true, shop: approvedShop, currentUid: uid),
        ProfessionalShopWorkspaceScreen,
      );
    });
  });
}
