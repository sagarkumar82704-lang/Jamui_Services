import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_image_utils.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/widgets/photo_source_picker.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';
import '../../../auth/presentation/bloc/provider_auth_bloc.dart';
import '../../../auth/presentation/bloc/provider_auth_event.dart';
import '../../../auth/presentation/bloc/provider_auth_state.dart';
import 'provider_edit_profile_page.dart';
import 'settings_page.dart';

/// [ProviderBusinessProfileScreen] - Provider's view of their Unisex Salon / Premium Business Profile
/// Strictly follows Column 5 of the design reference specification:
/// - Header with category title, "Premium Category", and [PREMIUM] badge
/// - Business Information card [Edit]
/// - Business Images card [Edit] with horizontal gallery & '+' upload tile
/// - Business Details card [Edit] (Description, Address, Working Hours, Visiting Charge)
/// - Social Links card [Edit] (Instagram, Facebook, WhatsApp)
class ProviderBusinessProfileScreen extends StatefulWidget {
  final ProviderProfileEntity profile;

  const ProviderBusinessProfileScreen({super.key, required this.profile});

  @override
  State<ProviderBusinessProfileScreen> createState() => _ProviderBusinessProfileScreenState();
}

class _ProviderBusinessProfileScreenState extends State<ProviderBusinessProfileScreen> {
  bool _isUploadingGalleryPhoto = false;

  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ProviderAuthBloc>(),
          child: ProviderEditProfilePage(profile: widget.profile),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadGalleryPhoto(ProviderProfileEntity currentProfile) async {
    final user = FirebaseAuth.instance.currentUser;
    PhotoSourcePicker.show(
      context,
      isCircle: false,
      title: 'सैलून / बिजनेस फोटो जोड़ें (Add Salon Photo)',
      onImagePicked: (imagePath) {},
      onImagePickedWithBytes: (imagePath, imageBytes) async {
        setState(() => _isUploadingGalleryPhoto = true);
        final providerId = user?.uid ?? currentProfile.id;
        final repo = context.read<ProviderAuthBloc>().providerRepository;

        try {
          String downloadUrl;
          if (imageBytes != null && imageBytes.isNotEmpty) {
            downloadUrl = await repo.uploadImageBytes(
              providerId: providerId,
              imageBytes: imageBytes,
              folder: 'business',
              mimeType: 'image/jpeg',
            );
          } else if (imagePath.startsWith('data:image/')) {
            final comma = imagePath.indexOf('base64,');
            final bytes = base64Decode(imagePath.substring(comma + 7).trim());
            downloadUrl = await repo.uploadImageBytes(
              providerId: providerId,
              imageBytes: bytes,
              folder: 'business',
              mimeType: 'image/jpeg',
            );
          } else if (kIsWeb) {
            throw Exception('वेब ब्राउज़र में फोटो डेटा लोड नहीं हो सका।');
          } else {
            final file = File(imagePath);
            downloadUrl = await repo.uploadImage(
              providerId: providerId,
              imageFile: file,
              folder: 'business',
            );
          }

          final updatedList = List<String>.from(currentProfile.galleryImages)..add(downloadUrl);
          await repo.updatePermittedProfileFields(
            providerId: providerId,
            fields: {'galleryImages': updatedList},
          );

          if (mounted) {
            context.read<ProviderAuthBloc>().add(LoadProviderProfileEvent(providerId));
            setState(() => _isUploadingGalleryPhoto = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(currentProfile.isUnisexSalon
                    ? '✓ नई सैलून फोटो सफलतापूर्वक जुड़ गई!'
                    : '✓ नई बिजनेस फोटो सफलतापूर्वक जुड़ गई!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isUploadingGalleryPhoto = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('फोटो अपलोड में त्रुटि: $e'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProviderAuthBloc, ProviderAuthState>(
      builder: (context, state) {
        ProviderProfileEntity p = widget.profile;
        if (state is ProviderAuthenticated) {
          p = state.profile;
        } else if (state is ProviderKycSubmittedSuccess && state.profile != null) {
          p = state.profile!;
        }

        final categoryTitle = p.resolvedCategoryTitle;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Column(
              children: [
                Text(
                  categoryTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  p.isUnisexSalon
                      ? 'प्रीमियम सैलून श्रेणी'
                      : (p.isPremiumCategory ? 'प्रीमियम श्रेणी' : 'व्यावसायिक प्रोफाइल'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              if (p.isPremiumApprovedAndLive)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'PREMIUM',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                tooltip: 'सेटिंग्स (Settings)',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ProviderAuthBloc>(),
                        child: SettingsPage(profile: p),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: ResponsiveContentContainer(
              maxWidth: 960,
              padding: ResponsiveLayout.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // 1. Business Information Card
                _buildCardContainer(
                  title: 'Business Information',
                  onEdit: _openEditProfile,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar / Salon Scissors Thumbnail
                      Stack(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B2E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: p.profileImageUrl.isNotEmpty
                                  ? AppImageUtils.buildImage(p.profileImageUrl, fit: BoxFit.cover)
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            p.isUnisexSalon ? Icons.content_cut_rounded : Icons.business_center_rounded,
                                            size: 32,
                                            color: p.isUnisexSalon ? Colors.pinkAccent.shade100 : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            p.isUnisexSalon ? 'SALON' : 'BUSINESS',
                                            style: const TextStyle(
                                              fontSize: 8,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: GestureDetector(
                              onTap: _openEditProfile,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoField(
                              label: 'Business Name',
                              value: p.businessName.trim().isNotEmpty ? p.businessName.trim() : 'व्यवसाय का नाम उपलब्ध नहीं',
                              isBold: true,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoField(
                              label: 'Owner Name',
                              value: p.fullName.trim().isNotEmpty ? p.fullName.trim() : 'प्रोवाइडर नाम',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoField(
                              label: 'Category',
                              value: categoryTitle,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoField(
                              label: 'Experience',
                              value: '${p.experienceYears > 0 ? p.experienceYears : 1}+ Years',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Business Images Card
                _buildCardContainer(
                  title: 'Business Images',
                  onEdit: _openEditProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 84,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...p.galleryImages.map((imageUrl) {
                              return Container(
                                width: 84,
                                height: 84,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: AppImageUtils.buildImage(imageUrl, fit: BoxFit.cover),
                                ),
                              );
                            }),
                            if (p.galleryImages.isEmpty && p.businessImageUrl.isNotEmpty)
                              Container(
                                width: 84,
                                height: 84,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: AppImageUtils.buildImage(p.businessImageUrl, fit: BoxFit.cover),
                                ),
                              ),
                            // Plus tile to add photo directly
                            InkWell(
                              onTap: _isUploadingGalleryPhoto
                                  ? null
                                  : () => _pickAndUploadGalleryPhoto(p),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    style: BorderStyle.solid,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: _isUploadingGalleryPhoto
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                        )
                                      : const Icon(Icons.add_rounded, size: 30, color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Business Details Card
                _buildCardContainer(
                  title: 'Business Details',
                  onEdit: _openEditProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        label: 'Description',
                        value: p.businessDescription.trim().isNotEmpty
                            ? p.businessDescription.trim()
                            : (p.isUnisexSalon
                                ? 'हम ग्राहकों को उच्च गुणवत्ता वाली सौंदर्य व सैलून सेवाएं प्रदान करते हैं।'
                                : 'व्यावसायिक सेवाएं उपलब्ध हैं।'),
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildDetailRow(
                        label: 'Address',
                        value: p.fullAddress.trim().isNotEmpty
                            ? p.fullAddress.trim()
                            : (p.jamuiArea.trim().isNotEmpty ? '${p.jamuiArea.trim()}, Jamui' : 'Jamui, Bihar'),
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildDetailRow(
                        label: 'Working Hours',
                        value: p.workingHours.trim().isNotEmpty ? p.workingHours.trim() : '9:00 AM - 8:00 PM',
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildDetailRow(
                        label: 'Visiting Charge',
                        value: '₹${p.visitingCharge > 0 ? p.visitingCharge.toInt() : 100} Onwards',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3.5 Services & Pricing Card (Dynamic real services & pricing from Firestore)
                if (p.isUnisexSalon || p.servicesWithPricing.isNotEmpty || p.subServices.isNotEmpty) ...[
                  _buildCardContainer(
                    title: p.isUnisexSalon ? 'Services & Pricing' : 'Services & Offerings',
                    onEdit: _openEditProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.servicesWithPricing.isNotEmpty) ...[
                          ...p.servicesWithPricing.map((s) {
                            final name = s['name']?.toString() ?? 'Service';
                            final price = '₹${s['price'] ?? p.visitingCharge.toInt()} Onwards';
                            final duration = s['durationMinutes'] != null
                                ? '${s['durationMinutes']} Mins'
                                : (s['duration']?.toString() ?? '');
                            final desc = s['description']?.toString() ?? '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: p.isUnisexSalon ? const Color(0xFFFDF2F8) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      p.isUnisexSalon ? Icons.content_cut_rounded : Icons.handyman_rounded,
                                      size: 16,
                                      color: p.isUnisexSalon ? const Color(0xFFDB2777) : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          duration.isNotEmpty ? '$price • $duration' : price,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                        if (desc.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            desc,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ] else if (p.subServices.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: p.subServices.map((sub) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: p.isUnisexSalon ? const Color(0xFFFDF2F8) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: p.isUnisexSalon ? const Color(0xFFFBCFE8) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      p.isUnisexSalon ? Icons.content_cut_rounded : Icons.check_circle_outline_rounded,
                                      size: 13,
                                      color: p.isUnisexSalon ? const Color(0xFFDB2777) : AppColors.primary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      sub,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: p.isUnisexSalon ? const Color(0xFF9D174D) : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'विज़िटिंग / परामर्श शुल्क: ₹${p.visitingCharge > 0 ? p.visitingCharge.toInt() : 100} Onwards',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else ...[
                          Text(
                            p.isUnisexSalon
                                ? 'अपनी सैलून सेवाओं और उनकी मूल्य सूची को जोड़ने के लिए [Edit] पर टैप करें।'
                                : 'अपनी सेवाएं व दरें जोड़ने के लिए [Edit] पर टैप करें।',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Social Links Card
                _buildCardContainer(
                  title: 'Social Links',
                  onEdit: _openEditProfile,
                  child: Column(
                    children: [
                      // Instagram
                      _buildSocialLinkRow(
                        iconWidget: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: const RadialGradient(
                              center: Alignment(-0.8, 0.8),
                              radius: 1.2,
                              colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF), Color(0xFF4F5BD5)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 15),
                        ),
                        platform: 'Instagram',
                        handleText: p.instagramHandle.isNotEmpty ? p.instagramHandle : 'उपलब्ध नहीं',
                        onTap: () {
                          if (p.hasInstagram) {
                            _launchExternalUrl(p.instagramLaunchUrl);
                          }
                        },
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      // Facebook
                      _buildSocialLinkRow(
                        iconWidget: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: Text(
                              'f',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                        platform: 'Facebook',
                        handleText: p.facebookUrl.isNotEmpty ? p.facebookUrl : 'उपलब्ध नहीं',
                        onTap: () {
                          if (p.hasFacebook) {
                            _launchExternalUrl(p.facebookLaunchUrl);
                          }
                        },
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      // WhatsApp
                      _buildSocialLinkRow(
                        iconWidget: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 14),
                        ),
                        platform: 'WhatsApp',
                        handleText: p.phoneNumber.isNotEmpty ? p.phoneNumber : '+91 12345 67890',
                        onTap: () {
                          final clean = p.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
                          if (clean.isNotEmpty) {
                            _launchExternalUrl('https://wa.me/91$clean');
                          }
                        },
                      ),
                      if (p.hasWebsite) ...[
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildSocialLinkRow(
                          iconWidget: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.language_rounded, color: Colors.white, size: 15),
                          ),
                          platform: 'Website',
                          handleText: p.websiteUrl,
                          onTap: () => _launchExternalUrl(p.websiteLaunchUrl),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContainer({
    required String title,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLinkRow({
    required Widget iconWidget,
    required String platform,
    required String handleText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              platform,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              handleText,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
