import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/constants/app_colors.dart';

void main() {
  testWidgets('App branding and colors smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'JAMUI SERVICE',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
    expect(find.text('JAMUI SERVICE'), findsOneWidget);
  });
}
