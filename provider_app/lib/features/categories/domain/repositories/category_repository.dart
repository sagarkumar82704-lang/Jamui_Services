import '../entities/service_category.dart';

abstract class CategoryRepository {
  Future<List<ServiceCategory>> getActiveCategories();
}
