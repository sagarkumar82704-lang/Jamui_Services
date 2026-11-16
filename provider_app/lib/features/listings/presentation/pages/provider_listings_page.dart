import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/r2_upload_service.dart';
import '../../../../core/utils/app_image_utils.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';
import '../../data/models/provider_listing_model.dart';
import '../widgets/listing_quota_summary_card.dart';
import 'add_edit_listing_page.dart';

class ProviderListingsPage extends StatefulWidget {
  final ProviderProfileEntity profile;

  const ProviderListingsPage({super.key, required this.profile});

  @override
  State<ProviderListingsPage> createState() => _ProviderListingsPageState();
}

class _ProviderListingsPageState extends State<ProviderListingsPage> {
  final R2UploadService _r2Service = R2UploadService();
  String _selectedFilter = 'all'; // 'all' | 'service' | 'product' | 'job'

  Future<void> _toggleListingStatus(ProviderListingModel listing, bool newActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('provider_listings')
          .doc(listing.id)
          .update({'isActive': newActive, 'updatedAt': FieldValue.serverTimestamp()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newActive ? '✓ लिस्टिंग सक्रिय कर दी गई।' : '✓ लिस्टिंग अस्थायी रूप से रोक दी गई।'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('स्थिति बदलने में विफल: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteListing(ProviderListingModel listing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('लिस्टिंग हटाएं?'),
          ],
        ),
        content: Text(
          'क्या आप "${listing.title}" और इसकी सभी ${listing.images.length} फ़ोटो को हमेशा के लिए हटाना चाहते हैं?\n\nयह आपका स्टोरेज स्पेस और लिस्टिंग कोटा तुरंत मुक्त कर देगा।',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('हटाएं (Delete)'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Delete associated R2 storage objects to decrement quota safely
      for (final key in listing.storageKeys.isNotEmpty ? listing.storageKeys : listing.images) {
        try {
          await _r2Service.deleteStorageObject(
            objectKey: key,
            folder: 'listings',
            listingId: listing.id,
          );
        } catch (storageErr) {
          debugPrint('Notice deleting listing object $key: $storageErr');
        }
      }

      // 2. Delete Firestore listing document
      await FirebaseFirestore.instance.collection('provider_listings').doc(listing.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ लिस्टिंग और संबद्ध फ़ोटोज़ सफलतापूर्वक हटा दिए गए।'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('डिलीशन विफल: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showRejectionReason(ProviderListingModel listing) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('अस्वीकृति का कारण'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listing.rejectionReason?.isNotEmpty == true
                  ? listing.rejectionReason!
                  : 'एडमिन द्वारा लिस्टिंग सामग्री अपूर्ण या दिशानिर्देशों के विपरीत पाई गई।',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'सुझाव: लिस्टिंग को संपादित करें और सही जानकारी के साथ पुनः सबमिट करें।',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('समझ गया')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('मेरी लिस्टिंग्स व मीडिया'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('providers').doc(widget.profile.id).snapshots(),
        builder: (context, providerSnap) {
          final pData = (providerSnap.data?.data() as Map<String, dynamic>?) ?? {};

          final rawLimits = pData['planLimits'] as Map<String, dynamic>?;
          final planLimits = rawLimits ?? {
            'maxActiveListings': 1,
            'maxImagesPerProvider': 3,
            'maxImagesPerListing': 2,
            'maxSizePerImageBytes': 2 * 1024 * 1024,
            'maxTotalStorageBytes': 6 * 1024 * 1024,
          };

          final rawUsage = pData['storageUsage'] as Map<String, dynamic>?;
          final storageUsage = rawUsage ?? {
            'totalBytesUsed': 0,
            'totalImagesCount': 0,
          };


          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('provider_listings')
                .where('providerId', isEqualTo: widget.profile.id)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, listingsSnap) {
              if (listingsSnap.connectionState == ConnectionState.waiting && !listingsSnap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final docs = listingsSnap.data?.docs ?? [];
              final allListings = docs.map((d) => ProviderListingModel.fromFirestore(d)).toList();

              final activeCount = allListings.where((l) => l.isActive && l.status == 'approved').length;

              final filteredListings = _selectedFilter == 'all'
                  ? allListings
                  : allListings.where((l) => l.listingType == _selectedFilter).toList();

              return SingleChildScrollView(
                child: ResponsiveContentContainer(
                  padding: ResponsiveLayout.pagePadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Real-time Quota Summary Card
                      ListingQuotaSummaryCard(
                        planLimits: planLimits,
                        storageUsage: storageUsage,
                        activeListingsCount: activeCount,
                        onUpgradePressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubscriptionPage(profile: widget.profile),
                            ),
                          );
                        },
                      ),

                      // Filter Chips (All, Services, Products, Jobs)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'सभी (${allListings.length})'),
                            const SizedBox(width: 8),
                            _buildFilterChip('service', 'सर्विसेज (${allListings.where((l) => l.listingType == 'service').length})'),
                            const SizedBox(width: 8),
                            _buildFilterChip('product', 'उत्पाद (${allListings.where((l) => l.listingType == 'product').length})'),
                            const SizedBox(width: 8),
                            _buildFilterChip('job', 'जॉब्स (${allListings.where((l) => l.listingType == 'job').length})'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Listings List or Empty State
                      if (filteredListings.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'कोई लिस्टिंग नहीं मिली',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedFilter == 'all'
                                    ? 'ग्राहकों को अपनी सेवाएं, उत्पाद या जॉब ऑफर दिखाने के लिए नीचे "नया लिस्टिंग जोड़ें" पर टैप करें।'
                                    : 'इस श्रेणी में वर्तमान में कोई लिस्टिंग मौजूद नहीं है।',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      else
                        ResponsiveCardGrid(
                          tabletColumns: 2,
                          desktopColumns: 2,
                          largeDesktopColumns: 3,
                          spacing: 14,
                          runSpacing: 12,
                          children: filteredListings.map((listing) {
                            return _buildListingCard(
                              listing: listing,
                              planLimits: planLimits,
                              storageUsage: storageUsage,
                              activeCount: activeCount,
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 72),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('नया लिस्टिंग जोड़ें', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _handleAddNewListing,
      ),
    );
  }

  Future<void> _handleAddNewListing() async {
    // 1. Check provider active subscription status
    if (!widget.profile.hasPaidSubscription) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ लिस्टिंग जोड़ने हेतु सक्रिय सब्सक्रिप्शन आवश्यक है।'),
          backgroundColor: AppColors.warning,
        ),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionPage(profile: widget.profile)));
      return;
    }

    // 2. Fetch fresh snapshot of provider limits
    final pDoc = await FirebaseFirestore.instance.collection('providers').doc(widget.profile.id).get();
    if (!mounted) return;
    final pData = pDoc.data() ?? {};
    final limits = (pData['planLimits'] as Map<String, dynamic>?) ?? {
      'maxActiveListings': 1,
      'maxImagesPerProvider': 3,
      'maxImagesPerListing': 2,
      'maxSizePerImageBytes': 2 * 1024 * 1024,
      'maxTotalStorageBytes': 6 * 1024 * 1024,
    };
    final usage = (pData['storageUsage'] as Map<String, dynamic>?) ?? {};

    final maxActive = (limits['maxActiveListings'] as num?)?.toInt() ?? 1;

    // Count currently active approved listings
    final snap = await FirebaseFirestore.instance
        .collection('provider_listings')
        .where('providerId', isEqualTo: widget.profile.id)
        .where('isActive', isEqualTo: true)
        .get();

    if (!mounted) return;

    if (snap.docs.length >= maxActive) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.workspace_premium, color: AppColors.gold, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text('लिस्टिंग सीमा समाप्त (Limit Reached)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Text(
            'आपके वर्तमान प्लान में अधिकतम $maxActive एक्टिव लिस्टिंग्स की अनुमति है।\n\nनई लिस्टिंग जोड़ने के लिए पुरानी लिस्टिंग रोकें/हटाएं या अधिक लिस्टिंग्स हेतु उच्च प्लान अपग्रेड करें।',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ठीक है')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionPage(profile: widget.profile)));
              },
              child: const Text('प्लान अपग्रेड करें'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditListingPage(
          profile: widget.profile,
          planLimits: limits,
          storageUsage: usage,
          currentActiveListingsCount: snap.docs.length,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary),
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }

  Widget _buildListingCard({
    required ProviderListingModel listing,
    required Map<String, dynamic> planLimits,
    required Map<String, dynamic> storageUsage,
    required int activeCount,
  }) {
    Color statusBg;
    Color statusFg;
    String statusLabel;

    switch (listing.status) {
      case 'approved':
        statusBg = Colors.green.shade50;
        statusFg = Colors.green.shade800;
        statusLabel = 'स्वीकृत (Approved)';
        break;
      case 'rejected':
        statusBg = Colors.red.shade50;
        statusFg = Colors.red.shade800;
        statusLabel = 'अस्वीकृत (Rejected)';
        break;
      case 'pending_review':
      default:
        statusBg = Colors.amber.shade50;
        statusFg = Colors.amber.shade900;
        statusLabel = 'समीक्षाधीन (Under Review)';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: listing.images.isNotEmpty
                      ? AppImageUtils.buildImage(listing.images.first, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey.shade100,
                          child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 28),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Title, Category, Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            listing.listingType.toUpperCase(),
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusFg),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listing.categoryName,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${listing.price.toInt()}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (listing.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              listing.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
            ),
          ],

          const Divider(height: 16),

          // Bottom Action Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              // Active toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: listing.isActive,
                    activeThumbColor: AppColors.success,
                    onChanged: (val) => _toggleListingStatus(listing, val),
                  ),
                  Text(
                    listing.isActive ? 'सक्रिय (Live)' : 'रोकी गई (Paused)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: listing.isActive ? AppColors.success : Colors.grey,
                    ),
                  ),
                ],
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (listing.status == 'rejected') ...[
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.red, size: 20),
                      tooltip: 'अस्वीकृति का कारण देखें',
                      onPressed: () => _showRejectionReason(listing),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                    tooltip: 'संपादित करें',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditListingPage(
                            profile: widget.profile,
                            existingListing: listing,
                            planLimits: planLimits,
                            storageUsage: storageUsage,
                            currentActiveListingsCount: activeCount,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    tooltip: 'हटाएं (Purge from Storage)',
                    onPressed: () => _deleteListing(listing),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
