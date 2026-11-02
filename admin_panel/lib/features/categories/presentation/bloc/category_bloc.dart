import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/category_repository.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository _repository;

  CategoryBloc({required CategoryRepository repository})
      : _repository = repository,
        super(CategoryInitialState()) {
    on<LoadCategoriesEvent>(_onLoadCategories);
    on<CreateCategoryEvent>(_onCreateCategory);
    on<UpdateCategoryEvent>(_onUpdateCategory);
    on<ToggleCategoryStatusEvent>(_onToggleStatus);
    on<CheckCategoryDependenciesEvent>(_onCheckDependencies);
    on<ArchiveCategoryEvent>(_onArchiveCategory);
    on<DeleteCategoryPermanentlyEvent>(_onDeletePermanently);
  }

  Future<void> _onLoadCategories(
    LoadCategoriesEvent event,
    Emitter<CategoryState> emit,
  ) async {
    emit(CategoryLoadingState());
    try {
      final categories = await _repository.fetchCategories(
        filterStatus: event.filterStatus,
        searchQuery: event.searchQuery,
      );
      emit(CategoryLoadedState(
        categories: categories,
        activeFilter: event.filterStatus ?? 'all',
        searchQuery: event.searchQuery ?? '',
      ));
    } catch (e) {
      emit(CategoryErrorState('Unable to load categories: ${e.toString()}'));
    }
  }

  Future<void> _onCreateCategory(
    CreateCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    emit(CategoryLoadingState());
    try {
      final isDup = await _repository.isDuplicateName(event.category.name);
      if (isDup) {
        emit(const CategoryErrorState('Category already exists. Duplicate names are not allowed.'));
        return;
      }
      final isDupSlug = await _repository.isDuplicateSlug(event.category.slug);
      if (isDupSlug) {
        emit(const CategoryErrorState('Category slug already exists. Duplicate slugs are not allowed.'));
        return;
      }

      await _repository.saveCategory(event.category, event.adminId);
      emit(const CategoryOperationSuccessState('Category created successfully.'));
      add(const LoadCategoriesEvent());
    } catch (e) {
      emit(CategoryErrorState('Failed to create category: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateCategory(
    UpdateCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    emit(CategoryLoadingState());
    try {
      final isDup = await _repository.isDuplicateName(event.category.name, excludeId: event.category.id);
      if (isDup) {
        emit(const CategoryErrorState('Category name already in use by another category.'));
        return;
      }
      final isDupSlug = await _repository.isDuplicateSlug(event.category.slug, excludeId: event.category.id);
      if (isDupSlug) {
        emit(const CategoryErrorState('Category slug already in use by another category.'));
        return;
      }

      await _repository.updateCategory(event.category, event.adminId);
      emit(const CategoryOperationSuccessState('Category updated successfully.'));
      add(const LoadCategoriesEvent());
    } catch (e) {
      emit(CategoryErrorState('Failed to update category: ${e.toString()}'));
    }
  }

  Future<void> _onToggleStatus(
    ToggleCategoryStatusEvent event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      await _repository.setCategoryStatus(event.categoryId, event.newStatus, event.adminId);
      emit(CategoryOperationSuccessState('Category status changed to ${event.newStatus.name}.'));
      add(const LoadCategoriesEvent());
    } catch (e) {
      emit(CategoryErrorState('Failed to change category status: ${e.toString()}'));
    }
  }

  Future<void> _onCheckDependencies(
    CheckCategoryDependenciesEvent event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      final counts = await _repository.checkDependencies(event.category.id, event.category.name);
      emit(CategoryDependenciesCheckedState(
        category: event.category,
        dependencyCount: counts,
      ));
    } catch (e) {
      emit(CategoryErrorState('Failed to check category dependencies: ${e.toString()}'));
    }
  }

  Future<void> _onArchiveCategory(
    ArchiveCategoryEvent event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      await _repository.archiveCategory(event.categoryId, event.adminId);
      emit(const CategoryOperationSuccessState('Category archived safely. Historical records preserved.'));
      add(const LoadCategoriesEvent());
    } catch (e) {
      emit(CategoryErrorState('Failed to archive category: ${e.toString()}'));
    }
  }

  Future<void> _onDeletePermanently(
    DeleteCategoryPermanentlyEvent event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      await _repository.deletePermanently(event.categoryId, event.adminId);
      emit(const CategoryOperationSuccessState('Category permanently deleted.'));
      add(const LoadCategoriesEvent());
    } catch (e) {
      emit(CategoryErrorState('Failed to delete category: ${e.toString()}'));
    }
  }
}
