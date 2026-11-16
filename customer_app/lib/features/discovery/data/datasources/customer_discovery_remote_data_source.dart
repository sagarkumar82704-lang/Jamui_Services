import '../../domain/entities/paginated_providers_entity.dart';
import '../models/service_category_model.dart';
import '../models/service_provider_model.dart';

abstract class CustomerDiscoveryRemoteDataSource {
  Future<List<ServiceCategoryModel>> fetchCategories();
  
  Future<List<ServiceProviderModel>> fetchProviders({
    String? categoryId,
    String? jamuiArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
    String? customerId,
    String? customerVillage,
    String? customerBlock,
  });

  /// True server/database-level cursor pagination
  Future<PaginatedProvidersResult> fetchPaginatedProviders({
    String? categoryId,
    String? jamuiArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
    String? customerId,
    String? customerVillage,
    String? customerBlock,
    int limit = 12,
    dynamic lastDocumentCursor,
  });

  Future<void> recordLeadClick({
    required String providerId,
    required bool isCall,
    String? customerId,
    String? categoryId,
  });

  Future<void> recordProfileView({
    required String providerId,
    String? customerId,
  });
}
