import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Provider-defined reusable custom variant type (e.g. Size, Color, Pack, Storage)
class CustomVariantTypeDefinition extends Equatable {
  final String key;
  final String label;
  final String displayType; // "pills", "color_swatch", "dropdown"
  final List<String> suggestedValues;

  const CustomVariantTypeDefinition({
    required this.key,
    required this.label,
    this.displayType = 'pills',
    this.suggestedValues = const [],
  });

  factory CustomVariantTypeDefinition.fromMap(Map<String, dynamic> map) {
    return CustomVariantTypeDefinition(
      key: (map['key'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      displayType: (map['displayType'] ?? 'pills').toString(),
      suggestedValues: (map['suggestedValues'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'label': label,
      'displayType': displayType,
      'suggestedValues': suggestedValues,
    };
  }

  @override
  List<Object?> get props => [key, label, displayType, suggestedValues];
}

/// Provider-defined custom field definition (e.g. Fabric, Battery, Expiry)
class CustomFieldDefinition extends Equatable {
  final String key;
  final String label;
  final String fieldType; // "text", "number", "dropdown", "date", "boolean"
  final List<String> options;
  final bool isRequired;

  const CustomFieldDefinition({
    required this.key,
    required this.label,
    this.fieldType = 'text',
    this.options = const [],
    this.isRequired = false,
  });

  factory CustomFieldDefinition.fromMap(Map<String, dynamic> map) {
    return CustomFieldDefinition(
      key: (map['key'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      fieldType: (map['fieldType'] ?? 'text').toString(),
      options: (map['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isRequired: (map['isRequired'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'label': label,
      'fieldType': fieldType,
      'options': options,
      'isRequired': isRequired,
    };
  }

  @override
  List<Object?> get props => [key, label, fieldType, options, isRequired];
}

/// Provider-Configurable Template for Attributes & Variant Types
/// Storage: `diamond_shops/{shopId}/attribute_templates/{templateId}`
class CustomAttributeTemplateEntity extends Equatable {
  final String id;
  final String shopId;
  final String name;
  final String targetCategory;
  final List<CustomVariantTypeDefinition> customVariantTypes;
  final List<CustomFieldDefinition> customFields;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomAttributeTemplateEntity({
    required this.id,
    required this.shopId,
    required this.name,
    this.targetCategory = 'General',
    this.customVariantTypes = const [],
    this.customFields = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory CustomAttributeTemplateEntity.fromMap(Map<String, dynamic> map, String id, {required String shopId}) {
    DateTime? created;
    DateTime? updated;
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) created = rawCreated.toDate();
    if (rawCreated is String) created = DateTime.tryParse(rawCreated);
    final rawUpdated = map['updatedAt'];
    if (rawUpdated is Timestamp) updated = rawUpdated.toDate();
    if (rawUpdated is String) updated = DateTime.tryParse(rawUpdated);

    final rawVariants = (map['customVariantTypes'] as List<dynamic>?) ?? const [];
    final parsedVariants = rawVariants
        .whereType<Map>()
        .map((m) => CustomVariantTypeDefinition.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final rawFields = (map['customFields'] as List<dynamic>?) ?? const [];
    final parsedFields = rawFields
        .whereType<Map>()
        .map((m) => CustomFieldDefinition.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    return CustomAttributeTemplateEntity(
      id: id,
      shopId: shopId,
      name: (map['name'] ?? '').toString(),
      targetCategory: (map['targetCategory'] ?? 'General').toString(),
      customVariantTypes: parsedVariants,
      customFields: parsedFields,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'name': name,
      'targetCategory': targetCategory,
      'customVariantTypes': customVariantTypes.map((v) => v.toMap()).toList(),
      'customFields': customFields.map((f) => f.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [id, shopId, name, targetCategory, customVariantTypes, customFields];
}

