import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_order_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_product_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/datasources/professional_shop_remote_data_source.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/bloc/professional_cart_bloc.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_order_receipt_sheet.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/storefront_floating_cart_bar.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/localization/ecom_strings.dart';
import 'package:apna_jamui_customer/features/professional_shop/services/professional_receipt_service.dart';

class MockCartCubit extends Cubit<ProfessionalCartState> implements ProfessionalCartBloc {
  MockCartCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EcomLocaleController.instance.setLocale('hi');
  });

  group('Professional Dual Order Identifier Entity Tests', () {
    test('ProfessionalOrderEntity properly parses new dual identifier fields', () {
      final map = {
        'orderId': 'doc_firestore_123',
        'orderNumber': 'JS-284731',
        'sellerOrderNumber': 'SGJ-019',
        'shopCode': 'SGJ',
        'channelId': 'JAMUI_SERVICES',
        'sellerToken': null,
        'invoiceNumber': null,
        'customerId': 'cust_1',
        'customerName': 'Sagar User',
        'customerPhone': '9876543210',
        'shopId': 'shop_sagar',
        'shopName': 'Sagar Grocery Jamui',
        'items': [
          {
            'productId': 'p1',
            'productTitle': 'Pure Mustard Oil',
            'price': 160.0,
            'quantity': 2,
            'unit': '1L',
          }
        ],
        'totalAmount': 320.0,
        'subtotal': 320.0,
        'deliveryFee': 0.0,
        'deliveryMethod': 'delivery',
        'deliveryAddress': {
          'fullAddress': 'Station Road, Jamui',
        },
        'status': 'placed',
      };

      final order = ProfessionalOrderEntity.fromMap(map, 'doc_firestore_123');

      expect(order.orderId, 'doc_firestore_123');
      expect(order.orderNumber, 'JS-284731');
      expect(order.sellerOrderNumber, 'SGJ-019');
      expect(order.shopCode, 'SGJ');
      expect(order.channelId, 'JAMUI_SERVICES');
      expect(order.sellerToken, isNull);
      expect(order.invoiceNumber, isNull);
      expect(order.shopName, 'Sagar Grocery Jamui');
      expect(order.totalAmount, 320.0);

      final toMapResult = order.toMap();
      expect(toMapResult['orderNumber'], 'JS-284731');
      expect(toMapResult['sellerOrderNumber'], 'SGJ-019');
      expect(toMapResult['channelId'], 'JAMUI_SERVICES');
      expect(toMapResult['sellerToken'], isNull);
      expect(toMapResult['invoiceNumber'], isNull);
    });

    test('ProfessionalOrderEntity gracefully handles legacy orders missing orderNumber', () {
      final legacyMap = {
        'orderId': 'ORD1731145600000',
        'customerId': 'cust_legacy',
        'customerName': 'Legacy Buyer',
        'shopId': 'shop_old',
        'shopName': 'Old Shop',
        'items': [],
        'totalAmount': 100.0,
        'status': 'delivered',
      };

      final order = ProfessionalOrderEntity.fromMap(legacyMap, 'doc_legacy_456');

      // Backward compatibility: orderNumber falls back to orderId or doc.id
      expect(order.orderNumber, 'ORD1731145600000');
      expect(order.sellerOrderNumber, isNull);
      expect(order.channelId, 'JAMUI_SERVICES');
      expect(order.sellerToken, isNull);
      expect(order.invoiceNumber, isNull);
    });

    test('PlaceOrderResult carries internal docId and public display orderNumber', () {
      const result = PlaceOrderResult(
        orderId: 'firestore_doc_789',
        orderNumber: 'JS-284731',
        sellerOrderNumber: 'SGJ-019',
        channelId: 'JAMUI_SERVICES',
      );

      expect(result.orderId, 'firestore_doc_789');
      expect(result.orderNumber, 'JS-284731');
      expect(result.sellerOrderNumber, 'SGJ-019');
      expect(result.channelId, 'JAMUI_SERVICES');
    });
  });

  group('Professional Order Receipt Sheet & PDF Actions (Customer App)', () {
    testWidgets('ProfessionalOrderReceiptSheet renders verified real data, Download/Share buttons, and hides Send to Customer', (tester) async {
      final order = ProfessionalOrderEntity(
        orderId: 'firestore_doc_999',
        orderNumber: 'JS-284731',
        sellerOrderNumber: 'SGJ-019',
        channelId: 'JAMUI_SERVICES',
        customerId: 'cust_123',
        customerName: 'Amit Kumar',
        customerPhone: '9431000000',
        shopId: 'shop_1',
        shopName: 'Jamui Super Market',
        items: const [
          ProfessionalOrderItem(
            productId: 'p_chana',
            title: 'Desi Chana Dal',
            price: 90.0,
            quantity: 2,
            unit: '1 kg',
            total: 180.0,
          ),
          ProfessionalOrderItem(
            productId: 'p_ghee',
            title: 'Pure Desi Ghee',
            price: 550.0,
            quantity: 1,
            unit: '500 ml',
            total: 550.0,
          ),
        ],
        subtotal: 730.0,
        deliveryCharge: 20.0,
        totalAmount: 750.0,
        fulfillmentType: 'delivery',
        deliveryAddress: const {
          'fullAddress': 'Main Market, Jamui',
          'landmark': 'Near SBI ATM',
        },
        status: 'placed',
        createdAt: DateTime(2026, 11, 9, 14, 30),
      );

      String? downloadedFileName;
      Uint8List? downloadedBytes;
      String? sharedFileName;
      Uint8List? sharedBytes;

      final mockReceiptService = ProfessionalReceiptService(
        downloadHandler: ({required fileName, required pdfBytes}) async {
          downloadedFileName = fileName;
          downloadedBytes = pdfBytes;
          return ReceiptActionResult(
            success: true,
            status: ReceiptActionStatus.downloaded,
            fileName: fileName,
            savedLocation: 'Downloads/$fileName',
            message: 'Receipt PDF saved to Downloads/$fileName',
          );
        },
        shareHandler: ({required fileName, required pdfBytes, required subject, required text}) async {
          sharedFileName = fileName;
          sharedBytes = pdfBytes;
          return ReceiptActionResult(
            success: true,
            status: ReceiptActionStatus.shared,
            fileName: fileName,
            message: 'Opened share sheet for $fileName',
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalOrderReceiptSheet(
              order: order,
              receiptService: mockReceiptService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Platform header & shop name
      expect(find.text('JAMUI SERVICES'), findsOneWidget);
      expect(find.text('Jamui Super Market'), findsOneWidget);

      // Store Order Number Badge
      expect(find.text('SGJ-019'), findsOneWidget);
      expect(find.text('STORE ORDER NO'), findsOneWidget);

      // Platform Order ID
      expect(find.text('#JS-284731'), findsOneWidget);

      // Real items list
      expect(find.textContaining('Desi Chana Dal'), findsOneWidget);
      expect(find.textContaining('Pure Desi Ghee'), findsOneWidget);
      expect(find.text('₹180'), findsOneWidget);
      expect(find.text('₹550'), findsOneWidget);

      // Financials
      expect(find.text('₹730'), findsOneWidget);
      expect(find.text('₹20'), findsOneWidget);
      expect(find.text('₹750'), findsOneWidget);

      // Real Customer Info
      expect(find.textContaining('Amit Kumar'), findsOneWidget);
      expect(find.textContaining('9431000000'), findsOneWidget);
      expect(find.textContaining('Main Market, Jamui'), findsOneWidget);

      // Mandatory Non-Tax Notice
      expect(find.text('Digital Order Receipt / Packing Slip — Not a Tax Invoice.'), findsOneWidget);
      expect(find.textContaining('This is a digital order receipt and packing slip'), findsOneWidget);

      // Verify Customer App shows Download PDF & Share PDF, and NEVER shows "Send to Customer on WhatsApp"
      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('Share PDF'), findsOneWidget);
      expect(find.text('Send to Customer on WhatsApp'), findsNothing);

      // Trigger Download PDF
      await tester.ensureVisible(find.byKey(const Key('receipt_download_pdf_button')));
      await tester.tap(find.byKey(const Key('receipt_download_pdf_button')));
      await tester.pumpAndSettle();

      expect(downloadedFileName, 'JamuiServices_JS-284731.pdf');
      expect(downloadedBytes, isNotNull);
      final pdfText = latin1.decode(downloadedBytes!);
      expect(pdfText.startsWith('%PDF-1.4'), isTrue);
      expect(pdfText.contains('Channel: JAMUI SERVICES'), isTrue);
      expect(pdfText.contains('Store: Jamui Super Market'), isTrue);
      expect(pdfText.contains('Platform Order Number: #JS-284731'), isTrue);
      expect(pdfText.contains('Seller Order Number: SGJ-019'), isTrue);
      expect(pdfText.contains('Desi Chana Dal'), isTrue);
      expect(pdfText.contains('Pure Desi Ghee'), isTrue);
      expect(pdfText.contains('Rs. 750'), isTrue);
      expect(pdfText.contains('Digital Order Receipt / Packing Slip - Not a Tax Invoice.'), isTrue);

      // Trigger Share PDF
      await tester.ensureVisible(find.byKey(const Key('receipt_share_pdf_button')));
      await tester.tap(find.byKey(const Key('receipt_share_pdf_button')));
      await tester.pumpAndSettle();

      expect(sharedFileName, 'JamuiServices_JS-284731.pdf');
      expect(sharedBytes, isNotNull);

      // Verify NO fake Tata Salt data is rendered
      expect(find.text('Tata Salt'), findsNothing);
      expect(find.text('320 reviews'), findsNothing);
    });

    testWidgets('ProfessionalOrderReceiptSheet gracefully hides empty customer address and phone in UI and PDF', (tester) async {
      final pickupOrder = ProfessionalOrderEntity(
        orderId: 'firestore_doc_pickup',
        orderNumber: 'JS-284732',
        sellerOrderNumber: 'SGJ-020',
        channelId: 'JAMUI_SERVICES',
        customerId: 'cust_anon',
        customerName: '',
        customerPhone: '',
        shopId: 'shop_1',
        shopName: 'Jamui Grocery',
        items: const [
          ProfessionalOrderItem(
            productId: 'p_rice',
            title: 'Basmati Rice',
            price: 120.0,
            quantity: 1,
            unit: '1 kg',
            total: 120.0,
          ),
        ],
        subtotal: 120.0,
        deliveryCharge: 0.0,
        totalAmount: 120.0,
        fulfillmentType: 'pickup',
        status: 'placed',
        createdAt: DateTime(2026, 11, 9, 15, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalOrderReceiptSheet(order: pickupOrder),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Store Pickup'), findsOneWidget);
      expect(find.text('#JS-284732'), findsOneWidget);
      expect(find.text('SGJ-020'), findsOneWidget);
      expect(find.textContaining('Basmati Rice'), findsOneWidget);
      expect(find.text('₹120'), findsAtLeastNWidgets(1));

      // Customer section hidden when customer name & phone are empty
      expect(find.textContaining('Customer:'), findsNothing);
      expect(find.textContaining('Address:'), findsNothing);

      // Also verify PDF hides empty customer & discount fields
      final pdfBytes = ProfessionalReceiptPdfGenerator.generatePdfBytes(pickupOrder.toReceiptData());
      final pdfText = latin1.decode(pdfBytes);
      expect(pdfText.contains('Customer:'), isFalse);
      expect(pdfText.contains('Customer Phone:'), isFalse);
      expect(pdfText.contains('Delivery Address:'), isFalse);
      expect(pdfText.contains('Discount:'), isFalse);
      expect(pdfText.contains('Fulfillment Type: Store Pickup'), isTrue);
    });
  });

  group('Storefront Cross-Shop Cart Banner Tests', () {
    testWidgets('StorefrontFloatingCartBar shows amber cross-shop notice bar when browsing Store B with Store A cart', (tester) async {
      const shopA = ProfessionalShopEntity(
        id: 'shop_A',
        shopName: 'Sagar Kirana Store',
        jamuiArea: 'Jamui Chowk',
        isHomeDeliveryActive: true,
        isPickupActive: true,
        rating: 4.8,
        ratingCount: 15,
      );

      const shopB = ProfessionalShopEntity(
        id: 'shop_B',
        shopName: 'Patna General Store',
        jamuiArea: 'Station Road',
        isHomeDeliveryActive: true,
        isPickupActive: true,
        rating: 4.5,
        ratingCount: 10,
      );

      const testProduct = ProfessionalProductEntity(
        id: 'p1',
        shopId: 'shop_A',
        titleEnglish: 'Tea Leaves',
        titleHindi: 'चाय पत्ती',
        sellingPrice: 150.0,
        regularPrice: 180.0,
        unit: '500g',
      );

      final cartBloc = MockCartCubit(
        const ProfessionalCartState(
          currentShop: shopA,
          items: [
            CartItemModel(
              product: testProduct,
              quantity: 2,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<ProfessionalCartBloc>.value(
              value: cartBloc,
              child: const StorefrontFloatingCartBar(browsingShop: shopB),
            ),
          ),
        ),
      );
      await tester.pump();

      // Amber cross-shop notice bar must be displayed
      expect(find.textContaining('कार्ट: Sagar Kirana Store (2)'), findsOneWidget);
      expect(find.text('कार्ट देखें'), findsOneWidget);

      await cartBloc.close();
    });
  });
}
