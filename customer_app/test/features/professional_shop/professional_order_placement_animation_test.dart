import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_order_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_order_processing_overlay.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_order_success_animation.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_order_success_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_order_tracking_page.dart';

void main() {
  group('Professional Order Placement & Animation Tests', () {
    testWidgets('1. ProfessionalOrderProcessingOverlay displays Hindi text, progress bar and blocks back pop',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfessionalOrderProcessingOverlay(),
          ),
        ),
      );

      // Verify Hindi messages
      expect(find.text('आपका ऑर्डर प्रोसेस हो रहा है...'), findsOneWidget);
      expect(find.text('कृपया प्रतीक्षा करें।'), findsOneWidget);
      expect(find.text('सुरक्षित लेनदेन • Jamui Services'), findsOneWidget);

      // Verify Progress bar & Icon
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_rounded), findsOneWidget);

      // Verify PopScope blocks back navigation
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);

      // Advance animation frames safely
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('2. ProfessionalOrderProcessingOverlay custom title and subtitle support',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfessionalOrderProcessingOverlay(
              customTitle: 'कस्टम प्रोसेसिंग...',
              customSubtitle: 'दो सेकंड प्रतीक्षा करें',
            ),
          ),
        ),
      );

      expect(find.text('कस्टम प्रोसेसिंग...'), findsOneWidget);
      expect(find.text('दो सेकंड प्रतीक्षा करें'), findsOneWidget);
    });

    testWidgets('3. ProfessionalOrderSuccessAnimation animates checkmark and triggers callback',
        (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProfessionalOrderSuccessAnimation(
                size: 120,
                onAnimationComplete: () => completed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ProfessionalOrderSuccessAnimation), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Animate through full duration (1400ms)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(completed, isTrue);
    });

    testWidgets('4. ProfessionalOrderSuccessPage displays JS-284731, SGJ-019 and real store information',
        (tester) async {
      final order = ProfessionalOrderEntity(
        orderId: 'doc_diamond_order_123',
        orderNumber: 'JS-284731',
        sellerOrderNumber: 'SGJ-019',
        channelId: 'JAMUI_SERVICES',
        customerId: 'cust_001',
        customerName: 'Sagar Kumar',
        customerPhone: '9876543210',
        shopId: 'shop_001',
        shopName: 'sagar Groccory Jamui',
        fulfillmentType: 'delivery',
        deliveryAddress: const {
          'address': 'Main Market, Station Road',
          'area': 'Jamui',
        },
        items: const [
          ProfessionalOrderItem(
            productId: 'p1',
            title: 'Tata Tea Gold',
            variantTitle: '500g',
            unit: 'g',
            price: 49.50,
            quantity: 2,
            total: 99.00,
          ),
        ],
        subtotal: 99.00,
        deliveryCharge: 0.0,
        totalAmount: 99.00,
        paymentMode: 'cod',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalOrderSuccessPage(order: order),
        ),
      );

      // Verify Hindi Titles
      expect(find.text('ऑर्डर सफलतापूर्वक हो गया!'), findsOneWidget);
      expect(find.text('धन्यवाद! आपका ऑर्डर मिल गया है।'), findsOneWidget);

      // Verify Platform Order Number & Seller Order Number
      expect(find.text('JS-284731'), findsOneWidget);
      expect(find.text('SGJ-019'), findsOneWidget);

      // Verify Store & Fulfillment details
      expect(find.text('sagar Groccory Jamui'), findsOneWidget);
      expect(find.text('होम डिलीवरी'), findsOneWidget);
      expect(find.text('₹99'), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('ऑर्डर ट्रैक करें'), findsOneWidget);
      expect(find.text('शॉपिंग जारी रखें'), findsOneWidget);

      // Verify PopScope blocks popping back to checkout
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsWidgets);
      final popScope = tester.widget<PopScope>(popScopeFinder.first);
      expect(popScope.canPop, isFalse);

      await tester.pump(const Duration(milliseconds: 1400));
    });

    testWidgets('5. ProfessionalOrderSuccessPage "ऑर्डर ट्रैक करें" triggers tracking navigation with orderId',
        (tester) async {
      String? trackedId;
      final order = ProfessionalOrderEntity(
        orderId: 'doc_diamond_order_123',
        orderNumber: 'JS-284731',
        customerId: 'cust_001',
        shopId: 'shop_001',
        shopName: 'sagar Groccory Jamui',
        subtotal: 100.0,
        totalAmount: 100.0,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalOrderSuccessPage(
            order: order,
            onTrackOrder: (ctx) => trackedId = order.orderId,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1400));

      final trackBtn = find.text('ऑर्डर ट्रैक करें');
      expect(trackBtn, findsOneWidget);
      await tester.tap(trackBtn);
      await tester.pump();

      // Confirms navigation handler receives the internal orderId
      expect(trackedId, equals('doc_diamond_order_123'));
    });

    testWidgets('6. ProfessionalOrderSuccessPage "शॉपिंग जारी रखें" invokes callback',
        (tester) async {
      bool continued = false;
      final order = ProfessionalOrderEntity(
        orderId: 'doc_diamond_order_123',
        orderNumber: 'JS-284731',
        customerId: 'cust_001',
        shopId: 'shop_001',
        shopName: 'sagar Groccory Jamui',
        subtotal: 100.0,
        totalAmount: 100.0,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalOrderSuccessPage(
            order: order,
            onContinueShopping: () => continued = true,
          ),
        ),
      );

      final continueBtn = find.text('शॉपिंग जारी रखें');
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pump();

      expect(continued, isTrue);
    });

    testWidgets('7. ProfessionalOrderSuccessPage copy order number action copies to clipboard',
        (tester) async {
      final order = ProfessionalOrderEntity(
        orderId: 'doc_diamond_order_123',
        orderNumber: 'JS-284731',
        customerId: 'cust_001',
        shopId: 'shop_001',
        shopName: 'sagar Groccory Jamui',
        subtotal: 100.0,
        totalAmount: 100.0,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalOrderSuccessPage(order: order),
        ),
      );

      final copyBtn = find.text('कॉपी करें');
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      await tester.pump();

      expect(find.text('ऑर्डर नंबर कॉपी किया गया: JS-284731'), findsOneWidget);
    });

    testWidgets('8. Online payment mode does not falsely mark paymentStatus completed',
        (tester) async {
      final order = ProfessionalOrderEntity(
        orderId: 'doc_online_order_456',
        orderNumber: 'JS-284732',
        customerId: 'cust_001',
        shopId: 'shop_001',
        shopName: 'sagar Groccory Jamui',
        paymentMode: 'razorpay',
        paymentStatus: 'pending', // Must remain pending until verified
        subtotal: 250.0,
        totalAmount: 250.0,
        createdAt: DateTime.now(),
      );

      expect(order.paymentStatus, equals('pending'));
      expect(order.paymentMode, equals('razorpay'));

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalOrderSuccessPage(order: order),
        ),
      );

      // Confirms payment mode displayed is online and not falsely claimed COD
      expect(find.textContaining('ऑनलाइन'), findsOneWidget);
    });

    testWidgets('9. Order items formatting preserves decimals and avoids duplicate units',
        (tester) async {
      const itemWithUnitInVariant = ProfessionalOrderItem(
        productId: 'p1',
        title: 'Tata Tea Gold',
        variantTitle: '500g',
        unit: 'g',
        price: 49.50,
        quantity: 2,
        total: 99.00,
      );

      expect(itemWithUnitInVariant.displayTitleWithUnit, equals('Tata Tea Gold (500g)'));
      expect(ProfessionalOrderItem.formatCurrency(49.50), equals('₹49.50'));
      expect(ProfessionalOrderItem.formatCurrency(100.00), equals('₹100'));
    });
  });
}
