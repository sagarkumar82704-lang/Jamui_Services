import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:apna_jamui_customer/features/professional_shop/data/datasources/professional_shop_remote_data_source.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/paginated_shops_result.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_category_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/domain/entities/professional_shop_entity.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/pages/professional_shops_listing_page.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_shop_card.dart';
import 'package:apna_jamui_customer/features/professional_shop/presentation/widgets/professional_shop_skeleton.dart';

class FakeDataSource extends ProfessionalShopRemoteDataSource {
  List<ProfessionalShopEntity> mockShops = [];
  bool shouldThrowError = false;
  String errorMessage = 'Failed to load shops';
  bool mockHasMore = false;
  int fetchCallCount = 0;
  bool forceRefreshCalled = false;

  List<ProfessionalShopEntity> mockSearchResults = [];
  bool searchShouldHaveMore = false;
  int searchCallCount = 0;

  @override
  Future<PaginatedProfessionalShopsResult> fetchPaginatedShops({
    String? categoryId,
    double? customerLat,
    double? customerLng,
    String? areaId,
    DocumentSnapshot? lastDoc,
    int chunkSize = 100,
    bool forceRefresh = false,
  }) async {
    fetchCallCount++;
    if (forceRefresh) forceRefreshCalled = true;

    if (shouldThrowError) {
      throw Exception(errorMessage);
    }

    return PaginatedProfessionalShopsResult(
      shops: mockShops,
      lastDoc: null,
      hasMore: mockHasMore,
      totalLoaded: mockShops.length,
      isFromCache: false,
    );
  }

  @override
  Future<PaginatedProfessionalShopsResult> searchShopsWithCeiling({
    required String queryText,
    String? categoryId,
    double? customerLat,
    double? customerLng,
    String? areaId,
    int maxReadCeiling = 300,
    int chunkSize = 100,
    int? generationToken,
  }) async {
    searchCallCount++;
    return PaginatedProfessionalShopsResult(
      shops: mockSearchResults,
      lastDoc: null,
      hasMore: searchShouldHaveMore,
      totalLoaded: maxReadCeiling,
      isFromCache: false,
    );
  }
}

