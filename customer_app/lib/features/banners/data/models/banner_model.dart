import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/banner_entity.dart';

class BannerModel extends BannerEntity {
  const BannerModel({
    required super.id,
    required super.sponsorName,
    required super.title,
    super.description = '',
    required super.imageUrl,
    super.ctaText = 'अधिक जानें',
    super.targetType = BannerTargetType.page,
    super.targetId = '',
    super.startAt,
    super.endAt,
    super.priority = 1,
    super.isActive = true,
    super.isSponsored = true,
    super.impressions = 0,
    super.clicks = 0,
  });

  factory BannerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BannerModel.fromMap(data, doc.id);
  }

  factory BannerModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawStatus = (map['status'] as String?)?.toLowerCase();
    final isActive = (map['isActive'] as bool?) ??
        (rawStatus == 'active' && map['isDeleted'] != true);

    return BannerModel(
      id: id,
      sponsorName: (map['sponsorName'] as String?) ?? (map['businessName'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? (map['subtitle'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? (map['bannerUrl'] as String?) ?? '',
      ctaText: (map['ctaText'] as String?) ?? 'अधिक जानें',
      targetType: BannerTargetType.fromString(map['targetType'] as String?),
      targetId: (map['targetId'] as String?) ?? (map['targetUrl'] as String?) ?? '',
      startAt: parseDate(map['startAt'] ?? map['startDate']),
      endAt: parseDate(map['endAt'] ?? map['endDate']),
      priority: (map['priority'] as num?)?.toInt() ?? 1,
      isActive: isActive,
      isSponsored: (map['isSponsored'] as bool?) ?? true,
      impressions: (map['impressions'] as num?)?.toInt() ?? 0,
      clicks: (map['clicks'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sponsorName': sponsorName,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'ctaText': ctaText,
      'targetType': targetType.name,
      'targetId': targetId,
      'startAt': startAt != null ? Timestamp.fromDate(startAt!) : null,
      'endAt': endAt != null ? Timestamp.fromDate(endAt!) : null,
      'priority': priority,
      'isActive': isActive,
      'isSponsored': isSponsored,
      'impressions': impressions,
      'clicks': clicks,
      'status': isActive ? 'active' : 'inactive',
      'isDeleted': false,
    };
  }
}
