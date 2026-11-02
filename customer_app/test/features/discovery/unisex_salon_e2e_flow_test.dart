import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_provider_entity.dart';

void main() {
  group('Customer App — Unisex Salon E2E Flow & Business Rules Verification', () {
    test('1. Homepage Category Payload from Firestore correctly sets Unisex Salon properties', () {
      final firestoreDoc = {
        'id': 'cat_unisex_salon',
        'categoryId': 'unisex_salon',
        'categoryName': 'Unisex Salon',
        'customTitle': 'Unisex Salon',
        'title': 'Unisex Salon',
        'imageUrl': 'https://images.unsplash.com/photo-1560066984-138dadb4c035',
        'priority': 1,
        'isActive': true,
        'showOnHome': true,
      };

      final title = firestoreDoc['customTitle']?.toString() ?? firestoreDoc['categoryName']?.toString();
      final categoryId = firestoreDoc['categoryId']?.toString() ?? '';
      final isUnisex = categoryId == 'unisex_salon' ||
          title!.toLowerCase().contains('unisex') ||
          title.contains('यूनिसेक्स');

      expect(title, 'Unisex Salon');
      expect(categoryId, 'unisex_salon');
      expect(isUnisex, isTrue);
      expect(firestoreDoc['isActive'], isTrue);
      expect(firestoreDoc['showOnHome'], isTrue);
    });

    test('2. Provider Listing Eligibility: Filters out unapproved, suspended, expired, or non-premium providers', () {
      final now = DateTime.now();

      // Case A: Fully eligible provider
      final eligibleProvider = ServiceProviderEntity(
        id: 'p_eligible',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio Unisex Salon',
        phoneNumber: '9876543210',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        visitingCharge: 199.0,
        experienceYears: 5,
        rating: 4.8,
        ratingCount: 126,
        isAvailable: true,
        kycStatus: 'approved',
        status: 'approved',
        paymentVerified: true,
        isSubscriptionActive: true,
        subscriptionExpiry: now.add(const Duration(days: 30)),
        isPremiumEligible: true,
      );

      // Case B: Unapproved provider (pending KYC/approval)
      final unapprovedProvider = ServiceProviderEntity(
        id: 'p_unapproved',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio Unisex Salon',
        phoneNumber: '9876543210',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        visitingCharge: 199.0,
        experienceYears: 5,
        rating: 4.8,
        ratingCount: 126,
        isAvailable: true,
        isVerified: false,
        kycStatus: 'pendingReview',
        status: 'pendingReview',
        paymentVerified: true,
        isSubscriptionActive: true,
        subscriptionExpiry: now.add(const Duration(days: 30)),
        isPremiumEligible: true,
      );

      // Case C: Suspended provider
      final suspendedProvider = ServiceProviderEntity(
        id: 'p_suspended',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio Unisex Salon',
        phoneNumber: '9876543210',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        visitingCharge: 199.0,
        experienceYears: 5,
        rating: 4.8,
        ratingCount: 126,
        isAvailable: true,
        kycStatus: 'approved',
        status: 'suspended',
        paymentVerified: true,
        isSubscriptionActive: true,
        subscriptionExpiry: now.add(const Duration(days: 30)),
        isPremiumEligible: true,
      );

      // Case D: Subscription expired provider
      final expiredProvider = eligibleProvider.copyWith(
        subscriptionExpiry: now.subtract(const Duration(days: 2)),
      );

      // Case E: Provider without premium eligibility
      final nonPremiumProvider = eligibleProvider.copyWith(
        isPremiumEligible: false,
      );

      expect(eligibleProvider.isPremiumApprovedAndLive, isTrue,
          reason: 'Approved + Verified + Subscription Active + Unexpired + Premium Eligible must be visible');
      expect(unapprovedProvider.isPremiumApprovedAndLive, isFalse,
          reason: 'Unapproved provider must NEVER be visible to customers');
      expect(suspendedProvider.isPremiumApprovedAndLive, isFalse,
          reason: 'Suspended provider must NEVER be visible to customers');
      expect(expiredProvider.isPremiumApprovedAndLive, isFalse,
          reason: 'Subscription expired provider must be hidden from listing');
      expect(nonPremiumProvider.isPremiumApprovedAndLive, isFalse,
          reason: 'Non-premium provider must not appear on premium listing');
    });

    test('3. Subcategory Gender Filtering logic matches Men, Women, and Unisex correctly', () {
      final salonMenServices = ServiceProviderEntity(
        id: 'p_men',
        fullName: 'Barber Jack',
        businessName: 'Jack Men Grooming',
        phoneNumber: '9876543210',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        businessDescription: 'Expert beard grooming and male hair styling',
        subServices: const ['Beard Grooming', 'Shaving'],
        servicesWithPricing: const [
          {'name': 'Beard Grooming', 'price': 149, 'durationMinutes': 20, 'gender': 'Men'},
        ],
        visitingCharge: 149.0,
        experienceYears: 4,
      );

      final salonWomenServices = ServiceProviderEntity(
        id: 'p_women',
        fullName: 'Pooja Sharma',
        businessName: 'Pooja Bridal & Beauty',
        phoneNumber: '9876543211',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        businessDescription: 'Bridal makeup, skin care and beauty parlour',
        subServices: const ['Bridal Makeup', 'Party Makeup', 'Facial'],
        servicesWithPricing: const [
          {'name': 'Bridal Makeup', 'price': 2499, 'durationMinutes': 90, 'gender': 'Women'},
        ],
        visitingCharge: 299.0,
        experienceYears: 6,
      );

      bool matchesFilter(ServiceProviderEntity p, String filter) {
        if (filter == 'All') return true;
        final filterLower = filter.toLowerCase();
        final desc = p.businessDescription.toLowerCase();
        final services = p.subServices.map((s) => s.toLowerCase()).join(' ');
        final pricing = p.servicesWithPricing.map((m) => m['name']?.toString().toLowerCase() ?? '').join(' ');
        final combined = '$desc $services $pricing';

        if (filterLower == 'men') {
          return combined.contains('men') || combined.contains('male') || combined.contains('beard') || combined.contains('पुरुष');
        } else if (filterLower == 'women') {
          return combined.contains('women') || combined.contains('female') || combined.contains('bridal') || combined.contains('महिला');
        } else if (filterLower == 'unisex') {
          return p.isUnisexSalon;
        }
        return true;
      }

      expect(matchesFilter(salonMenServices, 'Men'), isTrue);
      expect(matchesFilter(salonMenServices, 'Women'), isFalse);
      expect(matchesFilter(salonWomenServices, 'Women'), isTrue);
      expect(matchesFilter(salonWomenServices, 'Men'), isFalse);
      expect(matchesFilter(salonMenServices, 'All'), isTrue);
      expect(matchesFilter(salonWomenServices, 'All'), isTrue);
      expect(matchesFilter(salonMenServices, 'Unisex'), isTrue);
    });

    test('4. Provider Details Actions & Social Links Generation', () {
      final salon = ServiceProviderEntity(
        id: 'salon_details_1',
        fullName: 'Rohit Kumar',
        businessName: 'Style Studio Unisex Salon',
        phoneNumber: '+91 98765 43210',
        categoryId: 'unisex_salon',
        categoryTitle: 'Unisex Salon',
        visitingCharge: 199.0,
        experienceYears: 5,
        latitude: 24.92,
        longitude: 86.22,
        instagramUrl: '@stylestudio.salon',
        facebookUrl: 'stylestudiojamui',
        websiteUrl: 'https://stylestudio.com',
        galleryImages: const [
          'https://r2.jamuiservice.com/interior1.jpg',
          'https://r2.jamuiservice.com/interior2.jpg',
        ],
        servicesWithPricing: const [
          {'name': 'Haircut & Styling', 'price': 199, 'durationMinutes': 30, 'gender': 'Unisex'},
          {'name': 'Keratin Smoothening', 'price': 1999, 'durationMinutes': 90, 'gender': 'Women'},
        ],
      );

      // Verify Social URL Generation
      expect(salon.hasInstagram, isTrue);
      expect(salon.instagramHandle, '@stylestudio.salon');
      expect(salon.instagramLaunchUrl, 'https://instagram.com/stylestudio.salon');

      expect(salon.hasFacebook, isTrue);
      expect(salon.facebookLaunchUrl, 'https://facebook.com/stylestudiojamui');

      expect(salon.hasWebsite, isTrue);
      expect(salon.websiteLaunchUrl, 'https://stylestudio.com');

      // Verify Clean WhatsApp Link Generation
      final cleanDigits = salon.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final whatsappUrl = 'https://wa.me/91${cleanDigits.length > 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits}';
      expect(whatsappUrl, 'https://wa.me/919876543210');

      // Verify Google Maps Directions URL
      final mapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=${salon.latitude},${salon.longitude}';
      expect(mapsUrl, 'https://www.google.com/maps/dir/?api=1&destination=24.92,86.22');

      // Verify Services and Gallery
      expect(salon.galleryImages.length, 2);
      expect(salon.servicesWithPricing.length, 2);
      expect(salon.servicesWithPricing[0]['name'], 'Haircut & Styling');
      expect(salon.servicesWithPricing[0]['price'], 199);
      expect(salon.servicesWithPricing[1]['name'], 'Keratin Smoothening');
      expect(salon.servicesWithPricing[1]['price'], 1999);
    });
  });
}