void main() {
  late FakeDataSource fakeDataSource;

  final sampleShops = [
    const ProfessionalShopEntity(
      id: 'shop_1',
      shopName: 'Jamui Grocery Mart',
      jamuiArea: 'Main Bazaar',
      areaId: 'area_bazaar',
      latitude: 25.1337,
      longitude: 86.1772,
      distanceKm: 1.2,
      serviceRadiusKm: 5.0,
      isHomeDeliveryActive: true,
      isPickupActive: true,
      rating: 4.5,
      ratingCount: 15,
    ),
    const ProfessionalShopEntity(
      id: 'shop_2',
      shopName: 'Bihar Electronics',
      jamuiArea: 'Station Road',
      areaId: 'area_station',
      latitude: 25.1340,
      longitude: 86.1780,
      distanceKm: 2.8,
      serviceRadiusKm: 5.0,
      isHomeDeliveryActive: false,
      isPickupActive: true,
      rating: 4.0,
      ratingCount: 8,
    ),
  ];

  setUp(() {
    fakeDataSource = FakeDataSource();
  });

  Widget createWidgetUnderTest({
    ProfessionalCategoryEntity? category,
    double? customerLat = 25.1337,
    double? customerLng = 86.1772,
    String? customerArea = 'Main Bazaar',
  }) {
    return MaterialApp(
      home: ProfessionalShopsListingPage(
        category: category,
        dataSource: fakeDataSource,
        customerLat: customerLat,
        customerLng: customerLng,
        customerArea: customerArea,
      ),
    );
  }

  group('ProfessionalShopsListingPage Tests', () {
    testWidgets('renders category displayName properly', (tester) async {
      fakeDataSource.mockShops = sampleShops;

      final category = const ProfessionalCategoryEntity(
        id: 'cat_grocery',
        titleEnglish: 'Grocery & Essentials',
        titleHindi: 'किराना और जरूरी सामान',
        slug: 'grocery-essentials',
        priorityOrder: 1,
        isActive: true,
      );

      await tester.pumpWidget(createWidgetUnderTest(category: category));
      await tester.pumpAndSettle();

      expect(find.text(category.displayName), findsOneWidget);
    });

    testWidgets('displays skeletons while initial loading', (tester) async {
      fakeDataSource.mockShops = sampleShops;

      await tester.pumpWidget(createWidgetUnderTest());
      // On initial pump before async fetch resolves
      expect(find.byType(ProfessionalShopSkeleton), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.byType(ProfessionalShopSkeleton), findsNothing);
      expect(find.byType(ProfessionalShopCard), findsNWidgets(2));
    });

    testWidgets('displays loaded shops with ProfessionalShopCard', (tester) async {
      fakeDataSource.mockShops = sampleShops;

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Jamui Grocery Mart'), findsOneWidget);
      expect(find.text('Bihar Electronics'), findsOneWidget);
    });

    testWidgets('displays filter chips and filters items by tab', (tester) async {
      fakeDataSource.mockShops = sampleShops;

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);
      // The filter row has 'Open Now', while cards also have 'Open Now'
      expect(find.text('Open Now'), findsWidgets);

      // Tap on 'Delivery' filter chip
      await tester.tap(find.text('Delivery'));
      await tester.pumpAndSettle();

      // shop_1 has isHomeDeliveryActive=true & distance 1.2 <= 5.0km
      // shop_2 has isHomeDeliveryActive=false
      expect(find.text('Jamui Grocery Mart'), findsOneWidget);
      expect(find.text('Bihar Electronics'), findsNothing);
    });

    testWidgets('displays empty state when no shops are returned', (tester) async {
      fakeDataSource.mockShops = [];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('No verified shops found'), findsOneWidget);
    });

    testWidgets('displays error state with retry button on fetch failure', (tester) async {
      fakeDataSource.shouldThrowError = true;
      fakeDataSource.errorMessage = 'Network connection failed';

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Failed to load shops. Please tap retry.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Recover and click retry
      fakeDataSource.shouldThrowError = false;
      fakeDataSource.mockShops = sampleShops;

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfessionalShopCard), findsNWidgets(2));
      expect(find.text('Jamui Grocery Mart'), findsOneWidget);
    });

    testWidgets('search debounce triggers search and displays search results', (tester) async {
      fakeDataSource.mockShops = sampleShops;
      fakeDataSource.mockSearchResults = [
        const ProfessionalShopEntity(
          id: 'shop_search_1',
          shopName: 'SearchResult Pharmacy',
          jamuiArea: 'Main Bazaar',
          latitude: 25.1337,
          longitude: 86.1772,
          isHomeDeliveryActive: true,
          isPickupActive: true,
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Pharm');
      // Wait for debounce (350ms)
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(fakeDataSource.searchCallCount, 1);
      expect(find.text('SearchResult Pharmacy'), findsOneWidget);
      expect(find.text('Jamui Grocery Mart'), findsNothing);
    });

    testWidgets('search displays ceiling banner when searchHasMore is true', (tester) async {
      fakeDataSource.mockShops = sampleShops;
      fakeDataSource.mockSearchResults = [
        const ProfessionalShopEntity(
          id: 'shop_search_1',
          shopName: 'SearchResult Store',
          jamuiArea: 'Main Bazaar',
          latitude: 25.1337,
          longitude: 86.1772,
          isHomeDeliveryActive: true,
          isPickupActive: true,
        ),
      ];
      fakeDataSource.searchShouldHaveMore = true;

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Store');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        find.text('Showing search results from the first 300 loaded vendors.'),
        findsOneWidget,
      );
      expect(find.text('Search the next 100 vendors'), findsOneWidget);

      // Tapping banner searches next 100
      await tester.tap(find.text('Search the next 100 vendors'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(fakeDataSource.searchCallCount, 2);
    });

    testWidgets('pull to refresh invokes forceRefresh on data source', (tester) async {
      fakeDataSource.mockShops = sampleShops;

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Trigger refresh via RefreshIndicatorState
      final refreshIndicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      await refreshIndicator.onRefresh();

      expect(fakeDataSource.forceRefreshCalled, isTrue);
    });
  });
}
