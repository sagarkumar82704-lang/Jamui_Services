import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/config/razorpay_payment_config.dart';
import '../../../subscription/presentation/services/razorpay_checkout_service.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';

class ProfessionalShopSubscriptionPage extends StatefulWidget {
  final ProfessionalShopProfileEntity shop;
  final ProfessionalProviderRemoteDataSource? dataSource;
  final RazorpayCheckoutService? checkoutService;

  const ProfessionalShopSubscriptionPage({
    super.key,
    required this.shop,
    this.dataSource,
    this.checkoutService,
  });

  @override
  State<ProfessionalShopSubscriptionPage> createState() =>
      _ProfessionalShopSubscriptionPageState();
}

class _ProfessionalShopSubscriptionPageState
    extends State<ProfessionalShopSubscriptionPage> {
  late final ProfessionalProviderRemoteDataSource _dataSource;
  late final RazorpayCheckoutService _checkoutService;
  late ProfessionalShopProfileEntity _currentShop;
  StreamSubscription? _shopStreamSub;

  List<Map<String, dynamic>> _plans = [];
  bool _isLoadingPlans = true;
  bool _isProcessingPayment = false;
  String? _processingPlanId;
  Map<String, dynamic>? _selectedPlan;
  String? _currentOrderId;

  Map<String, dynamic>? _pendingVerification;
  Map<String, dynamic>? _pendingRetryPayment;

  @override
  void initState() {
    super.initState();
    _currentShop = widget.shop;
    _dataSource = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    _checkoutService =
        widget.checkoutService ?? RazorpayCheckoutService();

    _checkoutService.init(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onDismiss: _handlePaymentDismissed,
      onExternalWallet: _handleExternalWallet,
    );

    _subscribeToShopUpdates();
    _fetchPlans();
    _checkPendingRecoveryPayment();
  }

  @override
  void dispose() {
    _shopStreamSub?.cancel();
    _checkoutService.clear();
    super.dispose();
  }

  void _subscribeToShopUpdates() {
    try {
      _shopStreamSub = _dataSource
          .streamShopProfile(_currentShop.id, ownerUid: _currentShop.ownerUid)
          .listen((updatedShop) {
        if (updatedShop != null && mounted) {
          setState(() {
            _currentShop = updatedShop;
          });
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _fetchPlans() async {
    final plans = await _dataSource.fetchPublishedSubscriptionPlans();
    if (mounted) {
      setState(() {
        _plans = plans;
        _isLoadingPlans = false;
      });
    }
  }

  Future<void> _checkPendingRecoveryPayment() async {
    final pending =
        await _dataSource.fetchLatestPendingPayment(_currentShop.id);
    if (pending != null && mounted) {
      setState(() {
        _pendingRetryPayment = pending;
      });
    }
  }

  Future<void> _startPayment(Map<String, dynamic> plan) async {
    if (_isProcessingPayment) return;

    final planId = plan['id']?.toString() ?? '';
    final planName = plan['name']?.toString() ?? 'Pro Plan';
    if (planId.isEmpty) return;

    setState(() {
      _isProcessingPayment = true;
      _processingPlanId = planId;
      _selectedPlan = plan;
    });

    try {
      // 1. Authoritative Server-side Order Creation via Cloud Functions
      // Strictly sends only shopId and planId
      final orderRes = await _dataSource.createProfessionalSubscriptionOrder(
        shopId: _currentShop.id,
        planId: planId,
      );

      final orderId = orderRes['orderId']?.toString();
      if (orderId == null || !orderId.startsWith('order_')) {
        throw Exception('Server did not return a valid Razorpay Order ID.');
      }
      _currentOrderId = orderId;

      final keyId = (orderRes['keyId']?.toString().isNotEmpty ?? false)
          ? orderRes['keyId'].toString()
          : RazorpayPaymentConfig.keyId;

      final num? serverAmount = (orderRes['amount'] as num?) ??
          (orderRes['amountInPaise'] as num?);
      final int amountInPaise = (orderRes['amountInPaise'] as num?)?.toInt() ??
          ((serverAmount ?? 0) * 100).toInt();

      final currency = orderRes['currency']?.toString() ?? 'INR';
      final duration = (orderRes['durationDays'] as num?)?.toInt() ?? 30;

      // 2. Validate Gateway Key
      if (keyId.isEmpty ||
          keyId.contains('placeholder') ||
          keyId.contains('YOUR_KEY')) {
        if (!mounted) return;
        setState(() {
          _isProcessingPayment = false;
          _processingPlanId = null;
        });
        _showGatewayUnavailableDialog();
        return;
      }

      // 3. Launch Cross-Platform Razorpay Checkout
      final phone = _currentShop.ownerPhone.isNotEmpty
          ? _currentShop.ownerPhone
          : (_currentShop.contactPhone.isNotEmpty
              ? _currentShop.contactPhone
              : '');
      final email = _currentShop.ownerEmail.isNotEmpty
          ? _currentShop.ownerEmail
          : 'seller@jamuiservices.com';

      final options = <String, dynamic>{
        'key': keyId,
        'amount': amountInPaise,
        'currency': currency,
        'name': 'Jamui Services',
        'description': '$planName ($duration Days)',
        'order_id': orderId,
        'prefill': {
          'contact': phone,
          'email': email,
        },
        'theme': {
          'color': '#0F766E',
        },
        'modal': {
          'confirm_close': true,
        },
        'retry': {
          'enabled': true,
          'max_count': 3,
        },
        'notes': {
          'shopId': _currentShop.id,
          'planId': planId,
          'type': 'professional_subscription',
        },
      };

      try {
        _checkoutService.open(options);
        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
            _processingPlanId = null;
          });
        }
      } catch (sdkError) {
        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
            _processingPlanId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open payment gateway: $sdkError'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _processingPlanId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to initiate subscription payment: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _handlePaymentSuccess(
      String paymentId, String orderId, String signature) async {
    final activeOrderId = orderId.isNotEmpty ? orderId : _currentOrderId;
    final plan = _selectedPlan;
    final planId = plan?['id'] as String? ?? '';

    if (activeOrderId == null || activeOrderId.isEmpty || paymentId.isEmpty) {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _processingPlanId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Invalid payment response: Missing order or payment ID from gateway.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    _pendingVerification = {
      'shopId': _currentShop.id,
      'planId': planId,
      'razorpayOrderId': activeOrderId,
      'razorpayPaymentId': paymentId,
      'razorpaySignature': signature,
    };

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF0F766E)),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Verifying payment with server...\nPlease do not close.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final verifyResult =
          await _dataSource.verifyProfessionalSubscriptionPayment(
        shopId: _currentShop.id,
        planId: planId,
        razorpayOrderId: activeOrderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _pendingVerification = null;
      _pendingRetryPayment = null;

      final freshProfile = await _dataSource.fetchShopProfile(_currentShop.id);
      if (freshProfile != null && mounted) {
        setState(() {
          _currentShop = freshProfile;
        });
      }

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _processingPlanId = null;
        });

        final isShopApproved =
            _currentShop.isApproved || _currentShop.status == 'approved';
        final planName = verifyResult['planName'] as String? ??
            plan?['name'] as String? ??
            'Pro Plan';
        final duration = verifyResult['durationDays'] as num? ??
            plan?['durationDays'] as num? ??
            30;

        _showSuccessActivationDialog(planName, duration.toInt(), isShopApproved);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _processingPlanId = null;
        });

        final errMsg = e.toString();
        final isTimeout = errMsg.toLowerCase().contains('timeout') ||
            errMsg.toLowerCase().contains('network') ||
            errMsg.toLowerCase().contains('connection');

        _showVerificationErrorDialog(errMsg, isTimeout);
      }
    }
  }

  void _handlePaymentDismissed() {
    if (!mounted) return;
    setState(() {
      _isProcessingPayment = false;
      _processingPlanId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment cancelled by user. No amount was deducted.'),
        backgroundColor: Color(0xFFF59E0B),
      ),
    );
  }

  void _handlePaymentError(int code, String message) {
    if (!mounted) return;
    setState(() {
      _isProcessingPayment = false;
      _processingPlanId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed ($code): $message'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  void _handleExternalWallet(String walletName) {
    debugPrint('💳 [Razorpay] External wallet selected: $walletName');
  }

  Future<void> _retryVerification() async {
    final pending = _pendingVerification ?? _pendingRetryPayment;
    if (pending == null) return;

    final orderId = pending['razorpayOrderId'] as String? ??
        pending['orderId'] as String? ??
        '';
    final paymentId = pending['razorpayPaymentId'] as String? ??
        pending['paymentId'] as String? ??
        '';
    final signature = pending['razorpaySignature'] as String? ??
        pending['signature'] as String? ??
        '';

    if (orderId.isEmpty || paymentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid pending payment found to re-verify.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    _handlePaymentSuccess(paymentId, orderId, signature);
  }

  void _showGatewayUnavailableDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 8),
            Text('Gateway Unavailable'),
          ],
        ),
        content: const Text(
          'Razorpay payment gateway is currently unavailable. Please contact Jamui Services support.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessActivationDialog(
      String planName, int durationDays, bool isShopApproved) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text('Subscription Activated!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan: $planName ($durationDays Days)',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your subscription payment has been verified successfully.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isShopApproved
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isShopApproved
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isShopApproved
                        ? Icons.storefront_rounded
                        : Icons.hourglass_top_rounded,
                    color: isShopApproved
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isShopApproved
                          ? 'Your shop is approved and active! Customers on Jamui Services can now discover your products.'
                          : 'Your shop registration is pending Admin Approval. Once approved, your products will be published immediately on the customer marketplace.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isShopApproved
                            ? const Color(0xFF065F46)
                            : const Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showVerificationErrorDialog(String errMsg, bool isTimeout) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text('Payment Verification Notice',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          isTimeout
              ? 'Your payment was captured by Razorpay, but server verification timed out. Your money is safe! Please do NOT pay again. Tap "Retry Verification" below to activate your plan.'
              : 'Payment verification failed: $errMsg\nPlease tap "Retry Verification" to complete activation.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _retryVerification();
            },
            child: const Text('Retry Verification'),
          ),
        ],
      ),
    );
  }

  String _buildValidityText() {
    if (_currentShop.subscriptionExpiry == null) {
      return 'Valid Till: Unlimited';
    }
    final expiry = _currentShop.subscriptionExpiry!;
    final formattedDate =
        '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
    final now = DateTime.now();
    final difference = expiry.difference(now);

    if (difference.isNegative) {
      final daysAgo = (-difference.inDays);
      return 'Expired on: $formattedDate (${daysAgo == 0 ? "today" : "$daysAgo days ago"})';
    } else {
      final daysRemaining = difference.inDays;
      if (daysRemaining == 0) {
        return 'Valid Till: $formattedDate (Expires today)';
      } else if (daysRemaining <= 5) {
        return 'Valid Till: $formattedDate ($daysRemaining days left — Expiring Soon!)';
      } else {
        return 'Valid Till: $formattedDate ($daysRemaining days remaining)';
      }
    }
  }

  String _getPlanButtonText(Map<String, dynamic> plan) {
    final planId = plan['id'];
    final isCurrentPlan = _currentShop.subscriptionPlanId == planId ||
        _currentShop.subscriptionPlanName == plan['name'];

    if (_currentShop.isSubscriptionActive) {
      if (isCurrentPlan) {
        return 'Renew Plan';
      } else {
        return 'Switch to this Plan';
      }
    } else {
      if (_currentShop.subscriptionExpiry != null) {
        return 'Renew Subscription';
      } else {
        return 'Subscribe Now';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Shop Subscription Plans',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Plan Overview Card
            _buildCurrentPlanCard(),

            const SizedBox(height: 16),

            // Pending Verification Recovery Banner (if any)
            _buildRecoveryBanner(),

            // Admin Approval Separation Notice Banner
            _buildApprovalNoticeBanner(),

            // Available Plans Section
            const Text(
              'Available Plans (Managed by Admin)',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),

            if (_isLoadingPlans)
              const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0F766E)))
            else if (_plans.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.workspace_premium_outlined,
                        size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text(
                      'No subscription plans available currently.',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _plans.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (ctx, i) => _buildPlanCard(_plans[i]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    final isShopApproved =
        _currentShop.isApproved || _currentShop.status == 'approved';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0F766E).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _currentShop.subscriptionPlanName.isNotEmpty
                      ? _currentShop.subscriptionPlanName
                      : 'Free Plan',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _currentShop.isSubscriptionActive
                          ? const Color(0xFF10B981)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currentShop.isSubscriptionActive ? 'ACTIVE' : 'EXPIRED',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isShopApproved
                          ? Colors.white24
                          : const Color(0xFFF59E0B).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isShopApproved ? 'Approved' : 'Pending Approval',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Products Allowed: Up to ${_currentShop.maxProductsLimit} products',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 3),
          Text(
            'Images: Up to ${_currentShop.imageLimit} / month  •  Storage: ${_currentShop.storageLimitMb} MB',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Text(
            _buildValidityText(),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryBanner() {
    final pending = _pendingVerification ?? _pendingRetryPayment;
    if (pending == null) return const SizedBox.shrink();

    final orderId = pending['razorpayOrderId'] as String? ??
        pending['orderId'] as String? ??
        '';
    final amount = pending['amount'] as num?;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_problem_rounded,
                  color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pending Payment Verification ${amount != null ? "(₹$amount)" : ""}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Order $orderId was captured by gateway. Tap below to complete activation without paying again.',
            style: const TextStyle(
                fontSize: 12.5, color: Color(0xFF78350F), height: 1.3),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _isProcessingPayment ? null : _retryVerification,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Verify Payment Now',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalNoticeBanner() {
    final isShopApproved =
        _currentShop.isApproved || _currentShop.status == 'approved';
    if (isShopApproved) return const SizedBox.shrink();

    final isPaid = _currentShop.isSubscriptionActive;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPaid
                ? Icons.info_outline_rounded
                : Icons.pending_actions_rounded,
            color: isPaid ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPaid
                      ? 'Subscription Active — Pending Admin Approval'
                      : 'Pending Admin Approval',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: isPaid
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPaid
                      ? 'Your subscription is active! Your shop is pending Admin Approval before appearing in the customer marketplace.'
                      : 'Your shop registration is under Admin review. You can subscribe to a Pro Plan in advance so your shop goes live immediately once approved.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPaid
                        ? const Color(0xFF1E3A8A)
                        : const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final planId = plan['id']?.toString() ?? '';
    final name = plan['name'] ?? 'Shop Plan';
    final price = (plan['price'] as num?)?.toInt() ?? 199;
    final durationDays = plan['durationDays'] as num?;
    final maxProd = plan['maxProducts'] ?? plan['productLimit'] ?? 50;
    final imagesMonth =
        plan['maxImagesPerMonth'] ?? plan['imageLimit'] ?? 100;
    final storageMb = plan['storageMb'] ?? plan['storageLimitMb'] ?? 100;

    final isThisPlanProcessing =
        _isProcessingPayment && _processingPlanId == planId;
    final buttonText = _getPlanButtonText(plan);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B))),
              ),
              Text('₹$price',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F766E))),
            ],
          ),
          const Divider(height: 20),
          _buildFeatureRow(durationDays != null && durationDays > 0
              ? 'Duration: ${durationDays.toInt()} Days'
              : 'Duration: Duration not configured'),
          _buildFeatureRow('Catalog Limit: $maxProd products'),
          _buildFeatureRow('Product Images: Up to $imagesMonth / month'),
          _buildFeatureRow('Cloud Storage: $storageMb MB included'),
          _buildFeatureRow('Home Delivery & Pickup enabled'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isProcessingPayment
                  ? null
                  : () => _startPayment(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isThisPlanProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF0F766E), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }
}
