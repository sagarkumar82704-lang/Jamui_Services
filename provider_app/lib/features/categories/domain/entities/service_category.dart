import 'package:equatable/equatable.dart';

class ServiceCategory extends Equatable {
  final String id;
  final String titleHindi;
  final String titleEnglish;
  final String description;
  final String shortDescription;
  final String imageUrl;
  final String iconName;
  final String colorHex;
  final int priorityOrder;
  final String status;
  final bool isDeleted;
  final bool isActive;
  final List<String> subServices;
  final String providerRequirements;
  final bool experienceCertificateRequired;
  final bool verificationRequired;
  final bool isPremium;
  final String categoryType; // 'general', 'premium'

  const ServiceCategory({
    required this.id,
    required this.titleHindi,
    required this.titleEnglish,
    this.description = '',
    this.shortDescription = '',
    this.imageUrl = '',
    required this.iconName,
    required this.colorHex,
    required this.priorityOrder,
    this.status = 'active',
    this.isDeleted = false,
    this.isActive = true,
    this.subServices = const [],
    this.providerRequirements = '',
    this.experienceCertificateRequired = false,
    this.verificationRequired = false,
    this.isPremium = false,
    this.categoryType = 'general',
  });

  @override
  List<Object?> get props => [
        id,
        titleHindi,
        titleEnglish,
        description,
        shortDescription,
        imageUrl,
        iconName,
        colorHex,
        priorityOrder,
        status,
        isDeleted,
        isActive,
        subServices,
        providerRequirements,
        experienceCertificateRequired,
        verificationRequired,
        isPremium,
        categoryType,
      ];
}
