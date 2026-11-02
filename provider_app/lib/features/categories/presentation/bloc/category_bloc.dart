import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/category_repository.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository categoryRepository;

  CategoryBloc({required this.categoryRepository}) : super(CategoryInitial()) {
    on<FetchCategoriesEvent>(_onFetchCategories);
  }

  Future<void> _onFetchCategories(
    FetchCategoriesEvent event,
    Emitter<CategoryState> emit,
  ) async {
    emit(CategoryLoading());
    try {
      final categories = await categoryRepository.getActiveCategories();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError('कैटेगरीज लोड करने में त्रुटि: $e'));
    }
  }
}
