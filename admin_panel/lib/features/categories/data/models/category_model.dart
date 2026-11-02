import '../../domain/entities/category_entity.dart';

class CategoryModel extends CategoryEntity {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.slug,
    super.titleHindi = '',
    super.titleEnglish = '',
    super.shortDescription = '',
    super.fullDescription = '',
    super.description = '',
    super.iconUrl = '',
    super.imageUrl = '',
    super.imageStoragePath = '',
    super.iconName = 'build',
    super.colorHex = '#4F46E5',
    super.aboutCategory = '',
    super.whatIncludes = const [],
    super.commonProblems = const [],
    super.whoNeeds = '',
    super.whenToContact = '',
    super.subServices = const [],
    super.benefits = const [],
    super.includedServices = const [],
    super.excludedServices = const [],
    super.pricingType = 'contact_provider',
    super.startingPrice,
    super.priceUnit = '',
    super.priceNote = '',
    super.estimatedDuration = '',
    super.customerRequirements = '',
    super.customerPhotoRequired = false,
    super.providerRequirements = '',
    super.requiredSkills = const [],
    super.experienceCertificateRequired = false,
    super.verificationRequired = false,
    super.requiredDocuments = const [],
    super.faqs = const [],
    super.safetyInstructions = '',
    super.importantNotes = '',
    super.disclaimer = '',
    super.searchKeywords = const [],
    super.tags = const [],
    super.sortOrder = 0,
    super.priorityOrder = 0,
    super.status = CategoryStatus.active,
    super.isFeatured = false,
    super.isDeleted = false,
    required super.createdAt,
    super.updatedAt,
    super.deletedAt,
    super.deletedBy,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    final nameVal = (map['name'] as String?) ??
        (map['titleEnglish'] as String?) ??
        (map['titleHindi'] as String?) ??
        'Category';
    final rawStatus = (map['status'] as String?)?.toLowerCase();

    CategoryStatus parseStatus() {
      if (map['isDeleted'] == true || rawStatus == 'archived') return CategoryStatus.archived;
      if (map['isActive'] == false || rawStatus == 'inactive') return CategoryStatus.inactive;
      return CategoryStatus.active;
    }

    final rawFaqs = (map['faqs'] as List<dynamic>?) ?? [];
    final List<CategoryFaq> faqsList = rawFaqs
        .whereType<Map<String, dynamic>>()
        .map((f) => CategoryFaq.fromMap(f))
        .toList();

    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    final shortDesc = (map['shortDescription'] as String?) ?? (map['description'] as String?) ?? '';
    final fullDesc = (map['fullDescription'] as String?) ?? (map['description'] as String?) ?? '';

