import 'package:equatable/equatable.dart';

enum AdminBannerTargetType {
  provider('कारीगर (Provider)'),
  category('श्रेणी (Category)'),
  service('सेवा (Service)'),
  url('वेबसाइट लिंक (External URL)'),
  page('आंतरिक पेज (Internal Page)');

  final String label;
  const AdminBannerTargetType(this.label);

  static AdminBannerTargetType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'provider':
        return AdminBannerTargetType.provider;
      case 'category':
        return AdminBannerTargetType.category;
      case 'service':
        return AdminBannerTargetType.service;
      case 'url':
      case 'external_url':
        return AdminBannerTargetType.url;
      default:
        return AdminBannerTargetType.page;
    }
  }
}

class AdminBannerEntity extends Equatable {
  final String id;
  final String sponsorName;
  final String title;
  final String description;
  final String imageUrl;
  final String ctaText;
  final AdminBannerTargetType targetType;
  final String targetId;
  final DateTime? startAt;
  final DateTime? endAt;
  final int priority;
  final bool isActive;
  final bool isSponsored;
  final int impressions;
  final int clicks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminBannerEntity({
    required this.id,
    required this.sponsorName,
    required this.title,
    this.description = '',
    required this.imageUrl,
    this.ctaText = 'अधिक जानें',
    this.targetType = AdminBannerTargetType.page,
    this.targetId = '',
    this.startAt,
    this.endAt,
    this.priority = 1,
    this.isActive = true,
    this.isSponsored = true,
    this.impressions = 0,
    this.clicks = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isExpired {
    if (endAt == null) return false;
    return DateTime.now().isAfter(endAt!);
  }

  double get ctr {
    if (impressions == 0) return 0.0;
    return (clicks / impressions) * 100;
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
        createdAt,
        updatedAt,
      ];
}
