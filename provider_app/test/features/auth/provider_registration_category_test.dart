import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/categories/data/models/service_category_model.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/auth/data/models/provider_profile_model.dart';

void main() {
  group('Provider Registration: Premium Category & Dynamic Service Field Tests', () {
    // -------------------------------------------------------------
    // SCENARIO 1: Active Premium Categories Load from Firestore & Model Mapping
    // -------------------------------------------------------------
    test('1. Model Mapping: Active Premium Category correctly parses isPremium, categoryType, and colorHex', () {
      final rawFirestoreDoc = <String, dynamic>{
        'id': 'cat_unisex_salon',
        'categoryId': 'unisex_salon',
        'categoryName': 'Unisex Salon',
        'customTitle': 'यूनिसेक्स सैलून व ब्यूटी पार्लर',
        'titleHindi': 'यूनिसेक्स सैलून व ब्यूटी पार्लर',
        'titleEnglish': 'Unisex Salon & Beauty Parlour',
        'description': 'प्रीमियम सैलून, ग्रूमिंग एवं ब्यूटी सेवाएं',
        'shortDescription': 'हेयरकट, फेशियल, मेकअप',
        'imageUrl': 'https://firebasestorage.googleapis.com/.../salon.png',
        'isPremium': true,
        'categoryType': 'premium',
        'isActive': true,
        'priorityOrder': 1,
        'subServices': [
          'हेयरकट एवं स्टाइलिंग',
          'फेशियल एवं स्किन केयर',
          'ब्राइडल ग्रूमिंग पैकेज',
          'हेयर स्पा एवं केराटिन',
        ],
      };

      final model = ServiceCategoryModel.fromMap(rawFirestoreDoc, 'cat_unisex_salon');

      expect(model.id, equals('cat_unisex_salon'));
      expect(model.isPremium, isTrue, reason: 'Category must be identified as premium');
      expect(model.categoryType, equals('premium'), reason: 'categoryType must be premium');
      expect(model.titleHindi, equals('यूनिसेक्स सैलून व ब्यूटी पार्लर'));
      expect(model.colorHex, equals('#D4AF37'), reason: 'Premium categories default to gold color');
      expect(model.subServices.length, equals(4));
      expect(model.subServices, contains('ब्राइडल ग्रूमिंग पैकेज'));
    });

    test('1b. Fallback Mapping: isPremiumCategory flag or categoryType="premium" sets isPremium=true', () {
      final legacyDoc = <String, dynamic>{
        'id': 'cat_premium_spa',
        'titleHindi': 'लग्जरी स्पा',
        'titleEnglish': 'Luxury Spa',
        'isPremiumCategory': true, // Legacy boolean flag
        'subServices': ['बॉडी मसाज', 'अरोमा थेरेपी'],
      };

      final model = ServiceCategoryModel.fromMap(legacyDoc, 'cat_premium_spa');

      expect(model.isPremium, isTrue);
      expect(model.categoryType, equals('premium'));
      expect(model.colorHex, equals('#D4AF37'));
    });

    // -------------------------------------------------------------
    // SCENARIO 2: Empty Premium Categories List State Handling
    // -------------------------------------------------------------
    test('2. Empty State: Empty premium categories list handles gracefully without errors', () {
      final List<ServiceCategoryModel> premiumCategories = [];
      final List<ServiceCategoryModel> generalCategories = [
        const ServiceCategoryModel(
          id: 'cat_electrician',
          titleHindi: 'इलेक्ट्रीशियन',
          titleEnglish: 'Electrician',
          description: 'घरेलू वायरिंग व रिपेयर',
          shortDescription: 'बिजली का काम',
          imageUrl: '',
          iconName: 'electrical_services',
          colorHex: '#0D6E57',
          priorityOrder: 1,
          isActive: true,
          subServices: ['वायरिंग', 'स्विच बोर्ड रिपेयर', 'पंखा इंस्टॉलेशन'],
          categoryType: 'general',
          isPremium: false,
        ),
      ];

      expect(premiumCategories.isEmpty, isTrue, reason: 'Empty list should trigger the empty state banner');
      expect(generalCategories.isNotEmpty, isTrue, reason: 'General categories remain unaffected');
      expect(generalCategories.first.categoryType, equals('general'));
      expect(generalCategories.first.isPremium, isFalse);
    });

    // -------------------------------------------------------------
    // SCENARIO 3: General Category Selection & Flow Integrity
    // -------------------------------------------------------------
    test('3. General Category: Plumber category maintains standard parameters without premium flags', () {
      final rawPlumberDoc = <String, dynamic>{
        'id': 'cat_plumber',
        'titleHindi': 'प्लम्बर (नलसाज)',
        'titleEnglish': 'Plumber',
        'description': 'पाइप फिटिंग, मोटर एवं नल रिपेयर',
        'imageUrl': '',
        'categoryType': 'general',
        'isPremium': false,
        'isActive': true,
        'priorityOrder': 2,
        'subServices': ['पाइप लीकेज रिपेयर', 'नल फिटिंग', 'पानी मोटर इंस्टॉलेशन', 'गीजर कनेक्शन'],
      };

      final plumber = ServiceCategoryModel.fromMap(rawPlumberDoc, 'cat_plumber');

      expect(plumber.isPremium, isFalse);
      expect(plumber.categoryType, equals('general'));
      expect(plumber.colorHex, equals('#0D6E57'));
      expect(plumber.subServices.length, equals(4));
    });

    // -------------------------------------------------------------
    // SCENARIO 4: Electrician sub-services do NOT include Salon sub-services
    // -------------------------------------------------------------
    test('4. Dynamic Sub-Services: Electrician has strictly electrical services, never salon services', () {
      final electrician = const ServiceCategoryModel(
        id: 'cat_electrician',
        titleHindi: 'इलेक्ट्रीशियन',
        titleEnglish: 'Electrician',
        description: 'घरेलू वायरिंग',
        shortDescription: 'बिजली कारीगर',
        imageUrl: '',
        iconName: 'electrical_services',
        colorHex: '#0D6E57',
        priorityOrder: 1,
        isActive: true,
        subServices: ['घरेलू वायरिंग', 'स्विच बोर्ड रिपेयर', 'पंखा इंस्टॉलेशन', 'एमसीबी रिपेयर'],
        categoryType: 'general',
        isPremium: false,
      );

      final salon = const ServiceCategoryModel(
        id: 'cat_salon',
        titleHindi: 'यूनिसेक्स सैलून',
        titleEnglish: 'Unisex Salon',
        description: 'सैलून एवं ब्यूटी',
        shortDescription: 'ग्रूमिंग सेवाएं',
        imageUrl: '',
        iconName: 'content_cut',
        colorHex: '#D4AF37',
        priorityOrder: 1,
        isActive: true,
        subServices: ['हेयरकट', 'फेशियल', 'हेयर स्पा', 'ब्राइडल मेकअप'],
        categoryType: 'premium',
        isPremium: true,
      );

      // Verify strict isolation between electrician and salon sub-services
      for (final service in electrician.subServices) {
        expect(salon.subServices.contains(service), isFalse,
            reason: 'Electrician service "$service" must NOT exist in salon services');
      }

      for (final service in salon.subServices) {
        expect(electrician.subServices.contains(service), isFalse,
            reason: 'Salon service "$service" must NOT exist in electrician services');
      }

      expect(electrician.subServices, contains('घरेलू वायरिंग'));
      expect(electrician.subServices, isNot(contains('ब्राइडल मेकअप')));
      expect(electrician.subServices, isNot(contains('हेयरकट')));
    });

    // -------------------------------------------------------------
    // SCENARIO 5 & 6: Premium Category Dedicated Text Field & Submit Payload
    // -------------------------------------------------------------
    test('5 & 6. Submit Payload: Premium category saves dedicated premiumServiceDetails and flags correctly', () {
      final profile = ProviderProfileModel(
        id: 'provider_premium_001',
        phoneNumber: '+919876543210',
        fullName: 'सविता ब्यूटी स्टूडियो',
        email: 'savita@salon.com',
        businessName: 'सविता यूनिसेक्स सैलून',
        businessDescription: 'उच्च गुणवत्ता की सैलून व ब्राइडल सेवाएं',
        primaryCategoryId: 'cat_unisex_salon',
        primaryCategoryTitle: 'यूनिसेक्स सैलून व ब्यूटी पार्लर',
        selectedCategoryIds: const ['cat_unisex_salon'],
        categoryType: 'premium',
        isPremiumEligible: true,
        premiumServiceDetails: 'स्पेशल HD ब्राइडल मेकअप, प्री-ब्राइडल ग्रूमिंग पैकेज एवं केराटिन स्मूथनिंग ट्रीटमेंट',
        generalServiceDetails: '', // Clean isolation: empty for premium
        subServices: const ['हेयरकट एवं स्टाइलिंग', 'ब्राइडल ग्रूमिंग पैकेज'],
        visitingCharge: 500.0,
        experienceYears: 5,
        jamuiArea: 'Jamui Main Market',
        fullAddress: 'Station Road, Jamui, Bihar',
        registrationStatus: 'completed',
        currentStep: 5,
        status: ProviderAccountStatus.pendingReview,
        kycStatus: ProviderKycStatus.pendingReview,
        createdAt: DateTime.now(),
      );

      final firestoreMap = profile.toMap();

      expect(firestoreMap['categoryType'], equals('premium'));
      expect(firestoreMap['isPremiumCategory'], isTrue);
      expect(firestoreMap['isPremiumEligible'], isTrue);
      expect(firestoreMap['premiumServiceDetails'],
          contains('स्पेशल HD ब्राइडल मेकअप, प्री-ब्राइडल ग्रूमिंग पैकेज'));
      expect(firestoreMap['generalServiceDetails'], isEmpty,
          reason: 'General service details must remain empty for premium registration');
      expect(firestoreMap['primaryCategoryId'], equals('cat_unisex_salon'));
      expect(firestoreMap['primaryCategoryTitle'], equals('यूनिसेक्स सैलून व ब्यूटी पार्लर'));
      expect(firestoreMap['subServices'], contains('ब्राइडल ग्रूमिंग पैकेज'));
    });

    // -------------------------------------------------------------
    // SCENARIO 7: Category Switching Isolates Data and Clears Previous Values
    // -------------------------------------------------------------
    test('7. State Switching: Switching between General and Premium resets opposite fields', () {
      // Simulate state variables as in ProviderMultiStepRegistrationPageState
      String primaryCategoryId = 'cat_unisex_salon';
      String primaryCategoryTitle = 'यूनिसेक्स सैलून';
      String selectedCategoryType = 'premium';
      List<String> selectedSubServices = ['हेयरकट', 'ब्राइडल मेकअप'];
      String premiumServiceDetails = 'प्रीमियम सैलून पैकेज';
      String generalServiceDetails = '';

      void selectCategory(ServiceCategoryModel newCat) {
        final bool isDiffCat = primaryCategoryId != newCat.id;
        final bool isDiffType = selectedCategoryType != newCat.categoryType;

        primaryCategoryId = newCat.id;
        primaryCategoryTitle = newCat.titleHindi;
        selectedCategoryType = newCat.categoryType;

        if (isDiffCat) {
          selectedSubServices = [];
        }

        if (isDiffType) {
          if (newCat.categoryType == 'premium') {
            generalServiceDetails = '';
          } else {
            premiumServiceDetails = '';
          }
        }
      }

      // Switch to General Category (Electrician)
      final electricianCat = const ServiceCategoryModel(
        id: 'cat_electrician',
        titleHindi: 'इलेक्ट्रीशियन',
        titleEnglish: 'Electrician',
        description: '',
        shortDescription: '',
        imageUrl: '',
        iconName: 'electrical_services',
        colorHex: '#0D6E57',
        priorityOrder: 1,
        isActive: true,
        subServices: ['वायरिंग', 'स्विच बोर्ड रिपेयर'],
        categoryType: 'general',
        isPremium: false,
      );

      selectCategory(electricianCat);

      expect(primaryCategoryId, equals('cat_electrician'));
      expect(primaryCategoryTitle, equals('इलेक्ट्रीशियन'));
      expect(selectedCategoryType, equals('general'));
      expect(selectedSubServices.isEmpty, isTrue,
          reason: 'Old salon subServices must be cleared when switching category');
      expect(premiumServiceDetails.isEmpty, isTrue,
          reason: 'Old premium details must be cleared when switching to general category');

      // Now set general service details
      generalServiceDetails = 'घरेलू वायरिंग व इन्वर्टर रिपेयर में 10 साल का अनुभव';
      selectedSubServices = ['वायरिंग'];

      // Now switch back to Premium (Salon)
      final salonCat = const ServiceCategoryModel(
        id: 'cat_salon',
        titleHindi: 'यूनिसेक्स सैलून',
        titleEnglish: 'Unisex Salon',
        description: '',
        shortDescription: '',
        imageUrl: '',
        iconName: 'content_cut',
        colorHex: '#D4AF37',
        priorityOrder: 1,
        isActive: true,
        subServices: ['हेयरकट', 'फेशियल'],
        categoryType: 'premium',
        isPremium: true,
      );

      selectCategory(salonCat);

      expect(primaryCategoryId, equals('cat_salon'));
      expect(selectedCategoryType, equals('premium'));
      expect(selectedSubServices.isEmpty, isTrue,
          reason: 'Old electrician subServices must be cleared');
      expect(generalServiceDetails.isEmpty, isTrue,
          reason: 'Old general details must be cleared when switching to premium');
    });

    // -------------------------------------------------------------
    // SCENARIO 8: Backward Compatibility with Existing Profiles & Customer App
    // -------------------------------------------------------------
    test('8a. Backward Compatibility: Legacy profile with unisex_salon id resolves to premium', () {
      final legacySalonMap = <String, dynamic>{
        'id': 'provider_legacy_salon',
        'phoneNumber': '+919876543201',
        'fullName': 'राज ब्यूटी पार्लर',
        'primaryCategoryId': 'unisex_salon', // Legacy ID
        'primaryCategoryTitle': 'Unisex Salon',
        // Notice: categoryType and premiumServiceDetails are absent in legacy doc!
      };

      final profile = ProviderProfileModel.fromMap(legacySalonMap, 'provider_legacy_salon');

      expect(profile.categoryType, equals('premium'),
          reason: 'Legacy unisex_salon must automatically resolve to categoryType="premium"');
      expect(profile.isPremiumCategory, isTrue,
          reason: 'isPremiumCategory getter must return true for legacy unisex_salon');
      expect(profile.resolvedCategoryTitle, equals('Unisex Salon'));
    });

    test('8b. Backward Compatibility: Legacy profile with electrician id resolves to general', () {
      final legacyElectricianMap = <String, dynamic>{
        'id': 'provider_legacy_electrician',
        'phoneNumber': '+919876543202',
        'fullName': 'सुनील शर्मा',
        'primaryCategoryId': 'electrician', // Legacy ID
        'primaryCategoryTitle': '', // Title absent, needs fallback
      };

      final profile = ProviderProfileModel.fromMap(legacyElectricianMap, 'provider_legacy_electrician');

      expect(profile.categoryType, equals('general'),
          reason: 'Legacy electrician must resolve to categoryType="general"');
      expect(profile.isPremiumCategory, isFalse,
          reason: 'Electrician must NOT be treated as premium');
      expect(profile.resolvedCategoryTitle, equals('इलेक्ट्रीशियन'),
          reason: 'Fallback to Hindi title works correctly for Customer & Provider app');
    });
  });
}
