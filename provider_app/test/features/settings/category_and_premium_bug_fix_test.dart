import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/auth/data/models/provider_profile_model.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_bloc.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_state.dart';
import 'package:apna_jamui_provider/features/settings/presentation/pages/provider_business_profile_screen.dart';
import 'package:apna_jamui_provider/features/settings/presentation/pages/settings_page.dart';
import 'package:apna_jamui_provider/features/settings/presentation/pages/provider_edit_profile_page.dart';
import '../auth/provider_auth_bloc_test.dart';

void main() {
  group('Category & Premium Badge Bug Fix Verification Tests', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Electrician + empty category title -> Unisex Salon must NOT be shown
    // -------------------------------------------------------------------------
    testWidgets('1. Electrician with empty category title resolves to इलेक्ट्रीशियन and never Unisex Salon', (tester) async {
      final electricianProfile = ProviderProfileEntity(
        id: 'prov_elec_1',
        email: 'electrician@jamui.com',
        phoneNumber: '9876543210',
        fullName: 'Amit Kumar',
        businessName: 'Amit Electrical Works',
        primaryCategoryId: 'electrician',
        primaryCategoryTitle: '', // intentionally empty
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        isSubscriptionActive: false,
        isPremiumEligible: false,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(electricianProfile.isUnisexSalon, isFalse);
      expect(electricianProfile.resolvedCategoryTitle, 'इलेक्ट्रीशियन');

      final mockRepo = MockProviderRepository(currentProfile: electricianProfile);
      final bloc = ProviderAuthBloc(providerRepository: mockRepo);
      bloc.emit(ProviderAuthenticated(electricianProfile));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ProviderAuthBloc>.value(
            value: bloc,
            child: ProviderBusinessProfileScreen(profile: electricianProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that 'Unisex Salon' is completely absent
      expect(find.text('Unisex Salon'), findsNothing);
      expect(find.text('Style Studio Unisex Salon'), findsNothing);
      expect(find.text('SALON'), findsNothing);

      // Verify resolved title and business name are shown
      expect(find.text('इलेक्ट्रीशियन'), findsNWidgets(2)); // in AppBar and in Category info field
      expect(find.text('व्यावसायिक प्रोफाइल'), findsOneWidget);
      expect(find.text('Amit Electrical Works'), findsOneWidget);
      expect(find.text('Amit Kumar'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Plumber + inactive subscription -> Premium Badge must NOT be shown
    // -------------------------------------------------------------------------
    testWidgets('2. Plumber with inactive subscription does not display PREMIUM badge', (tester) async {
      final plumberProfile = ProviderProfileEntity(
        id: 'prov_plumb_1',
        email: 'plumber@jamui.com',
        phoneNumber: '9876543211',
        fullName: 'Sanjay Singh',
        businessName: 'Sanjay Plumbing Services',
        primaryCategoryId: 'plumber',
        primaryCategoryTitle: 'प्लम्बर',
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        subscriptionPlan: 'free_trial',
        isSubscriptionActive: false, // inactive
        isPremiumEligible: false,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(plumberProfile.isApprovedAndLive, isFalse);
      expect(plumberProfile.isPremiumApprovedAndLive, isFalse);

      final mockRepo = MockProviderRepository(currentProfile: plumberProfile);
      final bloc = ProviderAuthBloc(providerRepository: mockRepo);
      bloc.emit(ProviderAuthenticated(plumberProfile));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ProviderAuthBloc>.value(
            value: bloc,
            child: ProviderBusinessProfileScreen(profile: plumberProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify PREMIUM badge is NOT rendered
      expect(find.text('PREMIUM'), findsNothing);
      expect(find.text('Premium Category'), findsNothing);
      expect(find.text('Unisex Salon'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Active subscription but isPremiumEligible: false -> Premium Badge must NOT be shown
    // -------------------------------------------------------------------------
    testWidgets('3. Active standard subscription with isPremiumEligible: false does not show PREMIUM badge', (tester) async {
      final basicActiveProfile = ProviderProfileEntity(
        id: 'prov_active_basic',
        email: 'carpenter@jamui.com',
        phoneNumber: '9876543212',
        fullName: 'Manoj Sharma',
        businessName: 'Manoj Wood Crafts',
        primaryCategoryId: 'carpenter',
        primaryCategoryTitle: 'बढ़ई (कारपेंटर)',
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        subscriptionPlan: 'silver',
        isSubscriptionActive: true,
        isPremiumEligible: false, // strictly false
        subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime(2026, 1, 1),
      );

      expect(basicActiveProfile.isApprovedAndLive, isTrue);
      expect(basicActiveProfile.isPremiumApprovedAndLive, isFalse);

      final mockRepo = MockProviderRepository(currentProfile: basicActiveProfile);
      final bloc = ProviderAuthBloc(providerRepository: mockRepo);
      bloc.emit(ProviderAuthenticated(basicActiveProfile));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ProviderAuthBloc>.value(
            value: bloc,
            child: ProviderBusinessProfileScreen(profile: basicActiveProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show business name and resolved category, but NO PREMIUM badge
      expect(find.text('Manoj Wood Crafts'), findsOneWidget);
      expect(find.text('PREMIUM'), findsNothing);
      expect(find.text('Unisex Salon'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Real eligible Salon Provider -> Salon Category and valid Premium status displayed
    // -------------------------------------------------------------------------
    testWidgets('4. Real eligible Salon Provider displays Unisex Salon and valid PREMIUM badge', (tester) async {
      final salonProfile = ProviderProfileEntity(
        id: 'prov_salon_verified',
        email: 'glamour@jamui.com',
        phoneNumber: '9876543213',
        fullName: 'Pooja Kumari',
        businessName: 'Glamour Beauty Hub',
        primaryCategoryId: 'unisex_salon',
        primaryCategoryTitle: 'Unisex Salon',
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        subscriptionPlan: 'premium',
        isSubscriptionActive: true,
        isPremiumEligible: true, // verified premium
        subscriptionExpiry: DateTime.now().add(const Duration(days: 90)),
        createdAt: DateTime(2026, 1, 1),
      );

      expect(salonProfile.isUnisexSalon, isTrue);
      expect(salonProfile.isApprovedAndLive, isTrue);
      expect(salonProfile.isPremiumApprovedAndLive, isTrue);

      final mockRepo = MockProviderRepository(currentProfile: salonProfile);
      final bloc = ProviderAuthBloc(providerRepository: mockRepo);
      bloc.emit(ProviderAuthenticated(salonProfile));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ProviderAuthBloc>.value(
            value: bloc,
            child: ProviderBusinessProfileScreen(profile: salonProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Salon-specific elements are properly displayed for actual salon provider
      expect(find.text('Unisex Salon'), findsNWidgets(2));
      expect(find.text('प्रीमियम सैलून श्रेणी'), findsOneWidget);
      expect(find.text('PREMIUM'), findsOneWidget); // Legitimate Premium badge visible
      expect(find.text('Glamour Beauty Hub'), findsOneWidget);
      expect(find.text('SALON'), findsOneWidget); // Salon avatar placeholder
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Electrician Edit Profile -> No Salon quick-add chips
    // -------------------------------------------------------------------------
    testWidgets('5. Electrician Edit Profile does NOT show Salon quick-add chips', (tester) async {
      final electricianProfile = ProviderProfileEntity(
        id: 'prov_elec_edit',
        email: 'elec@jamui.com',
        phoneNumber: '9876543214',
        fullName: 'Vikash Kumar',
        businessName: 'Vikash Electricals',
        primaryCategoryId: 'electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        servicesWithPricing: const [], // empty
        createdAt: DateTime(2026, 1, 1),
      );

      expect(electricianProfile.isUnisexSalon, isFalse);

      final mockRepo = MockProviderRepository(currentProfile: electricianProfile);
      final bloc = ProviderAuthBloc(providerRepository: mockRepo);
      bloc.emit(ProviderAuthenticated(electricianProfile));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ProviderAuthBloc>.value(
            value: bloc,
            child: ProviderEditProfilePage(profile: electricianProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Quick-add salon chips must NOT exist for Electrician
      expect(find.text('+ Haircut (₹199)'), findsNothing);
      expect(find.text('+ Facial (₹499)'), findsNothing);
      expect(find.text('+ Hair Color (₹999)'), findsNothing);
      expect(find.text('+ Beard Grooming (₹149)'), findsNothing);
      expect(find.text('+ Bridal Makeup (₹2499)'), findsNothing);
      expect(find.text('सैलून सेवाएं व मूल्य सूची (Services & Pricing)'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Salon Provider's real services & profile preserved
    // -------------------------------------------------------------------------
    test('6. Salon Provider existing services & gallery images are preserved', () {
      const realServices = [
        {'name': 'Layer Cut', 'price': 350, 'durationMinutes': 40, 'gender': 'Women'},
        {'name': 'Gold Facial', 'price': 800, 'durationMinutes': 60, 'gender': 'Women'},
      ];
      const realGallery = [
        'https://r2.jamuiservice.com/salon1.jpg',
        'https://r2.jamuiservice.com/salon2.jpg',
      ];

      final salon = ProviderProfileEntity(
        id: 'prov_salon_data',
        email: 'beauty@jamui.com',
        phoneNumber: '9876543215',
        fullName: 'Sunita Sharma',
        businessName: 'Sunita Beauty Parlour',
        primaryCategoryId: 'unisex_salon',
        primaryCategoryTitle: 'Unisex Salon',
        servicesWithPricing: realServices,
        galleryImages: realGallery,
        createdAt: DateTime(2026, 1, 1),
      );

      final model = ProviderProfileModel.fromEntity(salon);
      final map = model.toMap();

      expect(map['servicesWithPricing'], realServices);
      expect(map['galleryImages'], realGallery);

      final deserialized = ProviderProfileModel.fromMap(map, 'prov_salon_data');
      expect(deserialized.servicesWithPricing.length, 2);
      expect(deserialized.servicesWithPricing.first['name'], 'Layer Cut');
      expect(deserialized.galleryImages.length, 2);
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Legacy profile missing category title resolves or shows neutral fallback
    // -------------------------------------------------------------------------
    test('7. Legacy profile missing category title resolves to canonical name or neutral fallback', () {
      // Case A: Legacy profile with categoryId = 'plumber' and missing categoryTitle
      final mapPlumber = {
        'id': 'prov_leg_1',
        'email': 'p@j.com',
        'categoryId': 'plumber', // legacy key
        'fullName': 'Ramesh',
      };
      final pPlumber = ProviderProfileModel.fromMap(mapPlumber, 'prov_leg_1');
      expect(pPlumber.primaryCategoryId, 'plumber');
      expect(pPlumber.resolvedCategoryTitle, 'प्लम्बर');
      expect(pPlumber.isUnisexSalon, isFalse);

      // Case B: Legacy profile with categoryId = 'carpenter'
      final mapCarpenter = {
        'id': 'prov_leg_2',
        'email': 'c@j.com',
        'category': 'carpenter', // legacy key
        'fullName': 'Suresh',
      };
      final pCarpenter = ProviderProfileModel.fromMap(mapCarpenter, 'prov_leg_2');
      expect(pCarpenter.primaryCategoryId, 'carpenter');
      expect(pCarpenter.resolvedCategoryTitle, 'बढ़ई (कारपेंटर)');
      expect(pCarpenter.isUnisexSalon, isFalse);

      // Case C: Legacy profile with legacy categoryTitle key
      final mapAc = {
        'id': 'prov_leg_3',
        'email': 'ac@j.com',
        'categoryId': 'ac_repair',
        'categoryTitle': 'एसी सर्विस व रिपेयर', // legacy key
        'fullName': 'Mukesh',
      };
      final pAc = ProviderProfileModel.fromMap(mapAc, 'prov_leg_3');
      expect(pAc.primaryCategoryTitle, 'एसी सर्विस व रिपेयर');
      expect(pAc.resolvedCategoryTitle, 'एसी सर्विस व रिपेयर');
      expect(pAc.isUnisexSalon, isFalse);

      // Case D: Completely missing category and title -> neutral fallback
      final mapEmpty = {
        'id': 'prov_leg_4',
        'email': 'unknown@j.com',
        'fullName': 'Dharmesh',
      };
      final pEmpty = ProviderProfileModel.fromMap(mapEmpty, 'prov_leg_4');
      expect(pEmpty.primaryCategoryId, '');
      expect(pEmpty.primaryCategoryTitle, '');
      expect(pEmpty.resolvedCategoryTitle, 'सेवा प्रदाता'); // Neutral fallback, NEVER Unisex Salon
      expect(pEmpty.isUnisexSalon, isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Settings showcase card dynamic icon and title
    // -------------------------------------------------------------------------
    testWidgets('8. Settings page displays dynamic storefront icon and category profile for non-salon provider', (tester) async {
      final painterProfile = ProviderProfileEntity(
        id: 'prov_painter_1',
        email: 'painter@jamui.com',
        phoneNumber: '9876543216',
        fullName: 'Deepak Roy',
        businessName: 'Deepak Painting Services',
        primaryCategoryId: 'painter',
        primaryCategoryTitle: 'पेंटर',
        status: ProviderAccountStatus.approved,
        kycStatus: ProviderKycStatus.approved,
        isSubscriptionActive: false, // inactive
        isPremiumEligible: false,
        createdAt: DateTime(2026, 1, 1),
      );

      final mockRepo = MockProviderRepository(currentProfile: painterProfile);
      final bloc = ProviderAuthBloc(providerRepository: mockRepo);
      bloc.emit(ProviderAuthenticated(painterProfile));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ProviderAuthBloc>.value(
            value: bloc,
            child: SettingsPage(profile: painterProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Non-salon provider should see their category title profile, not Unisex Salon
      expect(find.text('पेंटर प्रोफाइल'), findsOneWidget);
      expect(find.text('Unisex Salon Profile'), findsNothing);

      // Inactive provider should not see PREMIUM badge in settings
      expect(find.text('PREMIUM'), findsNothing);

      // Storefront icon should be present, scissors should not be in the showcase card
      expect(find.byIcon(Icons.storefront_rounded), findsWidgets);
    });
  });
}
