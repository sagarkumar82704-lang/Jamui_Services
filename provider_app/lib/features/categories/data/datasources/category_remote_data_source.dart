import '../models/service_category_model.dart';

abstract class CategoryRemoteDataSource {
  Future<List<ServiceCategoryModel>> fetchActiveCategories();
  Future<List<ServiceCategoryModel>> fetchActivePremiumCategories();
}
