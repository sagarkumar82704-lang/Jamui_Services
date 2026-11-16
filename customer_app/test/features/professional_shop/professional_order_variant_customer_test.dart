import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_order_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_order_receipt_sheet.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_order_tracking_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/localization/ecom_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EcomLocaleController.instance.setLocale('hi');
  });

  group('Customer App Order Variant & Receipt Currency Fix Tests', () {
    final variantOrder = ProfessionalOrderEntity(
      orderId: 'doc_order_cust_1',
      orderNumber: 'JS-284731',
      sellerOrderNumber: 'SGJ-019',
      channelId: 'JAMUI_SERVICES',
      customerId: 'cust_sagar',
      customerName: 'Sagar User',
      customerPhone: '9876543210',
      shopId: 'shop_sagar',
      shopName: 'Sagar Grocery Jamui',
      items: const [
        ProfessionalOrderItem(
          productId: 'p_tea_1',
          variantId: 'var_500g',
          variantTitle: '500g',
          title: 'Tata Tea Gold',
          unit: 'g',
          price: 49.50,
          quantity: 2,
          total: 99.00,
        ),
        ProfessionalOrderItem(
          productId: 'p_oil_1',
          variantId: 'var_1L',
          variantTitle: '1 Litre',
          title: 'Fortune Mustard Oil',
          unit: 'L',
          price: 165.25,
          quantity: 1,
          total: 165.25,
        ),
      ],
      subtotal: 264.25,
      deliveryCharge: 25.50,
      totalAmount: 289.75,
      fulfillmentType: 'delivery',
      status: 'placed',
      createdAt: DateTime(2026, 11, 9, 14, 30),
    );

    test('ProfessionalOrderItem parses variantTitle and avoids duplicate units', () {
      final it1 = variantOrder.items[0];
      expect(it1.hasVariant, isTrue);
      expect(it1.displayTitle, 'Tata Tea Gold (500g)');
      expect(it1.displayTitleWithUnit, 'Tata Tea Gold (500g)');

      final it2 = variantOrder.items[1];
      expect(it2.hasVariant, isTrue);
      expect(it2.displayTitle, 'Fortune Mustard Oil (1 Litre)');
      expect(it2.displayTitleWithUnit, 'Fortune Mustard Oil (1 Litre)');
    });

    test('Currency Formatter preserves whole and fractional rupee amounts accurately', () {
      expect(ProfessionalOrderItem.formatCurrency(49), '₹49');
      expect(ProfessionalOrderItem.formatCurrency(49.50), '₹49.50');
      expect(ProfessionalOrderItem.formatCurrency(49.75), '₹49.75');
      expect(ProfessionalOrderItem.formatCurrency(100.00), '₹100');
      expect(ProfessionalOrderItem.formatCurrency(264.25), '₹264.25');
      expect(ProfessionalOrderItem.formatCurrency(289.75), '₹289.75');
    });

    test('Safe quantity parsing handles non-standard numeric inputs safely', () {
      final mapDouble = {
        'productId': 'p1',
        'title': 'Test Item',
        'quantity': 2.0,
        'price': 49.50,
      };
      final itemFromMap = ProfessionalOrderItem.fromMap(mapDouble);
      expect(itemFromMap.quantity, 2);
      expect(itemFromMap.price, 49.50);
      expect(itemFromMap.total, 99.00);
    });

    testWidgets('ProfessionalOrderReceiptSheet displays variant titles and exact decimals', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalOrderReceiptSheet(order: variantOrder),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tata Tea Gold (500g) x 2'), findsOneWidget);
      expect(find.text('Fortune Mustard Oil (1 Litre) x 1'), findsOneWidget);
      expect(find.text('₹99'), findsOneWidget);
      expect(find.text('₹165.25'), findsOneWidget);
      expect(find.text('₹264.25'), findsOneWidget); // Subtotal
      expect(find.text('₹25.50'), findsOneWidget); // Delivery charge
      expect(find.text('₹289.75'), findsOneWidget); // Total
    });

    testWidgets('ProfessionalOrderTrackingPage displays variant titles and exact decimals', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalOrderTrackingPage(
              orderId: variantOrder.orderId,
              initialOrder: variantOrder,
              orderStream: Stream.value(variantOrder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand order items details
      await tester.tap(find.text(EcomStrings.viewOrderDetails));
      await tester.pumpAndSettle();

      expect(find.text('Tata Tea Gold (500g) x 2'), findsOneWidget);
      expect(find.text('Fortune Mustard Oil (1 Litre) x 1'), findsOneWidget);
      expect(find.text('₹99'), findsOneWidget);
      expect(find.text('₹165.25'), findsOneWidget);
      expect(find.text('₹264.25'), findsOneWidget); // Subtotal
      expect(find.text('₹25.50'), findsOneWidget); // Delivery charge
      expect(find.text('₹289.75'), findsOneWidget); // Total
    });
  });
}
