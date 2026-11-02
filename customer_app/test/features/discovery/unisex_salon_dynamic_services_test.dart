import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/discovery/data/models/service_provider_model.dart';

void main() {
  group('Customer App Unisex Salon Dynamic Services & Real Data Tests', () {
    test('1. Salon Provider with real servicesWithPricing serializes and preserves actual prices', () {
      final salonMap = <String, dynamic>{
        'id': 'provider_salon_style_studio',
        'fullName': 'Rohit Kumar',
        'businessName': 'Style Studio Unisex Salon',
        'phoneNumber': '+919876543210',
        'categoryId': 'unisex_salon',
        'categoryTitle': 'Unisex Salon',
        'selectedCategoryIds': ['unisex_salon'],
        'visitingCharge': 199.0,
        'experienceYears': 5,
        'jamuiArea': 'Lazmi Chauk',
        'fullAddress': 'Lazmi Chauk, Jamui, Bihar',
        'workingHours': '9:00 AM – 9:00 PM',
        'rating': 4.8,
        'ratingCount': 126,
        'isAvailable': true,
        'isVerified': true,
        'status': 'approved',
        'isSubscriptionActive': true,
        'paymentVerified': true,
        'subscriptionExpiry': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'isPremiumEligible': true,
        'galleryImages': [
          'https://jamuiservices.com/img1.jpg',
          'https://jamuiservices.com/img2.jpg',
        ],
        'servicesWithPricing': [
          {
            'name': 'HD Bridal Makeup',
            'price': 2500,
            'durationMinutes': 90,
            'description': 'Waterproof bridal makeup with saree draping',
          },
          {
            'name': 'Keratin Hair Spa',
            'price': 1200,
            'durationMinutes': 60,
            'description': 'Deep conditioning protein treatment',
          },
        ],
      };

      final provider = ServiceProviderModel.fromMap(salonMap, 'provider_salon_style_studio');

      expect(provider.isUnisexSalon, isTrue);
      expect(provider.isPremiumApprovedAndLive, isTrue);
      expect(provider.servicesWithPricing.length, equals(2));
      expect(provider.servicesWithPricing.first['name'], equals('HD Bridal Makeup'));
      expect(provider.servicesWithPricing.first['price'], equals(2500));
      expect(provider.servicesWithPricing[1]['name'], equals('Keratin Hair Spa'));
      expect(provider.servicesWithPricing[1]['price'], equals(1200));
      expect(provider.galleryImages.length, equals(2));
    });

    test('2. New Salon Provider with zero reviews does NOT fallback to fake 126 reviews', () {
      final newSalonMap = <String, dynamic>{
        'id': 'provider_new_salon',
        'fullName': 'Pooja Singh',
        'businessName': 'Pooja Beauty Hub',
        'phoneNumber': '+919876543211',
        'categoryId': 'unisex_salon',
        'categoryTitle': 'Unisex Salon',
        'visitingCharge': 150.0,
        'rating': 0.0,
        'ratingCount': 0,
        'workingHours': '',
        'status': 'approved',
        'isSubscriptionActive': true,
        'isPremiumEligible': true,
      };

      final provider = ServiceProviderModel.fromMap(newSalonMap, 'provider_new_salon');

      expect(provider.rating, equals(0.0));
      expect(provider.ratingCount, equals(0), reason: 'Zero ratings must remain zero, never faked');
      expect(provider.workingHours.isEmpty, isTrue);
    });

    test('3. Electrician Provider is isolated from Salon features and does NOT trigger isUnisexSalon', () {
      final electricianMap = <String, dynamic>{
        'id': 'provider_electrician_01',
        'fullName': 'Manoj Sharma',
        'businessName': 'Manoj Electricals',
        'phoneNumber': '+919876543212',
        'categoryId': 'electrician',
        'categoryTitle': 'इलेक्ट्रीशियन',
        'selectedCategoryIds': ['electrician'],
        'visitingCharge': 100.0,
        'status': 'approved',
        'isSubscriptionActive': true,
        'isPremiumEligible': false,
        'subServices': ['वायरिंग', 'स्विच बोर्ड रिपेयर', 'पंखा फिटिंग'],
      };

      final provider = ServiceProviderModel.fromMap(electricianMap, 'provider_electrician_01');

      expect(provider.isUnisexSalon, isFalse, reason: 'Electrician must never be classified as Unisex Salon');
      expect(provider.isPremiumApprovedAndLive, isFalse, reason: 'Standard electrician is not premium approved');
      expect(provider.subServices, contains('वायरिंग'));
      expect(provider.subServices, isNot(contains('हेयरकट')));
    });

    test('4. Salon SubServices fallback when servicesWithPricing is empty', () {
      final subServicesOnlySalon = <String, dynamic>{
        'id': 'provider_salon_subservices',
        'fullName': 'Sunil Verma',
        'businessName': 'Classic Unisex Salon',
        'categoryId': 'unisex_salon',
        'categoryTitle': 'Unisex Salon',
        'visitingCharge': 200.0,
        'status': 'approved',
        'isSubscriptionActive': true,
        'isPremiumEligible': true,
        'subServices': ['हेयरकट एवं स्टाइलिंग', 'दाढ़ी ग्रूमिंग', 'हेयर स्पा'],
        'servicesWithPricing': [],
      };

      final provider = ServiceProviderModel.fromMap(subServicesOnlySalon, 'provider_salon_subservices');

      expect(provider.isUnisexSalon, isTrue);
      expect(provider.servicesWithPricing.isEmpty, isTrue);
      expect(provider.subServices.length, equals(3));
      expect(provider.subServices, contains('हेयरकट एवं स्टाइलिंग'));
    });
  });
}
