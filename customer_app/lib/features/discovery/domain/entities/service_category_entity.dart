import 'package:equatable/equatable.dart';

class CustomerCategoryFaq extends Equatable {
  final String question;
  final String answer;

  const CustomerCategoryFaq({
    required this.question,
    required this.answer,
  });

  factory CustomerCategoryFaq.fromMap(Map<String, dynamic> map) {
    return CustomerCategoryFaq(
      question: (map['question'] as String?) ?? '',
      answer: (map['answer'] as String?) ?? '',
    );
  }

  @override
  List<Object?> get props => [question, answer];
}

class ServiceCategoryEntity extends Equatable {
  final String id;
  final String titleHindi;
  final String titleEnglish;
  final String description;
  final String shortDescription;
  final String fullDescription;
  final String aboutCategory;
  final String imageUrl;
  final String iconName;
  final String colorHex;
  final int priorityOrder;
  final bool isActive;
  final bool isFeatured;
  final List<String> subServices;
  final List<String> benefits;
  final List<String> commonProblems;
  final String pricingType;
  final double? startingPrice;
  final String priceUnit;
  final String estimatedDuration;
  final String customerRequirements;
  final bool customerPhotoRequired;
  final String safetyInstructions;
  final String importantNotes;
  final List<CustomerCategoryFaq> faqs;
  final bool isPremium;
  final String categoryType;

  const ServiceCategoryEntity({
    required this.id,
    required this.titleHindi,
    required this.titleEnglish,
    this.description = '',
    this.shortDescription = '',
    this.fullDescription = '',
    this.aboutCategory = '',
    this.imageUrl = '',
    required this.iconName,
    required this.colorHex,
    required this.priorityOrder,
    this.isActive = true,
    this.isFeatured = false,
    this.subServices = const [],
    this.benefits = const [],
    this.commonProblems = const [],
    this.pricingType = 'contact_provider',
    this.startingPrice,
    this.priceUnit = '',
    this.estimatedDuration = '',
    this.customerRequirements = '',
    this.customerPhotoRequired = false,
    this.safetyInstructions = '',
    this.importantNotes = '',
    this.faqs = const [],
    this.isPremium = false,
    this.categoryType = 'general',
  });

  /// Whether this category represents an authoritative Premium Category (e.g. Unisex Salon)
  bool get isPremiumCategory {
    if (isPremium || categoryType.toLowerCase() == 'premium') return true;
    final catId = id.toLowerCase().trim();
    final titleEn = titleEnglish.toLowerCase().trim();
    final titleHi = titleHindi.toLowerCase().trim();
    return catId == 'unisex_salon' ||
        catId == 'salon' ||
        titleEn.contains('unisex') ||
        titleHi.contains('यूनिसेक्स');
  }

  @override
  List<Object?> get props => [
        id,
        titleHindi,
        titleEnglish,
        description,
        shortDescription,
        fullDescription,
        aboutCategory,
        imageUrl,
        iconName,
        colorHex,
        priorityOrder,
        isActive,
        isFeatured,
        subServices,
        benefits,
        commonProblems,
        pricingType,
        startingPrice,
        priceUnit,
        estimatedDuration,
        customerRequirements,
        customerPhotoRequired,
        safetyInstructions,
        importantNotes,
        faqs,
        isPremium,
        categoryType,
      ];
}
