import 'package:flutter_test/flutter_test.dart';


import '../../archive/legacy_monolithic_lib/shared/models/base_firestore_model.dart';

class SampleTestModel extends BaseFirestoreModel {
  final String title;
  final int count;
  final double rating;
  final bool isVerified;
  final List<String> tags;

  const SampleTestModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.schemaVersion,
    required this.title,
    required this.count,
    required this.rating,
    required this.isVerified,
    required this.tags,
  });

  factory SampleTestModel.fromMap(Map<String, dynamic> map, String docId) {
    return SampleTestModel(
      id: docId,
      createdAt: BaseFirestoreModel.parseDateTime(map['createdAt']),
      updatedAt: BaseFirestoreModel.parseDateTime(map['updatedAt']),
      schemaVersion: BaseFirestoreModel.parseInt(map['schemaVersion'], 1),
      title: BaseFirestoreModel.parseString(map['title'], 'Default Title'),
      count: BaseFirestoreModel.parseInt(map['count'], 0),
      rating: BaseFirestoreModel.parseDouble(map['rating'], 0.0),
      isVerified: BaseFirestoreModel.parseBool(map['isVerified'], false),
      tags: BaseFirestoreModel.parseStringList(map['tags']),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'title': title,
      'count': count,
      'rating': rating,
      'isVerified': isVerified,
      'tags': tags,
    };
  }
}

void main() {
  group('BaseFirestoreModel Safe Parsing Tests', () {
    test('Should safely parse completely empty / corrupted map without crash', () {
      final model = SampleTestModel.fromMap({}, 'doc_123');

      expect(model.id, 'doc_123');
      expect(model.title, 'Default Title');
      expect(model.count, 0);
      expect(model.rating, 0.0);
      expect(model.isVerified, false);
      expect(model.tags, isEmpty);
      expect(model.schemaVersion, 1);
    });

    test('Should safely parse string representations of numbers and bools', () {
      final map = {
        'title': 'Plumber Jamui',
        'count': '45',
        'rating': '4.8',
        'isVerified': 'true',
        'tags': ['plumber', 'pipe', 123], // mixed types
      };

      final model = SampleTestModel.fromMap(map, 'doc_456');

      expect(model.title, 'Plumber Jamui');
      expect(model.count, 45);
      expect(model.rating, 4.8);
      expect(model.isVerified, true);
      expect(model.tags, ['plumber', 'pipe', '123']);
    });
  });
}
