import '../models/subscription_plan_model.dart';

abstract class SubscriptionRemoteDataSource {
  Future<List<SubscriptionPlanModel>> fetchPlans({String? providerId, String? planTier});

  Future<Map<String, dynamic>> createRazorpayOrder({
    required String planId,
    required String providerId,
    String? phone,
    String? email,
  });

  Future<Map<String, dynamic>> verifyPayment({
    required String providerId,
    required String planId,
    required String orderId,
    required String paymentId,
    required String signature,
  });

  Future<Map<String, dynamic>?> getPendingApprovalPayment({
    required String providerId,
  });

  Future<Map<String, dynamic>> reconcilePayment({
    required String orderId,
  });
}