    return CategoryModel(
      id: id,
      name: nameVal,
      slug: (map['slug'] as String?) ??
          nameVal.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      titleHindi: (map['titleHindi'] as String?) ?? nameVal,
      titleEnglish: (map['titleEnglish'] as String?) ?? nameVal,
      shortDescription: shortDesc,
      fullDescription: fullDesc,
      description: (map['description'] as String?) ?? shortDesc,
      iconUrl: (map['iconUrl'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? '',
      imageStoragePath: (map['imageStoragePath'] as String?) ?? '',
      iconName: (map['iconName'] as String?) ?? 'build',
      colorHex: (map['colorHex'] as String?) ?? '#4F46E5',
      aboutCategory: (map['aboutCategory'] as String?) ?? '',
      whatIncludes: parseStringList(map['whatIncludes']),
      commonProblems: parseStringList(map['commonProblems']),
      whoNeeds: (map['whoNeeds'] as String?) ?? '',
      whenToContact: (map['whenToContact'] as String?) ?? '',
      subServices: parseStringList(map['subServices']),
      benefits: parseStringList(map['benefits']),
      includedServices: parseStringList(map['includedServices']),
      excludedServices: parseStringList(map['excludedServices']),
      pricingType: (map['pricingType'] as String?) ?? 'contact_provider',
      startingPrice: (map['startingPrice'] as num?)?.toDouble(),
      priceUnit: (map['priceUnit'] as String?) ?? '',
      priceNote: (map['priceNote'] as String?) ?? '',
      estimatedDuration: (map['estimatedDuration'] as String?) ?? '',
      customerRequirements: (map['customerRequirements'] as String?) ?? '',
      customerPhotoRequired: (map['customerPhotoRequired'] as bool?) ?? false,
      providerRequirements: (map['providerRequirements'] as String?) ?? '',
      requiredSkills: parseStringList(map['requiredSkills']),
      experienceCertificateRequired:
          (map['experienceCertificateRequired'] as bool?) ?? false,
      verificationRequired: (map['verificationRequired'] as bool?) ?? false,
      requiredDocuments: parseStringList(map['requiredDocuments']),
      faqs: faqsList,
      safetyInstructions: (map['safetyInstructions'] as String?) ?? '',
      importantNotes: (map['importantNotes'] as String?) ?? '',
      disclaimer: (map['disclaimer'] as String?) ?? '',
      searchKeywords: parseStringList(map['searchKeywords']),
      tags: parseStringList(map['tags']),
      sortOrder: (map['sortOrder'] as num?)?.toInt() ??
          (map['priorityOrder'] as num?)?.toInt() ??
          0,
      priorityOrder: (map['priorityOrder'] as num?)?.toInt() ?? 0,
      status: parseStatus(),
      isFeatured: (map['isFeatured'] as bool?) ?? false,
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
      deletedAt: map['deletedAt'] != null
          ? DateTime.tryParse(map['deletedAt'].toString())
          : null,
      deletedBy: map['deletedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'titleHindi': titleHindi.isNotEmpty ? titleHindi : name,
      'titleEnglish': titleEnglish.isNotEmpty ? titleEnglish : name,
      'shortDescription': shortDescription,
      'fullDescription': fullDescription,
      'description': shortDescription.isNotEmpty ? shortDescription : description,
      'iconUrl': iconUrl,
      'imageUrl': imageUrl,
      'imageStoragePath': imageStoragePath,
      'iconName': iconName,
      'colorHex': colorHex,
      'aboutCategory': aboutCategory,
      'whatIncludes': whatIncludes,
      'commonProblems': commonProblems,
      'whoNeeds': whoNeeds,
      'whenToContact': whenToContact,
      'subServices': subServices,
      'benefits': benefits,
      'includedServices': includedServices,
      'excludedServices': excludedServices,
      'pricingType': pricingType,
      'startingPrice': startingPrice,
      'priceUnit': priceUnit,
      'priceNote': priceNote,
      'estimatedDuration': estimatedDuration,
      'customerRequirements': customerRequirements,
      'customerPhotoRequired': customerPhotoRequired,
      'providerRequirements': providerRequirements,
      'requiredSkills': requiredSkills,
      'experienceCertificateRequired': experienceCertificateRequired,
      'verificationRequired': verificationRequired,
      'requiredDocuments': requiredDocuments,
      'faqs': faqs.map((f) => f.toMap()).toList(),
      'safetyInstructions': safetyInstructions,
      'importantNotes': importantNotes,
      'disclaimer': disclaimer,
      'searchKeywords': searchKeywords,
      'tags': tags,
      'sortOrder': sortOrder,
      'priorityOrder': sortOrder,
      'status': status.name,
      'isActive': status == CategoryStatus.active && !isDeleted,
      'isFeatured': isFeatured,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedBy': deletedBy,
    };
  }

  factory CategoryModel.fromEntity(CategoryEntity entity) {
    return CategoryModel(
      id: entity.id,
      name: entity.name,
      slug: entity.slug,
      titleHindi: entity.titleHindi,
      titleEnglish: entity.titleEnglish,
      shortDescription: entity.shortDescription,
      fullDescription: entity.fullDescription,
      description: entity.description,
      iconUrl: entity.iconUrl,
      imageUrl: entity.imageUrl,
      imageStoragePath: entity.imageStoragePath,
      iconName: entity.iconName,
      colorHex: entity.colorHex,
      aboutCategory: entity.aboutCategory,
      whatIncludes: entity.whatIncludes,
      commonProblems: entity.commonProblems,
      whoNeeds: entity.whoNeeds,
      whenToContact: entity.whenToContact,
      subServices: entity.subServices,
      benefits: entity.benefits,
      includedServices: entity.includedServices,
      excludedServices: entity.excludedServices,
      pricingType: entity.pricingType,
      startingPrice: entity.startingPrice,
      priceUnit: entity.priceUnit,
      priceNote: entity.priceNote,
      estimatedDuration: entity.estimatedDuration,
      customerRequirements: entity.customerRequirements,
      customerPhotoRequired: entity.customerPhotoRequired,
      providerRequirements: entity.providerRequirements,
      requiredSkills: entity.requiredSkills,
      experienceCertificateRequired: entity.experienceCertificateRequired,
      verificationRequired: entity.verificationRequired,
      requiredDocuments: entity.requiredDocuments,
      faqs: entity.faqs,
      safetyInstructions: entity.safetyInstructions,
      importantNotes: entity.importantNotes,
      disclaimer: entity.disclaimer,
      searchKeywords: entity.searchKeywords,
      tags: entity.tags,
      sortOrder: entity.sortOrder,
      priorityOrder: entity.priorityOrder,
      status: entity.status,
      isFeatured: entity.isFeatured,
      isDeleted: entity.isDeleted,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
      deletedBy: entity.deletedBy,
    );
  }
}
