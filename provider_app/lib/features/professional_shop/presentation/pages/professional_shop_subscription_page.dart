import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/config/razorpay_payment_config.dart';
import '../../../subscription/presentation/services/razorpay_checkout_service.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import '../../domain/professional_entitlement_resolver.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/localization/provider_strings.dart';

/// Professional Subscription Page for Professional Marketplace Sellers.
/// Completely isolated from normal service provider subscriptions.
/// Displays Current Plan, Price, Validity, Expiry, Status, Used Limits, Features, Upgrades & Payment History.
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

  late final Stream<List<Map<String, dynamic>>> _productsStream;
  late final Stream<List<Map<String, dynamic>>> _paymentsStream;

  @override
  void initState() {
    super.initState();
    _currentShop = widget.shop;
    _dataSource = widget.dataSource ?? ProfessionalProviderRemoteDataSource();
    _checkoutService = widget.checkoutService ?? RazorpayCheckoutService();

    _checkoutService.init(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onDismiss: _handlePaymentDismissed,
      onExternalWallet: _handleExternalWallet,
    );

    _productsStream = _dataSource.streamProducts(_currentShop.id);
    _paymentsStream = _dataSource.streamShopPayments(_currentShop.id);

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

        _showSuccessActivationDialog(
            planName, duration.toInt(), isShopApproved);
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
      return 'Unlimited / Inactive';
    }
    final expiry = _currentShop.subscriptionExpiry!;
    final formattedDate =
        '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
    final now = DateTime.now();
    final difference = expiry.difference(now);

    if (difference.isNegative) {
      final daysAgo = (-difference.inDays);
      return 'Expired on $formattedDate (${daysAgo == 0 ? "today" : "$daysAgo days ago"})';
    } else {
      final daysRemaining = difference.inDays;
      if (daysRemaining == 0) {
        return 'Expires today ($formattedDate)';
      } else if (daysRemaining <= 5) {
        return '$formattedDate ($daysRemaining days left — Expiring Soon!)';
      } else {
        return '$formattedDate ($daysRemaining days remaining)';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = ProfessionalEntitlementResolver.resolve(_currentShop);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          ProviderStrings.professionalSubscription,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Current Plan Card
                _buildCurrentPlanHeroCard(entitlements),
                const SizedBox(height: 16),

                // Recovery Banner if payment is pending
                _buildRecoveryBanner(),

                // Admin Approval Notice Banner
                _buildApprovalNoticeBanner(),

                // 2. Used Limits vs Plan Limits
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _productsStream,
                  builder: (context, snap) {
                    final products = snap.data ?? [];
                    final productCount = products.length;
                    return _buildLimitsProgressCard(entitlements, productCount);
                  },
                ),
                const SizedBox(height: 16),

                // 3. Feature Entitlements Matrix
                _buildFeaturesMatrixCard(entitlements),
                const SizedBox(height: 24),

                // 4. Upgrade & Renew Subscription Plans
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upgrade or Renew Subscription',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A)),
                    ),
                    if (_isLoadingPlans)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF1D4ED8)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isLoadingPlans)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                              color: Color(0xFF1D4ED8))))
                else if (_plans.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: Text(
                        'No subscription plans available currently. Contact Admin.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                else
                  ResponsiveCardGrid(
                    tabletColumns: 2,
                    desktopColumns: 3,
                    largeDesktopColumns: 3,
                    children: _plans.map((p) => _buildPlanPurchaseCard(p, entitlements)).toList(),
                  ),

                const SizedBox(height: 28),

                // 5. Payment Transaction History
                const Text(
                  'Payment History',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _paymentsStream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                    }
                    final payments = snap.data ?? [];
                    return _buildPaymentHistoryCard(payments);
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPlanHeroCard(ProfessionalEntitlements ent) {
    final bool isLive = ent.isValid;
    final bool isExpired = ent.isExpired;

    Color statusBg = isLive ? const Color(0xFF10B981) : (isExpired ? const Color(0xFFEF4444) : const Color(0xFF64748B));
    String statusText = isLive ? 'ACTIVE' : (isExpired ? 'EXPIRED' : 'INACTIVE');

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT PLAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Color(0xFFBFDBFE),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ent.planName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.8, color: Color(0x33FFFFFF)),
          const SizedBox(height: 14),

          // Validity & Expiry
          Row(
            children: [
              const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF93C5FD)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Validity: ${_buildValidityText()}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (_currentShop.subscriptionDurationDays > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF93C5FD)),
                const SizedBox(width: 8),
                Text(
                  'Plan Duration: ${_currentShop.subscriptionDurationDays} Days',
                  style: const TextStyle(fontSize: 13, color: Color(0xFFE0E7FF)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLimitsProgressCard(ProfessionalEntitlements ent, int currentProducts) {
    final double progress = (ent.maxProducts > 0)
        ? (currentProducts / ent.maxProducts).clamp(0.0, 1.0)
        : 0.0;
    final bool isNearLimit = progress >= 0.8;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Plan Limits & Capacity Usage',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '$currentProducts / ${ent.maxProducts} Products',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isNearLimit ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                isNearLimit ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Limits Row
          Row(
            children: [
              Expanded(
                child: _buildLimitStatBox(
                  'Selling Options',
                  'Unlimited sizes & packs',
                  Icons.layers_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLimitStatBox(
                  'Image Uploads',
                  '${ent.maxImagesPerProduct} / Product',
                  Icons.photo_library_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLimitStatBox(
                  'Cloud Storage',
                  '${ent.storageLimitMb} MB',
                  Icons.cloud_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitStatBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesMatrixCard(ProfessionalEntitlements ent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Included Features & Entitlements',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildFeaturePill('Advanced Analytics', ent.advancedAnalytics),
              _buildFeaturePill('Promotional Banners', ent.promotionalTools),
              _buildFeaturePill('Low Stock Alerts', ent.lowStockAlerts),
              _buildFeaturePill('Custom Attributes', ent.customAttributes),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(String name, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isEnabled ? const Color(0xFF86EFAC) : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEnabled ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            size: 13,
            color: isEnabled ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isEnabled ? const Color(0xFF15803D) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPurchaseCard(Map<String, dynamic> plan, ProfessionalEntitlements currentEnt) {
    final planId = plan['id']?.toString() ?? '';
    final name = plan['name']?.toString() ?? 'Plan';
    final price = (plan['price'] as num?)?.toDouble() ?? 0.0;
    final duration = (plan['durationDays'] as num?)?.toInt() ?? 30;
    final maxProds = (plan['maxProducts'] as num?)?.toInt() ?? (plan['productLimit'] as num?)?.toInt() ?? 50;
    final isCurrent = _currentShop.subscriptionPlanId == planId || _currentShop.subscriptionPlanName == name;
    final isProcessing = _isProcessingPayment && _processingPlanId == planId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? const Color(0xFF1D4ED8) : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'YOUR CURRENT PLAN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
          Text(
            name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${price % 1 == 0 ? price.toInt() : price}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
              ),
              const SizedBox(width: 4),
              Text(
                '/ $duration Days',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 0.8, color: Color(0xFFF1F5F9)),
          _buildPlanBenefit(Icons.check_rounded, 'Up to $maxProds Products'),
          _buildPlanBenefit(Icons.check_rounded, 'Unlimited sizes, weights & pack options'),
          _buildPlanBenefit(Icons.check_rounded, 'Full Online Storefront'),
          _buildPlanBenefit(Icons.check_rounded, 'Direct Order Notifications'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? const Color(0xFF0F766E) : const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: isProcessing ? null : () => _startPayment(plan),
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isCurrent ? 'Renew Plan' : 'Upgrade to $name',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            'No payment transactions recorded yet.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: payments.length,
        separatorBuilder: (_, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final p = payments[index];
          final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
          final planName = p['planName']?.toString() ?? 'Plan';
          final status = p['status']?.toString() ?? 'created';
          final orderId = p['orderId']?.toString() ?? p['id']?.toString() ?? '';
          final payId = p['paymentId']?.toString() ?? '';

          DateTime? date;
          final rawCreated = p['createdAt'];
          if (rawCreated is Timestamp) date = rawCreated.toDate();

          final bool isSuccess = status == 'activated';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              child: Icon(
                isSuccess ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
                color: isSuccess ? const Color(0xFF059669) : const Color(0xFFD97706),
                size: 20,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  planName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                Text(
                  '₹${amt % 1 == 0 ? amt.toInt() : amt}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'Order: $orderId ${payId.isNotEmpty ? "• Pay: $payId" : ""}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                if (date != null)
                  Text(
                    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? const Color(0xFF15803D) : const Color(0xFFB45309),
                ),
              ),
            ),
          );
        },
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
}
