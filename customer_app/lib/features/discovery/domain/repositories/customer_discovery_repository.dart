import '../entities/paginated_providers_entity.dart';
import '../entities/service_category_entity.dart';
import '../entities/service_provider_entity.dart';

abstract class CustomerDiscoveryRepository {
  Future<List<ServiceCategoryEntity>> getCategories();
  
  Future<List<ServiceProviderEntity>> getProviders({
    String? categoryId,
    String? jamuiArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
    String? customerVillage,
    String? customerBlock,
  });

  /// True server/database cursor pagination
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
  });

  Future<void> trackLeadClick({
    required String providerId,
    required bool isCall,
    String? customerId,
    String? categoryId,
  });

  Future<void> trackProfileView({
    required String providerId,
    String? customerId,
  });
}
