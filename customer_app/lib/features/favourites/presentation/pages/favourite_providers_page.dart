import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../../discovery/domain/entities/service_provider_entity.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/pages/provider_details_page.dart';
import '../../../discovery/presentation/widgets/favourite_button.dart';
import '../../data/services/customer_favourites_service.dart';

class FavouriteProvidersPage extends StatelessWidget {
  const FavouriteProvidersPage({super.key});

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String name, String category) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final normalized = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final msg = Uri.encodeComponent(
      'नमस्ते $name, मुझे JAMUI SERVICE ऐप से आपकी $category सेवा चाहिए।',
    );
    final uri = Uri.parse('https://wa.me/$normalized?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'पसंदीदा कारीगर (Saved Providers)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.creamWhite,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.creamWhite,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? _buildGuestView(context)
          : StreamBuilder<List<ServiceProviderEntity>>(
              stream: CustomerFavouritesService().getFavouriteProvidersStream(
                user.uid,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final providers = snapshot.data ?? [];

                if (providers.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    final p = providers[index];
                    return _buildFavouriteCard(context, p);
                  },
                );
              },
            ),
    );
  }

  Widget _buildFavouriteCard(
    BuildContext context,
    ServiceProviderEntity provider,
  ) {
    final hasImage = provider.profileImageUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image / Fallback Avatar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasImage
                        ? AppNetworkOrBase64Image(
                            imageUrl: provider.profileImageUrl,
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) =>
                                _buildAvatarFallback(provider.fullName),
                          )
                        : _buildAvatarFallback(provider.fullName),
                  ),
                  const SizedBox(width: 12),

                  // Provider Details
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (provider.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${provider.categoryTitle} • ${provider.experienceYears} वर्ष अनुभव',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.gold,
                              size: 16,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              provider.rating > 0
                                  ? '${provider.rating.toStringAsFixed(1)} (${provider.ratingCount})'
                                  : 'नया',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                provider.jamuiArea.isNotEmpty
                                    ? provider.jamuiArea
                                    : 'जमुई',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Unfavourite Heart Button
                  FavouriteButton(providerId: provider.id, size: 24),
                ],
              ),
              const Divider(height: 18, thickness: 0.6),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openWhatsApp(
                        provider.phoneNumber,
                        provider.fullName,
                        provider.categoryTitle,
                      ),
                      icon: const Icon(
                        Icons.chat,
                        size: 15,
                        color: Color(0xFF25D366),
                      ),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF25D366),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF25D366)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makePhoneCall(provider.phoneNumber),
                      icon: const Icon(
                        Icons.call,
                        size: 15,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'कॉल करें',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'P',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 52,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'कोई पसंदीदा कारीगर नहीं है',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'होम स्क्रीन या कारीगर की प्रोफाइल पर दिल (❤️) दबाकर उन्हें अपनी पसंदीदा लिस्ट में सहेजें।',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'कारीगर खोजें (Discover)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 14),
            const Text(
              'पसंदीदा कारीगर देखने के लिए कृपया लॉगिन करें',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
