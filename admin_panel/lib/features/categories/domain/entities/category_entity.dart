import 'package:equatable/equatable.dart';

enum CategoryStatus { active, inactive, archived }

class CategoryFaq extends Equatable {
  final String question;
  final String answer;
  final int displayOrder;
  final String status;

  const CategoryFaq({
    required this.question,
    required this.answer,
    this.displayOrder = 0,
    this.status = 'active',
  });

  factory CategoryFaq.fromMap(Map<String, dynamic> map) {
    return CategoryFaq(
      question: (map['question'] as String?) ?? '',
      answer: (map['answer'] as String?) ?? '',
      displayOrder: (map['displayOrder'] as num?)?.toInt() ?? 0,
      status: (map['status'] as String?) ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'displayOrder': displayOrder,
      'status': status,
    };
  }

  CategoryFaq copyWith({
    String? question,
    String? answer,
    int? displayOrder,
    String? status,
  }) {
    return CategoryFaq(
      question: question ?? this.question,
      answer: answer ?? this.answer,
      displayOrder: displayOrder ?? this.displayOrder,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [question, answer, displayOrder, status];
}

class CategoryEntity extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String titleHindi;
  final String titleEnglish;
  final String shortDescription;
  final String fullDescription;
  final String description;
  final String iconUrl;
  final String imageUrl;
  final String imageStoragePath;
  final String iconName;
  final String colorHex;

  // Category Information
  final String aboutCategory;
  final List<String> whatIncludes;
  final List<String> commonProblems;
  final String whoNeeds;
  final String whenToContact;

  // Services
  final List<String> subServices;
  final List<String> benefits;
  final List<String> includedServices;
  final List<String> excludedServices;

  // Pricing
  final String pricingType; // 'fixed', 'starting_from', 'inspection', 'contact_provider'
  final double? startingPrice;
  final String priceUnit;
  final String priceNote;

  // Duration
  final String estimatedDuration;

  // Requirements
  final String customerRequirements;
  final bool customerPhotoRequired;
  final String providerRequirements;
  final List<String> requiredSkills;
  final bool experienceCertificateRequired;
  final bool verificationRequired;
  final List<String> requiredDocuments;

  // FAQs
  final List<CategoryFaq> faqs;

  // Safety & Notes
  final String safetyInstructions;
  final String importantNotes;
  final String disclaimer;

  // Search & Visibility
  final List<String> searchKeywords;
  final List<String> tags;
  final int sortOrder;
  final int priorityOrder;
  final CategoryStatus status;
  final bool isFeatured;
  final bool isDeleted;

  // Audit
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? deletedBy;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.slug,
    this.titleHindi = '',
    this.titleEnglish = '',
    this.shortDescription = '',
    this.fullDescription = '',
    this.description = '',
    this.iconUrl = '',
    this.imageUrl = '',
    this.imageStoragePath = '',
    this.iconName = 'build',
    this.colorHex = '#4F46E5',
    this.aboutCategory = '',
    this.whatIncludes = const [],
    this.commonProblems = const [],
    this.whoNeeds = '',
    this.whenToContact = '',
    this.subServices = const [],
    this.benefits = const [],
    this.includedServices = const [],
    this.excludedServices = const [],
    this.pricingType = 'contact_provider',
    this.startingPrice,
    this.priceUnit = '',
    this.priceNote = '',
    this.estimatedDuration = '',
    this.customerRequirements = '',
    this.customerPhotoRequired = false,
    this.providerRequirements = '',
    this.requiredSkills = const [],
    this.experienceCertificateRequired = false,
    this.verificationRequired = false,
    this.requiredDocuments = const [],
    this.faqs = const [],
    this.safetyInstructions = '',
    this.importantNotes = '',
    this.disclaimer = '',
    this.searchKeywords = const [],
    this.tags = const [],
    this.sortOrder = 0,
    this.priorityOrder = 0,
    this.status = CategoryStatus.active,
    this.isFeatured = false,
    this.isDeleted = false,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.deletedBy,
  });

  bool get isActive => status == CategoryStatus.active && !isDeleted;
  bool get isInactive => status == CategoryStatus.inactive && !isDeleted;
  bool get isArchived => status == CategoryStatus.archived || isDeleted;

  CategoryEntity copyWith({
    String? id,
    String? name,
    String? slug,
    String? titleHindi,
    String? titleEnglish,
    String? shortDescription,
    String? fullDescription,
    String? description,
    String? iconUrl,
    String? imageUrl,
    String? imageStoragePath,
    String? iconName,
    String? colorHex,
    String? aboutCategory,
    List<String>? whatIncludes,
    List<String>? commonProblems,
    String? whoNeeds,
    String? whenToContact,
    List<String>? subServices,
    List<String>? benefits,
    List<String>? includedServices,
    List<String>? excludedServices,
    String? pricingType,
    double? startingPrice,
    String? priceUnit,
    String? priceNote,
    String? estimatedDuration,
    String? customerRequirements,
    bool? customerPhotoRequired,
    String? providerRequirements,
    List<String>? requiredSkills,
    bool? experienceCertificateRequired,
    bool? verificationRequired,
    List<String>? requiredDocuments,
    List<CategoryFaq>? faqs,
    String? safetyInstructions,
    String? importantNotes,
    String? disclaimer,
    List<String>? searchKeywords,
    List<String>? tags,
    int? sortOrder,
    int? priorityOrder,
    CategoryStatus? status,
    bool? isFeatured,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deletedBy,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      titleHindi: titleHindi ?? this.titleHindi,
      titleEnglish: titleEnglish ?? this.titleEnglish,
      shortDescription: shortDescription ?? this.shortDescription,
      fullDescription: fullDescription ?? this.fullDescription,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      imageStoragePath: imageStoragePath ?? this.imageStoragePath,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      aboutCategory: aboutCategory ?? this.aboutCategory,
      whatIncludes: whatIncludes ?? this.whatIncludes,
      commonProblems: commonProblems ?? this.commonProblems,
      whoNeeds: whoNeeds ?? this.whoNeeds,
      whenToContact: whenToContact ?? this.whenToContact,
      subServices: subServices ?? this.subServices,
      benefits: benefits ?? this.benefits,
      includedServices: includedServices ?? this.includedServices,
      excludedServices: excludedServices ?? this.excludedServices,
      pricingType: pricingType ?? this.pricingType,
      startingPrice: startingPrice ?? this.startingPrice,
      priceUnit: priceUnit ?? this.priceUnit,
      priceNote: priceNote ?? this.priceNote,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      customerRequirements: customerRequirements ?? this.customerRequirements,
      customerPhotoRequired: customerPhotoRequired ?? this.customerPhotoRequired,
      providerRequirements: providerRequirements ?? this.providerRequirements,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      experienceCertificateRequired: experienceCertificateRequired ?? this.experienceCertificateRequired,
      verificationRequired: verificationRequired ?? this.verificationRequired,
      requiredDocuments: requiredDocuments ?? this.requiredDocuments,
      faqs: faqs ?? this.faqs,
      safetyInstructions: safetyInstructions ?? this.safetyInstructions,
      importantNotes: importantNotes ?? this.importantNotes,
      disclaimer: disclaimer ?? this.disclaimer,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      tags: tags ?? this.tags,
      sortOrder: sortOrder ?? this.sortOrder,
      priorityOrder: priorityOrder ?? this.priorityOrder,
      status: status ?? this.status,
      isFeatured: isFeatured ?? this.isFeatured,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        titleHindi,
        titleEnglish,
        shortDescription,
        fullDescription,
        description,
        iconUrl,
        imageUrl,
        imageStoragePath,
        iconName,
        colorHex,
        aboutCategory,
        whatIncludes,
        commonProblems,
        whoNeeds,
        whenToContact,
        subServices,
        benefits,
        includedServices,
        excludedServices,
        pricingType,
        startingPrice,
        priceUnit,
        priceNote,
        estimatedDuration,
        customerRequirements,
        customerPhotoRequired,
        providerRequirements,
        requiredSkills,
        experienceCertificateRequired,
        verificationRequired,
        requiredDocuments,
        faqs,
        safetyInstructions,
        importantNotes,
        disclaimer,
        searchKeywords,
        tags,
        sortOrder,
        priorityOrder,
        status,
        isFeatured,
        isDeleted,
        createdAt,
        updatedAt,
        deletedAt,
        deletedBy,
      ];
}
