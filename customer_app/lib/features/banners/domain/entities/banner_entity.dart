import 'package:equatable/equatable.dart';

enum BannerTargetType {
  provider,
  category,
  service,
  url,
  page;

  static BannerTargetType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'provider':
        return BannerTargetType.provider;
      case 'category':
        return BannerTargetType.category;
      case 'service':
        return BannerTargetType.service;
      case 'url':
      case 'external_url':
        return BannerTargetType.url;
      default:
        return BannerTargetType.page;
    }
  }
}

class BannerEntity extends Equatable {
  final String id;
  final String sponsorName;
  final String title;
  final String description;
  final String imageUrl;
  final String ctaText;
  final BannerTargetType targetType;
  final String targetId;
  final DateTime? startAt;
  final DateTime? endAt;
  final int priority;
  final bool isActive;
  final bool isSponsored;
  final int impressions;
  final int clicks;

  const BannerEntity({
    required this.id,
    required this.sponsorName,
    required this.title,
    this.description = '',
    required this.imageUrl,
    this.ctaText = 'अधिक जानें',
    this.targetType = BannerTargetType.page,
    this.targetId = '',
    this.startAt,
    this.endAt,
    this.priority = 1,
    this.isActive = true,
    this.isSponsored = true,
    this.impressions = 0,
    this.clicks = 0,
  });

  bool get isValidNow {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }

  @override
  List<Object?> get props => [
        id,
        sponsorName,
        title,
        description,
        imageUrl,
        ctaText,
        targetType,
        targetId,
        startAt,
        endAt,
        priority,
        isActive,
        isSponsored,
        impressions,
        clicks,
      ];
}
