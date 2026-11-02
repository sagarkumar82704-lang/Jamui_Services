import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/jamui_geo_validator.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/bloc/discovery_state.dart';
import '../../data/datasources/professional_shop_remote_data_source.dart';
import '../../domain/entities/professional_category_entity.dart';
import '../../domain/entities/professional_shop_entity.dart';
import '../widgets/professional_shop_card.dart';
import '../widgets/professional_shop_skeleton.dart';

class ProfessionalShopsListingPage extends StatefulWidget {
  final ProfessionalCategoryEntity? category;
  final String? categoryId;
  final String? categoryName;
  final ProfessionalShopRemoteDataSource? dataSource;
  final double? customerLat;
  final double? customerLng;
  final String? customerArea;

  const ProfessionalShopsListingPage({
    super.key,
    this.category,
    this.categoryId,
    this.categoryName,
    this.dataSource,
    this.customerLat,
    this.customerLng,
    this.customerArea,
  });

  @override
  State<ProfessionalShopsListingPage> createState() => _ProfessionalShopsListingPageState();
}

class _ProfessionalShopsListingPageState extends State<ProfessionalShopsListingPage> {
  late final ProfessionalShopRemoteDataSource _dataSource =
      widget.dataSource ?? ProfessionalShopRemoteDataSource();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // State Management
  List<ProfessionalShopEntity> _allLoadedShops = [];
  DocumentSnapshot? _lastVisibleDoc;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Filter Tabs: 'All', 'Delivery', 'Pickup', 'Open Now'
  String _activeFilter = 'All';

  // Search State & Debounce
  Timer? _searchDebounceTimer;
  int _searchGenerationToken = 0;
  String _activeSearchQuery = '';
  List<ProfessionalShopEntity> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;
  bool _searchHasMore = false;
  int _searchTotalScanned = 0;

  // Location Cache
  double? _customerLat;
  double? _customerLng;
  String? _customerArea;
  bool _hasGps = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractLocationAndFetchInitial();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _extractLocationAndFetchInitial() {
    if (widget.customerLat != null && widget.customerLng != null) {
      _customerLat = widget.customerLat;
      _customerLng = widget.customerLng;
      _customerArea = widget.customerArea;
      _hasGps = JamuiGeoValidator.isValidCoordinates(_customerLat, _customerLng);
    } else {
      try {
        final state = context.read<DiscoveryBloc>().state;
        if (state is DiscoveryLoaded) {
          _customerLat = state.customerLatitude;
          _customerLng = state.customerLongitude;
          _customerArea = state.customerAreaName;
          _hasGps = _customerLat != null &&
              _customerLng != null &&
              JamuiGeoValidator.isValidCoordinates(_customerLat, _customerLng);
        }
      } catch (_) {}
    }

    _fetchInitialShops();
  }

  String get _activeCategoryId => widget.categoryId ?? widget.category?.id ?? '';
  String get _activeCategoryName =>
      widget.categoryName ?? widget.category?.displayName ?? 'Professional Marketplace';

