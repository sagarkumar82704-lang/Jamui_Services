import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/categories/data/models/service_category_model.dart';

void main() {
  group('Provider Category Selection Visibility & Parsing Tests', () {
    test('Professional category dictionary parses titleEnglish, name, and titleHindi correctly', () {
      final adminCreatedCategory = <String, dynamic>{
        'id': 'cat_grocery',
        'titleEnglish': 'Grocery & Staples',
        'titleHindi': 'किराना एवं दैनिक वस्तुएं',
        'slug': 'cat_grocery',
        'iconUrl': 'https://example.com/icon.png',
        'priorityOrder': 1,
        'isActive': true,
      };

      final catId = (adminCreatedCategory['id'] as String?) ?? '';
      final titleEng = (adminCreatedCategory['titleEnglish'] as String?) ??
          (adminCreatedCategory['name'] as String?) ??
          catId;
      final titleHin = (adminCreatedCategory['titleHindi'] as String?) ??
          (adminCreatedCategory['nameHindi'] as String?) ??
          '';

      expect(catId, equals('cat_grocery'));
      expect(titleEng, equals('Grocery & Staples'));
      expect(titleHin, equals('किराना एवं दैनिक वस्तुएं'));
    });

    test('Professional categories sorting obeys priorityOrder and falls back to displayOrder or 0', () {
      final list = <Map<String, dynamic>>[
        {'id': 'cat_clothing', 'titleEnglish': 'Clothing', 'priorityOrder': 5},
        {'id': 'cat_grocery', 'titleEnglish': 'Grocery', 'priorityOrder': 1},
        {'id': 'cat_stationery', 'titleEnglish': 'Stationery', 'priorityOrder': 3},
        {'id': 'cat_fruits', 'titleEnglish': 'Fruits', 'displayOrder': 2},
      ];

      list.sort((a, b) =>
          ((a['priorityOrder'] as num?) ?? (a['displayOrder'] as num?) ?? 0)
              .compareTo((b['priorityOrder'] as num?) ?? (b['displayOrder'] as num?) ?? 0));

      final sortedIds = list.map((e) => e['id']).toList();
      expect(sortedIds, equals(['cat_grocery', 'cat_fruits', 'cat_stationery', 'cat_clothing']));
    });

    test('Normal categories from categories collection remain separated from professional categories', () {
      final normalModel = ServiceCategoryModel(
        id: 'electrician',
        titleHindi: 'इलेक्ट्रीशियन',
        titleEnglish: 'Electrician',
        description: 'Wiring and appliances repair',
        imageUrl: '',
        iconName: 'electrical_services',
        colorHex: '#4CAF50',
        priorityOrder: 1,
        subServices: const ['Fan Repair', 'Wiring'],
        isPremium: false,
        categoryType: 'general',
      );

      expect(normalModel.categoryType, equals('general'));
      expect(normalModel.isPremium, isFalse);
      expect(normalModel.id, equals('electrician'));
    });

    test('Professional seller profile flags generation test', () {
      const selectedCategoryType = 'professional';
      final isPro = selectedCategoryType == 'professional' || selectedCategoryType == 'diamond';

      final providerData = {
        'primaryCategoryId': 'grocery',
        'primaryCategoryTitle': 'Grocery & Staples',
        'categoryType': selectedCategoryType,
        'isProfessional': isPro,
        'isDiamond': isPro,
        'businessType': isPro ? 'professional_seller' : 'service_provider',
      };

      expect(providerData['isProfessional'], isTrue);
      expect(providerData['isDiamond'], isTrue);
      expect(providerData['businessType'], equals('professional_seller'));
    });

    test('Normal service provider profile flags generation test', () {
      const selectedCategoryType = 'general';
      final isPro = selectedCategoryType == 'professional' || selectedCategoryType == 'diamond';

      final providerData = {
        'primaryCategoryId': 'electrician',
        'primaryCategoryTitle': 'Electrician',
        'categoryType': selectedCategoryType,
        'isProfessional': isPro,
        'isDiamond': isPro,
        'businessType': isPro ? 'professional_seller' : 'service_provider',
      };

      expect(providerData['isProfessional'], isFalse);
      expect(providerData['isDiamond'], isFalse);
      expect(providerData['businessType'], equals('service_provider'));
    });
  });
}
