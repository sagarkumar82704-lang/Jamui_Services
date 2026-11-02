import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../data/models/service_provider_model.dart';
import '../../domain/entities/service_provider_entity.dart';
import 'provider_details_page.dart';

class PremiumCategoryProvidersPage extends StatefulWidget {
  final Map<String, dynamic> premiumCategory;

  const PremiumCategoryProvidersPage({
    super.key,
    required this.premiumCategory,
  });

  @override
  State<PremiumCategoryProvidersPage> createState() => _PremiumCategoryProvidersPageState();
}

class _PremiumCategoryProvidersPageState extends State<PremiumCategoryProvidersPage> {
  String _selectedGenderFilter = 'All';
  final Set<String> _bookmarkedProviderIds = {};
  late Stream<QuerySnapshot> _providersStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    // Single authoritative server-side filter: Only providers with an active subscription.
    // Cached as a persistent stream to prevent repeated queries and unnecessary Firestore reads on widget rebuilds.
    // Client-side isApprovedAndLive safely evaluates isActive (treating missing legacy field as true,
    // while strictly respecting isActive: false), preventing silent dropping of valid provider records.
    _providersStream = FirebaseFirestore.instance
        .collection('providers')
        .where('isSubscriptionActive', isEqualTo: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.premiumCategory['customTitle']?.toString() ??
        widget.premiumCategory['title']?.toString() ??
        widget.premiumCategory['categoryName']?.toString() ??
        'Premium Category';
    final categoryId = widget.premiumCategory['categoryId']?.toString() ?? '';
    final isUnisex = categoryId.toLowerCase().trim() == 'unisex_salon' ||
        categoryId.toLowerCase().trim() == 'salon' ||
        title.toLowerCase().contains('unisex') ||
        title.contains('यूनिसेक्स');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        title: isUnisex
            ? Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF43F5E), width: 1.2),
                    ),
                    child: const Icon(Icons.content_cut_rounded, color: Color(0xFFF43F5E), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text(
                        'Premium Salon Services',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: AppColors.gold, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '⭐ वेरिफाइड व प्रीमियम सर्विस पार्टनर',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => setState(() => _initStream()),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _providersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'डेटा लोड करने में समस्या आई',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'कृपया पुनः प्रयास करें',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('पुनः लोड करें'),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final allProviders = docs.map((d) {
            return ServiceProviderModel.fromMap(d.data() as Map<String, dynamic>, d.id);
          }).toList();

          // Strict filter: matches categoryId or selectedCategoryIds or isUnisexSalon, and meets isPremiumApprovedAndLive
          final eligibleProviders = allProviders.where((p) {
            if (!p.isPremiumApprovedAndLive) return false;

            if (categoryId.isNotEmpty) {
              final matchPrimary = p.categoryId.toLowerCase().trim() == categoryId.toLowerCase().trim();
              final matchSelected = p.selectedCategoryIds
                  .map((s) => s.toLowerCase().trim())
                  .contains(categoryId.toLowerCase().trim());
              final matchUnisex = isUnisex && p.isUnisexSalon;
              return matchPrimary || matchSelected || matchUnisex;
            }
            return true;
          }).toList();

          // Subcategory / Gender Filter for Salon
          final filteredProviders = eligibleProviders.where((p) {
            if (_selectedGenderFilter == 'All') return true;
            final filterLower = _selectedGenderFilter.toLowerCase();
            final desc = p.businessDescription.toLowerCase();
            final services = p.subServices.map((s) => s.toLowerCase()).join(' ');
            final pricing = p.servicesWithPricing.map((m) => m['name']?.toString().toLowerCase() ?? '').join(' ');
            final combined = '$desc $services $pricing';

            if (filterLower == 'men') {
              return combined.contains('men') || combined.contains('male') || combined.contains('beard') || combined.contains('पुरुष') || combined.contains('दाढ़ी');
            } else if (filterLower == 'women') {
              return combined.contains('women') || combined.contains('female') || combined.contains('bridal') || combined.contains('महिला') || combined.contains('makeup');
            } else if (filterLower == 'unisex') {
              return p.isUnisexSalon || combined.contains('unisex') || (combined.contains('men') && combined.contains('women'));
            }
            return true;
          }).toList();

          return CustomScrollView(
            slivers: [
              // Salon Gender Filter Chips Row (Reference Image Column 3)
              if (isUnisex)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Row(
                      children: ['All', 'Men', 'Women', 'Unisex'].map((chip) {
                        final isSelected = _selectedGenderFilter == chip;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(chip),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedGenderFilter = chip);
                              }
                            },
                            selectedColor: isSelected ? const Color(0xFF0F172A) : null,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // Providers List or Empty State
              if (filteredProviders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isUnisex ? Icons.content_cut_rounded : Icons.workspace_premium_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isUnisex ? 'इस फ़िल्टर में कोई सैलून उपलब्ध नहीं है' : 'कोई सक्रिय प्रीमियम प्रोवाइडर उपलब्ध नहीं है',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isUnisex
                                ? 'वर्तमान में Jamui में इस श्रेणी के लिए कोई स्वीकृत प्रीमियम सैलून उपलब्ध नहीं है। कृपया "All" फ़िल्टर देखें।'
                                : 'इस श्रेणी में वर्तमान में कोई स्वीकृत व सक्रिय प्रीमियम प्रोवाइडर नहीं है। कृपया सामान्य श्रेणी में देखें या बाद में प्रयास करें।',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final provider = filteredProviders[index];
                        return _buildPremiumProviderCard(context, provider);
                      },
                      childCount: filteredProviders.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPremiumProviderCard(BuildContext context, ServiceProviderEntity provider) {
    final isBookmarked = _bookmarkedProviderIds.contains(provider.id);
    final salonImage = provider.businessImageUrl.isNotEmpty
        ? provider.businessImageUrl
        : (provider.galleryImages.isNotEmpty ? provider.galleryImages.first : provider.profileImageUrl);

    final distanceStr = provider.distanceKm != null
        ? '${provider.distanceKm!.toStringAsFixed(1)} km'
        : '';

    final localityStr = provider.jamuiArea.isNotEmpty
        ? provider.jamuiArea
        : (provider.fullAddress.isNotEmpty ? provider.fullAddress : 'Jamui');

    final workingHoursStr = provider.workingHours.isNotEmpty
        ? provider.workingHours
        : (provider.isAvailable ? 'Open • उपलब्ध है' : 'Closed • ऑफलाइन');

    final hasRatings = provider.ratingCount > 0 || provider.rating > 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProviderDetailsPage(provider: provider),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Salon Photo Thumbnail (Reference Image Column 3)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 82,
                    height: 82,
                    color: const Color(0xFFF1F5F9),
                    child: salonImage.isNotEmpty
                        ? AppNetworkOrBase64Image(
                            imageUrl: salonImage,
                            width: 82,
                            height: 82,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.content_cut_rounded,
                              color: Color(0xFFF43F5E),
                              size: 32,
                            ),
                          )
                        : const Icon(
                            Icons.content_cut_rounded,
                            color: Color(0xFFF43F5E),
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Salon Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Gold Premium Badge + Bookmark Icon
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.businessName.isNotEmpty ? provider.businessName : provider.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFB45309),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isBookmarked) {
                                  _bookmarkedProviderIds.remove(provider.id);
                                } else {
                                  _bookmarkedProviderIds.add(provider.id);
                                }
                              });
                            },
                            child: Icon(
                              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 20,
                              color: isBookmarked ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Rating & Distance (Strictly real data)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 3),
                          Text(
                            hasRatings ? provider.rating.toStringAsFixed(1) : 'नया',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (provider.ratingCount > 0)
                            Text(
                              ' (${provider.ratingCount})',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          if (distanceStr.isNotEmpty) ...[
                            const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            Text(
                              distanceStr,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Locality
                      Text(
                        localityStr,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Open Status
                      Row(
                        children: [
                          Text(
                            workingHoursStr,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: provider.isAvailable ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
