import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/paginated_providers_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_category_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_provider_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/repositories/customer_discovery_repository.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/pages/category_providers_page.dart';
import 'package:apna_jamui_customer/features/location/domain/entities/customer_location_entity.dart';
import 'package:apna_jamui_customer/features/location/domain/repositories/location_repository.dart';
import 'package:apna_jamui_customer/features/location/presentation/bloc/location_bloc.dart';

class TrackingCustomerDiscoveryRepository implements CustomerDiscoveryRepository {
  final List<ServiceProviderEntity> allDbProviders;
  int getProvidersCallCount = 0;
  List<String?> requestedCategoryIds = [];

  TrackingCustomerDiscoveryRepository({required this.allDbProviders});

  @override
  Future<List<ServiceCategoryEntity>> getCategories() async => [];

  @override
  Future<List<ServiceProviderEntity>> getProviders({
    String? categoryId,
    String? jamuiArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
  }) async {
    getProvidersCallCount++;
    requestedCategoryIds.add(categoryId);

    var list = List<ServiceProviderEntity>.from(allDbProviders);
    if (categoryId != null && categoryId != 'all') {
      final target = categoryId.toLowerCase().trim();
      list = list.where((p) {
        return p.categoryId.toLowerCase().trim() == target ||
            p.selectedCategoryIds.map((s) => s.toLowerCase().trim()).contains(target);
      }).toList();
    }
    return list;
  }

  @override
  Future<PaginatedProvidersResult> getPaginatedProviders({
    String? categoryId,
    String? jamuiArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
    int limit = 12,
    dynamic lastDocumentCursor,
  }) async {
    final list = await getProviders(
      categoryId: categoryId,
      jamuiArea: jamuiArea,
      searchQuery: searchQuery,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      maxRadiusKm: maxRadiusKm,
    );
    return PaginatedProvidersResult(
      items: list,
      hasMore: false,
      lastDocumentCursor: null,
    );
  }

  @override
  Future<void> trackLeadClick({
    required String providerId,
    required bool isCall,
    String? customerId,
    String? categoryId,
  }) async {}

  @override
  Future<void> trackProfileView({
    required String providerId,
    String? customerId,
  }) async {}
}

class MockLocationRepository implements LocationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<CustomerLocationEntity?> getCachedCustomerLocation() async => null;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;

  @override
  Future<bool> isLocationServiceEnabled() async => true;
}

void main() {
  const electricianCat = ServiceCategoryEntity(
    id: 'cat_electrician',
    titleHindi: 'इलेक्ट्रीशियन',
    titleEnglish: 'Electrician',
    description: 'Electrician services',
    shortDescription: 'Bijli repairing',
    fullDescription: '',
    aboutCategory: '',
    imageUrl: '',
    iconName: 'electrician',
    colorHex: '#FFAA00',
    priorityOrder: 1,
    isActive: true,
    isFeatured: true,
    subServices: ['पंखा रिपेयर', 'वायरिंग'],
    benefits: [],
    commonProblems: [],
    pricingType: 'fixed',
    startingPrice: 150,
    priceUnit: 'प्रति विजिट',
    estimatedDuration: '1 घंटा',
    customerRequirements: '',
    customerPhotoRequired: false,
    safetyInstructions: '',
    importantNotes: '',
    faqs: [],
  );

  const plumberCat = ServiceCategoryEntity(
    id: 'cat_plumber',
    titleHindi: 'प्लंबर',
    titleEnglish: 'Plumber',
    description: 'Plumber services',
    shortDescription: 'Nal repairing',
    fullDescription: '',
    aboutCategory: '',
    imageUrl: '',
    iconName: 'plumber',
    colorHex: '#00AAFF',
    priorityOrder: 2,
    isActive: true,
    isFeatured: true,
    subServices: ['नल फिटिंग'],
    benefits: [],
    commonProblems: [],
    pricingType: 'fixed',
    startingPrice: 150,
    priceUnit: 'प्रति विजिट',
    estimatedDuration: '1 घंटा',
    customerRequirements: '',
    customerPhotoRequired: false,
    safetyInstructions: '',
    importantNotes: '',
    faqs: [],
  );

  final testElectrician = ServiceProviderEntity(
    id: 'p1',
    fullName: 'राकेश कुमार',
    businessName: 'राकेश इलेक्ट्रिकल्स',
    phoneNumber: '9876543210',
    categoryId: 'cat_electrician',
    categoryTitle: 'इलेक्ट्रीशियन',
    selectedCategoryIds: ['cat_electrician'],
    visitingCharge: 150,
    experienceYears: 5,
    jamuiArea: 'जमुई बाजार',
    status: 'approved',
    kycStatus: 'approved',
    isSubscriptionActive: true,
    paymentVerified: true,
    subscriptionExpiry: DateTime(2030, 1, 1),
    isActive: true,
    isDeleted: false,
  );

  group('Category Providers Overfetch Optimization Tests', () {
    testWidgets('Category with providers: calls repo exactly once with categoryId filter', (tester) async {
      final repo = TrackingCustomerDiscoveryRepository(allDbProviders: [testElectrician]);
      final discoveryBloc = DiscoveryBloc(discoveryRepository: repo);
      final locationBloc = LocationBloc(locationRepository: MockLocationRepository());

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<DiscoveryBloc>.value(value: discoveryBloc),
            BlocProvider<LocationBloc>.value(value: locationBloc),
          ],
          child: const MaterialApp(
            home: CategoryProvidersPage(category: electricianCat),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verified: Exactly 1 call was made with categoryId == 'cat_electrician'
      expect(repo.getProvidersCallCount, equals(1));
      expect(repo.requestedCategoryIds.first, equals('cat_electrician'));

      // Verified: The provider card is displayed
      expect(find.text('राकेश कुमार'), findsOneWidget);
      expect(find.text('इलेक्ट्रीशियन'), findsWidgets);
    });

    testWidgets('Empty category: does NOT trigger broad unfiltered repository fetch', (tester) async {
      // Database has 1 electrician, but user opens plumber category
      final repo = TrackingCustomerDiscoveryRepository(allDbProviders: [testElectrician]);
      final discoveryBloc = DiscoveryBloc(discoveryRepository: repo);
      final locationBloc = LocationBloc(locationRepository: MockLocationRepository());

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<DiscoveryBloc>.value(value: discoveryBloc),
            BlocProvider<LocationBloc>.value(value: locationBloc),
          ],
          child: const MaterialApp(
            home: CategoryProvidersPage(category: plumberCat),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // CRITICAL VERIFICATION:
      // Exactly 1 call was made for plumber category.
      // NO SECOND CALL with categoryId == null was made!
      expect(repo.getProvidersCallCount, equals(1));
      expect(repo.requestedCategoryIds, equals(['cat_plumber']));

      // Verified: Empty state message is cleanly displayed, NOT wrong-category providers!
      expect(find.text('इस सर्विस के लिए अभी कोई कारीगर उपलब्ध नहीं है।'), findsOneWidget);
      expect(find.text('राकेश कुमार'), findsNothing);
    });
  });
}
