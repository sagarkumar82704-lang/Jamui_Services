import '../../domain/entities/service_category.dart';

class ServiceCategoryModel extends ServiceCategory {
  const ServiceCategoryModel({
    required super.id,
    required super.titleHindi,
    required super.titleEnglish,
    super.description = '',
    super.shortDescription = '',
    super.imageUrl = '',
    required super.iconName,
    required super.colorHex,
    required super.priorityOrder,
    super.status,
    super.isDeleted,
    super.isActive,
    super.subServices,
    super.providerRequirements = '',
    super.experienceCertificateRequired = false,
    super.verificationRequired = false,
    super.isPremium = false,
    super.categoryType = 'general',
  });

  factory ServiceCategoryModel.fromMap(Map<String, dynamic> map, String id) {
    final name = (map['name'] as String?) ?? '';
    final titleHindi = (map['titleHindi'] as String?) ?? (name.isNotEmpty ? name : 'सेवा');
    final titleEnglish = (map['titleEnglish'] as String?) ?? (name.isNotEmpty ? name : 'Service');
    final status = (map['status'] as String?) ?? 'active';
    final isDeleted = (map['isDeleted'] as bool?) ?? false;
    final isActive = (map['isActive'] as bool?) ?? (status == 'active' && !isDeleted);
    final shortDesc = (map['shortDescription'] as String?) ?? (map['description'] as String?) ?? '';
    final isPremium = (map['isPremium'] as bool?) ??
        (map['isPremiumCategory'] as bool?) ??
        ((map['categoryType'] as String?) == 'premium');
    final categoryType = (map['categoryType'] as String?) ?? (isPremium ? 'premium' : 'general');

    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    return ServiceCategoryModel(
      id: id,
      titleHindi: titleHindi,
      titleEnglish: titleEnglish,
      description: (map['description'] as String?) ?? shortDesc,
      shortDescription: shortDesc,
      imageUrl: (map['imageUrl'] as String?) ?? (map['iconUrl'] as String?) ?? '',
      iconName: (map['iconName'] as String?) ?? 'handyman',
      colorHex: (map['colorHex'] as String?) ?? (isPremium ? '#D4AF37' : '#0D6E57'),
      priorityOrder: (map['priorityOrder'] as num?)?.toInt() ?? (map['sortOrder'] as num?)?.toInt() ?? 99,
      status: status,
      isDeleted: isDeleted,
      isActive: isActive,
      subServices: parseList(map['subServices']),
      providerRequirements: (map['providerRequirements'] as String?) ?? '',
      experienceCertificateRequired: (map['experienceCertificateRequired'] as bool?) ?? false,
      verificationRequired: (map['verificationRequired'] as bool?) ?? false,
      isPremium: isPremium,
      categoryType: categoryType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titleHindi': titleHindi,
      'titleEnglish': titleEnglish,
      'description': description,
      'shortDescription': shortDescription,
      'imageUrl': imageUrl,
      'iconName': iconName,
      'colorHex': colorHex,
      'priorityOrder': priorityOrder,
      'status': status,
      'isDeleted': isDeleted,
      'isActive': isActive,
      'subServices': subServices,
      'providerRequirements': providerRequirements,
      'experienceCertificateRequired': experienceCertificateRequired,
      'verificationRequired': verificationRequired,
      'isPremium': isPremium,
      'categoryType': categoryType,
    };
  }
}
