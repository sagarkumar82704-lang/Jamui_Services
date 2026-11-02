import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead_model.dart';
import 'lead_remote_data_source.dart';

/// Real Firebase Firestore implementation of [LeadRemoteDataSource].
/// Tracks ML-required status-transition timestamps on every status change.
class FirebaseLeadRemoteDataSource implements LeadRemoteDataSource {
  final FirebaseFirestore _firestore;
  static const String _collectionName = 'leads';

  FirebaseLeadRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<LeadModel>> getLeadsStream(String providerId, {int limit = 30}) async* {
    bool fallbackNeeded = false;

    try {
      // Primary query: server-side ordered by createdAt descending with limit.
      // Limits initial read count to requested limit (default 30) instead of unbounded collection scan.
      final primaryStream = _firestore
          .collection(_collectionName)
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots();

      await for (final snapshot in primaryStream) {
        final list = snapshot.docs
            .map((doc) => LeadModel.fromMap(doc.data(), doc.id))
            .toList();

        // Consistent ordering guarantee
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield list;
      }
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Specifically missing or building composite index in Firestore
        fallbackNeeded = true;
      } else {
        rethrow;
      }
    } catch (e) {
      if (e.toString().contains('failed-precondition') ||
          e.toString().contains('index') ||
          e.toString().contains('requires an index')) {
        fallbackNeeded = true;
      } else {
        rethrow;
      }
    }

    if (fallbackNeeded) {
      // Resilient fallback: in case composite index is building or missing
      final fallbackStream = _firestore
          .collection(_collectionName)
          .where('providerId', isEqualTo: providerId)
          .snapshots();

      await for (final snapshot in fallbackStream) {
        final list = snapshot.docs
            .map((doc) => LeadModel.fromMap(doc.data(), doc.id))
            .toList();

        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (list.length > limit) {
          yield list.sublist(0, limit);
        } else {
          yield list;
        }
      }
    }
  }

  @override
  Future<void> updateLeadStatus(String leadId, String status) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(leadId);
      final snap = await docRef.get();
      final data = snap.data();

      // --- ML DATA: Write status-specific timestamp ---
      // These timestamps power: response time, acceptance rate, completion rate
      final Map<String, dynamic> updateMap = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      switch (status) {
        case 'viewed':
          // Only write viewedAt once (first time provider views it)
          if (data?['viewedAt'] == null) {
            updateMap['viewedAt'] = FieldValue.serverTimestamp();
          }
          break;
        case 'accepted':
          updateMap['acceptedAt'] = FieldValue.serverTimestamp();
          break;
        case 'rejected':
          updateMap['rejectedAt'] = FieldValue.serverTimestamp();
          break;
        case 'completed':
          updateMap['completedAt'] = FieldValue.serverTimestamp();
          break;
        case 'cancelled':
          updateMap['cancelledAt'] = FieldValue.serverTimestamp();
          break;
      }

      await docRef.update(updateMap);

      // After writing timestamps, update provider_stats for ML aggregation
      if (data != null) {
        final providerId = (data['providerId'] as String?) ?? '';
        if (providerId.isNotEmpty) {
          await _updateProviderStats(providerId: providerId, newStatus: status);
        }
      }

      // In-app notification to customer
      if (data != null) {
        final customerId = (data['customerId'] as String?) ?? '';
        final providerName =
            (data['providerName'] ?? data['businessName'] ?? 'कारीगर').toString();

        if (customerId.isNotEmpty) {
          String notifTitle = 'सेवा अनुरोध अपडेट';
          String notifMsg = 'आपके अनुरोध की स्थिति अपडेट हो गई है।';

          if (status == 'accepted') {
            notifTitle = 'सेवा अनुरोध स्वीकृत! 🟢';
            notifMsg =
                '$providerName ने आपका सेवा अनुरोध स्वीकार कर लिया है। वे जल्द ही आपसे संपर्क करेंगे।';
          } else if (status == 'completed') {
            notifTitle = 'कार्य पूर्ण हुआ! ⭐ कृपया रेटिंग दें';
            notifMsg =
                '$providerName ने कार्य पूरा किया है। अपना अनुभव व रेटिंग दर्ज करें।';
          } else if (status == 'rejected') {
            notifTitle = 'सेवा अनुरोध अस्वीकृत ❌';
            notifMsg =
                'कारीगर इस समय व्यस्त होने के कारण अनुरोध स्वीकार नहीं कर सके। कृपया अन्य कारीगर चुनें।';
          }

          await _firestore.collection('notifications').add({
            'userId': customerId,
            'title': notifTitle,
            'message': notifMsg,
            'type': 'lead_$status',
            'leadId': leadId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      // Fallback: simple status update without ML tracking
      await _firestore.collection(_collectionName).doc(leadId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Updates the [provider_stats] denormalized document for a given provider.
  ///
  /// This document is the primary input for the ML provider scoring system.
  /// It stores aggregated counters so scoring can happen without reading all leads.
  ///
  /// Structure of `provider_stats/{providerId}`:
  ///   totalLeadsReceived, totalAccepted, totalRejected, totalCompleted,
  ///   totalCancelled, lastLeadAt, statsUpdatedAt
  Future<void> _updateProviderStats({
    required String providerId,
    required String newStatus,
  }) async {
    try {
      final statsRef =
          _firestore.collection('provider_stats').doc(providerId);

      final Map<String, dynamic> statsUpdate = {
        'statsUpdatedAt': FieldValue.serverTimestamp(),
        'lastLeadAt': FieldValue.serverTimestamp(),
      };

      switch (newStatus) {
        case 'pending':
        case 'newLead':
          statsUpdate['totalLeadsReceived'] = FieldValue.increment(1);
          break;
        case 'accepted':
          statsUpdate['totalAccepted'] = FieldValue.increment(1);
          break;
        case 'rejected':
          statsUpdate['totalRejected'] = FieldValue.increment(1);
          break;
        case 'completed':
          statsUpdate['totalCompleted'] = FieldValue.increment(1);
          break;
        case 'cancelled':
          statsUpdate['totalCancelled'] = FieldValue.increment(1);
          break;
      }

      await statsRef.set(statsUpdate, SetOptions(merge: true));
    } catch (_) {
      // Stats update failure should NOT break lead status update
    }
  }
}
