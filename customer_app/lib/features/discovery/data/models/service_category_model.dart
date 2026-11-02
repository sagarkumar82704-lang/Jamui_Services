import '../../domain/entities/service_category_entity.dart';

class ServiceCategoryModel extends ServiceCategoryEntity {
  const ServiceCategoryModel({
    required super.id,
    required super.titleHindi,
    required super.titleEnglish,
    super.description = '',
    super.shortDescription = '',
    super.fullDescription = '',
    super.aboutCategory = '',
    super.imageUrl = '',
    required super.iconName,
    required super.colorHex,
    required super.priorityOrder,
    super.isActive = true,
    super.isFeatured = false,
    super.subServices = const [],
    super.benefits = const [],
    super.commonProblems = const [],
    super.pricingType = 'contact_provider',
    super.startingPrice,
    super.priceUnit = '',
    super.estimatedDuration = '',
    super.customerRequirements = '',
    super.customerPhotoRequired = false,
    super.safetyInstructions = '',
    super.importantNotes = '',
    super.faqs = const [],
    super.isPremium = false,
    super.categoryType = 'general',
  });

  factory ServiceCategoryModel.fromMap(Map<String, dynamic> map, String id) {
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    final rawFaqs = (map['faqs'] as List<dynamic>?) ?? [];
    final faqsList = rawFaqs
        .whereType<Map<String, dynamic>>()
        .map((f) => CustomerCategoryFaq.fromMap(f))
        .toList();

    final name = (map['name'] as String?) ?? '';
    final titleHindi = (map['titleHindi'] as String?) ?? name;
    final titleEnglish = (map['titleEnglish'] as String?) ?? name;
    final shortDesc = (map['shortDescription'] as String?) ?? (map['description'] as String?) ?? '';
    final fullDesc = (map['fullDescription'] as String?) ?? (map['description'] as String?) ?? '';

    final rawIsPrem = (map['isPremium'] as bool?) ?? (map['isPremiumCategory'] as bool?);
    final isPrem = rawIsPrem ??
        (((map['categoryType'] as String?)?.toLowerCase().trim() == 'premium') ||
            id.toLowerCase().trim() == 'unisex_salon' ||
            titleEnglish.toLowerCase().contains('unisex') ||
            titleHindi.contains('यूनिसेक्स'));
    final catType = (map['categoryType'] as String?) ?? (isPrem ? 'premium' : 'general');

    return ServiceCategoryModel(
      id: id,
      titleHindi: titleHindi.isNotEmpty ? titleHindi : 'सेवा',
      titleEnglish: titleEnglish.isNotEmpty ? titleEnglish : 'Service',
      description: (map['description'] as String?) ?? shortDesc,
      shortDescription: shortDesc,
      fullDescription: fullDesc,
      aboutCategory: (map['aboutCategory'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? (map['iconUrl'] as String?) ?? '',
      iconName: (map['iconName'] as String?) ?? 'handyman',
      colorHex: (map['colorHex'] as String?) ?? (isPrem ? '#D4AF37' : '#0D6E57'),
      priorityOrder: (map['priorityOrder'] as num?)?.toInt() ?? (map['sortOrder'] as num?)?.toInt() ?? 99,
      isActive: (map['isActive'] as bool?) ?? (map['status'] == 'active' && map['isDeleted'] != true),
      isFeatured: (map['isFeatured'] as bool?) ?? false,
      subServices: parseList(map['subServices']),
      benefits: parseList(map['benefits']),
      commonProblems: parseList(map['commonProblems']),
      pricingType: (map['pricingType'] as String?) ?? 'contact_provider',
      startingPrice: (map['startingPrice'] as num?)?.toDouble(),
      priceUnit: (map['priceUnit'] as String?) ?? '',
      estimatedDuration: (map['estimatedDuration'] as String?) ?? '',
      customerRequirements: (map['customerRequirements'] as String?) ?? '',
      customerPhotoRequired: (map['customerPhotoRequired'] as bool?) ?? false,
      safetyInstructions: (map['safetyInstructions'] as String?) ?? '',
      importantNotes: (map['importantNotes'] as String?) ?? '',
      faqs: faqsList,
      isPremium: isPrem,
      categoryType: catType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titleHindi': titleHindi,
      'titleEnglish': titleEnglish,
      'description': description,
      'shortDescription': shortDescription,
      'fullDescription': fullDescription,
      'aboutCategory': aboutCategory,
      'imageUrl': imageUrl,
      'iconName': iconName,
      'colorHex': colorHex,
      'priorityOrder': priorityOrder,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'subServices': subServices,
      'benefits': benefits,
      'commonProblems': commonProblems,
      'pricingType': pricingType,
      'startingPrice': startingPrice,
      'priceUnit': priceUnit,
      'estimatedDuration': estimatedDuration,
      'customerRequirements': customerRequirements,
      'customerPhotoRequired': customerPhotoRequired,
      'safetyInstructions': safetyInstructions,
      'importantNotes': importantNotes,
      'isPremium': isPremium,
      'categoryType': categoryType,
    };
  }
}
