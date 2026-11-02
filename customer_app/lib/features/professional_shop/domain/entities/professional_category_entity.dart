import 'package:equatable/equatable.dart';

class ProfessionalCategoryEntity extends Equatable {
  final String id;
  final String titleHindi;
  final String titleEnglish;
  final String slug;
  final String iconUrl;
  final String bannerUrl;
  final int priorityOrder;
  final bool isActive;
  final int totalShopsCount;

  const ProfessionalCategoryEntity({
    required this.id,
    required this.titleHindi,
    required this.titleEnglish,
    required this.slug,
    this.iconUrl = '',
    this.bannerUrl = '',
    this.priorityOrder = 0,
    this.isActive = true,
    this.totalShopsCount = 0,
  });

  String get displayName => titleHindi.isNotEmpty ? titleHindi : titleEnglish;

  factory ProfessionalCategoryEntity.fromMap(Map<String, dynamic> map, String id) {
    return ProfessionalCategoryEntity(
      id: id,
      titleHindi: (map['titleHindi'] as String?) ?? (map['nameHindi'] as String?) ?? (map['name'] as String?) ?? '',
      titleEnglish: (map['titleEnglish'] as String?) ?? (map['nameEnglish'] as String?) ?? (map['title'] as String?) ?? id,
      slug: (map['slug'] as String?) ?? id,
      iconUrl: (map['iconUrl'] as String?) ?? (map['icon'] as String?) ?? '',
      bannerUrl: (map['bannerUrl'] as String?) ?? (map['banner'] as String?) ?? '',
      priorityOrder: (map['priorityOrder'] as num?)?.toInt() ?? (map['displayOrder'] as num?)?.toInt() ?? 0,
      isActive: (map['isActive'] as bool?) ?? true,
      totalShopsCount: (map['totalShopsCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titleHindi': titleHindi,
      'titleEnglish': titleEnglish,
      'slug': slug,
      'iconUrl': iconUrl,
      'bannerUrl': bannerUrl,
      'priorityOrder': priorityOrder,
      'isActive': isActive,
      'totalShopsCount': totalShopsCount,
    };
  }

  @override
  List<Object?> get props => [id, titleHindi, titleEnglish, slug, iconUrl, bannerUrl, priorityOrder, isActive, totalShopsCount];
}

