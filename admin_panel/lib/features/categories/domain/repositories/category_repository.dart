import '../entities/category_entity.dart';
import '../entities/category_dependency_count.dart';

abstract class CategoryRepository {
  Future<List<CategoryEntity>> fetchCategories({String? filterStatus, String? searchQuery});
  Future<void> saveCategory(CategoryEntity category, String adminId);
  Future<void> updateCategory(CategoryEntity category, String adminId);
  Future<void> setCategoryStatus(String id, CategoryStatus status, String adminId);
  Future<void> archiveCategory(String id, String adminId);
  Future<CategoryDependencyCount> checkDependencies(String categoryId, String categoryName);
  Future<bool> isDuplicateName(String name, {String? excludeId});
  Future<bool> isDuplicateSlug(String slug, {String? excludeId});
  Future<void> deletePermanently(String id, String adminId);
}
