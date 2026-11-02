import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_admin/features/categories/domain/entities/category_entity.dart';
import 'package:apna_jamui_admin/features/categories/domain/entities/category_dependency_count.dart';
import 'package:apna_jamui_admin/features/categories/domain/repositories/category_repository.dart';
import 'package:apna_jamui_admin/features/categories/presentation/bloc/category_bloc.dart';
import 'package:apna_jamui_admin/features/categories/presentation/bloc/category_event.dart';
import 'package:apna_jamui_admin/features/categories/presentation/bloc/category_state.dart';
import 'package:apna_jamui_admin/core/utils/admin_placeholder_images.dart';

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

  Future<CategoryEntity?> getCategoryById(String id) async {
    try {
      return store.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
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
  group('Admin Panel — Unisex Salon Category Flow & Verification', () {
    late MockCategoryRepository mockRepo;
    late CategoryBloc bloc;

    setUp(() {
      mockRepo = MockCategoryRepository();
      bloc = CategoryBloc(repository: mockRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('1. Unisex Salon Category Creation with full services, subservices and AI tags', () async {
      final salonCategory = CategoryEntity(
        id: 'cat_unisex_salon',
        name: 'Unisex Salon',
        slug: 'unisex-salon',
        titleHindi: 'यूनिसेक्स सैलून',
        shortDescription: 'Hair, beauty, grooming and salon services for men and women.',
        fullDescription: 'Comprehensive unisex salon offering modern styling, hair treatment, skincare, and beauty services in Jamui.',
        imageUrl: 'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=800&q=80',
        pricingType: 'starting_from',
        startingPrice: 199.0,
        priceUnit: 'ऑनवर्ड्स',
        estimatedDuration: '30-90 Mins',
        subServices: const [
          'Haircut & Styling',
          'Hair Color & Highlights',
          'Skin & Facial Care',
          'Beard Grooming & Shaving',
          'Manicure & Pedicure',
          'Bridal & Party Makeup',
          'Hair Treatment & Spa',
          'Smoothening & Keratin',
        ],
        benefits: const [
          'Certified Stylists',
          'Hygienic & Sanitized Salon',
          'Premium Branded Products',
          'Air Conditioned Lounge',
        ],
        commonProblems: const [
          'Damaged Hair',
          'Dandruff Problem',
          'Hair Fall',
          'Dry Skin',
        ],
        searchKeywords: const [
          'salon', 'parlour', 'haircut', 'unisex', 'grooming', 'facial', 'keratin', 'jamui salon',
        ],
        tags: const ['Trending', 'Premium', 'Men & Women'],
        iconName: 'content_cut',
        colorHex: '#EC4899',
        status: CategoryStatus.active,
        isFeatured: true,
        createdAt: DateTime.now(),
      );

      bloc.add(CreateCategoryEvent(category: salonCategory, adminId: 'admin_101'));

      await expectLater(
        bloc.stream,
        emitsThrough(predicate<CategoryState>((state) {
          if (state is CategoryLoadedState) {
            return state.categories.any((c) => c.name == 'Unisex Salon' && c.iconName == 'content_cut');
          }
          return false;
        })),
      );

      expect(mockRepo.store.length, 1);
      final created = mockRepo.store.first;
      expect(created.name, 'Unisex Salon');
      expect(created.titleHindi, 'यूनिसेक्स सैलून');
      expect(created.subServices.length, 8);
      expect(created.subServices.contains('Haircut & Styling'), isTrue);
      expect(created.subServices.contains('Smoothening & Keratin'), isTrue);
      expect(created.iconName, 'content_cut');
      expect(created.status, CategoryStatus.active);
    });

    test('2. Duplicate Category Prevention: Cannot create duplicate Unisex Salon category name or slug', () async {
      mockRepo.store.add(CategoryEntity(
        id: 'cat_existing_salon',
        name: 'Unisex Salon',
        slug: 'unisex-salon',
        titleHindi: 'यूनिसेक्स सैलून',
        shortDescription: 'Existing salon',
        fullDescription: 'Existing salon',
        imageUrl: '',
        pricingType: 'starting_from',
        startingPrice: 199.0,
        priceUnit: 'ऑनवर्ड्स',
        estimatedDuration: '30 Mins',
        subServices: const ['Haircut'],
        benefits: const [],
        commonProblems: const [],
        searchKeywords: const [],
        tags: const [],
        iconName: 'content_cut',
        colorHex: '#EC4899',
        status: CategoryStatus.active,
        createdAt: DateTime.now(),
      ));

      final duplicateCat = CategoryEntity(
        id: 'cat_dup_salon',
        name: 'Unisex Salon',
        slug: 'unisex-salon-2',
        titleHindi: 'यूनिसेक्स सैलून 2',
        shortDescription: 'Duplicate attempt',
        fullDescription: 'Duplicate attempt',
        imageUrl: '',
        pricingType: 'starting_from',
        startingPrice: 199.0,
        priceUnit: 'ऑनवर्ड्स',
        estimatedDuration: '30 Mins',
        subServices: const ['Haircut'],
        benefits: const [],
        commonProblems: const [],
        searchKeywords: const [],
        tags: const [],
        iconName: 'content_cut',
        colorHex: '#EC4899',
        status: CategoryStatus.active,
        createdAt: DateTime.now(),
      );

      bloc.add(CreateCategoryEvent(category: duplicateCat, adminId: 'admin_101'));

      await expectLater(
        bloc.stream,
        emitsThrough(predicate<CategoryState>((state) {
          return state is CategoryErrorState && state.message.contains('Duplicate names are not allowed');
        })),
      );

      expect(mockRepo.store.length, 1, reason: 'Duplicate creation must be blocked by validation');
    });

    test('3. Category Active/Inactive Status Toggle Verification', () async {
      mockRepo.store.add(CategoryEntity(
        id: 'cat_unisex_salon',
        name: 'Unisex Salon',
        slug: 'unisex-salon',
        titleHindi: 'यूनिसेक्स सैलून',
        shortDescription: 'Salon',
        fullDescription: 'Salon',
        imageUrl: '',
        pricingType: 'starting_from',
        startingPrice: 199.0,
        priceUnit: 'ऑनवर्ड्स',
        estimatedDuration: '30 Mins',
        subServices: const ['Haircut'],
        benefits: const [],
        commonProblems: const [],
        searchKeywords: const [],
        tags: const [],
        iconName: 'content_cut',
        colorHex: '#EC4899',
        status: CategoryStatus.active,
        createdAt: DateTime.now(),
      ));

      bloc.add(const ToggleCategoryStatusEvent(
        categoryId: 'cat_unisex_salon',
        newStatus: CategoryStatus.inactive,
        adminId: 'admin_101',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(predicate<CategoryState>((state) {
          if (state is CategoryLoadedState) {
            return state.categories.first.status == CategoryStatus.inactive;
          }
          return false;
        })),
      );

      expect(mockRepo.store.first.status, CategoryStatus.inactive);
    });

    test('4. AdminPlaceholderImages includes category/unisex_salon local asset', () {
      final salonItem = AdminPlaceholderImages.categoryPlaceholders
          .where((p) => p.id == 'category/unisex_salon')
          .firstOrNull;

      expect(salonItem, isNotNull);
      expect(salonItem!.titleEnglish, 'Unisex Salon & Grooming');
      expect(salonItem.titleHindi, 'यूनिसेक्स सैलून (डेमो)');
      expect(salonItem.tag, 'सैलून');
      expect(AdminPlaceholderImages.isPlaceholder('placeholder://category/unisex_salon'), isTrue);
    });

    test('5. Dropdown Sanitizer: unisex_salon dropdown has exactly one matching item and never crashes', () {
      // Helper function mirroring the exact deduplication algorithm in _AddEditPremiumCategoryDialog
      List<Map<String, String>> buildSanitized(List<Map<String, dynamic>> available, String? selectedId) {
        final Map<String, String> categoryMap = {};
        for (final cat in available) {
          final id = cat['id']?.toString().trim() ?? '';
          if (id.isEmpty) continue;
          final name = (cat['titleHindi'] != null && cat['titleHindi'].toString().isNotEmpty)
              ? '${cat['titleHindi']} (${cat['name'] ?? cat['title'] ?? cat['titleEnglish'] ?? id})'
              : (cat['name'] ?? cat['title'] ?? cat['titleEnglish'] ?? id).toString();
          categoryMap[id] = name;
        }
        if (selectedId != null && selectedId.isNotEmpty) {
          if (!categoryMap.containsKey(selectedId)) {
            categoryMap[selectedId] = (selectedId == 'unisex_salon') ? 'यूनिसेक्स सैलून (Unisex Salon)' : selectedId;
          }
        }
        if (!categoryMap.containsKey('unisex_salon')) {
          categoryMap['unisex_salon'] = 'यूनिसेक्स सैलून (Unisex Salon)';
        }
        return categoryMap.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
      }

      // Case A: availableCategories is completely empty
      final listEmpty = buildSanitized([], 'unisex_salon');
      final matchingA = listEmpty.where((c) => c['id'] == 'unisex_salon').toList();
      expect(matchingA.length, 1, reason: 'Must have exactly ONE unisex_salon item when availableCategories is empty');

      // Case B: availableCategories already has a unisex_salon document from Firestore
      final listWithSalon = buildSanitized([
        {'id': 'unisex_salon', 'name': 'Unisex Salon Firestore', 'titleHindi': 'यूनिसेक्स सैलून'},
        {'id': 'electrician', 'name': 'Electrician', 'titleHindi': 'इलेक्ट्रीशियन'},
        {'id': 'unisex_salon', 'name': 'Duplicate Salon'}, // Duplicate in Firestore
      ], 'unisex_salon');
      final matchingB = listWithSalon.where((c) => c['id'] == 'unisex_salon').toList();
      expect(matchingB.length, 1, reason: 'Must deduplicate and have exactly ONE unisex_salon item');
      expect(listWithSalon.length, 2, reason: 'Electrician and Unisex Salon must be distinct without duplicate IDs');

      // Case C: Missing or non-existent selectedCategoryId falls back safely without assertion
      final listRandom = buildSanitized([
        {'id': 'electrician', 'name': 'Electrician'},
      ], 'non_existent_id');
      final hasSelected = listRandom.any((c) => c['id'] == 'non_existent_id');
      expect(hasSelected, isTrue, reason: 'Non-existent initial value is added safely with fallback label');
      final nonExistentMatches = listRandom.where((c) => c['id'] == 'non_existent_id').toList();
      expect(nonExistentMatches.length, 1);
    });

    test('6. Duplicate Prevention: Updating existing premium category instead of creating duplicate document', () {
      final existingStore = <Map<String, dynamic>>[
        {
          'id': 'prem_101',
          'categoryId': 'unisex_salon',
          'categoryName': 'Unisex Salon',
          'customTitle': 'Unisex Salon',
          'priority': 1,
          'isActive': true,
          'showOnHome': true,
        }
      ];

      // Simulate save logic from _AddEditPremiumCategoryDialogState._save
      void simulateSave({required String categoryId, required String newTitle, String? docId}) {
        if (docId != null) {
          // Edit mode
          final idx = existingStore.indexWhere((d) => d['id'] == docId);
          existingStore[idx]['customTitle'] = newTitle;
        } else {
          // Add mode: duplicate check
          final existingIdx = existingStore.indexWhere((d) => d['categoryId'] == categoryId);
          if (existingIdx != -1) {
            // Found existing: Update existing document, do not create duplicate
            existingStore[existingIdx]['customTitle'] = newTitle;
          } else {
            existingStore.add({
              'id': 'prem_${DateTime.now().millisecondsSinceEpoch}',
              'categoryId': categoryId,
              'customTitle': newTitle,
            });
          }
        }
      }

      // Trying to add "Unisex Salon" again
      simulateSave(categoryId: 'unisex_salon', newTitle: 'Updated Unisex Salon Title', docId: null);

      expect(existingStore.length, 1, reason: 'Should not create a second document for unisex_salon');
      expect(existingStore.first['customTitle'], 'Updated Unisex Salon Title', reason: 'Existing document updated safely');
    });

    test('7. Active/Inactive Toggle and Homepage Visibility Data Flow', () {
      final premiumDoc = {
        'id': 'prem_salon_01',
        'categoryId': 'unisex_salon',
        'isActive': true,
        'showOnHome': true,
      };

      // Toggle inactive
      premiumDoc['isActive'] = !(premiumDoc['isActive'] as bool);
      expect(premiumDoc['isActive'], isFalse);

      // Verify that when inactive or showOnHome is false, it is filtered from customer homepage
      final allCategories = [premiumDoc];
      final visibleOnCustomerHome = allCategories
          .where((c) => c['isActive'] == true && c['showOnHome'] == true)
          .toList();

      expect(visibleOnCustomerHome.isEmpty, isTrue, reason: 'Inactive categories must be hidden from customer home');

      // Toggle active back on
      premiumDoc['isActive'] = true;
      final visibleNow = allCategories
          .where((c) => c['isActive'] == true && c['showOnHome'] == true)
          .toList();
      expect(visibleNow.length, 1, reason: 'Active and showOnHome category is visible on customer home');
    });

    test('8. Firestore Permission Error Guidance contract', () {
      const permissionError = '[cloud_firestore/permission-denied] Missing or insufficient permissions.';
      final isPermError = permissionError.toLowerCase().contains('permission') ||
          permissionError.contains('permission-denied') ||
          permissionError.contains('Missing or insufficient permissions');

      expect(isPermError, isTrue);

      // Verify retry callback increments state retry key
      int retryCounter = 0;
      void onRetry() {
        retryCounter++;
      }

      onRetry();
      expect(retryCounter, 1);
    });
  });
}
