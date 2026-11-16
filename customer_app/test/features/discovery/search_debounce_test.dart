import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/paginated_providers_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_category_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/entities/service_provider_entity.dart';
import 'package:apna_jamui_customer/features/discovery/domain/repositories/customer_discovery_repository.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/bloc/discovery_event.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/bloc/discovery_state.dart';

class MockDebounceDiscoveryRepository implements CustomerDiscoveryRepository {
  final List<String> queriedSearches = [];

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
    String? customerVillage,
    String? customerBlock,
  }) async {
    if (searchQuery != null) {
      queriedSearches.add(searchQuery);
    }
    return [];
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
    queriedSearches.add(searchQuery ?? '');
    return PaginatedProvidersResult(
      items: [],
      hasMore: false,
      totalCountEstimate: 0,
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

void main() {
  group('Search Query Suppression & Debounce Verification Tests', () {
    late MockDebounceDiscoveryRepository mockRepo;
    late DiscoveryBloc bloc;

    setUp(() {
      mockRepo = MockDebounceDiscoveryRepository();
      bloc = DiscoveryBloc(discoveryRepository: mockRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('Single character query ("p") is suppressed from executing Firestore query', () async {
      bloc.add(const LoadDiscoveryDataEvent());
      await bloc.stream.firstWhere((s) => s is DiscoveryLoaded);

      expect(mockRepo.queriedSearches.length, equals(1)); // Initial load query ('')

      // Dispatch 1-character query
      bloc.add(const SearchProvidersEvent('p'));
      await Future.delayed(const Duration(milliseconds: 50));

      // No new query executed
      expect(mockRepo.queriedSearches.length, equals(1));
    });

    test('Single character with whitespace ("  k  ") is trimmed and suppressed', () async {
      bloc.add(const LoadDiscoveryDataEvent());
      await bloc.stream.firstWhere((s) => s is DiscoveryLoaded);

      expect(mockRepo.queriedSearches.length, equals(1));

      // Dispatch trimmed 1-character query
      bloc.add(const SearchProvidersEvent('  k  '));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockRepo.queriedSearches.length, equals(1));
    });

    test('Two character query ("pl") executes Firestore query', () async {
      bloc.add(const LoadDiscoveryDataEvent());
      await bloc.stream.firstWhere((s) => s is DiscoveryLoaded);

      expect(mockRepo.queriedSearches.length, equals(1));

      // Dispatch 2-character query
      bloc.add(const SearchProvidersEvent('pl'));
      await bloc.stream.firstWhere((s) => s is DiscoveryLoaded && s.searchQuery == 'pl');

      expect(mockRepo.queriedSearches.length, equals(2));
      expect(mockRepo.queriedSearches.last, equals('pl'));
    });

    test('Consecutive duplicate empty search does not trigger duplicate Firestore reads', () async {
      bloc.add(const LoadDiscoveryDataEvent());
      await bloc.stream.firstWhere((s) => s is DiscoveryLoaded);

      expect(mockRepo.queriedSearches.length, equals(1));

      // Dispatch empty query when already empty
      bloc.add(const SearchProvidersEvent(''));
      await Future.delayed(const Duration(milliseconds: 50));

      // Remains 1 call
      expect(mockRepo.queriedSearches.length, equals(1));
    });
  });
}
