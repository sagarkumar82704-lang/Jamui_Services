import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_shop_skeleton.dart';

void main() {
  group('ProfessionalShopSkeleton Tests', () {
    testWidgets('renders skeleton container and shimmer elements properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfessionalShopSkeleton(),
          ),
        ),
      );

      // Verify skeleton widget is present
      expect(find.byType(ProfessionalShopSkeleton), findsOneWidget);

      // Verify AnimatedBuilder drives shimmer
      expect(find.byType(AnimatedBuilder), findsAtLeastNWidgets(1));

      // Pump 500ms to test animation progress without errors
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders multiple skeletons in a list without overflowing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                ProfessionalShopSkeleton(),
                ProfessionalShopSkeleton(),
                ProfessionalShopSkeleton(),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ProfessionalShopSkeleton), findsNWidgets(3));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    });
  });
}
