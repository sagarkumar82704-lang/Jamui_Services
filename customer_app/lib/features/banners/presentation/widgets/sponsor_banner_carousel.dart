import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../../discovery/data/models/service_provider_model.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/bloc/discovery_event.dart';
import '../../../discovery/presentation/pages/provider_details_page.dart';
import '../../data/datasources/banner_remote_data_source.dart';
import '../../domain/entities/banner_entity.dart';

class SponsorBannerCarousel extends StatefulWidget {
  final Widget? fallbackHeroCard;

  const SponsorBannerCarousel({
    super.key,
    this.fallbackHeroCard,
  });

  @override
  State<SponsorBannerCarousel> createState() => _SponsorBannerCarouselState();
}

class _SponsorBannerCarouselState extends State<SponsorBannerCarousel> {
  final BannerRemoteDataSource _dataSource = FirebaseBannerRemoteDataSource();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  final Set<String> _trackedImpressions = {};

  List<BannerEntity> _banners = [];
  bool _isLoading = true;
  StreamSubscription<List<BannerEntity>>? _bannerSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeBanners();
  }

  void _subscribeBanners() {
    // Single controlled subscription created once in initState()
    _bannerSubscription = _dataSource.watchActiveBanners().listen(
      (banners) {
        if (!mounted) return;
        setState(() {
          _banners = banners;
          _isLoading = false;
          if (_currentPage >= banners.length) {
            _currentPage = 0;
          }
        });
        _startAutoPlay(banners.length);
        if (banners.isNotEmpty && _currentPage < banners.length) {
          _trackImpression(banners[_currentPage]);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _bannerSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay(int itemCount) {
    if (itemCount <= 1) {
      _autoPlayTimer?.cancel();
      _autoPlayTimer = null;
      return;
    }
    // Prevent creating duplicate timers if active
    if (_autoPlayTimer != null && _autoPlayTimer!.isActive) return;

    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      int nextPage = (_currentPage + 1) % itemCount;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _trackImpression(BannerEntity banner) {
    if (!_trackedImpressions.contains(banner.id)) {
      _trackedImpressions.add(banner.id);
      final user = FirebaseAuth.instance.currentUser;
      _dataSource.trackImpression(banner.id, customerId: user?.uid);
    }
  }

  Future<void> _handleBannerClick(BuildContext context, BannerEntity banner) async {
    final user = FirebaseAuth.instance.currentUser;
    _dataSource.trackClick(banner.id, customerId: user?.uid);

    switch (banner.targetType) {
      case BannerTargetType.provider:
        if (banner.targetId.isEmpty) return;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('providers')
              .doc(banner.targetId)
              .get();
          if (doc.exists && doc.data() != null && context.mounted) {
            final provider = ServiceProviderModel.fromMap(doc.data()!, doc.id);
            if (!provider.isApprovedAndLive) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('यह सेवा प्रदाता अभी समीक्षाधीन या अस्थायी रूप से अनुपलब्ध है।')),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<DiscoveryBloc>(),
                  child: ProviderDetailsPage(provider: provider),
                ),
              ),
            );
          }
        } catch (_) {}
        break;

      case BannerTargetType.category:
        if (banner.targetId.isNotEmpty) {
          context.read<DiscoveryBloc>().add(SelectCategoryFilterEvent(banner.targetId));
        }
        break;

      case BannerTargetType.url:
        if (banner.targetId.isNotEmpty) {
          final uri = Uri.tryParse(banner.targetId);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _banners.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_banners.isEmpty) {
      return widget.fallbackHeroCard ?? const SizedBox.shrink();
    }

    final banners = _banners;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 148,
            child: PageView.builder(
              controller: _pageController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                if (index < banners.length) {
                  _trackImpression(banners[index]);
                }
              },
              itemBuilder: (context, index) {
                final banner = banners[index];
                return _buildBannerCard(context, banner);
              },
            ),
          ),
              if (banners.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    banners.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == i ? 18 : 6,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _currentPage == i ? AppColors.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
  }

  Widget _buildBannerCard(BuildContext context, BannerEntity banner) {
    final hasImage = banner.imageUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Image if available
            if (hasImage)
              Positioned.fill(
                child: AppNetworkOrBase64Image(
                  imageUrl: banner.imageUrl,
                  height: 148,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                ),
              ),

            // Subtle dark overlay to ensure text readability only when text is present
            if (hasImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: banner.title.isNotEmpty ? 0.55 : 0.10),
                        Colors.black.withValues(alpha: 0.10),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Sponsored Badge
                        if (banner.isSponsored)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade400,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 11, color: Colors.black87),
                                const SizedBox(width: 3),
                                Text(
                                  banner.sponsorName.isNotEmpty
                                      ? 'प्रायोजित • ${banner.sponsorName}'
                                      : 'प्रायोजित (Sponsored)',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          banner.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (banner.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            banner.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _handleBannerClick(context, banner),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  banner.ctaText,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
