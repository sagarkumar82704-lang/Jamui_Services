import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// [BaseFirestoreModel] सभी Firestore डेटा मॉडलों के लिए एक सुपर-क्लास (Base Model) है।
/// यह निम्नलिखित सुरक्षा मानक सुनिश्चित करता है:
/// 1. Schema Versioning (`schemaVersion`): भविष्य में जब मॉडल में बदलाव होगा तो पुराना डेटा क्रैश नहीं होगा।
/// 2. Safe Parsing Helpers: नल-पॉइंटर और टाइप-कास्टिंग क्रैश से 100% सुरक्षा।
abstract class BaseFirestoreModel extends Equatable {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const BaseFirestoreModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = 1,
  });

  /// डेटाबेस में लिखने के लिए Map
  Map<String, dynamic> toMap();

  @override
  List<Object?> get props => [id, createdAt, updatedAt, schemaVersion];

  // ==========================================
  // SAFE PARSING HELPERS (क्रैश-प्रूफ हेल्पर्स)
  // ==========================================

  /// सुरक्षित स्ट्रिंग निकालना
  static String parseString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  /// सुरक्षित पूर्णांक (int) निकालना
  static int parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// सुरक्षित दशमलव (double) निकालना
  static double parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// सुरक्षित बूलियन (bool) निकालना
  static bool parseBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return fallback;
  }

  /// सुरक्षित तारीख (DateTime / Timestamp) निकालना
  static DateTime parseDateTime(dynamic value, [DateTime? fallback]) {
    final defaultDate = fallback ?? DateTime.now();
    if (value == null) return defaultDate;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value) ?? defaultDate;
    return defaultDate;
  }

  /// सुरक्षित लिस्ट (`List<String>`) निकालना
  static List<String> parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList();
    }
    return [];
  }
}
