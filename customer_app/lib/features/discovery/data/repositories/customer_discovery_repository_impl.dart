import '../../data/datasources/customer_discovery_remote_data_source.dart';
import '../../domain/entities/paginated_providers_entity.dart';
import '../../domain/entities/service_category_entity.dart';
import '../../domain/entities/service_provider_entity.dart';
import '../../domain/repositories/customer_discovery_repository.dart';

class CustomerDiscoveryRepositoryImpl implements CustomerDiscoveryRepository {
  final CustomerDiscoveryRemoteDataSource remoteDataSource;

  CustomerDiscoveryRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ServiceCategoryEntity>> getCategories() async {
    return await remoteDataSource.fetchCategories();
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
    return await remoteDataSource.fetchProviders(
      categoryId: categoryId,
      jamuiArea: jamuiArea,
      searchQuery: searchQuery,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      maxRadiusKm: maxRadiusKm,
      customerVillage: customerVillage,
      customerBlock: customerBlock,
    );
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
    return await remoteDataSource.fetchPaginatedProviders(
      categoryId: categoryId,
      jamuiArea: jamuiArea,
      searchQuery: searchQuery,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      maxRadiusKm: maxRadiusKm,
      customerVillage: customerVillage,
      customerBlock: customerBlock,
      limit: limit,
      lastDocumentCursor: lastDocumentCursor,
    );
  }

  @override
  Future<void> trackLeadClick({
    required String providerId,
    required bool isCall,
    String? customerId,
    String? categoryId,
  }) async {
    await remoteDataSource.recordLeadClick(
      providerId: providerId,
      isCall: isCall,
      customerId: customerId,
      categoryId: categoryId,
    );
  }

  @override
  Future<void> trackProfileView({
    required String providerId,
    String? customerId,
  }) async {
    await remoteDataSource.recordProfileView(
      providerId: providerId,
      customerId: customerId,
    );
  }
}
