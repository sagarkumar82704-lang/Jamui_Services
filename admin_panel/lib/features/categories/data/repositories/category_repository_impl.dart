import '../../domain/entities/category_entity.dart';
import '../../domain/entities/category_dependency_count.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_remote_data_source.dart';
import '../models/category_model.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDataSource remoteDataSource;

  CategoryRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<CategoryEntity>> fetchCategories({String? filterStatus, String? searchQuery}) async {
    return await remoteDataSource.fetchCategories(filterStatus: filterStatus, searchQuery: searchQuery);
  }

  @override
  Future<void> saveCategory(CategoryEntity category, String adminId) async {
    await remoteDataSource.saveCategory(CategoryModel.fromEntity(category), adminId);
  }

  @override
  Future<void> updateCategory(CategoryEntity category, String adminId) async {
    await remoteDataSource.updateCategory(CategoryModel.fromEntity(category), adminId);
  }

  @override
  Future<void> setCategoryStatus(String id, CategoryStatus status, String adminId) async {
    await remoteDataSource.setCategoryStatus(id, status, adminId);
  }

  @override
  Future<void> archiveCategory(String id, String adminId) async {
    await remoteDataSource.archiveCategory(id, adminId);
  }

  @override
  Future<CategoryDependencyCount> checkDependencies(String categoryId, String categoryName) async {
    return await remoteDataSource.checkDependencies(categoryId, categoryName);
  }

  @override
  Future<bool> isDuplicateName(String name, {String? excludeId}) async {
    return await remoteDataSource.isDuplicateName(name, excludeId: excludeId);
  }

  @override
  Future<bool> isDuplicateSlug(String slug, {String? excludeId}) async {
    return await remoteDataSource.isDuplicateSlug(slug, excludeId: excludeId);
  }

  @override
  Future<void> deletePermanently(String id, String adminId) async {
    await remoteDataSource.deletePermanently(id, adminId);
  }
}
