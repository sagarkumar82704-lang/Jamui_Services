import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/auth/domain/entities/provider_profile_entity.dart';
import 'package:apna_jamui_provider/features/auth/data/models/provider_profile_model.dart';

void main() {
  group('Unisex Salon ProviderProfileEntity Tests', () {
    test('isUnisexSalon recognizes salon categories accurately', () {
      final p1 = ProviderProfileEntity(
        id: 'prov_salon_1',
        email: 'salon@jamui.com',
        phoneNumber: '9876543210',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio Unisex Salon',
        businessDescription: 'Premium unisex salon in Jamui',
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
        profileImageUrl: '',
        businessImageUrl: '',
        workingHours: '9:00 AM - 9:00 PM',
        hasExperienceCertificate: false,
        experienceCertificateUrl: '',
        experienceCertificateStatus: 'notUploaded',
        previousOrganization: '',
        experienceDescription: '',
        kycStatus: ProviderKycStatus.approved,
        status: ProviderAccountStatus.approved,
        subscriptionPlan: 'premium',
        isActive: true,
        createdAt: DateTime.now(),
      );
      expect(p1.isUnisexSalon, isTrue);

      final p2 = p1.copyWith(
        primaryCategoryId: 'electrician',
        primaryCategoryTitle: 'इलेक्ट्रीशियन',
      );
      expect(p2.isUnisexSalon, isFalse);
    });

    test('Social getters and launch URL converters format inputs cleanly', () {
      final p = ProviderProfileEntity(
        id: 'prov_social',
        email: 'stylestudio@jamui.com',
        phoneNumber: '+91 98765 43210',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio',
        businessDescription: 'Salon',
        businessType: 'Shop',
        primaryCategoryId: 'unisex_salon',
        primaryCategoryTitle: 'Unisex Salon',
        experienceYears: 5,
        visitingCharge: 199.0,
        serviceRadiusKm: 10.0,
        jamuiArea: 'Jamui',
        fullAddress: 'Jamui',
        latitude: 24.92,
        longitude: 86.22,
        profileImageUrl: '',
        businessImageUrl: '',
        workingHours: '9:00 AM - 9:00 PM',
        hasExperienceCertificate: false,
        experienceCertificateUrl: '',
        experienceCertificateStatus: 'notUploaded',
        previousOrganization: '',
        experienceDescription: '',
        kycStatus: ProviderKycStatus.approved,
        status: ProviderAccountStatus.approved,
        subscriptionPlan: 'premium',
        isActive: true,
        createdAt: DateTime.now(),
        instagramUrl: 'stylestudio.salon',
        facebookUrl: 'https://facebook.com/stylestudiojamui',
        websiteUrl: 'stylestudiojamui.in',
      );

      expect(p.hasInstagram, isTrue);
      expect(p.instagramHandle, '@stylestudio.salon');
      expect(p.instagramLaunchUrl, 'https://instagram.com/stylestudio.salon');

      expect(p.hasFacebook, isTrue);
      expect(p.facebookLaunchUrl, 'https://facebook.com/stylestudiojamui');

      expect(p.hasWebsite, isTrue);
      expect(p.websiteLaunchUrl, 'https://stylestudiojamui.in');
    });

    test('ProviderProfileModel serializes and deserializes salon gallery and services', () {
      final map = {
        'id': 'prov_salon_100',
        'email': 'stylestudio@jamui.com',
        'phoneNumber': '9876543210',
        'isMobileVerified': true,
        'isEmailVerified': true,
        'fullName': 'Rohit Kumar',
        'ownerName': 'Rohit Kumar',
        'businessName': 'Style Studio Unisex Salon',
        'businessDescription': 'Top salon',
        'businessType': 'Shop',
        'primaryCategoryId': 'unisex_salon',
        'primaryCategoryTitle': 'Unisex Salon',
        'experienceYears': 5,
        'visitingCharge': 199.0,
        'serviceRadiusKm': 10.0,
        'jamuiArea': 'Lazmi Chauk',
        'area': 'Lazmi Chauk',
        'fullAddress': 'Lazmi Chauk, Jamui',
        'latitude': 24.92,
        'longitude': 86.22,
        'profileImageUrl': 'https://r2.jamuiservice.com/profile.jpg',
        'businessImageUrl': 'https://r2.jamuiservice.com/business.jpg',
        'workingHours': '9:00 AM - 9:00 PM',
        'hasExperienceCertificate': false,
        'experienceCertificateUrl': '',
        'experienceCertificateStatus': 'notUploaded',
        'previousOrganization': '',
        'experienceDescription': '',
        'kycStatus': 'approved',
        'status': 'approved',
        'subscriptionPlan': 'premium',
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'paymentStatus': 'success',
        'isActive': true,
        'isDeleted': false,
        'totalViews': 250,
        'totalCalls': 45,
        'totalWhatsAppClicks': 32,
        'rating': 4.8,
        'ratingCount': 126,
        'isAvailable': true,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'galleryImages': [
          'https://r2.jamuiservice.com/salon_interior_1.jpg',
          'https://r2.jamuiservice.com/salon_interior_2.jpg',
        ],
        'servicesWithPricing': [
          {'name': 'Haircut & Styling', 'price': 199, 'durationMinutes': 30, 'gender': 'Unisex'},
          {'name': 'Keratin Treatment', 'price': 1499, 'durationMinutes': 90, 'gender': 'Women'},
        ],
        'instagramUrl': '@stylestudio.salon',
        'facebookUrl': 'Style Studio Jamui',
        'websiteUrl': 'https://stylestudio.com',
      };

      final model = ProviderProfileModel.fromMap(map, 'prov_salon_100');
      expect(model.id, 'prov_salon_100');
      expect(model.isUnisexSalon, isTrue);
      expect(model.galleryImages.length, 2);
      expect(model.servicesWithPricing.length, 2);
      expect(model.servicesWithPricing.first['name'], 'Haircut & Styling');
      expect(model.instagramUrl, '@stylestudio.salon');
      expect(model.facebookUrl, 'Style Studio Jamui');
      expect(model.websiteUrl, 'https://stylestudio.com');

      final toMapResult = model.toMap();
      expect(toMapResult['galleryImages'], isList);
      expect((toMapResult['galleryImages'] as List).length, 2);
      expect(toMapResult['servicesWithPricing'], isList);
      expect(toMapResult['instagramUrl'], '@stylestudio.salon');
      expect(toMapResult['facebookUrl'], 'Style Studio Jamui');
      expect(toMapResult['websiteUrl'], 'https://stylestudio.com');
    });
  });
}
