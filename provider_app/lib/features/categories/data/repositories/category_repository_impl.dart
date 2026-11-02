import '../../domain/entities/service_category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_remote_data_source.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDataSource remoteDataSource;

  CategoryRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ServiceCategory>> getActiveCategories() async {
    return await remoteDataSource.fetchActiveCategories();
  }
}
