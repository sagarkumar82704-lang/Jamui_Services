import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_admin/features/providers/data/models/provider_filter_criteria.dart';
import 'package:apna_jamui_admin/features/providers/presentation/widgets/provider_advanced_filter_bar.dart';

void main() {
  group('ProviderAdvancedFilterBar Widget Tests', () {
    final mockCategories = [
      {'id': 'electrician', 'titleHindi': 'इलेक्ट्रीशियन', 'titleEnglish': 'Electrician', 'isActive': true},
      {'id': 'plumber', 'titleHindi': 'प्लम्बर', 'titleEnglish': 'Plumber', 'isActive': false},
    ];

    final mockAreas = [
      'जमुई मुख्य बाजार',
      'झाझा (Jhajha)',
      'सोनो (Sono)',
    ];

    testWidgets('1. Renders title, stats, and all dropdown filter controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderAdvancedFilterBar(
              criteria: ProviderFilterCriteria.initial,
              onCriteriaChanged: (_) {},
              onClearAll: () {},
              availableCategories: mockCategories,
              availableAreas: mockAreas,
              totalCount: 150,
              filteredCount: 150,
            ),
          ),
        ),
      );

      // Verify title and stats
      expect(find.text('उन्नत फ़िल्टर (Advanced Filters)'), findsOneWidget);
      expect(find.text('प्रदाता: 150 / कुल 150'), findsOneWidget);

      // Verify dropdown labels
      expect(find.text('स्टेटस (Status)'), findsOneWidget);
      expect(find.text('श्रेणी (Category)'), findsOneWidget);
      expect(find.text('स्थान / क्षेत्र (Location)'), findsOneWidget);
      expect(find.text('GPS दायरा (Radius)'), findsOneWidget);
      expect(find.text('पंजीकरण दिनांक (Registered Date)'), findsOneWidget);
      expect(find.text('सब्सक्रिप्शन (Subscription)'), findsOneWidget);

      // Initially no active chips and no Clear All button
      expect(find.text('सक्रिय फ़िल्टर:'), findsNothing);
      expect(find.text('फ़िल्टर साफ़ करें (Clear All)'), findsNothing);
    });

    testWidgets('2. Renders active filter chips and Clear All button when filters are active', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool clearAllCalled = false;
      ProviderFilterCriteria? changedCriteria;

      final criteriaWithFilters = const ProviderFilterCriteria(
        status: 'pending_approval',
        categoryId: 'electrician',
        jamuiArea: 'झाझा (Jhajha)',
        subscriptionFilter: 'active',
        searchQuery: 'Rajesh',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderAdvancedFilterBar(
              criteria: criteriaWithFilters,
              onCriteriaChanged: (c) => changedCriteria = c,
              onClearAll: () => clearAllCalled = true,
              availableCategories: mockCategories,
              availableAreas: mockAreas,
              totalCount: 150,
              filteredCount: 12,
            ),
          ),
        ),
      );

      // Active count badge
      expect(find.text('5 सक्रिय'), findsOneWidget);
      expect(find.text('प्रदाता: 12 / कुल 150'), findsOneWidget);
      expect(find.text('सक्रिय फ़िल्टर:'), findsOneWidget);
      expect(find.text('फ़िल्टर साफ़ करें (Clear All)'), findsOneWidget);

      // Tap Clear All
      await tester.tap(find.text('फ़िल्टर साफ़ करें (Clear All)'));
      await tester.pump();
      expect(clearAllCalled, isTrue);

      // Tap delete on search chip
      final searchChip = find.text('सर्च: "Rajesh"');
      expect(searchChip, findsOneWidget);

      // Tap the remove icon inside the search chip
      final closeIcons = find.byIcon(Icons.close);
      expect(closeIcons, findsWidgets);
      await tester.tap(closeIcons.last);
      await tester.pump();
      expect(changedCriteria, isNotNull);
      expect(changedCriteria!.searchQuery, isEmpty);
    });
  });
}
