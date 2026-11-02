import 'package:equatable/equatable.dart';
import '../../domain/entities/category_entity.dart';

abstract class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadCategoriesEvent extends CategoryEvent {
  final String? filterStatus;
  final String? searchQuery;

  const LoadCategoriesEvent({this.filterStatus, this.searchQuery});

  @override
  List<Object?> get props => [filterStatus, searchQuery];
}

class CreateCategoryEvent extends CategoryEvent {
  final CategoryEntity category;
  final String adminId;

  const CreateCategoryEvent({required this.category, required this.adminId});

  @override
  List<Object?> get props => [category, adminId];
}

class UpdateCategoryEvent extends CategoryEvent {
  final CategoryEntity category;
  final String adminId;

  const UpdateCategoryEvent({required this.category, required this.adminId});

  @override
  List<Object?> get props => [category, adminId];
}

class ToggleCategoryStatusEvent extends CategoryEvent {
  final String categoryId;
  final CategoryStatus newStatus;
  final String adminId;

  const ToggleCategoryStatusEvent({
    required this.categoryId,
    required this.newStatus,
    required this.adminId,
  });

  @override
  List<Object?> get props => [categoryId, newStatus, adminId];
}

class CheckCategoryDependenciesEvent extends CategoryEvent {
  final CategoryEntity category;

  const CheckCategoryDependenciesEvent(this.category);

  @override
  List<Object?> get props => [category];
}

class ArchiveCategoryEvent extends CategoryEvent {
  final String categoryId;
  final String adminId;

  const ArchiveCategoryEvent({required this.categoryId, required this.adminId});

  @override
  List<Object?> get props => [categoryId, adminId];
}

class DeleteCategoryPermanentlyEvent extends CategoryEvent {
  final String categoryId;
  final String adminId;

  const DeleteCategoryPermanentlyEvent({required this.categoryId, required this.adminId});

  @override
  List<Object?> get props => [categoryId, adminId];
}
