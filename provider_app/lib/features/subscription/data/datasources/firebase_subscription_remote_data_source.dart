import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/subscription_plan_model.dart';
import 'subscription_remote_data_source.dart';

/// Production-Grade Secure Remote Data Source for Subscriptions & Payments
/// Powered by Firebase Cloud Functions & Cloud Firestore
class FirebaseSubscriptionRemoteDataSource implements SubscriptionRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String _backendBaseUrl;

  FirebaseSubscriptionRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    String? backendBaseUrl,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1'),
        _backendBaseUrl = backendBaseUrl ??
            (const String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '').isNotEmpty
                ? const String.fromEnvironment('BACKEND_BASE_URL')
                : (kIsWeb
                    ? 'http://localhost:8000'
                    : (defaultTargetPlatform == TargetPlatform.android
                        ? 'http://10.0.2.2:8000'
                        : 'http://localhost:8000')));

  @override
  Future<List<SubscriptionPlanModel>> fetchPlans({String? providerId, String? planTier}) async {
    // 1. Try fetching from Firebase Cloud Functions (tailored by server-side eligibility)
    try {
      final callable = _functions.httpsCallable('getSubscriptionPlans');
      final reqData = <String, dynamic>{
        'providerId': ?providerId,
        'planTier': ?planTier,
      };
      final result = await callable.call(reqData).timeout(const Duration(seconds: 5));
      if (result.data is Map && result.data['plans'] is List) {
        final list = result.data['plans'] as List<dynamic>;
        var plans = list.map((item) => SubscriptionPlanModel.fromMap(Map<String, dynamic>.from(item), item['id'] ?? '')).where((p) => p.isValid).toList();
        if (planTier != null && planTier.isNotEmpty) {
          plans = plans.where((p) => p.planTier == planTier).toList();
        }
        return plans;
      } else if (result.data is List) {
        final list = result.data as List<dynamic>;
        var plans = list.map((item) => SubscriptionPlanModel.fromMap(Map<String, dynamic>.from(item), item['id'] ?? '')).where((p) => p.isValid).toList();
        if (planTier != null && planTier.isNotEmpty) {
          plans = plans.where((p) => p.planTier == planTier).toList();
        }
        return plans;
      }
    } catch (e) {
      debugPrint('⚠️ [Subscription] Cloud Functions fetch error: $e. Trying Firestore directly...');
    }

    // 2. Try fetching directly from Firestore collection 'subscription_plans'
    try {
      final snapshot = await _firestore.collection('subscription_plans').where('isActive', isEqualTo: true).get();
      if (snapshot.docs.isNotEmpty) {
        var plans = snapshot.docs
            .map((doc) => SubscriptionPlanModel.fromMap(doc.data(), doc.id))
            .where((p) => p.isValid)
            .toList();
        if (planTier != null && planTier.isNotEmpty) {
          plans = plans.where((p) => p.planTier == planTier).toList();
        }
        if (plans.isNotEmpty) return plans;
      }
    } catch (e) {
      debugPrint('⚠️ [Subscription] Firestore fetch error: $e. Trying backend API...');
    }

    // 3. Try fetching from Backend API
    try {
      final response = await http.get(
        Uri.parse('$_backendBaseUrl/api/provider/subscription/plans'),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        var plans = list.map((json) => SubscriptionPlanModel.fromMap(json, json['id'] ?? '')).toList();
        if (planTier != null && planTier.isNotEmpty) {
          plans = plans.where((p) => p.planTier == planTier).toList();
        }
        return plans;
      }
    } catch (e) {
      debugPrint('⚠️ [Subscription] Backend API fetch error: $e');
    }

    throw Exception('सब्सक्रिप्शन प्लान्स लोड नहीं हो सके। कृपया इंटरनेट चेक करें और पुनः प्रयास करें।');
  }

  @override
  Future<Map<String, dynamic>> createRazorpayOrder({
    required String planId,
    required String providerId,
    String? phone,
    String? email,
  }) async {
    // 1. First Attempt: Firebase Cloud Functions (Authoritative)
    try {
      final callable = _functions.httpsCallable('createSubscriptionOrder');
      final result = await callable.call({
        'planId': planId,
        'providerId': providerId,
        'providerPhone': phone,
        'providerEmail': email,
      }).timeout(const Duration(seconds: 12));

      if (result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      }
    } on FirebaseFunctionsException catch (fe) {
      debugPrint('❌ [Subscription] Cloud Function createSubscriptionOrder error: ${fe.code} - ${fe.message}');
      throw Exception(fe.message ?? 'सब्सक्रिप्शन आर्डर बनाने में विफलता (${fe.code})');
    } catch (e) {
      debugPrint('⚠️ [Subscription] Firebase Cloud Function createSubscriptionOrder error: $e');
      throw Exception('पेमेंट गेटवे आर्डर बनाने में विफलता: $e');
    }

    throw Exception('आर्डर डेटा प्राप्त नहीं हो सका। कृपया पुनः प्रयास करें।');
  }

  @override
  Future<Map<String, dynamic>> verifyPayment({
    required String providerId,
    required String planId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    // 1. Firebase Cloud Functions (Cryptographic HMAC Signature Verification & Activation)
    try {
      final callable = _functions.httpsCallable('verifySubscriptionPayment');
      final result = await callable.call({
        'providerId': providerId,
        'planId': planId,
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      }).timeout(const Duration(seconds: 15));

      if (result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      }
    } on FirebaseFunctionsException catch (fe) {
      debugPrint('❌ [Subscription] Cloud Function verifySubscriptionPayment error: ${fe.code} - ${fe.message}');
      throw Exception(fe.message ?? 'भुगतान सत्यापन विफल (${fe.code})');
    } catch (e) {
      debugPrint('⚠️ [Subscription] Payment verification error: $e');
      throw Exception('भुगतान सत्यापन विफल: $e');
    }

    throw Exception('सत्यापन परिणाम प्राप्त नहीं हो सका। कृपया सहायता टीम से संपर्क करें।');
  }

  @override
  Future<Map<String, dynamic>?> getPendingApprovalPayment({required String providerId}) async {
    try {
      // 1. Authoritative check: Query payments collection for captured payment awaiting approval
      final snap = await _firestore
          .collection('payments')
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: 'success')
          .where('adminApprovalStatus', isEqualTo: 'pending_approval')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final data = doc.data();
        return {
          'id': doc.id,
          'orderId': data['orderId'] ?? doc.id,
          'paymentId': data['paymentId'] ?? data['razorpayPaymentId'] ?? '',
          'amount': data['amount'] ?? 0,
          'planName': data['planName'] ?? data['planId'] ?? 'Subscription',
          'planTier': data['planTier'] ?? 'normal',
          'adminApprovalStatus': 'pending_approval',
          'createdAt': data['createdAt'],
        };
      }

      // 2. Secondary check: Provider profile doc status
      final provDoc = await _firestore.collection('providers').doc(providerId).get();
      if (provDoc.exists && provDoc.data() != null) {
        final pData = provDoc.data()!;
        if (pData['adminApprovalStatus'] == 'pending_approval') {
          return {
            'orderId': pData['paymentOrderId'] ?? pData['renewalPendingOrderId'] ?? '',
            'paymentId': pData['lastPaymentId'] ?? '',
            'planName': pData['subscriptionPlan'] ?? '',
            'planTier': pData['subscriptionPlanTier'] ?? 'normal',
            'adminApprovalStatus': 'pending_approval',
          };
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Subscription] getPendingApprovalPayment notice: $e');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> reconcilePayment({
    required String orderId,
  }) async {
    try {
      final callable = _functions.httpsCallable('reconcileProviderSubscriptionPayment');
      final result = await callable.call({'orderId': orderId}).timeout(const Duration(seconds: 15));
      if (result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      }
    } on FirebaseFunctionsException catch (fe) {
      debugPrint('❌ [Subscription] reconcileProviderSubscriptionPayment error: ${fe.code} - ${fe.message}');
      throw Exception(fe.message ?? 'भुगतान रिकंसिलिएशन विफल (${fe.code})');
    } catch (e) {
      debugPrint('⚠️ [Subscription] Payment reconciliation error: $e');
      throw Exception('भुगतान रिकंसिलिएशन विफल: $e');
    }
    throw Exception('रिकंसिलिएशन परिणाम प्राप्त नहीं हो सका।');
  }
}

