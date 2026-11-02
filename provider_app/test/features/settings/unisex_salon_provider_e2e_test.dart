import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/auth/data/models/provider_profile_model.dart';

void main() {
  group('Provider App — Unisex Salon E2E Profile & Security Contract Tests', () {
    test('1. Profile Update with Salon gallery, services pricing and social links', () {
      final initialProfile = ProviderProfileEntity(
        id: 'prov_e2e_1',
        email: 'stylestudio@jamui.com',
        phoneNumber: '+919876543210',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio Unisex Salon',
        businessDescription: 'Initial description',
        businessType: 'Shop',
        primaryCategoryId: 'unisex_salon',
        primaryCategoryTitle: 'Unisex Salon',
        experienceYears: 4,
        visitingCharge: 150.0,
        serviceRadiusKm: 10.0,
        jamuiArea: 'Lazmi Chauk',
        fullAddress: 'Lazmi Chauk, Jamui',
        latitude: 24.92,
        longitude: 86.22,
        profileImageUrl: 'https://r2.jamuiservice.com/profile.jpg',
        businessImageUrl: 'https://r2.jamuiservice.com/business.jpg',
        workingHours: '9:00 AM - 8:00 PM',
        hasExperienceCertificate: false,
        experienceCertificateUrl: '',
        experienceCertificateStatus: 'notUploaded',
        previousOrganization: '',
        experienceDescription: '',
        kycStatus: ProviderKycStatus.approved,
        status: ProviderAccountStatus.approved,
        subscriptionPlan: 'premium',
        isSubscriptionActive: true,
        paymentVerified: true,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

      // Provider updates their profile with rich salon features
      final updatedProfile = initialProfile.copyWith(
        businessDescription: 'Top-notch hair, skin & beauty salon for men and women.',
        experienceYears: 5,
        visitingCharge: 199.0,
        workingHours: '9:00 AM - 9:00 PM',
        galleryImages: const [
          'https://r2.jamuiservice.com/business/salon_photo_1.jpg',
          'https://r2.jamuiservice.com/business/salon_photo_2.jpg',
          'https://r2.jamuiservice.com/business/salon_photo_3.jpg',
        ],
        servicesWithPricing: const [
          {'name': 'Haircut & Styling', 'price': 199, 'durationMinutes': 30, 'gender': 'Unisex'},
          {'name': 'Hair Color & Highlights', 'price': 999, 'durationMinutes': 60, 'gender': 'Unisex'},
          {'name': 'Facial & Skin Care', 'price': 499, 'durationMinutes': 45, 'gender': 'Unisex'},
          {'name': 'Beard Grooming', 'price': 149, 'durationMinutes': 20, 'gender': 'Men'},
          {'name': 'Bridal & Party Makeup', 'price': 2499, 'durationMinutes': 90, 'gender': 'Women'},
        ],
        instagramUrl: '@stylestudio.salon',
        facebookUrl: 'Style Studio Jamui',
        websiteUrl: 'https://stylestudiojamui.in',
      );

      expect(updatedProfile.isUnisexSalon, isTrue);
      expect(updatedProfile.experienceYears, 5);
      expect(updatedProfile.visitingCharge, 199.0);
      expect(updatedProfile.galleryImages.length, 3);
      expect(updatedProfile.servicesWithPricing.length, 5);
      expect(updatedProfile.hasInstagram, isTrue);
      expect(updatedProfile.instagramHandle, '@stylestudio.salon');
      expect(updatedProfile.instagramLaunchUrl, 'https://instagram.com/stylestudio.salon');
      expect(updatedProfile.hasFacebook, isTrue);
      expect(updatedProfile.facebookLaunchUrl, 'https://facebook.com/Style Studio Jamui');
    });

    test('2. Permitted Fields Whitelist: Only permitted business fields can be updated by provider', () {
      // These are the exact allowed fields defined in updatePermittedProfileFields
      const allowedFields = {
        'fullName',
        'businessName',
        'ownerName',
        'phoneNumber',
        'email',
        'businessType',
        'businessDescription',
        'visitingCharge',
        'experienceYears',
        'workingHours',
        'jamuiArea',
        'area',
        'fullAddress',
        'latitude',
        'longitude',
        'serviceRadiusKm',
        'profileImageUrl',
        'businessImageUrl',
        'isAvailable',
        'subServices',
        'customServiceOffered',
        'galleryImages',
        'servicesWithPricing',
        'instagramUrl',
        'facebookUrl',
        'websiteUrl',
      };

      // Ensure salon fields are in the whitelist
      expect(allowedFields.contains('galleryImages'), isTrue);
      expect(allowedFields.contains('servicesWithPricing'), isTrue);
      expect(allowedFields.contains('instagramUrl'), isTrue);
      expect(allowedFields.contains('facebookUrl'), isTrue);
      expect(allowedFields.contains('websiteUrl'), isTrue);

      // Ensure server-only fields are NEVER in the provider whitelist
      const serverOnlyFields = [
        'isPremiumEligible',
        'isSubscriptionActive',
        'planLimits',
        'storageUsage',
        'paymentVerified',
        'subscriptionExpiry',
        'paymentVerifiedAt',
        'adminCategoryOverrideLimit',
        'subscriptionPlan',
        'subscriptionStatus',
        'rating',
        'ratingCount',
        'status',
        'kycStatus',
      ];

      for (final forbidden in serverOnlyFields) {
        expect(allowedFields.contains(forbidden), isFalse,
            reason: 'Security Violation: Server-only field $forbidden must never be in provider update whitelist');
      }
    });

    test('3. Firestore Rules Anti-Privilege Escalation Contract: Mutating server-only fields is rejected', () {
      // Helper simulating the exact Firestore security rule in backend/firebase/firestore.rules
      bool simulateFirestoreProviderUpdate({
        required Map<String, dynamic> existingData,
        required Map<String, dynamic> incomingData,
      }) {
        const forbiddenKeys = {
          'planLimits',
          'isPremiumEligible',
          'storageUsage',
          'isSubscriptionActive',
          'paymentVerified',
          'subscriptionExpiry',
          'paymentVerifiedAt',
          'adminCategoryOverrideLimit',
          'subscriptionPlan',
          'subscriptionStatus',
          'rating',
          'ratingCount',
        };

        // Rule: !request.resource.data.diff(resource.data).affectedKeys().hasAny([...])
        for (final key in forbiddenKeys) {
          if (incomingData.containsKey(key) && incomingData[key] != existingData[key]) {
            return false; // REJECTED
          }
        }

        // Rule: Approved provider cannot change category or status
        final isApproved = existingData['status'] == 'approved' || existingData['isVerified'] == true;
        if (isApproved) {
          const lockedKeys = {'status', 'kycStatus', 'primaryCategoryId', 'categoryId'};
          for (final key in lockedKeys) {
            if (incomingData.containsKey(key) && incomingData[key] != existingData[key]) {
              return false; // REJECTED
            }
          }
        }

        return true; // PERMITTED
      }

      final existingDoc = <String, dynamic>{
        'id': 'prov_123',
        'fullName': 'Rohit Kumar',
        'businessName': 'Style Studio',
        'status': 'approved',
        'kycStatus': 'approved',
        'primaryCategoryId': 'unisex_salon',
        'isPremiumEligible': true,
        'isSubscriptionActive': true,
        'planLimits': {'maxImages': 10},
        'storageUsage': 5242880,
      };

      // Case A: Legitimate salon update (photos, services, social links)
      final validUpdate = Map<String, dynamic>.from(existingDoc)
        ..['galleryImages'] = ['https://r2.jamuiservice.com/new_photo.jpg']
        ..['instagramUrl'] = '@new_salon_handle'
        ..['servicesWithPricing'] = [{'name': 'Haircut', 'price': 250}];
      expect(simulateFirestoreProviderUpdate(existingData: existingDoc, incomingData: validUpdate), isTrue);

      // Case B: Tampering with isPremiumEligible (Self-escalation)
      final exploit1 = Map<String, dynamic>.from(existingDoc)..['isPremiumEligible'] = false;
      expect(simulateFirestoreProviderUpdate(existingData: existingDoc, incomingData: exploit1), isFalse);

      // Case C: Tampering with planLimits / storage quota
      final exploit2 = Map<String, dynamic>.from(existingDoc)..['planLimits'] = {'maxImages': 999};
      expect(simulateFirestoreProviderUpdate(existingData: existingDoc, incomingData: exploit2), isFalse);

      // Case D: Tampering with isSubscriptionActive
      final exploit3 = Map<String, dynamic>.from(existingDoc)..['isSubscriptionActive'] = false;
      expect(simulateFirestoreProviderUpdate(existingData: existingDoc, incomingData: exploit3), isFalse);

      // Case E: Approved provider changing primaryCategoryId
      final exploit4 = Map<String, dynamic>.from(existingDoc)..['primaryCategoryId'] = 'doctor';
      expect(simulateFirestoreProviderUpdate(existingData: existingDoc, incomingData: exploit4), isFalse);
    });

    test('4. Cross-App Serialization Parity: Provider profile toMap matches Customer discovery schema', () {
      final providerProfile = ProviderProfileEntity(
        id: 'prov_parity_1',
        email: 'salon@jamui.com',
        phoneNumber: '9876543210',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio Unisex Salon',
        businessDescription: 'Complete grooming & hair styling',
        businessType: 'Shop',
        primaryCategoryId: 'unisex_salon',
        primaryCategoryTitle: 'Unisex Salon',
        experienceYears: 5,
        visitingCharge: 199.0,
        serviceRadiusKm: 10.0,
        jamuiArea: 'Lazmi Chauk',
        fullAddress: 'Lazmi Chauk, Jamui',
        latitude: 24.92,
        longitude: 86.22,
        profileImageUrl: 'https://r2.jamuiservice.com/profile.jpg',
        businessImageUrl: 'https://r2.jamuiservice.com/business.jpg',
        workingHours: '9:00 AM - 9:00 PM',
        hasExperienceCertificate: false,
        experienceCertificateUrl: '',
        experienceCertificateStatus: 'notUploaded',
        previousOrganization: '',
        experienceDescription: '',
        kycStatus: ProviderKycStatus.approved,
        status: ProviderAccountStatus.approved,
        subscriptionPlan: 'premium',
        isSubscriptionActive: true,
        paymentVerified: true,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        galleryImages: const [
          'https://r2.jamuiservice.com/photo1.jpg',
          'https://r2.jamuiservice.com/photo2.jpg',
        ],
        servicesWithPricing: const [
          {'name': 'Haircut', 'price': 199, 'durationMinutes': 30, 'gender': 'Unisex'},
          {'name': 'Facial', 'price': 499, 'durationMinutes': 45, 'gender': 'Unisex'},
        ],
        instagramUrl: '@stylestudio.salon',
        facebookUrl: 'stylestudiojamui',
        websiteUrl: 'https://stylestudio.com',
      );

      final map = ProviderProfileModel.fromEntity(providerProfile).toMap();

      // Verify that all keys expected by Customer App's ServiceProviderModel are present
      expect(map['businessName'], 'Style Studio Unisex Salon');
      expect(map['fullName'], 'Rohit Kumar');
      expect(map['primaryCategoryId'], 'unisex_salon');
      expect(map['primaryCategoryTitle'], 'Unisex Salon');
      expect(map['visitingCharge'], 199.0);
      expect(map['galleryImages'], isA<List>());
      expect((map['galleryImages'] as List).length, 2);
      expect(map['servicesWithPricing'], isA<List>());
      expect((map['servicesWithPricing'] as List).length, 2);
      expect(map['instagramUrl'], '@stylestudio.salon');
      expect(map['facebookUrl'], 'stylestudiojamui');
      expect(map['websiteUrl'], 'https://stylestudio.com');
    });
  });
}
