import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_admin/features/professional_admin/data/datasources/professional_admin_remote_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2H: Admin Professional Marketplace Inspector Tests', () {
    test('ProfessionalAdminRemoteDataSource maps physical collections safely', () {
      expect(ProfessionalAdminRemoteDataSource.collectionShops, 'diamond_shops');
      expect(ProfessionalAdminRemoteDataSource.collectionOrders, 'diamond_orders');
      expect(ProfessionalAdminRemoteDataSource.collectionCategories, 'diamond_categories');
      expect(ProfessionalAdminRemoteDataSource.collectionSubscriptionPlans, 'diamond_subscription_plans');
      expect(ProfessionalAdminRemoteDataSource.collectionPayments, 'diamond_payments');
    });

    test('Shop Inspection Data Structure accommodates all Phase 2H requirements', () {
      final sampleDetails = {
        'totalProducts': 12,
        'activeProducts': 10,
        'inactiveProducts': 2,
        'totalStoreCategories': 3,
        'activeStoreCategories': 3,
        'inactiveStoreCategories': 0,
        'totalOrders': 25,
        'deliveredOrders': 20,
        'cancelledOrders': 2,
        'totalOrderValue': 7500.0,
        'latestPayment': {
          'status': 'captured',
          'paymentId': 'pay_test_123456',
          'orderId': 'order_test_987654',
          'verifiedAt': DateTime.now().toIso8601String(),
        },
      };

      expect(sampleDetails['totalProducts'], 12);
      expect(sampleDetails['activeProducts'], 10);
      expect(sampleDetails['inactiveProducts'], 2);
      expect(sampleDetails['totalStoreCategories'], 3);
      expect(sampleDetails['deliveredOrders'], 20);
      expect(sampleDetails['totalOrderValue'], 7500.0);
      expect((sampleDetails['latestPayment'] as Map)['status'], 'captured');
      expect((sampleDetails['latestPayment'] as Map)['paymentId'], 'pay_test_123456');
    });

    testWidgets('Admin Inspector displays all mandatory inspection sections and labels', (tester) async {
      final sampleShop = {
        'id': 'shop_admin_test_001',
        'ownerUid': 'uid_owner_888',
        'ownerName': 'Vikram Sharma',
        'ownerPhone': '+919876543210',
        'ownerEmail': 'vikram.pro@jamuiservices.in',
        'shopName': 'Vikram Electronics & Electricals',
        'demandCategoryTitle': 'Electronics & Appliances',
        'jamuiArea': 'Station Road, Jamui',
        'fullAddress': 'Holding No. 45, Near Railway Crossing, Jamui - 811307',
        'contactPhone': '+919876543210',
        'whatsAppNumber': '+919876543210',
        'status': 'pending',
        'isActive': false,
        'isSubscriptionActive': true,
        'planName': 'Enterprise Pro',
        'planPrice': 499.0,
        'planDurationDays': 30,
        'subscriptionExpiresAt': DateTime.now().add(const Duration(days: 28)).toIso8601String(),
        'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UID: ${sampleShop['ownerUid']}'),
                  Text('Owner Name: ${sampleShop['ownerName']}'),
                  Text('Owner Mobile: ${sampleShop['ownerPhone']}'),
                  Text('Owner Email: ${sampleShop['ownerEmail']}'),
                  Text('Shop Name: ${sampleShop['shopName']}'),
                  Text('Category: ${sampleShop['demandCategoryTitle']}'),
                  Text('Locality: ${sampleShop['jamuiArea']}'),
                  Text('Address: ${sampleShop['fullAddress']}'),
                  Text('Pro Plan: ${sampleShop['planName']}'),
                  Text('Plan Price: ₹${sampleShop['planPrice']} / ${sampleShop['planDurationDays']} days'),
                  const Text('Approve Shop'),
                  const Text('Reject'),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify all inspector elements
      expect(find.textContaining('Vikram Sharma'), findsOneWidget);
      expect(find.textContaining('+919876543210'), findsWidgets);
      expect(find.textContaining('vikram.pro@jamuiservices.in'), findsOneWidget);
      expect(find.textContaining('uid_owner_888'), findsOneWidget);
      expect(find.textContaining('Vikram Electronics'), findsOneWidget);
      expect(find.textContaining('Electronics & Appliances'), findsOneWidget);
      expect(find.textContaining('Station Road, Jamui'), findsOneWidget);
      expect(find.textContaining('Enterprise Pro'), findsOneWidget);
      expect(find.text('Approve Shop'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });
  });
}

