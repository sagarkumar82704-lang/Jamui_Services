import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_admin/features/categories/domain/entities/category_entity.dart';
import 'package:apna_jamui_admin/features/categories/domain/entities/category_dependency_count.dart';
import 'package:apna_jamui_admin/features/categories/domain/repositories/category_repository.dart';
import 'package:apna_jamui_admin/features/categories/presentation/bloc/category_bloc.dart';
import 'package:apna_jamui_admin/features/categories/presentation/bloc/category_event.dart';
import 'package:apna_jamui_admin/features/categories/presentation/bloc/category_state.dart';

class MockCategoryRepository implements CategoryRepository {
  List<CategoryEntity> store = [];

  @override
  Future<List<CategoryEntity>> fetchCategories({String? filterStatus, String? searchQuery}) async {
    return store;
  }

  @override
  Future<void> saveCategory(CategoryEntity category, String adminId) async {
    store.add(category);
  }

  @override
  Future<void> updateCategory(CategoryEntity category, String adminId) async {
    final idx = store.indexWhere((c) => c.id == category.id);
    if (idx != -1) store[idx] = category;
  }

  @override
  Future<void> setCategoryStatus(String id, CategoryStatus status, String adminId) async {
    final idx = store.indexWhere((c) => c.id == id);
    if (idx != -1) {
      store[idx] = store[idx].copyWith(status: status);
    }
  }

  @override
  Future<void> archiveCategory(String id, String adminId) async {
    final idx = store.indexWhere((c) => c.id == id);
    if (idx != -1) {
      store[idx] = store[idx].copyWith(status: CategoryStatus.archived, isDeleted: true);
    }
  }

  @override
  Future<CategoryDependencyCount> checkDependencies(String categoryId, String categoryName) async {
    return const CategoryDependencyCount(
      providerCount: 0,
      serviceCount: 0,
      leadCount: 0,
      bookingCount: 0,
      reviewCount: 0,
    );
  }

  @override
  Future<bool> isDuplicateName(String name, {String? excludeId}) async {
    final clean = name.trim().toLowerCase();
    return store.any((c) => c.id != excludeId && c.name.toLowerCase() == clean);
  }

  @override
  Future<bool> isDuplicateSlug(String slug, {String? excludeId}) async {
    final clean = slug.trim().toLowerCase();
    return store.any((c) => c.id != excludeId && c.slug.toLowerCase() == clean);
  }

  @override
  Future<void> deletePermanently(String id, String adminId) async {
    store.removeWhere((c) => c.id == id);
  }
}

void main() {
  group('CategoryBloc Unit Tests', () {
    late MockCategoryRepository mockRepo;
    late CategoryBloc bloc;

    setUp(() {
      mockRepo = MockCategoryRepository();
      bloc = CategoryBloc(repository: mockRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is CategoryInitialState', () {
      expect(bloc.state, equals(CategoryInitialState()));
    });

    test('LoadCategoriesEvent emits Loaded state', () async {
      final expected = [
        CategoryLoadingState(),
        const CategoryLoadedState(categories: []),
      ];

      expectLater(bloc.stream, emitsInOrder(expected));
      bloc.add(const LoadCategoriesEvent());
    });

    test('CreateCategoryEvent creates complete advanced category with image and FAQs', () async {
      final cat = CategoryEntity(
        id: 'cat_electrician_1',
        name: 'Electrician',
        slug: 'electrician',
        titleHindi: 'इलेक्ट्रीशियन',
        shortDescription: 'Professional electrical repair and installation.',
        fullDescription: 'Complete electrical services for residential and commercial premises.',
        imageUrl: 'https://firebasestorage.googleapis.com/v0/b/jamui/o/category_images%2Fcat_1%2Fcover.webp',
        imageStoragePath: 'category_images/cat_1/cover.webp',
        pricingType: 'starting_from',
        startingPrice: 149.0,
        priceUnit: 'per visit',
        estimatedDuration: '30-45 Mins',
        subServices: const ['Fan Repair', 'Switch Replacement', 'Short Circuit Fix'],
        benefits: const ['Certified Electricians', '30-Day Warranty'],
        commonProblems: const ['Sparking Socket', 'Low Voltage'],
        customerRequirements: 'Clear path to switchboard and ladder if ceiling work.',
        customerPhotoRequired: true,
        providerRequirements: 'Minimum 2 years experience in 220V electrical systems.',
        experienceCertificateRequired: true,
        verificationRequired: true,
        faqs: const [
          CategoryFaq(
            question: 'Are materials included in the service cost?',
            answer: 'No, spare parts and switches are charged at actuals.',
            displayOrder: 1,
          ),
        ],
        safetyInstructions: 'Always turn off main MCB before inspecting.',
        searchKeywords: const ['electrician', 'bijli mistri', 'jamui electrician'],
        isFeatured: true,
        createdAt: DateTime.now(),
      );

      bloc.add(CreateCategoryEvent(category: cat, adminId: 'admin_1'));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<CategoryState>((state) {
            if (state is CategoryLoadedState && state.categories.length == 1) {
              final saved = state.categories.first;
              return saved.name == 'Electrician' &&
                  saved.imageUrl.contains('category_images') &&
                  saved.subServices.length == 3 &&
                  saved.faqs.length == 1 &&
                  saved.isFeatured == true;
            }
            return false;
          }),
        ),
      );
    });

    test('CreateCategoryEvent prevents duplicate name', () async {
      mockRepo.store.add(CategoryEntity(
        id: 'cat_1',
        name: 'Plumber',
        slug: 'plumber',
        createdAt: DateTime.now(),
      ));

      bloc.add(CreateCategoryEvent(
        category: CategoryEntity(
          id: 'cat_2',
          name: 'Plumber',
          slug: 'plumber-new',
          createdAt: DateTime.now(),
        ),
        adminId: 'admin_1',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<CategoryState>((state) {
            return state is CategoryErrorState && state.message.contains('Duplicate names are not allowed');
          }),
        ),
      );
    });

    test('CreateCategoryEvent prevents duplicate slug', () async {
      mockRepo.store.add(CategoryEntity(
        id: 'cat_1',
        name: 'Plumber',
        slug: 'plumber',
        createdAt: DateTime.now(),
      ));

      bloc.add(CreateCategoryEvent(
        category: CategoryEntity(
          id: 'cat_2',
          name: 'Plumbing Works',
          slug: 'plumber',
          createdAt: DateTime.now(),
        ),
        adminId: 'admin_1',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<CategoryState>((state) {
            return state is CategoryErrorState && state.message.contains('Duplicate slugs are not allowed');
          }),
        ),
      );
    });
  });
}
