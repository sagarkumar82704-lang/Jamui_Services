import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/ai_search_intent_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_category_entity.dart';
import 'package:apna_jamui_customer/core/services/ai_search_intent_service.dart';
import 'package:apna_jamui_customer/core/services/location_service.dart';

void main() {
  group('AI Smart Search & Intent Extraction Tests', () {
    // Dynamic real Firestore categories
    final List<ServiceCategoryEntity> activeCategories = [
      const ServiceCategoryEntity(
        id: 'cat_electrician_101',
        titleHindi: 'इलेक्ट्रीशियन',
        titleEnglish: 'Electrician',
        iconName: 'bolt',
        colorHex: '#F59E0B',
        priorityOrder: 1,
        isActive: true,
        subServices: ['Fan Repair', 'House Wiring', 'Switch Board', 'Inverter'],
        commonProblems: ['पंखा नहीं चल रहा', 'शॉर्ट सर्किट', 'लाइट खराब', 'पंखा खराब'],
      ),
      const ServiceCategoryEntity(
        id: 'cat_plumber_202',
        titleHindi: 'प्लंबर',
        titleEnglish: 'Plumber',
        iconName: 'plumbing',
        colorHex: '#3B82F6',
        priorityOrder: 2,
        isActive: true,
        subServices: ['Pipe Leakage', 'Water Tank', 'Tap Repair', 'Drainage'],
        commonProblems: ['पानी टपक रहा है', 'पाइप लीक', 'टंकी की सफाई', 'नल खराब'],
      ),
      const ServiceCategoryEntity(
        id: 'cat_ac_303',
        titleHindi: 'एसी व फ्रिज मरम्मत',
        titleEnglish: 'AC & Appliance Repair',
        iconName: 'ac_unit',
        colorHex: '#10B981',
        priorityOrder: 3,
        isActive: true,
        subServices: ['AC Servicing', 'Gas Refill', 'Fridge Repair', 'Cooling Issue'],
        commonProblems: ['AC ठंडा नहीं कर रहा', 'कूलिंग नहीं हो रही', 'गैस खत्म'],
      ),
      // Inactive category (should be ignored)
      const ServiceCategoryEntity(
        id: 'cat_inactive_999',
        titleHindi: 'अक्रिय श्रेणी',
        titleEnglish: 'Inactive Category',
        iconName: 'block',
        colorHex: '#999999',
        priorityOrder: 99,
        isActive: false,
        subServices: ['Inactive SubService'],
        commonProblems: ['Problem in inactive'],
      ),
    ];

    test('Test 1: Hindi Fan query matches Electrician category (मेरे घर का पंखा खराब है)', () async {
      final intent = await AISearchIntentService.extractIntent(
        query: 'मेरे घर का पंखा खराब है',
        availableCategories: activeCategories,
        backendTimeout: const Duration(milliseconds: 10),
      );

      expect(intent.categoryId, equals('cat_electrician_101'));
      expect(intent.categoryTitleHindi, equals('इलेक्ट्रीशियन'));
      expect(intent.confidence, greaterThanOrEqualTo(0.40));
    });

    test('Test 2: Hindi Pipe Leakage query matches Plumber category (पानी की पाइप लीक हो रही है)', () async {
      final intent = await AISearchIntentService.extractIntent(
        query: 'पानी की पाइप लीक हो रही है',
        availableCategories: activeCategories,
        backendTimeout: const Duration(milliseconds: 10),
      );

      expect(intent.categoryId, equals('cat_plumber_202'));
      expect(intent.categoryTitleHindi, equals('प्लंबर'));
      expect(intent.confidence, greaterThanOrEqualTo(0.40));
    });

    test('Test 3: Hindi AC query matches AC category (AC ठंडा नहीं कर रहा)', () async {
      final intent = await AISearchIntentService.extractIntent(
        query: 'AC ठंडा नहीं कर रहा',
        availableCategories: activeCategories,
        backendTimeout: const Duration(milliseconds: 10),
      );

      expect(intent.categoryId, equals('cat_ac_303'));
      expect(intent.confidence, greaterThanOrEqualTo(0.40));
    });

    test('Test 4: Hinglish Wiring query matches Electrician (Mere ghar me wiring ka problem hai)', () async {
      final intent = await AISearchIntentService.extractIntent(
        query: 'Mere ghar me wiring ka problem hai',
        availableCategories: activeCategories,
        backendTimeout: const Duration(milliseconds: 10),
      );

      expect(intent.categoryId, equals('cat_electrician_101'));
      expect(intent.confidence, greaterThanOrEqualTo(0.40));
    });

    test('Test 5: Ambiguous query requires clarification (मुझे कुछ काम करवाना है)', () async {
      final intent = await AISearchIntentService.extractIntent(
        query: 'मुझे कुछ काम करवाना है',
        availableCategories: activeCategories,
        backendTimeout: const Duration(milliseconds: 10),
      );

      expect(
        intent.intentType == AISearchIntentType.clarificationRequired ||
            intent.intentType == AISearchIntentType.noMatch ||
            intent.confidence < 0.40,
        isTrue,
      );
    });

    test('Test 6: Unknown/Irrelevant service query returns noMatch', () async {
      final intent = await AISearchIntentService.extractIntent(
        query: 'xyz 123 rocket science quantum physics',
        availableCategories: activeCategories,
        backendTimeout: const Duration(milliseconds: 10),
      );

      expect(intent.intentType, equals(AISearchIntentType.noMatch));
      expect(intent.categoryId, isNull);
    });

    test('Test 7: Inactive category is never matched', () async {
      final intent = await AISearchIntentService.extractIntent(
        query: 'Inactive SubService',
        availableCategories: activeCategories,
        backendTimeout: const Duration(milliseconds: 10),
      );

      expect(intent.categoryId, isNot(equals('cat_inactive_999')));
    });

    test('Test 8: Exact Category Name Fast-Path gives 1.0 confidence', () async {
      final intent = await AISearchIntentService.extractIntent(
        query: 'इलेक्ट्रीशियन',
        availableCategories: activeCategories,
        backendTimeout: const Duration(milliseconds: 10),
      );

      expect(intent.categoryId, equals('cat_electrician_101'));
      expect(intent.confidence, equals(1.0));
      expect(intent.isDirectMatch, isTrue);
    });

    test('Test 8B: Conversational query (पंखा बनाने वाला) correctly matches Electrician', () async {
      final intent = await AISearchIntentService.extractIntent(
        query: 'पंखा बनाने वाला',
        availableCategories: activeCategories,
        backendTimeout: const Duration(milliseconds: 10),
      );

      expect(intent.categoryId, equals('cat_electrician_101'));
      expect(intent.categoryTitleHindi, equals('इलेक्ट्रीशियन'));
    });

    test('Test 8C: Non-existent category query (watch banane wala) returns noMatch with zero false positive', () async {
      final intent = await AISearchIntentService.extractIntent(
        query: 'watch banane wala',
        availableCategories: activeCategories,
        backendTimeout: const Duration(milliseconds: 10),
      );

      expect(intent.intentType, equals(AISearchIntentType.noMatch));
      expect(intent.categoryId, isNull);
    });

    test('Test 9: Distance & Radius calculation verifies nearby providers', () {
      // Customer at Jamui Town (25.0253, 86.1711)
      const customerLat = 25.0253;
      const customerLng = 86.1711;

      // Provider 1 nearby (2 km away)
      const prov1Lat = 25.0350;
      const prov1Lng = 86.1800;
      final dist1 = LocationService.calculateDistanceKm(
        startLatitude: customerLat,
        startLongitude: customerLng,
        endLatitude: prov1Lat,
        endLongitude: prov1Lng,
      );

      expect(dist1, lessThan(5.0));

      // Provider 2 far away (e.g. 50 km away)
      const prov2Lat = 25.5000;
      const prov2Lng = 86.8000;
      final dist2 = LocationService.calculateDistanceKm(
        startLatitude: customerLat,
        startLongitude: customerLng,
        endLatitude: prov2Lat,
        endLongitude: prov2Lng,
      );

      expect(dist2, greaterThan(20.0));
    });
  });
}
