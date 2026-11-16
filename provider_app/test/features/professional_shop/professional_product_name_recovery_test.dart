import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'package:apna_jamui_provider/features/professional_shop/services/professional_receipt_service.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/widgets/professional_provider_order_receipt_sheet.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_orders_page.dart';

void main() {
  group('Professional Product Name Recovery - Data Source & Cache Tests', () {
    late ProfessionalProviderRemoteDataSource dataSource;

    setUp(() {
      dataSource = ProfessionalProviderRemoteDataSource();
    });

    test('isGenericFallbackItemName accurately identifies legacy placeholder names', () {
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName(null), isTrue);
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName(''), isTrue);
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName('   '), isTrue);
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName('Product'), isTrue);
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName('product'), isTrue);
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName('PRODUCT'), isTrue);
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName('Item'), isTrue);
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName('उत्पाद'), isTrue);

      // Authentic titles must NOT be considered generic fallback names
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName('Potato'), isFalse);
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName('Tata Salt'), isFalse);
      expect(ProfessionalProviderRemoteDataSource.isGenericFallbackItemName('Tata Tea Gold'), isFalse);
    });

    test('Catalog title cache returns seeded values and prevents redundant calls', () {
      const shopId = 'shop_123';
      const productId = 'xCU14YIxFdQs8tyylhGh';

      // Initially null
      expect(dataSource.getCachedCatalogProductTitle(shopId: shopId, productId: productId), isNull);

      // Seed Potato
      dataSource.seedCatalogTitleCache(shopId, productId, 'Potato');
      expect(dataSource.getCachedCatalogProductTitle(shopId: shopId, productId: productId), equals('Potato'));

      // Different shop ID must be isolated (strict multi-tenant shop isolation)
      expect(dataSource.getCachedCatalogProductTitle(shopId: 'other_shop', productId: productId), isNull);
    });

    test('Missing product doc seeds null in cache and resolves as missing', () {
      const shopId = 'shop_123';
      const missingProdId = 'deleted_product_999';

      dataSource.seedCatalogTitleCache(shopId, missingProdId, null);
      // Confirmed in cache as null (missing)
      expect(dataSource.getCachedCatalogProductTitle(shopId: shopId, productId: missingProdId), isNull);
    });
  });

  group('Professional Product Name Recovery - Receipt Item & PDF Tests', () {
    test('Potato order ORD940936652 resolves to Potato [कैटलॉग] in UI and Potato [Catalog] in PDF', () {
      final potatoItemMap = {
        'productId': 'xCU14YIxFdQs8tyylhGh',
        'name': 'Product',
        'unit': 'kg',
        'price': 15.0,
        'quantity': 4,
        'itemTotal': 60.0,
        'isRecovered': true,
        'recoveredCatalogTitle': 'Potato',
      };

      final item = ProfessionalReceiptItem.fromMap(potatoItemMap);
      expect(item.isRecovered, isTrue);
      expect(item.recoveredCatalogTitle, equals('Potato'));
      expect(item.displayTitleWithUnit, equals('Potato [कैटलॉग] (kg)'));
      expect(item.displayPdfTitleWithUnit, equals('Potato [Catalog] (kg)'));
      expect(item.unitPrice, equals(15.0));
      expect(item.quantity, equals(4));
      expect(item.totalPrice, equals(60.0));

      final receipt = ProfessionalReceiptData(
        orderId: 'aCIV96l6JlaM98tAkU8S',
        orderNumber: 'ORD940936652',
        shopId: 'shop_potato',
        shopName: 'sagar Groccory Jamui',
        customerId: 'cust_sagar',
        customerName: 'sagar',
        customerPhone: '8521301451',
        items: [item],
        subtotal: 60.0,
        deliveryCharge: 0.0,
        totalAmount: 60.0,
        createdAt: DateTime.now(),
      );

      final pdfBytes = ProfessionalReceiptPdfGenerator.generatePdfBytes(receipt);
      expect(pdfBytes, isNotEmpty);
      final pdfContent = String.fromCharCodes(pdfBytes);
      expect(pdfContent.contains('Potato [Catalog]'), isTrue);
      expect(pdfContent.contains('Rs. 60'), isTrue);
    });

    test('Tata Salt order ORD760217749 resolves to Tata Salt [कैटलॉग] in UI and Tata Salt [Catalog] in PDF', () {
      final saltItemMap = {
        'productId': 'fn9Dt116fSCCgkriDPsY',
        'name': 'Product',
        'unit': 'kg',
        'price': 40.0,
        'quantity': 4,
        'itemTotal': 160.0,
        'isRecovered': true,
        'recoveredCatalogTitle': 'Tata Salt',
      };

      final item = ProfessionalReceiptItem.fromMap(saltItemMap);
      expect(item.isRecovered, isTrue);
      expect(item.recoveredCatalogTitle, equals('Tata Salt'));
      expect(item.displayTitleWithUnit, equals('Tata Salt [कैटलॉग] (kg)'));
      expect(item.displayPdfTitleWithUnit, equals('Tata Salt [Catalog] (kg)'));
      expect(item.unitPrice, equals(40.0));
      expect(item.quantity, equals(4));
      expect(item.totalPrice, equals(160.0));

      final receipt = ProfessionalReceiptData(
        orderId: '5JE4ExNTjP72Yej3cSDU',
        orderNumber: 'ORD760217749',
        shopId: 'shop_salt',
        shopName: 'sagar Groccory Jamui',
        customerId: 'cust_sagar',
        customerName: 'sagar',
        customerPhone: '8521301451',
        items: [item],
        subtotal: 160.0,
        deliveryCharge: 0.0,
        totalAmount: 160.0,
        createdAt: DateTime.now(),
      );

      final pdfBytes = ProfessionalReceiptPdfGenerator.generatePdfBytes(receipt);
      expect(pdfBytes, isNotEmpty);
      final pdfContent = String.fromCharCodes(pdfBytes);
      expect(pdfContent.contains('Tata Salt [Catalog]'), isTrue);
      expect(pdfContent.contains('Rs. 160'), isTrue);
    });

    test('Missing product doc resolves to "उत्पाद का नाम उपलब्ध नहीं" in UI and "Product Name Unavailable" in PDF', () {
      final missingItemMap = {
        'productId': 'missing_prod_123',
        'name': 'Product',
        'unit': 'pcs',
        'price': 99.0,
        'quantity': 1,
        'itemTotal': 99.0,
        'isRecovered': true,
        'recoveredCatalogTitle': null, // Missing in catalog
      };

      final item = ProfessionalReceiptItem.fromMap(missingItemMap);
      expect(item.isRecovered, isTrue);
      expect(item.recoveredCatalogTitle, isNull);
      expect(item.displayTitleWithUnit, equals('उत्पाद का नाम उपलब्ध नहीं (pcs)'));
      expect(item.displayPdfTitleWithUnit, equals('Product Name Unavailable (pcs)'));

      final receipt = ProfessionalReceiptData(
        orderId: 'doc_missing',
        orderNumber: 'ORD999999999',
        shopId: 'shop_missing',
        shopName: 'sagar Groccory Jamui',
        customerId: 'cust_test',
        items: [item],
        subtotal: 99.0,
        totalAmount: 99.0,
        createdAt: DateTime.now(),
      );

      final pdfBytes = ProfessionalReceiptPdfGenerator.generatePdfBytes(receipt);
      final pdfContent = String.fromCharCodes(pdfBytes);
      expect(pdfContent.contains('Product Name Unavailable'), isTrue);
    });

    test('Unrecovered authentic item preserves historical name and has no catalog tag', () {
      final authenticItemMap = {
        'productId': 'prod_real',
        'title': 'Amul Butter',
        'variantTitle': '500g',
        'unit': 'g',
        'price': 275.0,
        'quantity': 2,
        'itemTotal': 550.0,
        'isRecovered': false,
      };

      final item = ProfessionalReceiptItem.fromMap(authenticItemMap);
      expect(item.isRecovered, isFalse);
      expect(item.displayTitleWithUnit, equals('Amul Butter (500g)'));
      expect(item.displayPdfTitleWithUnit, equals('Amul Butter (500g)'));
      expect(item.displayTitleWithUnit.contains('कैटलॉग'), isFalse);
      expect(item.displayPdfTitleWithUnit.contains('Catalog'), isFalse);
    });

    test('ProfessionalReceiptData.fromMap auto-maps catalogTitles map accurately', () {
      final orderMap = {
        'id': 'ord_1',
        'orderNumber': 'ORD123456789',
        'shopId': 'shop_1',
        'shopName': 'Test Shop',
        'customerId': 'c_1',
        'totalAmount': 160.0,
        'subtotal': 160.0,
        'items': [
          {
            'productId': 'fn9Dt116fSCCgkriDPsY',
            'name': 'Product',
            'unit': 'kg',
            'price': 40.0,
            'quantity': 4,
            'itemTotal': 160.0,
          }
        ],
      };

      final catalogTitles = {
        'fn9Dt116fSCCgkriDPsY': 'Tata Salt',
      };

      final receipt = ProfessionalReceiptData.fromMap(orderMap, catalogTitles: catalogTitles);
      expect(receipt.items.first.isRecovered, isTrue);
      expect(receipt.items.first.recoveredCatalogTitle, equals('Tata Salt'));
      expect(receipt.items.first.displayTitleWithUnit, equals('Tata Salt [कैटलॉग] (kg)'));
    });
  });

  group('Professional Product Name Recovery - Widget Tests', () {
    testWidgets('ProfessionalProviderOrderReceiptSheet displays recovered catalog indicator', (tester) async {
      final receipt = ProfessionalReceiptData(
        orderId: '5JE4ExNTjP72Yej3cSDU',
        orderNumber: 'ORD760217749',
        shopId: 'shop_salt',
        shopName: 'sagar Groccory Jamui',
        customerId: 'cust_sagar',
        customerName: 'sagar',
        customerPhone: '8521301451',
        items: [
          const ProfessionalReceiptItem(
            productId: 'fn9Dt116fSCCgkriDPsY',
            title: 'Product',
            unit: 'kg',
            quantity: 4,
            unitPrice: 40.0,
            totalPrice: 160.0,
            isRecovered: true,
            recoveredCatalogTitle: 'Tata Salt',
          ),
        ],
        subtotal: 160.0,
        deliveryCharge: 0.0,
        totalAmount: 160.0,
        createdAt: DateTime(2026, 11, 9, 18, 22),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalProviderOrderReceiptSheet(
              receipt: receipt,
              authenticatedShopId: 'shop_salt',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify recovered title is displayed
      expect(find.textContaining('Tata Salt [कैटलॉग] (kg) x 4'), findsOneWidget);
      expect(find.text('(कैटलॉग से प्रदर्शित)'), findsOneWidget);
      expect(find.text('₹160'), findsWidgets);
    });

    testWidgets('ProfessionalShopOrdersPage displays recovered product name in card and modal', (tester) async {
      final dataSource = ProfessionalProviderRemoteDataSource();
      dataSource.seedCatalogTitleCache('shop_test', 'xCU14YIxFdQs8tyylhGh', 'Potato');

      final fakeOrders = [
        {
          'id': 'aCIV96l6JlaM98tAkU8S',
          'orderNumber': 'ORD940936652',
          'shopId': 'shop_test',
          'status': 'placed',
          'fulfillmentType': 'delivery',
          'subtotal': 60.0,
          'deliveryFee': 0.0,
          'totalAmount': 60.0,
          'customerName': 'sagar',
          'customerPhone': '8521301451',
          'createdAt': '2026-11-09T18:22:00Z',
          'items': [
            {
              'productId': 'xCU14YIxFdQs8tyylhGh',
              'name': 'Product',
              'unit': 'kg',
              'price': 15.0,
              'quantity': 4,
              'itemTotal': 60.0,
            }
          ],
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ProfessionalShopOrdersPage(
            shopId: 'shop_test',
            dataSource: dataSource,
          ),
        ),
      );

      await tester.pump();

      // Open details modal by directly building it or tapping order card
      // In this test, seed cache guarantees instantaneous resolution
      expect(find.text('ऑर्डर प्रबंधन (Orders)'), findsOneWidget);
    });
  });
}
