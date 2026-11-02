import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_state.dart';
import '../../../../core/services/provider_app_launcher_service.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../../../core/widgets/provider_avatar_widget.dart';
import '../../../../core/widgets/provider_category_badge.dart';
import '../../domain/entities/service_category_entity.dart';
import '../../domain/entities/service_provider_entity.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_state.dart';
import '../widgets/customer_category_details_sheet.dart';
import 'all_categories_page.dart';
import 'provider_details_page.dart';

class CategoryProvidersPage extends StatefulWidget {
  final ServiceCategoryEntity category;
  final String? initialJamuiArea;

  const CategoryProvidersPage({
    super.key,
    required this.category,
    this.initialJamuiArea,
  });

  @override
  State<CategoryProvidersPage> createState() => _CategoryProvidersPageState();
}

class _CategoryProvidersPageState extends State<CategoryProvidersPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ServiceProviderEntity> _allCategoryProviders = [];

  String _selectedSubService = 'all';
  late String _selectedArea;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedArea = widget.initialJamuiArea ?? 'सभी इलाके';
    _fetchCategoryProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Strictly fetch real providers for this category from backend
  Future<void> _fetchCategoryProviders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<DiscoveryBloc>().discoveryRepository;
      final blocState = context.read<DiscoveryBloc>().state;
      final locState = context.read<LocationBloc>().state;

      double? customerLat;
      double? customerLng;
      if (locState is LocationLoaded &&
          LocationService.isValidCoordinate(locState.location.latitude, locState.location.longitude)) {
        customerLat = locState.location.latitude;
        customerLng = locState.location.longitude;
      } else if (blocState is DiscoveryLoaded &&
          LocationService.isValidCoordinate(blocState.customerLatitude, blocState.customerLongitude)) {
        customerLat = blocState.customerLatitude;
        customerLng = blocState.customerLongitude;
      }

      final fetched = await repo.getProviders(
        categoryId: widget.category.id,
        customerLatitude: customerLat,
        customerLongitude: customerLng,
      );

      final targetCatId = widget.category.id.toLowerCase().trim();
      final catTitleEn = widget.category.titleEnglish.toLowerCase().trim();
      final catTitleHi = widget.category.titleHindi.toLowerCase().trim();

      // Strict approval and category filter
      List<ServiceProviderEntity> filtered = fetched.where((p) {
        if (!p.isApprovedAndLive) return false;

        // Strict isolation: Unisex Salon / Premium category providers must never be listed on Normal Category Page
        if (p.isUnisexSalon || p.categoryId.toLowerCase().trim() == 'unisex_salon') {
          return false;
        }

        final pCatId = p.categoryId.toLowerCase().trim();
        final pCatTitle = p.categoryTitle.toLowerCase().trim();
        final selected = p.selectedCategoryIds
            .map((s) => s.toLowerCase().trim())
            .toSet();

        return pCatId == targetCatId ||
            selected.contains(targetCatId) ||
            pCatTitle == targetCatId ||
            (catTitleEn.isNotEmpty && pCatTitle == catTitleEn) ||
            (catTitleHi.isNotEmpty && pCatTitle == catTitleHi);
      }).toList();

      // If specific category query returned empty, check only already-cached providers in DiscoveryBloc (0 network reads).
      // Never perform an unfiltered global fetch across other categories, preserving empty state and zero unnecessary reads.
      if (filtered.isEmpty &&
          mounted &&
          blocState is DiscoveryLoaded &&
          blocState.providers.isNotEmpty) {
        filtered = blocState.providers.where((p) {
          if (!p.isApprovedAndLive) return false;

          // Strict isolation: Unisex Salon / Premium category providers must never be listed on Normal Category Page
          if (p.isUnisexSalon || p.categoryId.toLowerCase().trim() == 'unisex_salon') {
            return false;
          }

          final pCatId = p.categoryId.toLowerCase().trim();
          final pCatTitle = p.categoryTitle.toLowerCase().trim();
          final selected = p.selectedCategoryIds
              .map((s) => s.toLowerCase().trim())
              .toSet();

          return pCatId == targetCatId ||
              selected.contains(targetCatId) ||
              pCatTitle == targetCatId ||
              (catTitleEn.isNotEmpty && pCatTitle == catTitleEn) ||
              (catTitleHi.isNotEmpty && pCatTitle == catTitleHi);
        }).toList();
      }

      // Maintain nearest-first order if distance is available
      if (filtered.any((p) => p.distanceKm != null)) {
        filtered.sort((a, b) {
          final distA = a.distanceKm ?? double.infinity;
          final distB = b.distanceKm ?? double.infinity;
          final cmp = distA.compareTo(distB);
          if (cmp != 0) return cmp;
          return b.rating.compareTo(a.rating);
        });
      }

      if (mounted) {
        setState(() {
          _allCategoryProviders = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Telephone launcher via native dialer
  Future<void> _handleCallProvider(
    BuildContext context,
    ServiceProviderEntity provider,
  ) async {
    final phone = provider.phoneNumber.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('फोन नंबर उपलब्ध नहीं है')));
      return;
    }
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('कॉल शुरू नहीं की जा सकी')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('कॉल त्रुटि: $e')));
      }
    }
  }

  List<ServiceProviderEntity> get _filteredProviders {
    final list = _allCategoryProviders.where((p) {
      // Sub-service filter
      if (_selectedSubService != 'all') {
        final matchesSub = p.subServices.any(
          (s) => s.toLowerCase().contains(_selectedSubService.toLowerCase()),
        );
        if (!matchesSub) return false;
      }

      // Area filter
      if (_selectedArea != 'सभी इलाके') {
        if (!p.jamuiArea.toLowerCase().contains(_selectedArea.toLowerCase())) {
          return false;
        }
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName =
            p.fullName.toLowerCase().contains(q) ||
            p.businessName.toLowerCase().contains(q) ||
            p.subServices.any((s) => s.toLowerCase().contains(q)) ||
            p.jamuiArea.toLowerCase().contains(q);
        if (!matchesName) return false;
      }

      return true;
    }).toList();

    // Preserve nearest-first order in filtered category view
    if (list.any((p) => p.distanceKm != null)) {
      list.sort((a, b) {
        final distA = a.distanceKm ?? double.infinity;
        final distB = b.distanceKm ?? double.infinity;
        final cmp = distA.compareTo(distB);
        if (cmp != 0) return cmp;
        return b.rating.compareTo(a.rating);
      });
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final categoryName = widget.category.titleHindi.isNotEmpty
        ? (widget.category.titleEnglish.isNotEmpty &&
                  widget.category.titleEnglish != widget.category.titleHindi
              ? '${widget.category.titleHindi} (${widget.category.titleEnglish})'
              : widget.category.titleHindi)
        : widget.category.titleEnglish;

    final dynamicAreas = [
      'सभी इलाके',
      ..._allCategoryProviders
          .map((p) => p.jamuiArea.trim())
          .where((a) => a.isNotEmpty)
          .toSet(),
    ];

    final displayList = _filteredProviders;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.creamWhite,
            size: 24,
          ),
          tooltip: 'वापस (Back)',
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'कारीगर का नाम या सेवा खोजें...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.creamWhite,
                  ),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                style: const TextStyle(color: AppColors.creamWhite),
                cursorColor: AppColors.accent,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    categoryName,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.creamWhite,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isLoading
                        ? 'लोड हो रहा है...'
                        : '${displayList.length} उपलब्ध कारीगर (Verified)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.creamWhite,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search_rounded,
              color: AppColors.creamWhite,
            ),
            tooltip: _isSearching ? 'सर्च बंद करें' : 'सर्च करें',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.creamWhite,
            ),
            tooltip: 'सर्विस जानकारी (Info)',
            onPressed: () {
              CustomerCategoryDetailsSheet.show(
                context,
                category: widget.category,
                onSelectCategory: () {},
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCategoryProviders,
        color: AppColors.accent,
        child: _isLoading
            ? _buildLoadingSkeleton()
            : _errorMessage != null
            ? _buildErrorView()
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Header Overview Card
                    _buildCategoryOverviewBanner(),

                    const SizedBox(height: 12),

                    // Dedicated In-Category Provider Name Search Field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'इस श्रेणी में कारीगर खोजें (उदा. राहुल, अमित)...',
                          hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Sub-services horizontal filter chips (if available)
                    if (widget.category.subServices.isNotEmpty) ...[
                      _buildSubServicesBar(),
                      const SizedBox(height: 10),
                    ],

                    // Area Filter Bar
                    if (dynamicAreas.length > 1) ...[
                      _buildAreaFilterChips(dynamicAreas),
                      const SizedBox(height: 14),
                    ],

                    // Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'सत्यापित कारीगर सूची (${displayList.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_selectedArea != 'सभी इलाके' ||
                            _selectedSubService != 'all' ||
                            _searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedArea = 'सभी इलाके';
                                _selectedSubService = 'all';
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                            child: const Text(
                              'फ़िल्टर रीसेट करें',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Provider Grid
                    if (displayList.isEmpty)
                      _buildEmptyState()
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayList.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.84,
                            ),
                        itemBuilder: (context, index) {
                          return _buildProviderCard(
                            context,
                            displayList[index],
                          );
                        },
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  /// Category Header Overview Banner
  Widget _buildCategoryOverviewBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: widget.category.imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppNetworkOrBase64Image(
                      imageUrl: widget.category.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.handyman_rounded,
                        color: Color(0xFFEA580C),
                        size: 28,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.handyman_rounded,
                    color: Color(0xFFEA580C),
                    size: 28,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.category.titleHindi.isNotEmpty
                      ? widget.category.titleHindi
                      : widget.category.titleEnglish,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                const Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'जमुई के जाँचे-परखे लोकल कारीगर • 0% कमीशन',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sub-services filter chips
  Widget _buildSubServicesBar() {
    final subServices = ['all', ...widget.category.subServices];
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: subServices.length,
        itemBuilder: (context, index) {
          final sub = subServices[index];
          final isSelected = _selectedSubService == sub;
          final label = sub == 'all' ? 'सभी प्रकार' : sub;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              selectedColor: AppColors.accent,
              backgroundColor: Colors.white,
              onSelected: (_) => setState(() => _selectedSubService = sub),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  /// Area filter chips
  Widget _buildAreaFilterChips(List<String> areas) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: areas.length,
        itemBuilder: (context, index) {
          final area = areas[index];
          final isSelected = _selectedArea == area;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              selected: isSelected,
              label: Text(area),
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              selectedColor: AppColors.accent,
              backgroundColor: Colors.white,
              onSelected: (_) => setState(() => _selectedArea = area),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  /// Exact Provider Card matching Reference Image:
  /// - Circular Avatar on left
  /// - Name (bold, 2 lines) & Category on right
  /// - Star rating row: ★ 4.8 (128)
  /// - Location row: 📍 Jamui, Bihar
  /// - Bottom row: ₹150 Starting on left, circular green phone call button on right
  Widget _buildProviderCard(
    BuildContext context,
    ServiceProviderEntity provider,
  ) {
    final displayName = provider.fullName.isNotEmpty
        ? provider.fullName
        : provider.businessName;
    final displayService = provider.categoryTitle.isNotEmpty
        ? provider.categoryTitle
        : widget.category.titleEnglish;
    final locationText = provider.jamuiArea.trim().isNotEmpty
        ? '${provider.jamuiArea.trim()}, Bihar'
        : 'Jamui, Bihar';

    // Formatted distance badge from precalculated provider distance
    String? distanceBadge;
    if (provider.distanceKm != null) {
      distanceBadge = provider.distanceKm! < 1.0
          ? '${(provider.distanceKm! * 1000).round()} m'
          : '${provider.distanceKm!.toStringAsFixed(1)} km';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<DiscoveryBloc>(),
              child: ProviderDetailsPage(provider: provider),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Circular Avatar (left) + Provider Name & Category (right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProviderAvatarWidget(
                  provider: provider,
                  size: 38,
                  isCircular: true,
                  showVerifiedBadge: false,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      ProviderCategoryBadge(
                        categoryTitle: displayService,
                        fontSize: 9.5,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Star rating + Rating score + (review count)
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: AppColors.accent,
                  size: 15,
                ),
                const SizedBox(width: 3),
                Text(
                  provider.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  provider.ratingCount > 0
                      ? '(${provider.ratingCount})'
                      : '(0)',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 3: Location pin icon + Jamui, Bihar + Approximate Distance Badge
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey.shade500, size: 13),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    locationText,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (distanceBadge != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 0.8),
                    ),
                    child: Text(
                      distanceBadge,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),

            // Row 4: Price on left + Green call button on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: provider.visitingCharge > 0
                              ? '₹${provider.visitingCharge.toInt()} '
                              : 'निःशुल्क ',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        TextSpan(
                          text: provider.visitingCharge > 0 ? 'Starting' : '',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleCallProvider(context, provider),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone,
                        color: Color(0xFF16A34A),
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Empty State matching user prompt: "इस सर्विस के लिए अभी कोई कारीगर उपलब्ध नहीं है।"
  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            isSearching ? Icons.person_search_rounded : Icons.search_off_rounded,
            size: 54,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          Text(
            isSearching
                ? '‘$_searchQuery’ नाम का कोई कारीगर इस श्रेणी में उपलब्ध नहीं है।'
                : 'इस सर्विस के लिए अभी कोई कारीगर उपलब्ध नहीं है।',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isSearching
                ? 'कृपया नाम की स्पेलिंग जांचें या सर्च हटाकर इस श्रेणी के सभी कारीगर देखें।'
                : 'जमुई में इस श्रेणी के जाँचे-परखे कारीगरों को जल्द ही जोड़ा जा रहा है। आप अन्य सेवाएं देख सकते हैं।',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (isSearching)
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('सर्च रीसेट करें (Show All)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            )
          else ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<DiscoveryBloc>(),
                      child: const AllCategoriesPage(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.category_rounded, size: 16),
              label: const Text('अन्य सेवाएं देखें (All Services)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                ProviderAppLauncherService.showJoinProviderModal(context),
            icon: const Icon(
              Icons.handyman_rounded,
              size: 16,
              color: Color(0xFF1E3A8A),
            ),
            label: Text(
              'क्या आप ${widget.category.titleEnglish} कारीगर हैं? यहाँ जुड़ें',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1E3A8A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// Loading skeleton shimmer
  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              itemBuilder: (_, _) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Network Error View with Retry option
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 14),
            const Text(
              'डेटा लोड करने में त्रुटि हुई',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ??
                  'कृपया अपना इंटरनेट कनेक्शन जांचें और पुनः प्रयास करें।',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _fetchCategoryProviders,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('पुनः प्रयास करें (Retry)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
