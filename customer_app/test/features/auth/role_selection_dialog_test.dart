import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/auth/domain/entities/customer_entity.dart';
import 'package:apna_jamui_customer/features/auth/presentation/widgets/role_selection_dialog.dart';

void main() {
  group('RoleSelectionDialog Tests', () {
    final testCustomer = CustomerEntity(
      id: 'test_uid_456',
      fullName: 'सागर कुमार',
      email: 'sagar@example.com',
      phoneNumber: '+919876543210',
      jamuiArea: 'जमुई स्टेशन रोड',
      address: 'स्टेशन रोड, जमुई',
      createdAt: DateTime.now(),
    );

    final approvedProvider = {
      'id': 'test_uid_456',
      'businessName': 'सागर इलेक्ट्रिकल वर्क्स',
      'primaryCategoryTitle': 'इलेक्ट्रीशियन',
      'status': 'approved',
      'isVerified': true,
    };

    final pendingProvider = {
      'id': 'test_uid_456',
      'businessName': 'नया पार्टनर',
      'primaryCategoryTitle': 'प्लंबिंग',
      'status': 'pending',
      'isVerified': false,
    };

    testWidgets('renders both Customer and Approved Provider options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleSelectionDialog(
              customer: testCustomer,
              providerData: approvedProvider,
              isProviderApproved: true,
              providerStatus: 'approved',
              onSignOut: () {},
            ),
          ),
        ),
      );

      // Verify header and titles
      expect(find.text('खाता चुनें (Select Profile)'), findsOneWidget);
      expect(find.text('सागर कुमार'), findsOneWidget);
      expect(find.text('सागर इलेक्ट्रिकल वर्क्स'), findsOneWidget);
      expect(find.text('सत्यापित'), findsOneWidget);
    });

    testWidgets('renders Pending badge for unapproved provider', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleSelectionDialog(
              customer: testCustomer,
              providerData: pendingProvider,
              isProviderApproved: false,
              providerStatus: 'pending',
              onSignOut: () {},
            ),
          ),
        ),
      );

      expect(find.text('समीक्षाधीन'), findsOneWidget);
      expect(find.text('नया पार्टनर'), findsOneWidget);
    });
  });
}
