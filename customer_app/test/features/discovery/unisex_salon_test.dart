import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_provider_entity.dart';
import 'package:apna_jamui_customer/features/discovery/data/models/service_provider_model.dart';

void main() {
  group('Unisex Salon ServiceProviderEntity Tests', () {
    test('isUnisexSalon returns true when categoryId or title indicates unisex salon', () {
      const p1 = ServiceProviderEntity(
        id: 'p1',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio Unisex Salon',
        phoneNumber: '9876543210',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        visitingCharge: 199.0,
        experienceYears: 5,
        rating: 4.8,
        ratingCount: 126,
        fullAddress: 'Lazmi Chauk, Jamui',
        isAvailable: true,
      );
      expect(p1.isUnisexSalon, isTrue);

      const p2 = ServiceProviderEntity(
        id: 'p2',
        fullName: 'Aman Verma',
        businessName: 'Glam Point',
        phoneNumber: '9876543211',
        categoryId: 'salon',
        categoryTitle: 'यूनिसेक्स सैलून',
        visitingCharge: 150.0,
        experienceYears: 3,
        rating: 4.7,
        ratingCount: 50,
        fullAddress: 'Jamui',
        isAvailable: true,
      );
      expect(p2.isUnisexSalon, isTrue);

      const p3 = ServiceProviderEntity(
        id: 'p3',
        fullName: 'Suresh Sharma',
        businessName: 'Sharma Electrician',
        phoneNumber: '9876543212',
        categoryId: 'electrician',
        categoryTitle: 'इलेक्ट्रीशियन',
        visitingCharge: 299.0,
        experienceYears: 6,
        rating: 4.5,
        ratingCount: 83,
        fullAddress: 'Jamui',
        isAvailable: true,
      );
      expect(p3.isUnisexSalon, isFalse);
    });

    test('Instagram helpers correctly parse handles, launch URLs, and detect presence', () {
      const pWithHandle = ServiceProviderEntity(
        id: 'p_insta_1',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio',
        phoneNumber: '9876543210',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        visitingCharge: 199.0,
        experienceYears: 5,
        rating: 4.8,
        ratingCount: 10,
        fullAddress: 'Jamui',
        isAvailable: true,
        instagramUrl: '@stylestudio.salon',
      );
      expect(pWithHandle.hasInstagram, isTrue);
      expect(pWithHandle.instagramHandle, '@stylestudio.salon');
      expect(pWithHandle.instagramLaunchUrl, 'https://instagram.com/stylestudio.salon');

      const pWithUrl = ServiceProviderEntity(
        id: 'p_insta_2',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio',
        phoneNumber: '9876543210',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        visitingCharge: 199.0,
        experienceYears: 5,
        rating: 4.8,
        ratingCount: 10,
        fullAddress: 'Jamui',
        isAvailable: true,
        instagramUrl: 'https://instagram.com/jamui_glam?igsh=123',
      );
      expect(pWithUrl.hasInstagram, isTrue);
      expect(pWithUrl.instagramHandle, '@jamui_glam');
      expect(pWithUrl.instagramLaunchUrl, 'https://instagram.com/jamui_glam?igsh=123');

      const pEmpty = ServiceProviderEntity(
        id: 'p_empty',
        fullName: 'Salon Owner',
        businessName: 'Salon',
        phoneNumber: '9876543210',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        visitingCharge: 100.0,
        experienceYears: 2,
        rating: 4.0,
        ratingCount: 1,
        fullAddress: 'Jamui',
        isAvailable: true,
      );
      expect(pEmpty.hasInstagram, isFalse);
      expect(pEmpty.instagramHandle, '');
      expect(pEmpty.instagramLaunchUrl, '');
    });

    test('Facebook & Website helpers format launch URLs appropriately', () {
      const p = ServiceProviderEntity(
        id: 'p_social',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio',
        phoneNumber: '9876543210',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        visitingCharge: 199.0,
        experienceYears: 5,
        rating: 4.8,
        ratingCount: 10,
        fullAddress: 'Jamui',
        isAvailable: true,
        facebookUrl: 'stylestudiojamui',
        websiteUrl: 'stylestudio.com',
      );
      expect(p.hasFacebook, isTrue);
      expect(p.facebookLaunchUrl, 'https://facebook.com/stylestudiojamui');
      expect(p.hasWebsite, isTrue);
      expect(p.websiteLaunchUrl, 'https://stylestudio.com');
    });

    test('ServiceProviderModel serializes and deserializes salon fields accurately', () {
      final map = {
        'id': 'salon_101',
        'businessName': 'Glam Point Unisex Salon',
        'fullName': 'Aman Kumar',
        'phoneNumber': '9876543210',
        'primaryCategoryId': 'unisex_salon',
        'primaryCategoryTitle': 'Unisex Salon',
        'rating': 4.7,
        'ratingCount': 85,
        'visitingCharge': 199.0,
        'experienceYears': 4,
        'fullAddress': 'Station Road, Jamui',
        'isAvailable': true,
        'galleryImages': [
          'https://storage.jamui.com/gallery1.jpg',
          'https://storage.jamui.com/gallery2.jpg',
        ],
        'servicesWithPricing': [
          {'name': 'Haircut', 'price': 199, 'durationMinutes': 30, 'gender': 'Unisex'},
          {'name': 'Facial', 'price': 499, 'durationMinutes': 45, 'gender': 'Women'},
        ],
        'instagramUrl': '@glampoint.jamui',
        'facebookUrl': 'glampointjamui',
        'websiteUrl': 'https://glampoint.in',
      };

      final model = ServiceProviderModel.fromMap(map, 'salon_101');
      expect(model.id, 'salon_101');
      expect(model.businessName, 'Glam Point Unisex Salon');
      expect(model.isUnisexSalon, isTrue);
      expect(model.galleryImages.length, 2);
      expect(model.servicesWithPricing.length, 2);
      expect(model.servicesWithPricing[0]['name'], 'Haircut');
      expect(model.servicesWithPricing[0]['price'], 199);
      expect(model.instagramUrl, '@glampoint.jamui');
      expect(model.facebookUrl, 'glampointjamui');
      expect(model.websiteUrl, 'https://glampoint.in');

      final toMapResult = model.toMap();
      expect(toMapResult['galleryImages'], isList);
      expect((toMapResult['galleryImages'] as List).length, 2);
      expect(toMapResult['servicesWithPricing'], isList);
      expect(toMapResult['instagramUrl'], '@glampoint.jamui');
      expect(toMapResult['facebookUrl'], 'glampointjamui');
      expect(toMapResult['websiteUrl'], 'https://glampoint.in');
    });
  });
}