  Future<void> _fetchInitialShops({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _dataSource.fetchPaginatedShops(
        categoryId: _activeCategoryId,
        customerLat: _customerLat,
        customerLng: _customerLng,
        areaId: _customerArea,
        lastDoc: null,
        chunkSize: 100,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _allLoadedShops = result.shops;
          _lastVisibleDoc = result.lastDoc;
          _hasMore = result.hasMore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load shops. Please tap retry.';
        });
      }
    }
  }

  void _onScroll() {
    if (_isSearching) return; // Search pagination is explicit or on-demand
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchNextPage() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    // Viewport Anchoring: Capture top-visible shop before merge and re-sort
    final currentShops = _displayedShops;
    String? anchorShopId;
    double anchorRelativeOffset = 0.0;

    if (currentShops.isNotEmpty && _scrollController.hasClients) {
      final approxIndex = (_scrollController.offset / 120).floor().clamp(0, currentShops.length - 1);
      anchorShopId = currentShops[approxIndex].id;
      anchorRelativeOffset = _scrollController.offset - (approxIndex * 120.0);
    }

    try {
      final result = await _dataSource.fetchPaginatedShops(
        categoryId: _activeCategoryId,
        customerLat: _customerLat,
        customerLng: _customerLng,
        areaId: _customerArea,
        lastDoc: _lastVisibleDoc,
        chunkSize: 100,
      );

      if (mounted) {
        setState(() {
          // Deduplicate incoming items against existing pool
          _allLoadedShops = ProfessionalShopRemoteDataSource.deduplicateShops(
            _allLoadedShops,
            result.shops,
          );
          _lastVisibleDoc = result.lastDoc;
          _hasMore = result.hasMore;
          _isLoadingMore = false;
        });

        // Viewport Anchoring: Restore scroll position smoothly
        if (anchorShopId != null && _scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final newShops = _displayedShops;
            final newIndex = newShops.indexWhere((s) => s.id == anchorShopId);
            if (newIndex >= 0 && _scrollController.hasClients) {
              final targetOffset = (newIndex * 120.0 + anchorRelativeOffset).clamp(
                0.0,
                _scrollController.position.maxScrollExtent,
              );
              _scrollController.jumpTo(targetOffset);
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  // 350ms Search Debounce & Stale Request Cancellation
  void _onSearchQueryChanged(String query) {
    _searchDebounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _activeSearchQuery = '';
        _isSearching = false;
        _searchResults = [];
        _searchHasMore = false;
        _searchTotalScanned = 0;
      });
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    final currentToken = ++_searchGenerationToken;

    setState(() {
      _activeSearchQuery = query;
      _isSearching = true;
      _isSearchLoading = true;
    });

    try {
      final result = await _dataSource.searchShopsWithCeiling(
        queryText: query,
        categoryId: _activeCategoryId,
        customerLat: _customerLat,
        customerLng: _customerLng,
        areaId: _customerArea,
        maxReadCeiling: 300,
        generationToken: currentToken,
      );

      // Discard stale response if a newer query was typed
      if (currentToken != _searchGenerationToken || !mounted) return;

      setState(() {
        _searchResults = result.shops;
        _searchHasMore = result.hasMore;
        _searchTotalScanned = result.totalLoaded;
        _isSearchLoading = false;
      });
    } catch (_) {
      if (currentToken == _searchGenerationToken && mounted) {
        setState(() => _isSearchLoading = false);
      }
    }
  }

  // Active shops passed through pure tab filter rules
  List<ProfessionalShopEntity> get _displayedShops {
    final sourceList = _isSearching ? _searchResults : _allLoadedShops;

    return ProfessionalShopRemoteDataSource.filterShopsByTab(
      shops: sourceList,
      activeTab: _activeFilter,
      hasGps: _hasGps,
      selectedAreaId: _customerArea,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          _activeCategoryName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Non-blocking Location Permission Banner
          if (!_hasGps) _buildLocationWarningBanner(),

          // Search Bar with Clear Button
          _buildSearchBar(),

          // Quick Filter Tabs (All, Delivery, Store Pickup, Open Now)
          _buildFilterTabsRow(),

          // Main Listing Content
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                _dataSource.cacheManager.forceEvict(_activeCategoryId);
                await _fetchInitialShops(forceRefresh: true);
              },
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFEF3C7),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Location permission is disabled. Showing Store Pickup options. Enable GPS for Home Delivery.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () => _extractLocationAndFetchInitial(),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
            child: const Text('RETRY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchQueryChanged,
                decoration: const InputDecoration(
                  hintText: 'Search shops in Jamui...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _onSearchQueryChanged('');
                },
                child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabsRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabChip('All'),
            const SizedBox(width: 8),
            _buildTabChip('Delivery'),
            const SizedBox(width: 8),
            _buildTabChip('Pickup'),
            const SizedBox(width: 8),
            _buildTabChip('Open Now'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String label) {
    final isSelected = _activeFilter.toLowerCase() == label.toLowerCase();
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading || _isSearchLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 5,
        itemBuilder: (context, index) => const ProfessionalShopSkeleton(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final shops = _displayedShops;
    if (shops.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: shops.length + (_isSearching && _searchTotalScanned >= 300 && _searchHasMore ? 1 : 0) + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Honest Search Ceiling Banner at bottom of search results
        if (_isSearching && _searchTotalScanned >= 300 && _searchHasMore && index == shops.length) {
          return _buildSearchCeilingBanner();
        }

        // Loading more pagination indicator
        if (index >= shops.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
              ),
            ),
          );
        }

        return ProfessionalShopCard(
          key: ValueKey(shops[index].id),
          shop: shops[index],
        );
      },
    );
  }

  Widget _buildSearchCeilingBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Text(
            'Showing search results from the first 300 loaded vendors.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () {
              // On-demand search deeper
              _executeSearch(_activeSearchQuery);
            },
            icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
            label: const Text(
              'Search the next 100 vendors',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: constraints.maxHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _isSearching ? 'No vendors matched your search' : 'No verified shops found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 6),
              Text(
                _isSearching
                    ? 'Try searching with a different term or keyword.'
                    : 'There are no active professional shops matching the selected filter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
              if (_activeFilter != 'All' || _searchController.text.isNotEmpty)
                ElevatedButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _activeFilter = 'All';
                      _isSearching = false;
                      _activeSearchQuery = '';
                      _searchResults = [];
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reset Filters', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Something went wrong',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _fetchInitialShops(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
