import 'package:equatable/equatable.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/category_dependency_count.dart';

abstract class CategoryState extends Equatable {
  const CategoryState();

  @override
  List<Object?> get props => [];
}

class CategoryInitialState extends CategoryState {}

class CategoryLoadingState extends CategoryState {}

class CategoryLoadedState extends CategoryState {
  final List<CategoryEntity> categories;
  final String activeFilter;
  final String searchQuery;

  const CategoryLoadedState({
    required this.categories,
    this.activeFilter = 'all',
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [categories, activeFilter, searchQuery];
}

class CategoryOperationSuccessState extends CategoryState {
  final String message;

  const CategoryOperationSuccessState(this.message);

  @override
  List<Object?> get props => [message];
}

class CategoryDependenciesCheckedState extends CategoryState {
  final CategoryEntity category;
  final CategoryDependencyCount dependencyCount;

  const CategoryDependenciesCheckedState({
    required this.category,
    required this.dependencyCount,
  });

  @override
  List<Object?> get props => [category, dependencyCount];
}

class CategoryErrorState extends CategoryState {
  final String message;

  const CategoryErrorState(this.message);

  @override
  List<Object?> get props => [message];
}
