import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/paginated_providers_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_category_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_provider_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/repositories/customer_discovery_repository.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/bloc/discovery_event.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/bloc/discovery_state.dart';

class MockCustomerDiscoveryRepository implements CustomerDiscoveryRepository {
  final List<ServiceCategoryEntity> categories;
  final List<ServiceProviderEntity> providers;
  final List<String> leadClicks = [];
  int getPaginatedProvidersCallCount = 0;

  MockCustomerDiscoveryRepository({required this.categories, required this.providers});

  @override
  Future<List<ServiceCategoryEntity>> getCategories() async {
    return List.from(categories);
  }

  @override
  Future<List<ServiceProviderEntity>> getProviders({
    String? categoryId,
    String? jamuiArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
    String? customerVillage,
    String? customerBlock,
  }) async {
    var list = List<ServiceProviderEntity>.from(providers);
    if (categoryId != null && categoryId != 'all') {
      list = list.where((p) => p.categoryId == categoryId).toList();
    }
    if (jamuiArea != null && jamuiArea != 'सभी इलाके') {
      list = list.where((p) => p.jamuiArea.contains(jamuiArea)).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      list = list.where((p) => p.fullName.contains(searchQuery) || p.businessName.contains(searchQuery)).toList();
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
    String? customerVillage,
    String? customerBlock,
    int limit = 12,
    dynamic lastDocumentCursor,
  }) async {
    getPaginatedProvidersCallCount++;
    final list = await getProviders(
      categoryId: categoryId,
      jamuiArea: jamuiArea,
      searchQuery: searchQuery,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      maxRadiusKm: maxRadiusKm,
    );
    return PaginatedProvidersResult(
      items: list.take(limit).toList(),
      hasMore: list.length > limit,
      totalCountEstimate: list.length,
    );
  }

  @override
  Future<void> trackLeadClick({
    required String providerId,
    required bool isCall,
    String? customerId,
    String? categoryId,
  }) async {
    leadClicks.add('$providerId:${isCall ? "call" : "whatsapp"}');
  }

  @override
  Future<void> trackProfileView({
    required String providerId,
    String? customerId,
  }) async {
    leadClicks.add('$providerId:view');
  }
}

void main() {
  group('DiscoveryBloc Unit Tests', () {
    late MockCustomerDiscoveryRepository mockRepo;
    late DiscoveryBloc bloc;

    final dummyCategories = [
      const ServiceCategoryEntity(
        id: 'cat_electrician',
        titleHindi: 'इलेक्ट्रीशियन',
        titleEnglish: 'Electrician',
        iconName: 'bolt',
        colorHex: '#F59E0B',
        priorityOrder: 1,
      ),
      const ServiceCategoryEntity(
        id: 'cat_plumber',
        titleHindi: 'प्लंबर',
        titleEnglish: 'Plumber',
        iconName: 'plumbing',
        colorHex: '#3B82F6',
        priorityOrder: 2,
      ),
    ];

    final dummyProviders = [
      const ServiceProviderEntity(
        id: 'prov_1',
        fullName: 'राजेश कुमार',
        businessName: 'राजेश इलेक्ट्रिकल वर्क्स',
        phoneNumber: '+919876543210',
        categoryId: 'cat_electrician',
        categoryTitle: 'इलेक्ट्रीशियन',
        visitingCharge: 150,
        experienceYears: 7,
        jamuiArea: 'बोधवन तालाब रोड, जमुई',
      ),
      const ServiceProviderEntity(
        id: 'prov_2',
        fullName: 'अमित कुमार',
        businessName: 'अमित प्लंबिंग',
        phoneNumber: '+919431288412',
        categoryId: 'cat_plumber',
        categoryTitle: 'प्लंबर',
        visitingCharge: 199,
        experienceYears: 5,
        jamuiArea: 'महिसौरी चौक, जमुई',
      ),
    ];

    setUp(() {
      mockRepo = MockCustomerDiscoveryRepository(
        categories: dummyCategories,
        providers: dummyProviders,
      );
      bloc = DiscoveryBloc(discoveryRepository: mockRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is DiscoveryInitial', () {
      expect(bloc.state, equals(DiscoveryInitial()));
    });

    test('LoadDiscoveryDataEvent loads categories and providers', () async {
      final expectedStates = [
        DiscoveryLoading(),
        DiscoveryLoaded(
          categories: dummyCategories,
          providers: dummyProviders,
          hasMoreProviders: false,
          generationToken: 1,
        ),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(const LoadDiscoveryDataEvent());
    });

    test('SelectCategoryFilterEvent filters providers by category', () async {
      // First load
      bloc.add(const LoadDiscoveryDataEvent());
      await bloc.stream.firstWhere((s) => s is DiscoveryLoaded);

      // Select category
      bloc.add(const SelectCategoryFilterEvent('cat_plumber'));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<DiscoveryState>((state) {
            return state is DiscoveryLoaded &&
                state.selectedCategoryId == 'cat_plumber' &&
                state.providers.length == 1 &&
                state.providers.first.id == 'prov_2';
          }),
        ),
      );
    });

    test('TrackProviderLeadEvent invokes repository lead tracker', () async {
      bloc.add(const TrackProviderLeadEvent(providerId: 'prov_1', isCall: true));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.leadClicks, contains('prov_1:call'));
    });

    test('SearchProvidersEvent with query length < 2 does not trigger provider query', () async {
      // First load
      bloc.add(const LoadDiscoveryDataEvent());
      await bloc.stream.firstWhere((s) => s is DiscoveryLoaded);
      final initialCallCount = mockRepo.getPaginatedProvidersCallCount;

      // Dispatch 1-character query ('p')
      bloc.add(const SearchProvidersEvent('p'));
      await Future.delayed(const Duration(milliseconds: 50));

      // Repository query count should not increase
      expect(mockRepo.getPaginatedProvidersCallCount, equals(initialCallCount));
      expect((bloc.state as DiscoveryLoaded).searchQuery, equals(''));
    });

    test('SearchProvidersEvent with query length >= 2 triggers provider query and filters', () async {
      // First load
      bloc.add(const LoadDiscoveryDataEvent());
      await bloc.stream.firstWhere((s) => s is DiscoveryLoaded);
      final initialCallCount = mockRepo.getPaginatedProvidersCallCount;

      // Dispatch 2-character query ('अम')
      bloc.add(const SearchProvidersEvent('अम'));
      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<DiscoveryState>((state) {
            return state is DiscoveryLoaded &&
                state.searchQuery == 'अम' &&
                state.providers.length == 1 &&
                state.providers.first.fullName == 'अमित कुमार';
          }),
        ),
      );

      expect(mockRepo.getPaginatedProvidersCallCount, equals(initialCallCount + 1));
    });

    test('SearchProvidersEvent with empty query when already empty does not duplicate query', () async {
      // First load
      bloc.add(const LoadDiscoveryDataEvent());
      await bloc.stream.firstWhere((s) => s is DiscoveryLoaded);
      final initialCallCount = mockRepo.getPaginatedProvidersCallCount;

      // Dispatch empty query when already empty
      bloc.add(const SearchProvidersEvent(''));
      await Future.delayed(const Duration(milliseconds: 50));

      // Repository query count should not increase
      expect(mockRepo.getPaginatedProvidersCallCount, equals(initialCallCount));
    });
  });
}
