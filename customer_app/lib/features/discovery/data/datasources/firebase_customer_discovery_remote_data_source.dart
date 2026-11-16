import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/paginated_providers_entity.dart';
import '../../domain/entities/service_provider_entity.dart';
import '../models/service_category_model.dart';
import '../models/service_provider_model.dart';
import 'customer_discovery_remote_data_source.dart';

class FirebaseCustomerDiscoveryRemoteDataSource
    implements CustomerDiscoveryRemoteDataSource {
  FirebaseFirestore? _firestoreInstance;
  static const String _categoriesCollection = 'categories';
  static const String _providersCollection = 'providers';
  static const String _analyticsCollection = 'analytics_events';

  FirebaseCustomerDiscoveryRemoteDataSource({FirebaseFirestore? firestore})
      : _firestoreInstance = firestore;

  FirebaseFirestore? get _firestore {
    if (_firestoreInstance != null) return _firestoreInstance;
    try {
      _firestoreInstance = FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ServiceCategoryModel>> fetchCategories() async {
    try {
      final fs = _firestore;
      if (fs != null) {
        final snapshot = await fs
            .collection(_categoriesCollection)
            .orderBy('priorityOrder')
            .get()
            .timeout(const Duration(seconds: 6));

        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs
              .map((doc) => ServiceCategoryModel.fromMap(doc.data(), doc.id))
              .where((c) => c.isActive)
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<List<ServiceProviderModel>> fetchProviders({
    String? categoryId,
    String? jamuiArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
    String? customerId,
    String? customerVillage,
    String? customerBlock,
  }) async {
    final paginated = await fetchPaginatedProviders(
      categoryId: categoryId,
      jamuiArea: jamuiArea,
      searchQuery: searchQuery,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      maxRadiusKm: maxRadiusKm,
      customerId: customerId,
      customerVillage: customerVillage,
      customerBlock: customerBlock,
      limit: (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') ? 30 : 20,
      lastDocumentCursor: null,
    );
    return paginated.items.map((e) => e as ServiceProviderModel).toList();
  }

  @override
  Future<PaginatedProvidersResult> fetchPaginatedProviders({
    String? categoryId,
    String? jamuiArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
    String? customerId,
    String? customerVillage,
    String? customerBlock,
    int limit = 12,
    dynamic lastDocumentCursor,
  }) async {
    List<ServiceProviderModel> list = [];
    DocumentSnapshot? newLastDoc;
    bool hasMore = false;

    try {
      final fs = _firestore;
      if (fs != null) {
        Query<Map<String, dynamic>> query = fs.collection(_providersCollection);

        // Server-side category filtering (primaryCategoryId, categoryId, or selectedCategoryIds)
        final bool hasCategoryFilter = categoryId != null && categoryId.isNotEmpty && categoryId != 'all';
        if (hasCategoryFilter) {
          final target = categoryId.trim();
          try {
            query = query.where(
              Filter.or(
                Filter('primaryCategoryId', isEqualTo: target),
                Filter('categoryId', isEqualTo: target),
                Filter('selectedCategoryIds', arrayContains: target),
              ),
            );
          } catch (_) {
            try {
              query = query.where(
                Filter.or(
                  Filter('primaryCategoryId', isEqualTo: target),
                  Filter('categoryId', isEqualTo: target),
                ),
              );
            } catch (_) {
              query = query.where('primaryCategoryId', isEqualTo: target);
            }
          }
        }

        // Apply true database-level limit (use exact limit when category-filtered to avoid 3x overfetch)
        final int effectiveDbLimit = hasCategoryFilter ? limit : (limit * 2);
        query = query.limit(effectiveDbLimit);

        // Apply cursor pagination
        if (lastDocumentCursor is DocumentSnapshot) {
          query = query.startAfterDocument(lastDocumentCursor);
        }

        final snapshot = await query.get().timeout(const Duration(seconds: 6));

        if (snapshot.docs.isNotEmpty) {
          newLastDoc = snapshot.docs.last;
          hasMore = snapshot.docs.length >= limit;

          list = snapshot.docs
              .map((doc) => ServiceProviderModel.fromMap(doc.data(), doc.id))
              .where((p) => p.isApprovedAndLive)
              .toList();
        }
      }
    } catch (_) {
      // Targeted fallback query preserving category constraint if compound Filter.or throws
      try {
        final fs = _firestore;
        if (fs != null) {
          Query<Map<String, dynamic>> fallbackQuery = fs.collection(_providersCollection);
          final bool hasCategoryFilter = categoryId != null && categoryId.isNotEmpty && categoryId != 'all';
          if (hasCategoryFilter) {
            fallbackQuery = fallbackQuery.where('primaryCategoryId', isEqualTo: categoryId.trim());
          }
          final int fallbackLimit = hasCategoryFilter ? limit : (limit * 2);
          fallbackQuery = fallbackQuery.limit(fallbackLimit);
          if (lastDocumentCursor is DocumentSnapshot) {
            fallbackQuery = fallbackQuery.startAfterDocument(lastDocumentCursor);
          }
          final snap = await fallbackQuery.get().timeout(const Duration(seconds: 5));
          if (snap.docs.isNotEmpty) {
            newLastDoc = snap.docs.last;
            hasMore = snap.docs.length >= limit;
            list = snap.docs
                .map((doc) => ServiceProviderModel.fromMap(doc.data(), doc.id))
                .where((p) => p.isApprovedAndLive)
                .toList();
          }
        }
      } catch (_) {}
    }

    // -- POST-FETCH CATEGORY REFINEMENT --
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      final targetCat = categoryId.toLowerCase().trim();
      list = list.where((p) {
        final pCatId = p.categoryId.toLowerCase().trim();
        final pCatTitle = p.categoryTitle.toLowerCase().trim();
        final selected = p.selectedCategoryIds.map((s) => s.toLowerCase().trim()).toSet();
        return pCatId == targetCat ||
            selected.contains(targetCat) ||
            pCatTitle == targetCat ||
            (targetCat.length >= 3 && pCatTitle.contains(targetCat)) ||
            (pCatId.length >= 3 && targetCat.contains(pCatId));
      }).toList();
    }

    // -- POST-FETCH LOCAL REFINEMENT (Area & Search) --
    if (jamuiArea != null && jamuiArea.isNotEmpty && jamuiArea != 'सभी इलाके') {
      list = list.where((p) => p.jamuiArea.toLowerCase().contains(jamuiArea.toLowerCase())).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      const stopWords = {
        'wala', 'wali', 'wale', 'banane', 'banao', 'chahiye', 'karna', 'karo', 'karwana',
        'hai', 'hain', 'ho', 'tha', 'thi', 'the', 'ko', 'ka', 'ki', 'ke', 'se', 'me', 'mein',
        'par', 'kuch', 'bhi', 'mera', 'meri', 'mere', 'apna', 'apni', 'kisko', 'kahan',
        'need', 'want', 'require', 'please', 'help', 'service', 'repair',
        'theek', 'thik', 'kar', 'kardo', 'jaldi', 'urgent', 'mujhe', 'mujhko', 'kaam',
        'काम', 'कुछ', 'मदद', 'चाहिए', 'करवाना', 'है', 'मेरे', 'घर', 'ghar',
      };
      final tokens = RegExp(r'[\w\u0900-\u097F]+')
          .allMatches(q)
          .map((m) => m.group(0)!)
          .where((t) => t.length >= 2 && !stopWords.contains(t))
          .toList();

      list = list.where((p) {
        // Direct full phrase match
        if (p.fullName.toLowerCase().contains(q) ||
            p.businessName.toLowerCase().contains(q) ||
            p.categoryTitle.toLowerCase().contains(q) ||
            p.subServices.any((s) => s.toLowerCase().contains(q))) {
          return true;
        }
        // Token match (e.g. searching "rajesh electrician" or "पंखा मिस्त्री")
        if (tokens.isNotEmpty) {
          return tokens.any((t) =>
              p.fullName.toLowerCase().contains(t) ||
              p.businessName.toLowerCase().contains(t) ||
              p.categoryTitle.toLowerCase().contains(t) ||
              p.subServices.any((s) => s.toLowerCase().contains(t)));
        }
        return false;
      }).toList();
    }

    // -- 5. LOCATION VALIDATION, RADIUS CHECK & 3-TIER PRIORITY + NEAREST-FIRST SORTING --
    list = filterAndSortProviders(
      providers: list,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
      maxRadiusKm: maxRadiusKm,
      customerVillage: customerVillage,
      customerBlock: customerBlock,
    );

    return PaginatedProvidersResult(
      items: list,
      lastDocumentCursor: newLastDoc,
      hasMore: hasMore,
      totalCountEstimate: list.length,
    );
  }

  static bool _containsLocationToken(String text, String targetLower) {
    if (text.isEmpty || targetLower.isEmpty) return false;
    final norm = text.trim().toLowerCase();
    if (norm == targetLower) return true;
    final parts = norm
        .split(RegExp(r'[,/\-()|\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.contains(targetLower)) return true;
    return norm.contains(targetLower);
  }

  static bool matchesProviderVillage(ServiceProviderEntity p, String customerVillageLower) {
    if (customerVillageLower.isEmpty) return false;
    final pVillage = p.village.trim().toLowerCase();
    final pLocality = p.locality.trim().toLowerCase();
    if (pVillage.isNotEmpty && pVillage == customerVillageLower) return true;
    if (pLocality.isNotEmpty && pLocality == customerVillageLower) return true;
    if (pVillage.isEmpty) {
      if (_containsLocationToken(p.jamuiArea, customerVillageLower)) return true;
      if (_containsLocationToken(p.fullAddress, customerVillageLower)) return true;
    }
    return false;
  }

  static bool matchesProviderBlock(ServiceProviderEntity p, String customerBlockLower) {
    if (customerBlockLower.isEmpty) return false;
    final pBlock = p.block.trim().toLowerCase();
    final pCity = p.city.trim().toLowerCase();
    if (pBlock.isNotEmpty && pBlock == customerBlockLower) return true;
    if (pCity.isNotEmpty && pCity == customerBlockLower) return true;
    if (pBlock.isEmpty) {
      if (_containsLocationToken(p.jamuiArea, customerBlockLower)) return true;
      if (_containsLocationToken(p.fullAddress, customerBlockLower)) return true;
    }
    return false;
  }

  /// Computes 3-tier provider matching priority:
  /// - Tier 1: Same Village AND Same Block (when both are reliably available)
  /// - Tier 2: Same Block (when Block is available)
  /// - Tier 3: Other nearby eligible providers sorted by GPS distance
  static int computeLocationMatchTier(
    ServiceProviderEntity p, {
    String? customerVillage,
    String? customerBlock,
  }) {
    final cleanVillage = (customerVillage ?? '').trim().toLowerCase();
    final cleanBlock = (customerBlock ?? '').trim().toLowerCase();

    final bool hasVillageMatch = cleanVillage.isNotEmpty && matchesProviderVillage(p, cleanVillage);
    final bool hasBlockMatch = cleanBlock.isNotEmpty && matchesProviderBlock(p, cleanBlock);

    if (cleanVillage.isNotEmpty && cleanBlock.isNotEmpty && hasVillageMatch && hasBlockMatch) {
      return 1;
    }
    if (cleanBlock.isNotEmpty && hasBlockMatch) {
      return 2;
    }
    if (cleanBlock.isEmpty && cleanVillage.isNotEmpty && hasVillageMatch) {
      return 1;
    }
    return 3;
  }

  /// Authoritative provider filtering & 3-tier location priority + nearest-first sorting
  List<ServiceProviderModel> filterAndSortProviders({
    required List<ServiceProviderModel> providers,
    double? customerLatitude,
    double? customerLongitude,
    double? maxRadiusKm,
    String? customerVillage,
    String? customerBlock,
  }) {
    // 1. Strict approval & business eligibility filter
    List<ServiceProviderModel> list = providers.where((p) => p.isApprovedAndLive).toList();

    // 2. Location validation, radius check & 3-tier priority + nearest-first sorting
    final bool hasValidCustomerLocation = LocationService.isValidCoordinate(customerLatitude, customerLongitude);

    if (hasValidCustomerLocation) {
      final List<ServiceProviderModel> eligibleWithDistance = [];

      for (final p in list) {
        // Eligibility rule: Provider coordinates must be valid and non-zero
        if (!LocationService.isValidCoordinate(p.latitude, p.longitude)) {
          // Reject invalid or missing coordinates
          continue;
        }

        // Eligibility rule: Provider service radius must be configured and valid in Firebase
        if (!LocationService.isValidRadius(p.serviceRadiusKm)) {
          // Reject invalid or missing service radius
          continue;
        }

        final double distanceKm = LocationService.calculateDistanceKm(
          startLatitude: customerLatitude!,
          startLongitude: customerLongitude!,
          endLatitude: p.latitude,
          endLongitude: p.longitude,
        );

        final double effectiveRadius = (maxRadiusKm != null && LocationService.isValidRadius(maxRadiusKm))
            ? (maxRadiusKm < p.serviceRadiusKm ? maxRadiusKm : p.serviceRadiusKm)
            : p.serviceRadiusKm;

        // Provider is ONLY eligible if customer is strictly within their configured service radius
        if (distanceKm <= effectiveRadius) {
          eligibleWithDistance.add(p.copyWith(distanceKm: distanceKm));
        }
      }

      // Sort by:
      // Priority 1: Same Village + Same Block (Tier 1)
      // Priority 2: Same Block (Tier 2)
      // Priority 3: Nearby by GPS distance (Tier 3)
      // Within each tier, sort strictly nearest-first (ascending distance), then higher rating.
      eligibleWithDistance.sort((a, b) {
        final tierA = computeLocationMatchTier(
          a,
          customerVillage: customerVillage,
          customerBlock: customerBlock,
        );
        final tierB = computeLocationMatchTier(
          b,
          customerVillage: customerVillage,
          customerBlock: customerBlock,
        );
        final tierCmp = tierA.compareTo(tierB);
        if (tierCmp != 0) return tierCmp;

        final distCompare = (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity);
        if (distCompare != 0) return distCompare;
        return b.rating.compareTo(a.rating);
      });

      return eligibleWithDistance;
    } else {
      // Customer location permission is denied or location fetch failed.
      // Zero fake distance: ensure distanceKm is strictly null.
      final fallbackList = list.map((p) => p.copyWith(distanceKm: null)).toList();

      // Graceful fallback sort: Village/Block tier first (if manual location set without coords),
      // then highest rated & most experienced providers first
      fallbackList.sort((a, b) {
        final tierA = computeLocationMatchTier(
          a,
          customerVillage: customerVillage,
          customerBlock: customerBlock,
        );
        final tierB = computeLocationMatchTier(
          b,
          customerVillage: customerVillage,
          customerBlock: customerBlock,
        );
        final tierCmp = tierA.compareTo(tierB);
        if (tierCmp != 0) return tierCmp;

        final ratingCmp = b.rating.compareTo(a.rating);
        if (ratingCmp != 0) return ratingCmp;
        return b.experienceYears.compareTo(a.experienceYears);
      });

      return fallbackList;
    }
  }

  @override
  Future<void> recordLeadClick({
    required String providerId,
    required bool isCall,
    String? customerId,
    String? categoryId,
  }) async {
    try {
      final fs = _firestore;
      if (fs != null) {
        await fs.collection(_providersCollection).doc(providerId).update({
          if (isCall) 'totalCalls': FieldValue.increment(1),
          if (!isCall) 'totalWhatsAppClicks': FieldValue.increment(1),
        }).timeout(const Duration(seconds: 4));

        await fs.collection(_analyticsCollection).add({
          'eventType': isCall ? 'call_click' : 'whatsapp_click',
          'providerId': providerId,
          'customerId': customerId ?? 'anonymous_customer',
          'categoryId': categoryId ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  @override
  Future<void> recordProfileView({
    required String providerId,
    String? customerId,
  }) async {
    try {
      final fs = _firestore;
      if (fs != null) {
        await fs.collection(_providersCollection).doc(providerId).update({
          'totalViews': FieldValue.increment(1),
        }).timeout(const Duration(seconds: 4));

        await fs.collection(_analyticsCollection).add({
          'eventType': 'profile_view',
          'providerId': providerId,
          'customerId': customerId ?? 'anonymous_customer',
          'timestamp': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }
}
