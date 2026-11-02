import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_environment.dart';
import '../errors/failures.dart';

/// [FirestoreService] क्लाउड फायरस्टोर के साथ सुरक्षित, स्केलेबल और एनवायरनमेंट-आइसोलेटेड ऑपरेशन्स प्रदान करता है।
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// एनवायरनमेंट के अनुसार सही कलेक्शन रिफरेंस प्राप्त करें (उदा: dev_users या users)
  CollectionReference<Map<String, dynamic>> collection(String baseCollectionName) {
    final resolvedName = AppConfig.getCollectionName(baseCollectionName);
    return _firestore.collection(resolvedName);
  }

  /// डॉक्यूमेंट प्राप्त करें (Get Single Document)
  Future<Map<String, dynamic>?> getDocument({
    required String collectionName,
    required String documentId,
  }) async {
    try {
      final doc = await collection(collectionName).doc(documentId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    } on FirebaseException catch (e) {
      throw ServerFailure('Firestore Error [${e.code}]: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerFailure('डेटा लोड करने में असमर्थ: $e');
    }
  }

  /// डॉक्यूमेंट सेट/अपडेट करें (Create / Overwrite Document)
  Future<void> setDocument({
    required String collectionName,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['updatedAt'] = FieldValue.serverTimestamp();
      if (!merge) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }
      await collection(collectionName).doc(documentId).set(payload, SetOptions(merge: merge));
    } on FirebaseException catch (e) {
      throw ServerFailure('Firestore Error [${e.code}]: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerFailure('डेटा सुरक्षित करने में असमर्थ: $e');
    }
  }

  /// डॉक्यूमेंट अपडेट करें (Update Specific Fields)
  Future<void> updateDocument({
    required String collectionName,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['updatedAt'] = FieldValue.serverTimestamp();
      await collection(collectionName).doc(documentId).update(payload);
    } on FirebaseException catch (e) {
      throw ServerFailure('Firestore Error [${e.code}]: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerFailure('डेटा अपडेट करने में असमर्थ: $e');
    }
  }

  /// डॉक्यूमेंट हटाएं (Delete Document)
  Future<void> deleteDocument({
    required String collectionName,
    required String documentId,
  }) async {
    try {
      await collection(collectionName).doc(documentId).delete();
    } on FirebaseException catch (e) {
      throw ServerFailure('Firestore Error [${e.code}]: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerFailure('डेटा हटाने में असमर्थ: $e');
    }
  }

  /// पेजिनेटेड लिस्ट क्वेरी (Query Collection with Limits)
  Future<List<Map<String, dynamic>>> queryDocuments({
    required String collectionName,
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query)? queryBuilder,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query = collection(collectionName).limit(limit);
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerFailure('Firestore Error [${e.code}]: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerFailure('डेटा सूची प्राप्त करने में असमर्थ: $e');
    }
  }
}
