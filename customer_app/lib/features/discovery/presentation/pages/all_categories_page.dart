import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/category_image_widget.dart';
import '../../domain/entities/service_category_entity.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_event.dart';
import '../bloc/discovery_state.dart';
import 'category_providers_page.dart';
import 'premium_category_providers_page.dart';

/// Alias for semantic clarity
typedef CustomerServicesScreen = AllCategoriesPage;

class AllCategoriesPage extends StatefulWidget {
  final bool isEmbedded;
  final String? initialCategoryId;

  const AllCategoriesPage({
    super.key,
    this.isEmbedded = false,
    this.initialCategoryId,
  });

  @override
  State<AllCategoriesPage> createState() => _AllCategoriesPageState();
}

class _AllCategoriesPageState extends State<AllCategoriesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<Color> _pastelBgColors = [
    Color(0xFFE0F2FE), // Blue
    Color(0xFFFEF3C7), // Amber
    Color(0xFFE8F5E9), // Green
    Color(0xFFFCE4EC), // Pink
    Color(0xFFF3E8FF), // Purple
    Color(0xFFFFF7ED), // Orange
    Color(0xFFE0F7FA), // Cyan
    Color(0xFFEDE7F6), // Deep purple
  ];

  static const List<Color> _pastelIconColors = [
    Color(0xFF0284C7),
    Color(0xFFD97706),
    Color(0xFF16A34A),
    Color(0xFFDB2777),
    Color(0xFF9333EA),
    Color(0xFFEA580C),
    Color(0xFF0891B2),
    Color(0xFF7C3AED),
  ];

  // ignore: unused_element
  IconData _getCategoryIcon(String iconName) {
    switch (iconName.toLowerCase().trim()) {
      case 'ac_unit':
      case 'ac':
      case 'hvac':
        return Icons.ac_unit_rounded;
      case 'cleaning_services':
      case 'cleaning':
      case 'clean':
        return Icons.cleaning_services_rounded;
      case 'format_paint':
      case 'paint':
      case 'painting':
        return Icons.format_paint_rounded;
      case 'bolt':
      case 'electric':
      case 'electrician':
        return Icons.bolt_rounded;
      case 'plumbing':
      case 'plumber':
      case 'water_drop':
        return Icons.plumbing_rounded;
      case 'handyman':
      case 'build':
      case 'repair':
      case 'home_repair_service':
        return Icons.home_repair_service_rounded;
      case 'pest_control':
      case 'pest':
        return Icons.pest_control_rounded;
      case 'carpenter':
      case 'carpentry':
        return Icons.carpenter_rounded;
      case 'two_wheeler':
      case 'bike':
      case 'motorcycle':
        return Icons.two_wheeler_rounded;
      case 'local_laundry_service':
      case 'laundry':
        return Icons.local_laundry_service_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ServiceCategoryEntity> _filterCategories(List<ServiceCategoryEntity> allCategories) {
    // Only real active categories from database
    final activeCategories = allCategories.where((c) => c.isActive).toList();

    // Preserve priority order from database
    activeCategories.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));

    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return activeCategories;
    }

    // Flexible, case-insensitive partial match across English, Hindi & subservices
    return activeCategories.where((cat) {
      final titleEn = cat.titleEnglish.toLowerCase();
      final titleHi = cat.titleHindi.toLowerCase();
      final shortDesc = cat.shortDescription.toLowerCase();
      final fullDesc = cat.fullDescription.toLowerCase();
      final subServices = cat.subServices.map((s) => s.toLowerCase()).join(' ');

      return titleEn.contains(query) ||
          titleHi.contains(query) ||
          shortDesc.contains(query) ||
          fullDesc.contains(query) ||
          subServices.contains(query);
    }).toList();
  }

  void _onCategoryTapped(ServiceCategoryEntity category) {
    if (category.isPremiumCategory) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumCategoryProvidersPage(
            premiumCategory: {
              'categoryId': category.id,
              'categoryName': category.titleEnglish.isNotEmpty ? category.titleEnglish : category.titleHindi,
              'customTitle': category.titleHindi.isNotEmpty ? category.titleHindi : category.titleEnglish,
              'imageUrl': category.imageUrl,
            },
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DiscoveryBloc>(),
          child: CategoryProvidersPage(category: category),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: !widget.isEmbedded,
        leading: !widget.isEmbedded
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.creamWhite),
                tooltip: 'वापस (Back)',
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.miscellaneous_services_rounded, color: AppColors.accent, size: 20),
                SizedBox(width: 8),
                Text(
                  'सभी सेवाएं (Services)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppColors.creamWhite,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              'जमुई के प्रमाणित लोकल कारीगर व सेवाएं',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.creamWhite,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: BlocBuilder<DiscoveryBloc, DiscoveryState>(
        builder: (context, state) {
          if (state is DiscoveryLoading) {
            return _buildLoadingSkeleton();
          }

          if (state is DiscoveryError) {
            return _buildErrorState(state.message);
          }

          final allCategories = state is DiscoveryLoaded ? state.categories : <ServiceCategoryEntity>[];

          if (allCategories.isEmpty) {
            return _buildNoCategoriesState();
          }

          final displayCategories = _filterCategories(allCategories);

          return RefreshIndicator(
            onRefresh: () async {
              context.read<DiscoveryBloc>().add(const LoadDiscoveryDataEvent());
            },
            color: AppColors.accent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Search Bar for Service Categories
                  _buildCategorySearchBar(),

                  const SizedBox(height: 16),

                  // 2. Section Header with Live Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'खोज परिणाम (${displayCategories.length})'
                            : 'उपलब्ध सेवा श्रेणियां (${displayCategories.length})',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Text(
                            'रीसेट करें',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 3. Category Grid or Empty Search State
                  if (displayCategories.isEmpty)
                    _buildNoSearchResultsState()
                  else
                    _buildCategoryGrid(displayCategories),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Prominent Category Search Bar
  Widget _buildCategorySearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          setState(() {
            _searchQuery = v.trim().toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'सर्विस या श्रेणी खोजें (उदा. AC, प्लंबर, इलेक्ट्रीशियन...)',
          hintStyle: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                  tooltip: 'सर्च हटाएं',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  /// Clean & Professional Category Grid Layout
  Widget _buildCategoryGrid(List<ServiceCategoryEntity> categories) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 600 ? 3 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.10,
      ),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final bgColor = _pastelBgColors[index % _pastelBgColors.length];
        final iconColor = _pastelIconColors[index % _pastelIconColors.length];
        final titleHi = cat.titleHindi.isNotEmpty ? cat.titleHindi : cat.titleEnglish;
        final titleEn = cat.titleEnglish.isNotEmpty ? cat.titleEnglish : cat.titleHindi;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onCategoryTapped(cat),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CategoryImageWidget(
                        imageUrl: cat.imageUrl,
                        categoryTitle: cat.titleEnglish.isNotEmpty ? cat.titleEnglish : cat.titleHindi,
                        iconName: cat.iconName,
                        size: 58,
                        imageSize: 46,
                        backgroundColor: bgColor,
                        iconColor: iconColor,
                        borderRadius: BorderRadius.circular(14),
                        fit: BoxFit.contain,
                      ),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleHi,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        titleEn,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// No Search Results View
  Widget _buildNoSearchResultsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            '‘$_searchQuery’ के लिए कोई श्रेणी नहीं मिली',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'कृपया स्पेलिंग जांचें या नीचे दिए बटन पर टैप करके सभी सेवाएं देखें।',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('सभी सेवाएं देखें'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty State when no categories exist in backend
  Widget _buildNoCategoriesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'कोई सेवा श्रेणी उपलब्ध नहीं है',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'प्रशासक द्वारा नई सेवा श्रेणियां जल्द ही जोड़ी जाएंगी।',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                context.read<DiscoveryBloc>().add(const LoadDiscoveryDataEvent());
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('रिफ्रेश करें (Refresh)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Loading Skeleton Grid
  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.18,
              ),
              itemBuilder: (context, index) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 50,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Error State with Retry
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'सेवाएं लोड करने में समस्या हुई',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                context.read<DiscoveryBloc>().add(const LoadDiscoveryDataEvent());
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('पुनः प्रयास करें (Retry)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
