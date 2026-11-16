import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/firebase_customer_discovery_remote_data_source.dart';
import '../../domain/entities/service_provider_entity.dart';
import '../../domain/repositories/customer_discovery_repository.dart';
import 'discovery_event.dart';
import 'discovery_state.dart';

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final CustomerDiscoveryRepository discoveryRepository;
  static const int _pageSize = 12;

  DiscoveryBloc({required this.discoveryRepository}) : super(DiscoveryInitial()) {
    on<LoadDiscoveryDataEvent>(_onLoadData);
    on<UpdateCustomerLocationEvent>(_onUpdateLocation);
    on<SelectCategoryFilterEvent>(_onSelectCategory);
    on<SelectAreaFilterEvent>(_onSelectArea);
    on<SearchProvidersEvent>(_onSearch);
    on<LoadMoreProvidersEvent>(_onLoadMore);
    on<ApplyAISearchIntentEvent>(_onApplyAISearchIntent);
    on<TrackProviderLeadEvent>(_onTrackLead);
    on<TrackProviderViewEvent>(_onTrackView);
  }

  Future<void> _onLoadData(
    LoadDiscoveryDataEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    final nextGen = (state is DiscoveryLoaded ? (state as DiscoveryLoaded).generationToken : 0) + 1;
    emit(DiscoveryLoading());
    try {
      final categories = await discoveryRepository.getCategories();
      final paginated = await discoveryRepository.getPaginatedProviders(
        customerLatitude: event.customerLatitude,
        customerLongitude: event.customerLongitude,
        customerVillage: event.customerVillage,
        customerBlock: event.customerBlock,
        limit: _pageSize,
        lastDocumentCursor: null,
      );

      emit(DiscoveryLoaded(
        categories: categories,
        providers: paginated.items,
        customerLatitude: event.customerLatitude,
        customerLongitude: event.customerLongitude,
        customerAreaName: event.customerAreaName ?? 'स्थान चुनें (GPS)',
        customerVillage: event.customerVillage ?? '',
        customerBlock: event.customerBlock ?? '',
        hasMoreProviders: paginated.hasMore,
        lastDocumentCursor: paginated.lastDocumentCursor,
        isLoadingMore: false,
        generationToken: nextGen,
      ));
    } catch (e) {
      emit(DiscoveryError(e.toString()));
    }
  }

  Future<void> _onUpdateLocation(
    UpdateCustomerLocationEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    final current = state is DiscoveryLoaded
        ? state as DiscoveryLoaded
        : const DiscoveryLoaded(categories: [], providers: []);

    final nextGen = current.generationToken + 1;
    emit(DiscoveryLoading());
    try {
      final categories = current.categories.isNotEmpty
          ? current.categories
          : await discoveryRepository.getCategories();

      final paginated = await discoveryRepository.getPaginatedProviders(
        categoryId: current.selectedCategoryId,
        jamuiArea: current.selectedArea,
        searchQuery: current.searchQuery,
        customerLatitude: event.latitude,
        customerLongitude: event.longitude,
        customerVillage: event.village,
        customerBlock: event.block,
        limit: _pageSize,
        lastDocumentCursor: null,
      );

      emit(current.copyWith(
        categories: categories,
        providers: paginated.items,
        customerLatitude: event.latitude,
        customerLongitude: event.longitude,
        customerAreaName: event.areaName,
        customerVillage: event.village,
        customerBlock: event.block,
        hasMoreProviders: paginated.hasMore,
        lastDocumentCursor: paginated.lastDocumentCursor,
        isLoadingMore: false,
        generationToken: nextGen,
      ));
    } catch (e) {
      emit(DiscoveryError(e.toString()));
    }
  }

  Future<void> _onSelectCategory(
    SelectCategoryFilterEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    if (state is DiscoveryLoaded) {
      final current = state as DiscoveryLoaded;
      final newCategory = current.selectedCategoryId == event.categoryId ? 'all' : event.categoryId;
      final nextGen = current.generationToken + 1;

      emit(current.copyWith(
        selectedCategoryId: newCategory,
        clearCursor: true,
        hasMoreProviders: true,
        isLoadingMore: false,
        generationToken: nextGen,
      ));

      try {
        final paginated = await discoveryRepository.getPaginatedProviders(
          categoryId: newCategory,
          jamuiArea: current.selectedArea,
          searchQuery: current.searchQuery,
          customerLatitude: current.customerLatitude,
          customerLongitude: current.customerLongitude,
          customerVillage: current.customerVillage,
          customerBlock: current.customerBlock,
          limit: _pageSize,
          lastDocumentCursor: null,
        );

        if (state is DiscoveryLoaded && (state as DiscoveryLoaded).generationToken == nextGen) {
          emit((state as DiscoveryLoaded).copyWith(
            selectedCategoryId: newCategory,
            providers: paginated.items,
            hasMoreProviders: paginated.hasMore,
            lastDocumentCursor: paginated.lastDocumentCursor,
            isLoadingMore: false,
          ));
        }
      } catch (e) {
        emit(DiscoveryError(e.toString()));
      }
    }
  }

  Future<void> _onSelectArea(
    SelectAreaFilterEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    if (state is DiscoveryLoaded) {
      final current = state as DiscoveryLoaded;
      final nextGen = current.generationToken + 1;

      emit(current.copyWith(
        selectedArea: event.area,
        clearCursor: true,
        hasMoreProviders: true,
        isLoadingMore: false,
        generationToken: nextGen,
      ));

      try {
        final paginated = await discoveryRepository.getPaginatedProviders(
          categoryId: current.selectedCategoryId,
          jamuiArea: event.area,
          searchQuery: current.searchQuery,
          customerLatitude: current.customerLatitude,
          customerLongitude: current.customerLongitude,
          customerVillage: current.customerVillage,
          customerBlock: current.customerBlock,
          limit: _pageSize,
          lastDocumentCursor: null,
        );

        if (state is DiscoveryLoaded && (state as DiscoveryLoaded).generationToken == nextGen) {
          emit((state as DiscoveryLoaded).copyWith(
            selectedArea: event.area,
            providers: paginated.items,
            hasMoreProviders: paginated.hasMore,
            lastDocumentCursor: paginated.lastDocumentCursor,
            isLoadingMore: false,
          ));
        }
      } catch (e) {
        emit(DiscoveryError(e.toString()));
      }
    }
  }

  Future<void> _onSearch(
    SearchProvidersEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    if (state is DiscoveryLoaded) {
      final current = state as DiscoveryLoaded;
      final clean = event.query.trim();

      // Guard: Do not execute provider search query when under 2 characters (unless empty to reset)
      if (clean.isNotEmpty && clean.length < 2) {
        return;
      }

      // Guard: Avoid duplicate query if search is already empty
      if (clean.isEmpty && current.searchQuery.isEmpty) {
        return;
      }

      final nextGen = current.generationToken + 1;

      emit(current.copyWith(
        searchQuery: clean,
        clearActiveAiIntent: clean.isEmpty,
        clearCursor: true,
        hasMoreProviders: true,
        isLoadingMore: false,
        generationToken: nextGen,
      ));

      try {
        final paginated = await discoveryRepository.getPaginatedProviders(
          categoryId: current.selectedCategoryId,
          jamuiArea: current.selectedArea,
          searchQuery: clean,
          customerLatitude: current.customerLatitude,
          customerLongitude: current.customerLongitude,
          customerVillage: current.customerVillage,
          customerBlock: current.customerBlock,
          limit: _pageSize,
          lastDocumentCursor: null,
        );

        if (state is DiscoveryLoaded && (state as DiscoveryLoaded).generationToken == nextGen) {
          emit((state as DiscoveryLoaded).copyWith(
            searchQuery: event.query,
            providers: paginated.items,
            hasMoreProviders: paginated.hasMore,
            lastDocumentCursor: paginated.lastDocumentCursor,
            isLoadingMore: false,
          ));
        }
      } catch (e) {
        emit(DiscoveryError(e.toString()));
      }
    }
  }

  Future<void> _onLoadMore(
    LoadMoreProvidersEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    if (state is! DiscoveryLoaded) return;
    final current = state as DiscoveryLoaded;

    // Guard: Do not trigger pagination if already loading or no more items
    if (current.isLoadingMore || !current.hasMoreProviders) return;

    final currentGen = current.generationToken;
    emit(current.copyWith(isLoadingMore: true));

    try {
      final paginated = await discoveryRepository.getPaginatedProviders(
        categoryId: current.selectedCategoryId,
        jamuiArea: current.selectedArea,
        searchQuery: current.searchQuery,
        customerLatitude: current.customerLatitude,
        customerLongitude: current.customerLongitude,
        customerVillage: current.customerVillage,
        customerBlock: current.customerBlock,
        limit: _pageSize,
        lastDocumentCursor: current.lastDocumentCursor,
      );

      // Race condition check: only apply if generation has not changed during network call
      if (state is DiscoveryLoaded && (state as DiscoveryLoaded).generationToken == currentGen) {
        final existingIds = current.providers.map((p) => p.id).toSet();
        final newUnique = paginated.items.where((p) => !existingIds.contains(p.id)).toList();

        final merged = List<ServiceProviderEntity>.from(current.providers)..addAll(newUnique);

        // Maintain global 3-tier + nearest-first order across pagination batches
        if (current.customerLatitude != null && current.customerLongitude != null) {
          merged.sort((a, b) {
            final tierA = FirebaseCustomerDiscoveryRemoteDataSource.computeLocationMatchTier(
              a,
              customerVillage: current.customerVillage,
              customerBlock: current.customerBlock,
            );
            final tierB = FirebaseCustomerDiscoveryRemoteDataSource.computeLocationMatchTier(
              b,
              customerVillage: current.customerVillage,
              customerBlock: current.customerBlock,
            );
            final tierCmp = tierA.compareTo(tierB);
            if (tierCmp != 0) return tierCmp;

            final distA = a.distanceKm ?? double.infinity;
            final distB = b.distanceKm ?? double.infinity;
            final cmp = distA.compareTo(distB);
            if (cmp != 0) return cmp;
            return b.rating.compareTo(a.rating);
          });
        }

        emit(current.copyWith(
          providers: merged,
          hasMoreProviders: paginated.hasMore,
          lastDocumentCursor: paginated.lastDocumentCursor ?? current.lastDocumentCursor,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      if (state is DiscoveryLoaded && (state as DiscoveryLoaded).generationToken == currentGen) {
        emit(current.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> _onApplyAISearchIntent(
    ApplyAISearchIntentEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    if (state is DiscoveryLoaded) {
      final current = state as DiscoveryLoaded;
      final targetCatId = event.intent.categoryId ?? current.selectedCategoryId;
      final targetArea = event.intent.extractedArea ?? current.selectedArea;
      final nextGen = current.generationToken + 1;

      emit(current.copyWith(
        searchQuery: event.query,
        selectedCategoryId: targetCatId,
        selectedArea: targetArea,
        activeAiIntent: event.intent,
        clearCursor: true,
        hasMoreProviders: true,
        isLoadingMore: false,
        generationToken: nextGen,
      ));

      try {
        final paginated = await discoveryRepository.getPaginatedProviders(
          categoryId: targetCatId,
          jamuiArea: targetArea,
          searchQuery: event.intent.categoryId != null ? null : event.query,
          customerLatitude: current.customerLatitude,
          customerLongitude: current.customerLongitude,
          customerVillage: current.customerVillage,
          customerBlock: current.customerBlock,
          limit: _pageSize,
          lastDocumentCursor: null,
        );

        if (state is DiscoveryLoaded && (state as DiscoveryLoaded).generationToken == nextGen) {
          emit((state as DiscoveryLoaded).copyWith(
            searchQuery: event.query,
            selectedCategoryId: targetCatId,
            selectedArea: targetArea,
            activeAiIntent: event.intent,
            providers: paginated.items,
            hasMoreProviders: paginated.hasMore,
            lastDocumentCursor: paginated.lastDocumentCursor,
            isLoadingMore: false,
          ));
        }
      } catch (e) {
        emit(DiscoveryError(e.toString()));
      }
    }
  }

  Future<void> _onTrackLead(
    TrackProviderLeadEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    try {
      await discoveryRepository.trackLeadClick(
        providerId: event.providerId,
        isCall: event.isCall,
        customerId: event.customerId,
        categoryId: event.categoryId,
      );
    } catch (_) {}
  }

  Future<void> _onTrackView(
    TrackProviderViewEvent event,
    Emitter<DiscoveryState> emit,
  ) async {
    try {
      await discoveryRepository.trackProfileView(
        providerId: event.providerId,
        customerId: event.customerId,
      );
    } catch (_) {}
  }
}
