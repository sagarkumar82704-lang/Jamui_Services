import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../auth/data/models/provider_profile_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/razorpay_checkout_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';
import '../../../auth/presentation/bloc/provider_auth_bloc.dart';
import '../../../auth/presentation/bloc/provider_auth_event.dart';
import '../../../auth/presentation/bloc/provider_auth_state.dart';
import '../../data/datasources/firebase_subscription_remote_data_source.dart';
import '../../data/datasources/subscription_remote_data_source.dart';
import '../../domain/entities/subscription_plan.dart';

import '../../../../core/config/razorpay_payment_config.dart';
import '../../../../main.dart';

class SubscriptionPage extends StatefulWidget {
  final ProviderProfileEntity profile;
  final bool isPostRegistration;
  final SubscriptionRemoteDataSource? dataSource;

  const SubscriptionPage({
    super.key,
    required this.profile,
    this.isPostRegistration = false,
    this.dataSource,
  });

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> with WidgetsBindingObserver {
  late final SubscriptionRemoteDataSource _dataSource;
  late final RazorpayCheckoutService _checkoutService;
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = true;
  SubscriptionPlan? _selectedPlan;
  Map<String, dynamic>? _pendingApprovalPayment;
  late ProviderProfileEntity _currentProfile;
  StreamSubscription? _profileStreamSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentProfile = widget.profile;
    _subscribeToProfileChanges();
    _dataSource = widget.dataSource ?? FirebaseSubscriptionRemoteDataSource();
    _checkoutService = RazorpayCheckoutService();
    _checkoutService.init(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onDismiss: _handlePaymentDismissed,
      onExternalWallet: _handleExternalWallet,
    );
    _loadPlans();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profileStreamSub?.cancel();
    _checkoutService.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SubscriptionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile.primaryCategoryId != _currentProfile.primaryCategoryId ||
        widget.profile.categoryType != _currentProfile.categoryType ||
        widget.profile.isPremiumCategory != _currentProfile.isPremiumCategory ||
        widget.profile.isPremiumEligible != _currentProfile.isPremiumEligible ||
        widget.profile.resolvedPlanTier != _currentProfile.resolvedPlanTier) {
      _handleUpdatedProfile(widget.profile);
    }
  }

  void _subscribeToProfileChanges() {
    try {
      final pid = widget.profile.id.trim();
      if (pid.isNotEmpty && !pid.startsWith('mock_')) {
        _profileStreamSub = FirebaseFirestore.instance
            .collection('providers')
            .doc(pid)
            .snapshots()
            .listen((docSnap) {
          if (!docSnap.exists || docSnap.data() == null) return;
          final updatedModel = ProviderProfileModel.fromMap(docSnap.data()!, docSnap.id);
          _handleUpdatedProfile(updatedModel);
        }, onError: (e) {
          debugPrint('⚠️ [SubscriptionPage] Profile stream notice: $e');
        });
      }
    } catch (_) {}
  }

  void _handleUpdatedProfile(ProviderProfileEntity updatedProfile) {
    final oldTier = _currentProfile.resolvedPlanTier;
    final newTier = updatedProfile.resolvedPlanTier;
    final oldCat = _currentProfile.primaryCategoryId;
    final newCat = updatedProfile.primaryCategoryId;
    final oldCatType = _currentProfile.categoryType;
    final newCatType = updatedProfile.categoryType;

    if (oldTier != newTier || oldCat != newCat || oldCatType != newCatType) {
      debugPrint('🔄 [SubscriptionPage] Category / Tier change detected! Old: $oldCat ($oldTier) ➔ New: $newCat ($newTier). Clearing cached plans and re-fetching.');
      if (mounted) {
        setState(() {
          _currentProfile = updatedProfile;
          _plans = [];
          _selectedPlan = null;
          _isLoading = true;
        });
        _loadPlans();
      }
    } else {
      if (mounted) {
        setState(() {
          _currentProfile = updatedProfile;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentOrderId != null) {
      _checkPaymentStatusOnResume();
    }
  }

  Future<void> _checkPaymentStatusOnResume() async {
    final orderId = _currentOrderId;
    if (orderId == null || !orderId.startsWith('order_')) return;
    try {
      final res = await _dataSource.reconcilePayment(orderId: orderId);
      if (res['captured'] == true || res['status'] == 'reconciled' || res['status'] == 'already_fulfilled') {
        if (mounted) {
          setState(() {
            _pendingApprovalPayment = {
              'orderId': orderId,
              'paymentId': res['paymentId'] ?? '',
              'amount': _selectedPlan?.price ?? 0,
              'planName': _selectedPlan?.name ?? 'Subscription',
              'adminApprovalStatus': 'pending_approval',
            };
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ आपका भुगतान Razorpay से सत्यापित हो गया है और Admin Approval के लिए भेजा गया है।'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SubscriptionPage] Resume payment reconciliation check note: $e');
    }
  }

  Future<void> _loadPlans() async {
    try {
      try {
        await RazorpayPaymentConfig.fetchFromCloud();
      } catch (_) {}
      final providerTier = _currentProfile.resolvedPlanTier;
      final isRenewal = _currentProfile.hasPaidSubscription || _currentProfile.paymentVerified;
      final targetAudience = isRenewal ? 'existing_provider' : 'new_provider';

      final rawPlans = await _dataSource.fetchPlans(
        providerId: _currentProfile.id,
        planTier: providerTier,
      );

      // Strict Defense-in-depth UI Filtering:
      // 1. Plan Tier: Only plans strictly matching providerTier (Normal vs Premium - ZERO mixing)
      var tierPlans = rawPlans.where((p) => p.planTier == providerTier).toList();

      // 2. Audience Filtering: Tailored to New vs Renewal (existing_provider)
      var audiencePlans = tierPlans.where((p) {
        final aud = p.targetAudience;
        return aud == targetAudience || aud == 'all';
      }).toList();

      final finalPlans = audiencePlans.isNotEmpty ? audiencePlans : tierPlans;

      Map<String, dynamic>? pendingPayment;
      try {
        pendingPayment = await _dataSource.getPendingApprovalPayment(providerId: widget.profile.id);
      } catch (err) {
        debugPrint('⚠️ [SubscriptionPage] Error fetching pending approval payment: $err');
      }
      setState(() {
        _plans = finalPlans;
        _pendingApprovalPayment = pendingPayment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String? _currentOrderId;

  Future<void> _startRazorpayPayment(SubscriptionPlan plan) async {
    if (_isLoading) return; // Prevent duplicate taps
    final providerTier = _currentProfile.resolvedPlanTier;
    if (plan.planTier != providerTier) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(providerTier == 'normal'
              ? '⚠️ आप केवल Normal सब्सक्रिप्शन प्लान खरीदने के लिए पात्र हैं।'
              : '⚠️ आप केवल Premium सब्सक्रिप्शन प्लान खरीदने के लिए पात्र हैं।'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_pendingApprovalPayment != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ आपका एक भुगतान पहले से सत्यापन व अनुमोदन के लिए लंबित है। कृपया दोबारा भुगतान न करें।'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    _selectedPlan = plan;
    setState(() => _isLoading = true);

    try {
      // 1. Authoritative Server-side Order Creation via Cloud Functions
      final orderData = await _dataSource.createRazorpayOrder(
        planId: plan.id,
        providerId: _currentProfile.id,
        phone: _currentProfile.phoneNumber,
        email: _currentProfile.email,
      );

      final orderId = orderData['orderId']?.toString();
      if (orderId == null || !orderId.startsWith('order_')) {
        throw Exception('सर्वर से वैध आर्डर ID प्राप्त नहीं हुई।');
      }
      _currentOrderId = orderId;

      final keyId = RazorpayPaymentConfig.keyId.isNotEmpty
          ? RazorpayPaymentConfig.keyId
          : (orderData['keyId']?.toString() ?? '');

      // Strict Authority: Amount MUST be received from server-side order calculation (No client-side fallback)
      final num? serverAmount = (orderData['amount'] as num?) ?? (orderData['amountInPaise'] as num?);
      if (serverAmount == null || serverAmount <= 0) {
        throw Exception('सर्वर से अमान्य भुगतान राशि प्राप्त हुई।');
      }
      final amountInPaise = serverAmount.toInt();

      setState(() => _isLoading = false);

      // 2. Validate Razorpay Key ID
      if (keyId.isEmpty || keyId.contains('placeholder') || keyId.contains('YOUR_KEY')) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                SizedBox(width: 8),
                Text('गेटवे अनुपलब्ध'),
              ],
            ),
            content: const Text(
              'रेजरपे पेमेंट गेटवे अभी सक्रिय नहीं है। कृपया सिस्टम एडमिनिस्ट्रेटर से संपर्क करें।',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ठीक है'),
              ),
            ],
          ),
        );
        return;
      }

      // 3. Launch Cross-Platform Razorpay Standard Checkout
      final options = <String, dynamic>{
        'key': keyId,
        'amount': amountInPaise,
        'currency': 'INR',
        'name': RazorpayPaymentConfig.merchantName,
        'description': '${plan.name} Subscription (${plan.durationDays} Days)',
        'prefill': {
          'contact': widget.profile.phoneNumber,
          'email': widget.profile.email.isNotEmpty ? widget.profile.email : 'provider@apnajamui.com',
        },
        'theme': {
          'color': '#0D6E57',
        },
        'modal': {
          'confirm_close': true,
        },
        'send_sms_hash': true,
        'retry': {
          'enabled': true,
          'max_count': 3,
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      // Pass authoritative server-generated Razorpay order_id if present
      final activeOrderId = _currentOrderId;
      if (activeOrderId != null &&
          activeOrderId.startsWith('order_') &&
          !activeOrderId.contains('local') &&
          !activeOrderId.contains('sim')) {
        options['order_id'] = activeOrderId;
        options['notes'] = {
          'providerId': widget.profile.id,
          'planId': plan.id,
          'orderId': activeOrderId,
        };
      }

      try {
        _checkoutService.open(options);
      } catch (sdkError) {
        setState(() => _isLoading = false);
        debugPrint('❌ [Razorpay] Checkout open failed: $sdkError');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('रेजरपे गेटवे खोलने में विफल: $sdkError'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('पेमेंट शुरू करने में समस्या: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _handlePaymentSuccess(String paymentId, String orderId, String signature) async {
    if (_selectedPlan == null) return;
    setState(() => _isLoading = true);

    try {
      final activeOrderId = orderId.isNotEmpty ? orderId : _currentOrderId;

      if (activeOrderId == null || paymentId.isEmpty || signature.isEmpty) {
        throw Exception('अमान्य भुगतान डेटा: रेजरपे से हस्ताक्षर या भुगतान आईडी प्राप्त नहीं हुई।');
      }

      // 3. Server-side Cryptographic Signature Verification & Activation
      final verifyResult = await _dataSource.verifyPayment(
        providerId: _currentProfile.id,
        planId: _selectedPlan!.id,
        orderId: activeOrderId,
        paymentId: paymentId,
        signature: signature,
      );

      setState(() {
        _isLoading = false;
        _pendingApprovalPayment = {
          'orderId': activeOrderId,
          'paymentId': paymentId,
          'amount': _selectedPlan?.price ?? 0,
          'planName': _selectedPlan?.name ?? 'Subscription',
          'adminApprovalStatus': 'pending_approval',
        };
      });

      if (mounted) {
        if (widget.isPostRegistration) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.verified, color: AppColors.success, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'भुगतान सफल! (Payment Verified)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'आपका सब्सक्रिप्शन शुल्क सफलतापूर्वक प्राप्त हो गया है।',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.access_time_filled, color: AppColors.primary, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'आपका प्रोफाइल अब एडमिन रिव्यू (Admin Approval) के लिए भेज दिया गया है। एडमिन द्वारा अनुमोदन मिलते ही आपकी सेवाएं कस्टमर ऐप में लाइव हो जाएंगी।',
                            style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (widget.isPostRegistration) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ProviderAuthBloc>(),
                            child: ProviderWorkspaceScreen(profile: widget.profile),
                          ),
                        ),
                        (route) => false,
                      );
                    } else {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  child: const Text('डैशबोर्ड पर जाएँ (Go to Dashboard)'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(verifyResult['message'] ?? 'सब्सक्रिप्शन सफलतापूर्वक एक्टिव हो गया!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        context.read<ProviderAuthBloc>().add(CheckAuthStatusEvent());
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('भुगतान सत्यापन विफल: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _handlePaymentDismissed() {
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('भुगतान रद्द कर दिया गया। सब्सक्रिप्शन सक्रिय नहीं हुआ।'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _handlePaymentError(int code, String message) {
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('भुगतान विफल ($code): $message'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _handleExternalWallet(String walletName) {
    debugPrint('💳 [Razorpay] External wallet selected: $walletName');
  }

  @override
  Widget build(BuildContext context) {
    ProviderProfileEntity profile = _currentProfile;
    try {
      final authState = context.watch<ProviderAuthBloc>().state;
      if (authState is ProviderAuthenticated) {
        profile = authState.profile;
      } else if (authState is ProviderProfileIncomplete) {
        profile = authState.profile;
      } else if (authState is ProviderProfileUpdatedSuccessState) {
        profile = authState.profile;
      }
      if (profile.primaryCategoryId != _currentProfile.primaryCategoryId ||
          profile.categoryType != _currentProfile.categoryType ||
          profile.resolvedPlanTier != _currentProfile.resolvedPlanTier) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleUpdatedProfile(profile);
        });
      }
    } catch (_) {
      // Fallback to widget.profile when ProviderAuthBloc is not in the ancestor tree (e.g. isolated unit/widget tests)
    }
    final expiry = profile.subscriptionExpiry;
    final daysRemaining = expiry != null ? expiry.difference(DateTime.now()).inDays : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.isPostRegistration ? 'स्टेप 2: सब्सक्रिप्शन प्लान' : 'बिजनेस सब्सक्रिप्शन प्लान्स',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (widget.isPostRegistration) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ProviderAuthBloc>(),
                    child: ProviderWorkspaceScreen(profile: widget.profile),
                  ),
                ),
                (route) => false,
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'प्लान रिफ्रेश करें (Refresh Plans)',
            onPressed: () {
              setState(() {
                _plans = [];
                _isLoading = true;
              });
              _loadPlans();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(() {
            _plans = [];
            _isLoading = true;
          });
          await _loadPlans();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isPostRegistration) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: AppColors.primary, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'चरण 2: अपना बिजनेस प्लान चुनें',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'रजिस्ट्रेशन पूर्ण करने और सेवा शुरू करने हेतु प्लान चुनें। भुगतान के बाद आपका आवेदन एडमिन अनुमोदन के लिए जाएगा।',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // 0. Pending Approval Warning Banner (Authoritative Duplicate Payment Guard)
            if (_pendingApprovalPayment != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB), // Amber-50
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB45309), size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'भुगतान प्राप्त • एडमिन अनुमोदन लंबित',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFB45309)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE68A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PENDING APPROVAL',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'आपका पिछला सब्सक्रिप्शन भुगतान सफलतापूर्वक प्राप्त हो चुका है। सुरक्षा जांच एवं एडमिन अनुमोदन (Admin Approval) की प्रक्रिया चल रही है। कृपया दूसरा भुगतान न करें।',
                      style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((_pendingApprovalPayment!['orderId'] ?? '').toString().isNotEmpty)
                            Text(
                              'Order ID: ${_pendingApprovalPayment!['orderId']}',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textPrimary),
                            ),
                          if ((_pendingApprovalPayment!['paymentId'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Payment Ref: ${_pendingApprovalPayment!['paymentId']}',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textPrimary),
                            ),
                          ],
                          if ((_pendingApprovalPayment!['amount'] as num?) != null && (_pendingApprovalPayment!['amount'] as num) > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              'भुगतान राशि: ₹${(_pendingApprovalPayment!['amount'] as num).toDouble().toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Active Subscription Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.workspace_premium, color: AppColors.gold, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            profile.subscriptionPlan.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: profile.hasPaidSubscription
                              ? AppColors.success.withValues(alpha: 0.2)
                              : (profile.isTrialActive ? Colors.amber.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: profile.hasPaidSubscription
                                ? AppColors.success
                                : (profile.isTrialActive ? Colors.amber : Colors.red),
                          ),
                        ),
                        child: Text(
                          profile.hasPaidSubscription
                              ? 'ACTIVE'
                              : (profile.isTrialActive ? 'TRIAL' : (profile.paymentVerified ? 'EXPIRED' : 'UNPAID')),
                          style: TextStyle(
                            color: profile.hasPaidSubscription
                                ? AppColors.success
                                : (profile.isTrialActive ? Colors.amber : Colors.red),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    expiry != null
                        ? 'वैधता शेष: $daysRemaining दिन (${expiry.day}/${expiry.month}/${expiry.year} तक)'
                        : (profile.hasPaidSubscription ? 'सक्रिय' : 'अवधि अनिर्धारित (भुगतान आवश्यक)'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text('0% कमीशन नीति • जमुई के ग्राहकों से 100% कमाई आपकी', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Provider Tier Badge & Info (Defense-in-depth UI Indicator)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: profile.resolvedPlanTier == 'premium'
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: profile.resolvedPlanTier == 'premium'
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF94A3B8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    profile.resolvedPlanTier == 'premium'
                        ? Icons.workspace_premium_rounded
                        : Icons.layers_rounded,
                    color: profile.resolvedPlanTier == 'premium'
                        ? const Color(0xFFB45309)
                        : const Color(0xFF334155),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.resolvedPlanTier == 'premium'
                              ? '⭐ प्रीमियम श्रेणी प्लान्स (Premium Tier)'
                              : '📦 मानक श्रेणी प्लान्स (Normal Tier)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: profile.resolvedPlanTier == 'premium'
                                ? const Color(0xFFB45309)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'स्वीकृत श्रेणी (Approved Category): ${profile.resolvedCategoryTitle} • केवल पात्र प्लान्स प्रदर्शित',
                          style: TextStyle(
                            fontSize: 11,
                            color: profile.resolvedPlanTier == 'premium'
                                ? const Color(0xFF78350F)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        if (profile.isCategoryChangePending ||
                            (profile.requestedCategoryTitle.isNotEmpty &&
                                (profile.categoryApprovalStatus == 'pending_review' ||
                                    profile.categoryRequestStatus == 'pending_review'))) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFB45309)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Requested Category: ${profile.requestedCategoryTitle} — Pending Approval',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (profile.isCategoryRejected) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFB91C1C)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'श्रेणी अनुरोध अस्वीकृत: ${profile.categoryRejectionReason ?? "कृपया एडिट प्रोफाइल में सुधार करें"}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Text(
              'उपलब्ध प्लान्स चुनें (Choose Plan)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.accent))
            else if (_plans.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, size: 36, color: AppColors.textSecondary),
                    const SizedBox(height: 10),
                    Text(
                      'आपकी ${profile.resolvedPlanTier == 'premium' ? 'प्रीमियम' : 'मानक'} श्रेणी के लिए कोई सक्रिय प्लान उपलब्ध नहीं है।',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _plans.map((plan) => _buildPlanCard(context, plan)).toList(),
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildPlanCard(BuildContext context, SubscriptionPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isPopular ? AppColors.accent : AppColors.border,
          width: plan.isPopular ? 2 : 1,
        ),
        boxShadow: plan.isPopular
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.isPopular) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('सबसे लोकप्रिय (Most Popular)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(plan.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${plan.price.toInt()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
                  if (plan.discountPercentage > 0)
                    Text('(${plan.discountPercentage.toInt()}% छूट लागू)', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Text('${plan.durationDays} दिनों के लिए', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'अधिकतम ${plan.categoryLimit} सेवा श्रेणियां',
                  style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              if (plan.targetAudience == 'existing_provider') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '🔄 रिन्यूअल प्लान',
                    style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (plan.isPremiumCategoryEligible)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: const Text('⭐ प्रीमियम श्रेणी पात्र', style: TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('📦 ${plan.maxActiveListings} एक्टिव लिस्टिंग्स', style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('🖼️ ${plan.maxImagesPerProvider} फ़ोटोज़ (${plan.maxTotalStorageMb.toStringAsFixed(0)} MB स्टोरेज)', style: TextStyle(fontSize: 10, color: Colors.purple.shade800, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (plan.offerDescription.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '🎁 ${plan.offerDescription}',
              style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
          const Divider(height: 20),

          Column(
            children: plan.features
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _pendingApprovalPayment != null ? null : () => _startRazorpayPayment(plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: _pendingApprovalPayment != null
                  ? Colors.grey.shade400
                  : (plan.isPopular ? AppColors.accent : AppColors.primary),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade700,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _pendingApprovalPayment != null
                  ? '⏳ अनुमोदन लंबित (Approval Pending)'
                  : '₹${plan.price.toInt()} में अभी खरीदें (Razorpay Pay)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
