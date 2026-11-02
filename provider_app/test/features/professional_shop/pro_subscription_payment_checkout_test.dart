import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_subscription_page.dart';
import 'package:apna_jamui_provider/features/subscription/presentation/services/razorpay_checkout_service.dart';

/// Mock Remote Data Source for Professional Provider Payments
class MockProfessionalRemoteDataSource
    implements ProfessionalProviderRemoteDataSource {
  final List<Map<String, dynamic>> mockPlans;
  final Map<String, dynamic>? pendingPayment;
  ProfessionalShopProfileEntity? currentProfile;

  bool createOrderCalled = false;
  Map<String, dynamic>? createOrderParams;

  bool verifyPaymentCalled = false;
  Map<String, dynamic>? verifyPaymentParams;

  bool shouldTimeoutVerification = false;
  bool shouldFailVerification = false;

  MockProfessionalRemoteDataSource({
    required this.mockPlans,
    this.pendingPayment,
    this.currentProfile,
  });

  @override
  Future<List<Map<String, dynamic>>> fetchPublishedSubscriptionPlans() async {
    return mockPlans;
  }

  @override
  Stream<ProfessionalShopProfileEntity?> streamShopProfile(String uid,
      {String? ownerUid}) {
    return Stream.value(currentProfile);
  }

  @override
  Future<ProfessionalShopProfileEntity?> fetchShopProfile(String uid) async {
    return currentProfile;
  }

  @override
  Future<Map<String, dynamic>> createProfessionalSubscriptionOrder({
    required String shopId,
    required String planId,
  }) async {
    createOrderCalled = true;
    createOrderParams = {'shopId': shopId, 'planId': planId};
    final plan = mockPlans.firstWhere((p) => p['id'] == planId,
        orElse: () => mockPlans.first);

    final price = (plan['price'] as num?)?.toDouble() ?? 499.0;
    return {
      'success': true,
      'orderId': 'order_mock_test_12345',
      'amount': price,
      'amountInPaise': (price * 100).toInt(),
      'currency': 'INR',
      'keyId': 'rzp_test_mockKeyId1234',
      'shopId': shopId,
      'planId': planId,
      'planName': plan['name'] ?? 'Pro Standard',
      'durationDays': plan['durationDays'] ?? 30,
    };
  }

  @override
  Future<Map<String, dynamic>> verifyProfessionalSubscriptionPayment({
    required String shopId,
    required String planId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    verifyPaymentCalled = true;
    verifyPaymentParams = {
      'shopId': shopId,
      'planId': planId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    };

    if (shouldTimeoutVerification) {
      throw TimeoutException('Verification request timed out');
    }
    if (shouldFailVerification) {
      throw Exception('Payment signature mismatch');
    }

    // Simulate activation on profile
    if (currentProfile != null) {
      final now = DateTime.now();
      currentProfile = currentProfile!.copyWith(
        isSubscriptionActive: true,
        subscriptionPlanId: planId,
        subscriptionPlanName: 'Pro Standard 30 Days',
        subscriptionExpiry: now.add(const Duration(days: 30)),
        paymentVerified: true,
      );
    }

    return {
      'success': true,
      'alreadyVerified': false,
      'orderId': razorpayOrderId,
      'paymentId': razorpayPaymentId,
      'shopId': shopId,
      'planId': planId,
      'planName': 'Pro Standard 30 Days',
      'durationDays': 30,
      'isSubscriptionActive': true,
    };
  }

  @override
  Future<Map<String, dynamic>?> fetchLatestPendingPayment(String shopId) async {
    return pendingPayment;
  }

  // Stubs for other methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock Razorpay Checkout Service for testing callbacks
class MockRazorpayCheckoutService implements RazorpayCheckoutService {
  void Function(String paymentId, String orderId, String signature)? onSuccessCallback;
  void Function(int code, String message)? onErrorCallback;
  void Function()? onDismissCallback;
  void Function(String walletName)? onExternalWalletCallback;

  bool openCalled = false;
  Map<String, dynamic>? lastOptions;
  bool clearCalled = false;

  @override
  void init({
    required void Function(String paymentId, String orderId, String signature)
        onSuccess,
    required void Function(int code, String message) onError,
    required void Function() onDismiss,
    void Function(String walletName)? onExternalWallet,
  }) {
    onSuccessCallback = onSuccess;
    onErrorCallback = onError;
    onDismissCallback = onDismiss;
    onExternalWalletCallback = onExternalWallet;
  }

  @override
  void open(Map<String, dynamic> options) {
    openCalled = true;
    lastOptions = options;
  }

  @override
  void clear() {
    clearCalled = true;
  }
}

void main() {
  group('Professional Seller Razorpay Checkout & Subscription Page Tests (Phase 1C)', () {
    late ProfessionalShopProfileEntity testShop;
    late List<Map<String, dynamic>> testPlans;

    setUp(() {
      testShop = ProfessionalShopProfileEntity(
        id: 'shop_seller_1',
        ownerUid: 'seller_user_1',
        ownerPhone: '9876543210',
        ownerEmail: 'krishna@jamuiservices.com',
        shopName: 'Krishna Electronics',
        status: 'pending_approval',
        isApproved: false,
        isActive: false,
        isSubscriptionActive: false,
        subscriptionPlanName: 'Free Plan',
        maxProductsLimit: 100,
        imageLimit: 100,
        storageLimitMb: 500,
        subscriptionDurationDays: 30,
      );

      testPlans = [
        {
          'id': 'plan_pro_30',
          'name': 'Pro Standard 30 Days',
          'price': 499,
          'durationDays': 30,
          'maxProducts': 100,
          'maxImagesPerMonth': 200,
          'storageMb': 1024,
          'isActive': true,
        },
        {
          'id': 'plan_pro_90',
          'name': 'Pro Premium 90 Days',
          'price': 1299,
          'durationDays': 90,
          'maxProducts': 300,
          'maxImagesPerMonth': 500,
          'storageMb': 2048,
          'isActive': true,
        },
      ];
    });

    testWidgets('1. Displays real Firestore shop subscription details & plan limits',
        (WidgetTester tester) async {
      final mockDataSource = MockProfessionalRemoteDataSource(
        mockPlans: testPlans,
        currentProfile: testShop,
      );
      final mockCheckout = MockRazorpayCheckoutService();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopSubscriptionPage(
            shop: testShop,
            dataSource: mockDataSource,
            checkoutService: mockCheckout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shop Subscription Plans'), findsOneWidget);
      expect(find.text('Free Plan'), findsOneWidget);
      expect(find.text('EXPIRED'), findsOneWidget);
      expect(find.text('Pending Approval'), findsOneWidget);
      expect(find.textContaining('Up to 100 products'), findsOneWidget);
      expect(find.textContaining('1024 MB'), findsOneWidget);
      expect(find.text('Pro Standard 30 Days'), findsOneWidget);
      expect(find.text('₹499'), findsOneWidget);
      expect(find.text('Pro Premium 90 Days'), findsOneWidget);
      expect(find.text('₹1299'), findsOneWidget);
    });

    testWidgets('2. Displays Admin Approval separation notice when paid but unapproved',
        (WidgetTester tester) async {
      final paidUnapprovedShop = testShop.copyWith(
        isSubscriptionActive: true,
        subscriptionPlanName: 'Pro Standard 30 Days',
        subscriptionExpiry: DateTime.now().add(const Duration(days: 28)),
        isApproved: false,
        status: 'pending_approval',
      );

      final mockDataSource = MockProfessionalRemoteDataSource(
        mockPlans: testPlans,
        currentProfile: paidUnapprovedShop,
      );
      final mockCheckout = MockRazorpayCheckoutService();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopSubscriptionPage(
            shop: paidUnapprovedShop,
            dataSource: mockDataSource,
            checkoutService: mockCheckout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Pending Approval'), findsOneWidget);
      expect(find.text('Subscription Active — Pending Admin Approval'), findsOneWidget);
      expect(
        find.textContaining('Your shop is pending Admin Approval before appearing in the customer marketplace'),
        findsOneWidget,
      );
    });

    testWidgets('3. Subscribe button triggers createProfessionalSubscriptionOrder with server pricing',
        (WidgetTester tester) async {
      final mockDataSource = MockProfessionalRemoteDataSource(
        mockPlans: testPlans,
        currentProfile: testShop,
      );
      final mockCheckout = MockRazorpayCheckoutService();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopSubscriptionPage(
            shop: testShop,
            dataSource: mockDataSource,
            checkoutService: mockCheckout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Subscribe Now on first plan
      final subscribeBtn = find.text('Subscribe Now').first;
      await tester.ensureVisible(subscribeBtn);
      await tester.tap(subscribeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check createProfessionalSubscriptionOrder was called with strictly shopId and planId
      expect(mockDataSource.createOrderCalled, isTrue);
      expect(mockDataSource.createOrderParams?['shopId'], equals('shop_seller_1'));
      expect(mockDataSource.createOrderParams?['planId'], equals('plan_pro_30'));

      // Check Razorpay Checkout open was called with server order parameters
      expect(mockCheckout.openCalled, isTrue);
      expect(mockCheckout.lastOptions?['key'], equals('rzp_test_mockKeyId1234'));
      expect(mockCheckout.lastOptions?['amount'], equals(49900));
      expect(mockCheckout.lastOptions?['currency'], equals('INR'));
      expect(mockCheckout.lastOptions?['order_id'], equals('order_mock_test_12345'));
      expect(mockCheckout.lastOptions?['notes']?['type'], equals('professional_subscription'));
    });

    testWidgets('4. Successful checkout callback triggers backend verification & activates subscription',
        (WidgetTester tester) async {
      final mockDataSource = MockProfessionalRemoteDataSource(
        mockPlans: testPlans,
        currentProfile: testShop,
      );
      final mockCheckout = MockRazorpayCheckoutService();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopSubscriptionPage(
            shop: testShop,
            dataSource: mockDataSource,
            checkoutService: mockCheckout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start checkout
      final subscribeBtn = find.text('Subscribe Now').first;
      await tester.ensureVisible(subscribeBtn);
      await tester.tap(subscribeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate Razorpay SDK success callback
      mockCheckout.onSuccessCallback!(
        'pay_mock_test_9988',
        'order_mock_test_12345',
        'mock_signature_hash_abcdef',
      );
      await tester.pump(); // Show progress dialog
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle(); // Settle verify call

      expect(mockDataSource.verifyPaymentCalled, isTrue);
      expect(mockDataSource.verifyPaymentParams?['shopId'], equals('shop_seller_1'));
      expect(mockDataSource.verifyPaymentParams?['planId'], equals('plan_pro_30'));
      expect(mockDataSource.verifyPaymentParams?['razorpayOrderId'], equals('order_mock_test_12345'));
      expect(mockDataSource.verifyPaymentParams?['razorpayPaymentId'], equals('pay_mock_test_9988'));
      expect(mockDataSource.verifyPaymentParams?['razorpaySignature'], equals('mock_signature_hash_abcdef'));

      // Verify Success Dialog is shown
      expect(find.text('Subscription Activated!'), findsOneWidget);
    });

    testWidgets('5. User cancellation in Razorpay checkout resets state & displays cancelled banner',
        (WidgetTester tester) async {
      final mockDataSource = MockProfessionalRemoteDataSource(
        mockPlans: testPlans,
        currentProfile: testShop,
      );
      final mockCheckout = MockRazorpayCheckoutService();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopSubscriptionPage(
            shop: testShop,
            dataSource: mockDataSource,
            checkoutService: mockCheckout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final subscribeBtn = find.text('Subscribe Now').first;
      await tester.ensureVisible(subscribeBtn);
      await tester.tap(subscribeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate dismiss
      mockCheckout.onDismissCallback!();
      await tester.pumpAndSettle();

      expect(find.text('Payment cancelled by user. No amount was deducted.'), findsOneWidget);
    });

    testWidgets('6. Gateway error in Razorpay checkout displays failed payment SnackBar',
        (WidgetTester tester) async {
      final mockDataSource = MockProfessionalRemoteDataSource(
        mockPlans: testPlans,
        currentProfile: testShop,
      );
      final mockCheckout = MockRazorpayCheckoutService();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopSubscriptionPage(
            shop: testShop,
            dataSource: mockDataSource,
            checkoutService: mockCheckout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final subscribeBtn = find.text('Subscribe Now').first;
      await tester.ensureVisible(subscribeBtn);
      await tester.tap(subscribeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate error
      mockCheckout.onErrorCallback!(2, 'Card declined by issuing bank');
      await tester.pumpAndSettle();

      expect(find.text('Payment failed (2): Card declined by issuing bank'), findsOneWidget);
    });

    testWidgets('7. Verification timeout does not claim payment failed; presents retry option',
        (WidgetTester tester) async {
      final mockDataSource = MockProfessionalRemoteDataSource(
        mockPlans: testPlans,
        currentProfile: testShop,
      );
      mockDataSource.shouldTimeoutVerification = true;
      final mockCheckout = MockRazorpayCheckoutService();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopSubscriptionPage(
            shop: testShop,
            dataSource: mockDataSource,
            checkoutService: mockCheckout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final subscribeBtn = find.text('Subscribe Now').first;
      await tester.ensureVisible(subscribeBtn);
      await tester.tap(subscribeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Simulate payment success on gateway but backend verification timeout
      mockCheckout.onSuccessCallback!(
        'pay_mock_timeout_1',
        'order_mock_test_12345',
        'mock_signature_hash',
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Payment Verification Notice'), findsOneWidget);
      expect(
        find.textContaining('Your payment was captured by Razorpay, but server verification timed out. Your money is safe!'),
        findsOneWidget,
      );
      expect(find.text('Retry Verification'), findsOneWidget);
    });

    testWidgets('8. Pending recovery payment banner appears and triggers re-verification without new order',
        (WidgetTester tester) async {
      final pendingPaymentData = {
        'orderId': 'order_mock_pending_recovery_77',
        'razorpayOrderId': 'order_mock_pending_recovery_77',
        'paymentId': 'pay_mock_pending_recovery_88',
        'razorpayPaymentId': 'pay_mock_pending_recovery_88',
        'signature': 'mock_signature_rec_99',
        'razorpaySignature': 'mock_signature_rec_99',
        'planId': 'plan_pro_30',
        'amount': 499,
        'status': 'pending_retry',
      };

      final mockDataSource = MockProfessionalRemoteDataSource(
        mockPlans: testPlans,
        pendingPayment: pendingPaymentData,
        currentProfile: testShop,
      );
      final mockCheckout = MockRazorpayCheckoutService();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopSubscriptionPage(
            shop: testShop,
            dataSource: mockDataSource,
            checkoutService: mockCheckout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Pending Payment Verification (₹499)'), findsOneWidget);
      expect(find.text('Verify Payment Now'), findsOneWidget);

      // Tap Verify Payment Now
      final verifyNowBtn = find.text('Verify Payment Now');
      await tester.ensureVisible(verifyNowBtn);
      await tester.tap(verifyNowBtn);
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify payment was verified using existing credentials without creating new order
      expect(mockDataSource.createOrderCalled, isFalse);
      expect(mockDataSource.verifyPaymentCalled, isTrue);
      expect(mockDataSource.verifyPaymentParams?['razorpayOrderId'], equals('order_mock_pending_recovery_77'));
      expect(mockDataSource.verifyPaymentParams?['razorpayPaymentId'], equals('pay_mock_pending_recovery_88'));
    });

    testWidgets('9. Renewal button labels adapt to current active plan',
        (WidgetTester tester) async {
      final activeShop = testShop.copyWith(
        isSubscriptionActive: true,
        subscriptionPlanId: 'plan_pro_30',
        subscriptionPlanName: 'Pro Standard 30 Days',
        subscriptionExpiry: DateTime.now().add(const Duration(days: 15)),
        isApproved: true,
        status: 'approved',
      );

      final mockDataSource = MockProfessionalRemoteDataSource(
        mockPlans: testPlans,
        currentProfile: activeShop,
      );
      final mockCheckout = MockRazorpayCheckoutService();

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopSubscriptionPage(
            shop: activeShop,
            dataSource: mockDataSource,
            checkoutService: mockCheckout,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // For plan_pro_30 (current plan), button should say "Renew Plan"
      expect(find.text('Renew Plan'), findsOneWidget);
      // For plan_pro_90 (different plan), button should say "Switch to this Plan"
      expect(find.text('Switch to this Plan'), findsOneWidget);
    });

    testWidgets('10. Confirms Normal/Premium provider subscription page remains isolated',
        (WidgetTester tester) async {
      // Ensure Professional Shop data source uses dedicated collections
      expect(ProfessionalProviderRemoteDataSource.collectionPayments, equals('diamond_payments'));
      expect(ProfessionalProviderRemoteDataSource.collectionSubscriptionPlans, equals('diamond_subscription_plans'));
      expect(ProfessionalProviderRemoteDataSource.collectionShops, equals('diamond_shops'));
    });
  });
}
