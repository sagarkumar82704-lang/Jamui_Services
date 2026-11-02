import '../models/category_model.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/category_dependency_count.dart';

abstract class CategoryRemoteDataSource {
  Future<List<CategoryModel>> fetchCategories({String? filterStatus, String? searchQuery});
  Future<void> saveCategory(CategoryModel category, String adminId);
  Future<void> updateCategory(CategoryModel category, String adminId);
  Future<void> setCategoryStatus(String id, CategoryStatus status, String adminId);
  Future<void> archiveCategory(String id, String adminId);
  Future<CategoryDependencyCount> checkDependencies(String categoryId, String categoryName);
  Future<bool> isDuplicateName(String name, {String? excludeId});
  Future<bool> isDuplicateSlug(String slug, {String? excludeId});
  Future<void> deletePermanently(String id, String adminId);
}
