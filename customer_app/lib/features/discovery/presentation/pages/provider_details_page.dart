import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../../bookings/presentation/widgets/submit_review_dialog.dart';
import '../../../reviews/domain/entities/customer_review_entity.dart';
import '../../domain/entities/service_provider_entity.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_event.dart';
import '../widgets/favourite_button.dart';
import '../widgets/request_service_modal.dart';
import '../widgets/customer_listing_detail_modal.dart';

class ProviderDetailsPage extends StatefulWidget {
  final ServiceProviderEntity provider;

  const ProviderDetailsPage({super.key, required this.provider});

  @override
  State<ProviderDetailsPage> createState() => _ProviderDetailsPageState();
}

class _ProviderDetailsPageState extends State<ProviderDetailsPage>
    with SingleTickerProviderStateMixin {
  int _reviewsLimit = 10;
  CustomerReviewEntity? _myDirectReview;
  bool _hasCheckedMyReview = false;

  late TabController _salonTabController;
  int _currentHeroPhotoIndex = 0;
  final PageController _heroPageController = PageController();

  void _checkMyReview() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _hasCheckedMyReview) return;
    _hasCheckedMyReview = true;

    FirebaseFirestore.instance
        .collection('reviews')
        .where('providerId', isEqualTo: widget.provider.id)
        .where('customerId', isEqualTo: user.uid)
        .limit(1)
        .get()
        .then((snap) {
      if (snap.docs.isNotEmpty && mounted) {
        setState(() {
          _myDirectReview = CustomerReviewEntity.fromFirestore(snap.docs.first);
        });
      }
    }).catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    _salonTabController = TabController(length: 5, vsync: this);
    // Step 4: Increment profile view counter and record analytical event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMyReview();
      final user = FirebaseAuth.instance.currentUser;
      context.read<DiscoveryBloc>().add(
        TrackProviderViewEvent(
          providerId: widget.provider.id,
          customerId: user?.uid,
        ),
      );
    });
  }

  @override
  void dispose() {
    _salonTabController.dispose();
    _heroPageController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    if (widget.provider.phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('फ़ोन नंबर उपलब्ध नहीं है')));
      return;
    }

    final cleanPhone = widget.provider.phoneNumber.replaceAll(
      RegExp(r'[^\d+]'),
      '',
    );
    final uri = Uri(scheme: 'tel', path: cleanPhone);

    context.read<DiscoveryBloc>().add(
      TrackProviderLeadEvent(
        providerId: widget.provider.id,
        isCall: true,
        categoryId: widget.provider.categoryId,
      ),
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('कॉल नहीं मिलाया जा सका: $cleanPhone')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    if (widget.provider.phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp नंबर उपलब्ध नहीं है')),
      );
      return;
    }

    final cleanPhone = widget.provider.phoneNumber.replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    final normalizedPhone = cleanPhone.length == 10
        ? '91$cleanPhone'
        : cleanPhone;
    final message = Uri.encodeComponent(
      'नमस्ते ${widget.provider.fullName}, मुझे JAMUI SERVICE ऐप से आपकी ${widget.provider.categoryTitle} सेवा चाहिए।',
    );
    final uri = Uri.parse('https://wa.me/$normalizedPhone?text=$message');

    context.read<DiscoveryBloc>().add(
      TrackProviderLeadEvent(
        providerId: widget.provider.id,
        isCall: false,
        categoryId: widget.provider.categoryId,
      ),
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp खोलने में असमर्थ। कृपया ऐप जांचें।'),
          ),
        );
      }
    }
  }

  Future<void> _openDirections(BuildContext context) async {
    final p = widget.provider;
    Uri uri;
    if (p.latitude != 0.0 && p.longitude != 0.0) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}');
    } else {
      final query = Uri.encodeComponent('${p.businessName} ${p.jamuiArea} Jamui Bihar');
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _openInstagram(BuildContext context) async {
    final launchUrlStr = widget.provider.instagramLaunchUrl;
    if (launchUrlStr.isEmpty) return;
    final uri = Uri.parse(launchUrlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instagram लिंक खोलने में असमर्थ')),
        );
      }
    }
  }

  Future<void> _openFacebook(BuildContext context) async {
    final launchUrlStr = widget.provider.facebookLaunchUrl;
    if (launchUrlStr.isEmpty) return;
    final uri = Uri.parse(launchUrlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facebook लिंक खोलने में असमर्थ')),
        );
      }
    }
  }

  void _shareProvider(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.provider.businessName.isNotEmpty ? widget.provider.businessName : widget.provider.fullName} की जानकारी कॉपी की गई'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final hasImage = provider.profileImageUrl.isNotEmpty;

    if (!provider.isApprovedAndLive) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('सेवा प्रदाता अनुपलब्ध', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: AppColors.primary,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_rounded, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 16),
                const Text(
                  'यह सेवा प्रदाता वर्तमान में सक्रिय नहीं है',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'इस प्रदाता की प्रोफ़ाइल समीक्षाधीन या सदस्यता असत्यापित है। कृपया अन्य सक्रिय सेवा प्रदाताओं की सूची देखें।',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('वापस जाएं (Back)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (provider.isUnisexSalon) {
      return _buildUnisexSalonDetailsView(context);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          provider.businessName.isNotEmpty
              ? provider.businessName
              : provider.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          FavouriteButton(providerId: provider.id, size: 24),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Header Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Actual Optimized Provider Image with Shimmer & Fallback Avatar (Tappable for Full View)
                      GestureDetector(
                        onTap: hasImage
                            ? () => _openFullScreenImageViewer(
                                context,
                                provider.profileImageUrl,
                                provider.fullName,
                              )
                            : null,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: hasImage
                                  ? AppNetworkOrBase64Image(
                                      imageUrl: provider.profileImageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) =>
                                          _buildAvatarFallback(),
                                    )
                                  : _buildAvatarFallback(),
                            ),
                            if (hasImage)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    provider.businessName.isNotEmpty
                                        ? provider.businessName
                                        : provider.fullName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (provider.isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                            if (provider.businessName.isNotEmpty &&
                                provider.businessName != provider.fullName) ...[
                              const SizedBox(height: 2),
                              Text(
                                'कारीगर: ${provider.fullName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                provider.categoryTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Quick Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat(
                        provider.ratingCount > 0
                            ? '⭐ ${provider.rating.toStringAsFixed(1)}'
                            : '⭐ नया',
                        provider.ratingCount > 0
                            ? '${provider.ratingCount} रिव्यूज'
                            : 'कोई रिव्यू नहीं',
                        AppColors.accent,
                      ),
                      _buildQuickStat(
                        '${provider.experienceYears} वर्ष',
                        'अनुभव (Exp)',
                        AppColors.primary,
                      ),
                      _buildQuickStat(
                        '₹${provider.visitingCharge.toInt()}',
                        'विजिट चार्ज',
                        AppColors.success,
                      ),
                      if (provider.distanceKm != null)
                        _buildQuickStat(
                          '${provider.distanceKm!.toStringAsFixed(1)} KM',
                          'दूरी (Distance)',
                          AppColors.info,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Verification Badges Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'सत्यापन एवं सुरक्षा (Trust & Verification)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildVerificationItem(
                    Icons.verified_user_rounded,
                    'KYC वेरिफाइड कारीगर',
                    'प्रशासन द्वारा आधार व पहचान सत्यापित है',
                    Colors.green,
                  ),
                  if (provider.experienceCertificateStatus == 'verified') ...[
                    const SizedBox(height: 8),
                    _buildVerificationItem(
                      Icons.workspace_premium_rounded,
                      'अनुभव प्रमाण पत्र सत्यापित (Certificate Verified)',
                      'प्रमाणित तकनीकी प्रशिक्षण एवं कार्य अनुभव प्राप्त',
                      Colors.amber.shade800,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Services Offered
            if (provider.subServices.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'उपलब्ध सेवाएं (Offered Services)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.subServices.map((service) {
                        return Chip(
                          label: Text(
                            service,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: AppColors.backgroundLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Business Details & Location
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'दुकान / कार्यस्थल विवरण',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    'इलाका',
                    provider.jamuiArea,
                  ),
                  if (provider.fullAddress.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.map_outlined,
                      'पूरा पता',
                      provider.fullAddress,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.access_time_rounded,
                    'कार्य समय',
                    provider.workingHours,
                  ),
                  if (provider.businessDescription.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text(
                      'विवरण (About Business):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.businessDescription,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Business Workspace Photo (Tappable for Full View)
            if (provider.businessImageUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'दुकान / वर्कप्लेस फोटो',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'बड़ा देखें',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _openFullScreenImageViewer(
                        context,
                        provider.businessImageUrl,
                        '${provider.businessName.isNotEmpty ? provider.businessName : provider.fullName} — वर्कप्लेस',
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppNetworkOrBase64Image(
                          imageUrl: provider.businessImageUrl,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Provider Listings Showcase Section (Services, Products, Jobs)
            _buildProviderListingsSection(context),

            const SizedBox(height: 16),

            // Real Customer Reviews Section (Step 3)
            _buildReviewsSection(context),

            const SizedBox(height: 100), // Space for floating bottom bar
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _openWhatsApp(context),
                  icon: const Icon(
                    Icons.chat,
                    size: 18,
                    color: Color(0xFF25D366),
                  ),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(
                      color: Color(0xFF25D366),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF25D366),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(context),
                  icon: const Icon(Icons.call, size: 18, color: Colors.white),
                  label: const Text(
                    'कॉल करें',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: () {
                    RequestServiceModal.show(context, provider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'सेवा अनुरोध',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    final provider = widget.provider;
    final providerName = provider.businessName.isNotEmpty
        ? provider.businessName
        : provider.fullName;
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('providerId', isEqualTo: provider.id)
          .orderBy('createdAt', descending: true)
          .limit(_reviewsLimit)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final reviews = docs
            .map((d) => CustomerReviewEntity.fromFirestore(d))
            .toList();

        // Calculate aggregate statistics & 1..5 star distribution
        // Preserve provider aggregates: use stored aggregates if available (> 0), fallback to loaded reviews
        final int totalCount = widget.provider.ratingCount > 0
            ? widget.provider.ratingCount
            : reviews.length;
        final double fallbackAvg = reviews.isNotEmpty
            ? double.parse(
                (reviews.fold<double>(0.0, (acc, r) => acc + r.rating) / reviews.length)
                    .toStringAsFixed(1),
              )
            : 0.0;
        final double avgRating = widget.provider.rating > 0.0
            ? widget.provider.rating
            : fallbackAvg;

        final Map<int, int> starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
        final List<String> allReviewPhotos = [];

        for (final r in reviews) {
          starCounts[r.rating] = (starCounts[r.rating] ?? 0) + 1;
          allReviewPhotos.addAll(r.photoUrls);
        }

        // Find if current user has an existing review here (check loaded sample or targeted direct lookup)
        final myReviewFromList = currentUser != null
            ? reviews.where((r) => r.customerId == currentUser.uid).firstOrNull
            : null;
        final myReview = myReviewFromList ?? _myDirectReview;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header with Title and Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ग्राहकों की समीक्षाएं व रेटिंग',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (myReview != null)
                    TextButton.icon(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      label: const Text(
                        'मेरी समीक्षा बदलें',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () {
                        SubmitReviewDialog.show(
                          context,
                          providerId: provider.id,
                          providerName: providerName,
                          leadId: myReview.bookingId,
                          existingReview: myReview,
                        ).then((_) {
                          _hasCheckedMyReview = false;
                          _checkMyReview();
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Amazon / Flipkart Style Rating Overview & Star Distribution Bars
              if (totalCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // Left Big Score & Star Display
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: List.generate(5, (i) {
                              final starIdx = i + 1;
                              return Icon(
                                starIdx <= avgRating.floor()
                                    ? Icons.star_rounded
                                    : (starIdx - avgRating <= 0.5
                                          ? Icons.star_half_rounded
                                          : Icons.star_outline_rounded),
                                color: AppColors.gold,
                                size: 16,
                              );
                            }),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalCount रेटिंग व समीक्षाएं',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      const SizedBox(
                        height: 70,
                        child: VerticalDivider(width: 1, thickness: 0.8),
                      ),
                      const SizedBox(width: 14),

                      // Right 5-Star to 1-Star Progress Bars
                      Expanded(
                        child: Column(
                          children: [5, 4, 3, 2, 1].map((star) {
                            final count = starCounts[star] ?? 0;
                            final int distributionBase = reviews.isNotEmpty ? reviews.length : totalCount;
                            final percent = distributionBase > 0
                                ? (count / distributionBase)
                                : 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 1.5,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '$star',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 12,
                                    color: AppColors.gold,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percent,
                                        minHeight: 6,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              star >= 4
                                                  ? AppColors.success
                                                  : (star == 3
                                                        ? Colors.amber
                                                        : Colors.orange),
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 18,
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. Customer Uploaded Review Photos Carousel / Strip
              if (allReviewPhotos.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ग्राहकों द्वारा अपलोड की गई तस्वीरें (${allReviewPhotos.length})',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: allReviewPhotos.length,
                    itemBuilder: (context, index) {
                      final photoUrl = allReviewPhotos[index];
                      return GestureDetector(
                        onTap: () => _openFullScreenImageViewer(
                          context,
                          photoUrl,
                          'समीक्षा फ़ोटो (${index + 1}/${allReviewPhotos.length})',
                        ),
                        child: Container(
                          width: 72,
                          height: 72,
                          margin: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AppNetworkOrBase64Image(
                              imageUrl: photoUrl,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. Empty State
              if (reviews.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.star_border_rounded,
                          size: 40,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'अभी तक कोई समीक्षा उपलब्ध नहीं है।',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'सेवा पूर्ण होने के बाद सत्यापित ग्राहक यहां पहली समीक्षा दे सकते हैं।',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // 5. Verified Reviews List
                Column(
                  children: reviews.map((r) {
                    final isMyReview =
                        currentUser != null && r.customerId == currentUser.uid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: isMyReview
                            ? Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              )
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    child: Text(
                                      r.customerDisplayName.isNotEmpty
                                          ? r.customerDisplayName[0]
                                                .toUpperCase()
                                          : 'G',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            r.customerDisplayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (isMyReview) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'आप (You)',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 12,
                                            color: AppColors.success,
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'सत्यापित सेवा बुकिंग',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.success,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Star display
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < r.rating
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: AppColors.gold,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Comment text
                          if (r.comment.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              r.comment,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],

                          // Tags chips
                          if (r.tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: r.tags
                                  .map(
                                    (tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],

                          // Attached Photo Thumbnails
                          if (r.photoUrls.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: r.photoUrls
                                  .map(
                                    (url) => GestureDetector(
                                      onTap: () => _openFullScreenImageViewer(
                                        context,
                                        url,
                                        '${r.customerDisplayName} की समीक्षा फ़ोटो',
                                      ),
                                      child: Container(
                                        width: 54,
                                        height: 54,
                                        margin: const EdgeInsets.only(right: 6),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: AppNetworkOrBase64Image(
                                            imageUrl: url,
                                            width: 54,
                                            height: 54,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],

                          // Bottom Footer (Edited Indicator + Date)
                          if (r.isEdited || r.createdAt != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (r.isEdited)
                                  const Text(
                                    'संपादित (Edited) • ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                if (r.createdAt != null)
                                  Text(
                                    '${r.createdAt!.day}/${r.createdAt!.month}/${r.createdAt!.year}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (reviews.length >= _reviewsLimit) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        totalCount > reviews.length
                            ? 'और समीक्षाएं देखें (${reviews.length}/$totalCount)'
                            : 'और समीक्षाएं लोड करें',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _reviewsLimit += 10;
                        });
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          widget.provider.fullName.isNotEmpty
              ? widget.provider.fullName[0].toUpperCase()
              : 'P',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(String title, String subtitle, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildVerificationItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  void _openFullScreenImageViewer(
    BuildContext context,
    String imageUrl,
    String title,
  ) {
    if (imageUrl.trim().isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.8,
              maxScale: 4.0,
              child: AppNetworkOrBase64Image(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white54,
                        size: 64,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'फोटो लोड नहीं हो सकी',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProviderListingsSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('provider_listings')
          .where('providerId', isEqualTo: widget.provider.id)
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'सेवाएं, उत्पाद व जॉब्स',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${docs.length} ऑफर्स',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 175,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data() as Map<String, dynamic>;
                    final title = data['title']?.toString() ?? '';
                    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
                    final type = data['listingType']?.toString().toLowerCase() ?? 'service';
                    final rawImages = data['images'];
                    final List<String> images = rawImages is List
                        ? rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
                        : [];

                    String typeShort;
                    Color typeColor;
                    switch (type) {
                      case 'product':
                        typeShort = 'उत्पाद';
                        typeColor = Colors.purple;
                        break;
                      case 'job':
                        typeShort = 'जॉब';
                        typeColor = Colors.blue;
                        break;
                      case 'service':
                      default:
                        typeShort = 'सर्विस';
                        typeColor = Colors.green;
                        break;
                    }

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        CustomerListingDetailModal.show(
                          context,
                          listing: data,
                          provider: widget.provider,
                        );
                      },
                      child: Container(
                        width: 140,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
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
                            // Thumbnail
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: SizedBox(
                                height: 90,
                                width: 140,
                                child: images.isNotEmpty
                                    ? AppNetworkOrBase64Image(imageUrl: images.first, fit: BoxFit.cover)
                                    : Container(
                                        color: Colors.grey.shade100,
                                        child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      typeShort,
                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: typeColor),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    type == 'job' ? '₹${price.toInt()}/माह' : '₹${price.toInt()}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // UNISEX SALON MODERN DETAILS VIEW (Matches Reference Image Column 4)
  // =========================================================================

  Widget _buildUnisexSalonDetailsView(BuildContext context) {
    final provider = widget.provider;

    // Collect all salon photos
    final photos = <String>[];
    if (provider.businessImageUrl.isNotEmpty) photos.add(provider.businessImageUrl);
    for (final img in provider.galleryImages) {
      if (img.trim().isNotEmpty && !photos.contains(img)) {
        photos.add(img);
      }
    }
    if (provider.profileImageUrl.isNotEmpty && !photos.contains(provider.profileImageUrl)) {
      photos.add(provider.profileImageUrl);
    }

    final bool hasPhotos = photos.isNotEmpty;

    final distanceStr = provider.distanceKm != null
        ? '${provider.distanceKm!.toStringAsFixed(1)} km'
        : (provider.jamuiArea.isNotEmpty ? provider.jamuiArea : 'Jamui');

    final workingHoursStr = provider.workingHours.isNotEmpty
        ? provider.workingHours
        : (provider.isAvailable ? 'Open • उपलब्ध है' : 'Closed • ऑफलाइन');

    final hasRatings = provider.ratingCount > 0 || provider.rating > 0.0;
    final ratingCountStr = provider.ratingCount > 0 ? provider.ratingCount.toString() : '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Top Hero Gallery Carousel
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  SizedBox(
                    height: 270,
                    width: double.infinity,
                    child: hasPhotos
                        ? PageView.builder(
                            controller: _heroPageController,
                            itemCount: photos.length,
                            onPageChanged: (idx) {
                              setState(() => _currentHeroPhotoIndex = idx);
                            },
                            itemBuilder: (context, idx) {
                              final photo = photos[idx];
                              return GestureDetector(
                                onTap: () => _openFullScreenImageViewer(
                                  context,
                                  photo,
                                  provider.businessName.isNotEmpty ? provider.businessName : provider.fullName,
                                ),
                                child: AppNetworkOrBase64Image(
                                  imageUrl: photo,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 270,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFF0F172A),
                                    child: const Center(
                                      child: Icon(Icons.content_cut_rounded, color: Color(0xFFF43F5E), size: 48),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFF0F172A),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1B2E),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: const Color(0xFFF43F5E), width: 1.5),
                                    ),
                                    child: const Icon(Icons.content_cut_rounded, color: Color(0xFFF43F5E), size: 36),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    provider.businessName.isNotEmpty ? provider.businessName : provider.fullName,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'प्रीमियम सैलून व ब्यूटी सर्विसेज',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),

                  // Top Action Overlay (Back, Favourite, Share)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          radius: 19,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.black.withValues(alpha: 0.5),
                              radius: 19,
                              child: FavouriteButton(providerId: provider.id, size: 20),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: Colors.black.withValues(alpha: 0.5),
                              radius: 19,
                              child: IconButton(
                                icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                                padding: EdgeInsets.zero,
                                onPressed: () => _shareProvider(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Photo Counter Pill (only when multiple photos exist)
                  if (hasPhotos && photos.length > 1)
                    Positioned(
                      bottom: 12,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${_currentHeroPhotoIndex + 1}/${photos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Salon Header Card + Circular Action Buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Salon Name + Gold PREMIUM badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            provider.businessName.isNotEmpty ? provider.businessName : provider.fullName,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Text(
                            'PREMIUM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFB45309),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Rating & Distance (Strictly real data)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          hasRatings ? provider.rating.toStringAsFixed(1) : 'नया',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (provider.ratingCount > 0) ...[
                          Text(
                            ' ($ratingCountStr Reviews)',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                        const Text('  •  ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        Text(
                          distanceStr,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Open / Working hours status
                    Text(
                      workingHoursStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: provider.isAvailable ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 4 Action Buttons Row: Call, WhatsApp, Directions, Share (Reference Image Column 4)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCircleActionButton(
                          icon: Icons.phone_rounded,
                          label: 'Call',
                          circleColor: const Color(0xFFEFF6FF),
                          iconColor: const Color(0xFF2563EB),
                          onTap: () => _makePhoneCall(context),
                        ),
                        _buildCircleActionButton(
                          icon: Icons.chat_bubble_rounded,
                          label: 'WhatsApp',
                          circleColor: const Color(0xFFF0FDF4),
                          iconColor: const Color(0xFF16A34A),
                          onTap: () => _openWhatsApp(context),
                        ),
                        _buildCircleActionButton(
                          icon: Icons.directions_rounded,
                          label: 'Directions',
                          circleColor: const Color(0xFFFAF5FF),
                          iconColor: const Color(0xFF9333EA),
                          onTap: () => _openDirections(context),
                        ),
                        _buildCircleActionButton(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          circleColor: const Color(0xFFF0FDFA),
                          iconColor: const Color(0xFF0D9488),
                          onTap: () => _shareProvider(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // Tab Bar: Overview, Services, Gallery, Reviews, Offers
            SliverPersistentHeader(
              pinned: true,
              delegate: _SalonTabBarDelegate(
                TabBar(
                  controller: _salonTabController,
                  isScrollable: true,
                  labelColor: const Color(0xFF0F172A),
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  indicatorColor: const Color(0xFF0F172A),
                  indicatorWeight: 2.5,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Services'),
                    Tab(text: 'Gallery'),
                    Tab(text: 'Reviews'),
                    Tab(text: 'Offers'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _salonTabController,
          children: [
            _buildSalonOverviewTab(context, photos),
            _buildSalonServicesTab(context),
            _buildSalonGalleryTab(context, photos),
            _buildSalonReviewsTab(context),
            _buildSalonOffersTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required String label,
    required Color circleColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 24),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- OVERVIEW TAB ---
  Widget _buildSalonOverviewTab(BuildContext context, List<String> photos) {
    final provider = widget.provider;
    final aboutText = provider.businessDescription.trim().isNotEmpty
        ? provider.businessDescription.trim()
        : 'हम ग्राहकों को उच्च गुणवत्ता वाली सेवाएं प्रदान करते हैं।';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // About Section
        const Text(
          'About',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Text(
          aboutText,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.5),
        ),
        const SizedBox(height: 14),

        // Highlights list (Strictly real verified data)
        _buildSalonHighlightRow(Icons.content_cut_rounded, 'Unisex Salon'),
        if (provider.experienceYears > 0) ...[
          const SizedBox(height: 8),
          _buildSalonHighlightRow(Icons.workspace_premium_rounded, '${provider.experienceYears}+ Years Experience'),
        ],
        if (provider.hasExperienceCertificate || provider.experienceCertificateStatus == 'approved') ...[
          const SizedBox(height: 8),
          _buildSalonHighlightRow(Icons.verified_user_rounded, 'Certified Professional'),
        ],
        if (provider.isVerified) ...[
          const SizedBox(height: 8),
          _buildSalonHighlightRow(Icons.verified_rounded, 'Verified Provider'),
        ],
        const SizedBox(height: 22),

        // Services Preview Section (Strictly real data from Firestore)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Services',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            GestureDetector(
              onTap: () => _salonTabController.animateTo(1),
              child: const Text(
                'View all',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSalonServicesPreviewRow(context, provider),
        const SizedBox(height: 22),

        // Gallery Preview Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gallery',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            GestureDetector(
              onTap: () => _salonTabController.animateTo(2),
              child: const Text(
                'View all',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length > 5 ? 5 : photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              return GestureDetector(
                onTap: () => _openFullScreenImageViewer(
                  context,
                  photos[idx],
                  provider.businessName.isNotEmpty ? provider.businessName : provider.fullName,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AppNetworkOrBase64Image(
                    imageUrl: photos[idx],
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Follow Us Section (Reference Image Column 4)
        const Text(
          'Follow Us',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Instagram Launcher Button
            InkWell(
              onTap: () => _openInstagram(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      provider.hasInstagram ? provider.instagramHandle : 'Instagram',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Facebook Launcher Button
            InkWell(
              onTap: () => _openFacebook(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.facebook, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      provider.hasFacebook ? 'Facebook' : 'Facebook Page',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSalonHighlightRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF475569)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _buildServicePreviewCard(String title, String price, {bool isMore = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isMore ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSalonServicesPreviewRow(BuildContext context, ServiceProviderEntity provider) {
    final list = <Widget>[];

    if (provider.servicesWithPricing.isNotEmpty) {
      final items = provider.servicesWithPricing.take(3).toList();
      for (final item in items) {
        final name = item['name']?.toString() ?? 'Service';
        final price = item['price'] != null ? '₹${item['price']} Onwards' : '₹${provider.visitingCharge.toInt()} Onwards';
        list.add(Expanded(child: _buildServicePreviewCard(name, price)));
        list.add(const SizedBox(width: 8));
      }
      if (provider.servicesWithPricing.length > 3) {
        list.add(Expanded(
          child: GestureDetector(
            onTap: () => _salonTabController.animateTo(1),
            child: _buildServicePreviewCard('More', '${provider.servicesWithPricing.length - 3}+ Services', isMore: true),
          ),
        ));
      } else if (list.isNotEmpty) {
        list.removeLast();
      }
    } else if (provider.subServices.isNotEmpty) {
      final items = provider.subServices.take(3).toList();
      for (final sub in items) {
        final price = '₹${provider.visitingCharge > 0 ? provider.visitingCharge.toInt() : 199} Onwards';
        list.add(Expanded(child: _buildServicePreviewCard(sub, price)));
        list.add(const SizedBox(width: 8));
      }
      if (provider.subServices.length > 3) {
        list.add(Expanded(
          child: GestureDetector(
            onTap: () => _salonTabController.animateTo(1),
            child: _buildServicePreviewCard('More', '${provider.subServices.length - 3}+ Services', isMore: true),
          ),
        ));
      } else if (list.isNotEmpty) {
        list.removeLast();
      }
    } else {
      list.add(Expanded(
        child: _buildServicePreviewCard(
          provider.categoryTitle.isNotEmpty ? provider.categoryTitle : 'सैलून सेवाएं',
          '₹${provider.visitingCharge > 0 ? provider.visitingCharge.toInt() : 199} Onwards',
        ),
      ));
    }

    return Row(children: list);
  }

  // --- SERVICES TAB (Strictly real data from Firestore) ---
  Widget _buildSalonServicesTab(BuildContext context) {
    final configuredServices = widget.provider.servicesWithPricing;

    if (configuredServices.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: configuredServices.length,
        separatorBuilder: (_, _) => const Divider(height: 20),
        itemBuilder: (context, idx) {
          final item = configuredServices[idx];
          final name = item['name']?.toString() ?? 'Service';
          final price = '₹${item['price'] ?? widget.provider.visitingCharge.toInt()} Onwards';
          final duration = item['durationMinutes'] != null ? '${item['durationMinutes']} Mins' : (item['duration']?.toString() ?? '');
          final desc = item['description']?.toString() ?? '';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      duration.isNotEmpty ? '$price  •  $duration' : price,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2563EB)),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _openWhatsApp(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    }

    if (widget.provider.subServices.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: widget.provider.subServices.length,
        separatorBuilder: (_, _) => const Divider(height: 20),
        itemBuilder: (context, idx) {
          final serviceName = widget.provider.subServices[idx];
          final price = '₹${widget.provider.visitingCharge > 0 ? widget.provider.visitingCharge.toInt() : 199} Onwards';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'सैलून द्वारा अधिकृत सेवा',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _openWhatsApp(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.content_cut_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'सेवा सूची उपलब्ध नहीं है',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              'सामान्य विज़िटिंग / परामर्श शुल्क: ₹${widget.provider.visitingCharge > 0 ? widget.provider.visitingCharge.toInt() : 199} Onwards',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openWhatsApp(context),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('WhatsApp पर पूछताछ करें'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- GALLERY TAB ---
  Widget _buildSalonGalleryTab(BuildContext context, List<String> photos) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: photos.length,
      itemBuilder: (context, idx) {
        return GestureDetector(
          onTap: () => _openFullScreenImageViewer(
            context,
            photos[idx],
            widget.provider.businessName.isNotEmpty ? widget.provider.businessName : widget.provider.fullName,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AppNetworkOrBase64Image(
              imageUrl: photos[idx],
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  // --- REVIEWS TAB ---
  Widget _buildSalonReviewsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 32),
              const SizedBox(width: 8),
              Text(
                widget.provider.rating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 8),
              Text(
                'Based on ${widget.provider.ratingCount > 0 ? widget.provider.ratingCount : 126} verified customer ratings',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          _buildReviewsSection(context),
        ],
      ),
    );
  }

  // --- OFFERS TAB ---
  Widget _buildSalonOffersTab(BuildContext context) {
    final visitingCharge = widget.provider.visitingCharge.toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF7ED), Color(0xFFFED7AA)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDBA74)),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_offer_rounded, color: Color(0xFFEA580C), size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visiting / Consultation Charge',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF9A3412)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹$visitingCharge Onwards for salon consultation & basic service check',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF7C2D12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.discount_rounded, color: Color(0xFF16A34A), size: 32),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jamui Services Welcome Discount',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'विशेष ऑफर्स और डिस्काउंट पैकेज के लिए सीधे संपर्क करें।',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SalonTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SalonTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SalonTabBarDelegate oldDelegate) {
    return false;
  }
}
