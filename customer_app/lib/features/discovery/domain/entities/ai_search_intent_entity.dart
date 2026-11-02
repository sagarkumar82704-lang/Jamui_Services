import 'package:equatable/equatable.dart';

enum AISearchIntentType {
  serviceSearch,
  clarificationRequired,
  noMatch,
}

class AISearchIntentEntity extends Equatable {
  final AISearchIntentType intentType;
  final String? categoryId;
  final String? categoryTitleHindi;
  final String? categoryTitleEnglish;
  final String? serviceId;
  final String? serviceTitle;
  final String? extractedProblem;
  final String? extractedArea;
  final bool isUrgent;
  final double confidence;
  final List<String> suggestedSubServices;
  final String? clarificationMessage;

  const AISearchIntentEntity({
    required this.intentType,
    this.categoryId,
    this.categoryTitleHindi,
    this.categoryTitleEnglish,
    this.serviceId,
    this.serviceTitle,
    this.extractedProblem,
    this.extractedArea,
    this.isUrgent = false,
    this.confidence = 1.0,
    this.suggestedSubServices = const [],
    this.clarificationMessage,
  });

  bool get isDirectMatch =>
      intentType == AISearchIntentType.serviceSearch &&
      categoryId != null &&
      confidence >= 0.70;

  bool get isMediumConfidence =>
      intentType == AISearchIntentType.serviceSearch &&
      categoryId != null &&
      confidence >= 0.40 &&
      confidence < 0.70;

  bool get needsClarification =>
      intentType == AISearchIntentType.clarificationRequired ||
      confidence < 0.40;

  @override
  List<Object?> get props => [
        intentType,
        categoryId,
        categoryTitleHindi,
        categoryTitleEnglish,
        serviceId,
        serviceTitle,
        extractedProblem,
        extractedArea,
        isUrgent,
        confidence,
        suggestedSubServices,
        clarificationMessage,
      ];
}
