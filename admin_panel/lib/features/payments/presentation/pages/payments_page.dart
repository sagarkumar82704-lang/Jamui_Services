import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/status_badge.dart';

class PaymentsPage extends StatefulWidget {
  final int initialTabIndex;
  const PaymentsPage({super.key, this.initialTabIndex = 0});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Active Tab:
  // 0 = ⏳ Pending Approvals
  // 1 = ✓ Approved Subscriptions
  // 2 = 👥 All Subscriptions & History
  // 3 = 💳 Razorpay Gateway Logs
  int _activeTabIndex = 0;

  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';
  String _selectedDateFilter = 'all';
  String _selectedTierFilter = 'all'; // 'all', 'normal', 'premium'

  // Payments and Providers Live Records
  List<Map<String, dynamic>> _allPayments = [];
  List<Map<String, dynamic>> _filteredPayments = [];
  Map<String, dynamic>? _paymentConfig;

  List<Map<String, dynamic>> _allProviders = [];
  List<Map<String, dynamic>> _filteredProviders = [];

  // Real Metric Counters (Financial)
  int _totalVerifiedCount = 0;
  double _totalCollectedAmount = 0.0;
  int _refundsCount = 0;
  double _refundsAmount = 0.0;
  double _netRevenue = 0.0;
  int _pendingCount = 0;
  int _failedCount = 0;
  int _unverifiedCount = 0;

  // Provider Subscription Real Metrics
  int _totalProvidersCount = 0;
  int _pendingApprovalsCount = 0;
  int _activePaidSubscriptionsCount = 0;
  int _unpaidPendingProvidersCount = 0;
  int _expiringOrExpiredCount = 0;
  double _prospectiveRenewalAmount = 0.0;

  // Pagination
  int _currentPaymentPage = 1;
  int _currentProviderPage = 1;
  final int _rowsPerPage = 15;

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.initialTabIndex;
    _loadAllPaymentData();
  }

  Future<void> _loadAllPaymentData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Razorpay Cloud Configuration
      try {
        final configDoc = await _firestore.collection('app_config').doc('payment').get();
        if (configDoc.exists && configDoc.data() != null) {
          _paymentConfig = configDoc.data();
        }
      } catch (cfgErr) {
        debugPrint('⚠️ [PaymentsPage] app_config/payment read notice: $cfgErr');
      }

      // 2. Fetch Payments Records from Firestore
      List<Map<String, dynamic>> loadedPayments = [];
      try {
        final snap = await _firestore
            .collection('payments')
            .orderBy('createdAt', descending: true)
            .limit(300)
            .get();
        loadedPayments = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (orderErr) {
        debugPrint('⚠️ [PaymentsPage] Ordered query failed, falling back to unordered: $orderErr');
        final snap = await _firestore.collection('payments').limit(300).get();
        loadedPayments = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }

      // Explicitly load all payments in pending_approval state so they are NEVER truncated or omitted by limit(300)
      try {
        final pendingSnap = await _firestore
            .collection('payments')
            .where('adminApprovalStatus', isEqualTo: 'pending_approval')
            .get();
        for (final doc in pendingSnap.docs) {
          if (!loadedPayments.any((p) => (p['orderId'] ?? p['id']) == doc.id)) {
            loadedPayments.add({'id': doc.id, ...doc.data()});
          }
        }
      } catch (pendErr) {
        debugPrint('⚠️ [PaymentsPage] Direct pending payments query notice: $pendErr');
      }

      // Fetch Professional Seller Payments from diamond_payments (Marketplace)
      List<Map<String, dynamic>> rawDiamondPayments = [];
      try {
        final diamondPaySnap = await _firestore
            .collection('diamond_payments')
            .orderBy('createdAt', descending: true)
            .limit(300)
            .get();
        rawDiamondPayments = diamondPaySnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (dPayErr) {
        debugPrint('⚠️ [PaymentsPage] Ordered diamond_payments query failed, falling back: $dPayErr');
        try {
          final diamondPaySnap = await _firestore.collection('diamond_payments').limit(300).get();
          rawDiamondPayments = diamondPaySnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        } catch (e) {
          debugPrint('⚠️ [PaymentsPage] diamond_payments fetch error: $e');
        }
      }

      // Fetch Professional Shops for relational mapping
      Map<String, Map<String, dynamic>> diamondShopsById = {};
      try {
        final diamondShopSnap = await _firestore.collection('diamond_shops').get();
        for (final d in diamondShopSnap.docs) {
          diamondShopsById[d.id] = {'id': d.id, ...d.data()};
        }
      } catch (dShopErr) {
        debugPrint('⚠️ [PaymentsPage] diamond_shops fetch error: $dShopErr');
      }

      // Ingest and normalize Professional Seller Payments into loadedPayments
      for (final dp in rawDiamondPayments) {
        final sId = (dp['shopId'] ?? dp['ownerUid'] ?? '').toString();
        final shop = diamondShopsById[sId] ?? {};
        final oId = (dp['orderId'] ?? dp['id'] ?? '').toString();
        final payId = (dp['paymentId'] ?? '').toString();
        final rawStatus = (dp['status'] ?? 'pending').toString().toLowerCase();
        final normalizedStatus = rawStatus == 'activated' ? 'success' : rawStatus;
        final isSuccess = normalizedStatus == 'success';
        final amount = (dp['amount'] as num?)?.toDouble() ?? 0.0;
        final shopName = (shop['shopName'] ?? dp['shopName'] ?? 'Pro Store').toString();
        final ownerName = (shop['ownerName'] ?? dp['ownerName'] ?? 'Seller').toString();

        loadedPayments.add({
          ...dp,
          'id': dp['id'] ?? oId,
          'orderId': oId,
          'paymentId': payId,
          'providerId': sId,
          'shopId': sId,
          'providerName': '$shopName ($ownerName)',
          'shopName': shopName,
          'userName': ownerName,
          'planName': (dp['planName'] ?? 'Basic (Pro)').toString(),
          'planTier': 'professional',
          'amount': amount,
          'status': normalizedStatus,
          'captured': isSuccess,
          'liveVerified': isSuccess,
          'signature': isSuccess ? 'server_verified' : '',
          'type': 'professional_subscription',
          'isProfessional': true,
          'adminApprovalStatus': isSuccess ? 'approved' : 'none',
        });
      }

      // Sort loadedPayments chronologically descending
      loadedPayments.sort((a, b) {
        final aDate = _extractDateTime(a['createdAt'] ?? a['verifiedAt']);
        final bDate = _extractDateTime(b['createdAt'] ?? b['verifiedAt']);
        if (aDate != null && bDate != null) return bDate.compareTo(aDate);
        return 0;
      });

      // Index payments by orderId and providerId for fast, authoritative relational lookup
      final Map<String, Map<String, dynamic>> latestPaymentByProviderId = {};
      final Map<String, Map<String, dynamic>> pendingApprovalPaymentByProviderId = {};
      final Map<String, Map<String, dynamic>> paymentByOrderId = {};
      for (final p in loadedPayments) {
        final oId = (p['orderId'] ?? p['id'] ?? '').toString();
        if (oId.isNotEmpty) {
          paymentByOrderId[oId] = p;
        }
        final pId = (p['providerId'] ?? '').toString();
        if (pId.isNotEmpty) {
          if (!latestPaymentByProviderId.containsKey(pId)) {
            latestPaymentByProviderId[pId] = p;
          }
          final isPending = (p['adminApprovalStatus'] == 'pending_approval' || p['subscriptionApprovalStatus'] == 'pending_approval') &&
              (p['captured'] == true || p['status'] == 'success') &&
              p['isConsumed'] != true &&
              p['isApproved'] != true;
          if (isPending && !pendingApprovalPaymentByProviderId.containsKey(pId)) {
            pendingApprovalPaymentByProviderId[pId] = p;
          }
        }
      }

      // 3. Fetch Providers to build unified subscriptions & payment approval records
      List<Map<String, dynamic>> loadedProviders = [];
      int activePaid = 0;
      int unpaidPending = 0;
      int expiringExpired = 0;
      double renewalDueEstimated = 0.0;
      final now = DateTime.now();

      try {
        final provSnap = await _firestore.collection('providers').get();
        final rawProviders = provSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        final Map<String, Map<String, dynamic>> rawProvidersById = {
          for (final r in rawProviders) (r['id'] ?? '').toString(): r
        };
        final Set<String> coveredOrderIds = {};

        for (final data in rawProviders) {
          final pId = (data['id'] ?? '').toString();

          final storedOrderId = (data['paymentOrderId'] ?? '').toString();
          // Prioritize active pending approval payment so that an old uncaptured or previously approved storedOrderId never shadows an active captured payment!
          final linkedPayment = pendingApprovalPaymentByProviderId[pId] ??
              (storedOrderId.isNotEmpty ? paymentByOrderId[storedOrderId] : null) ??
              latestPaymentByProviderId[pId];

          if (storedOrderId.isNotEmpty && storedOrderId != '-') {
            coveredOrderIds.add(storedOrderId);
          }
          if (linkedPayment != null) {
            final lOrderId = (linkedPayment['orderId'] ?? linkedPayment['id'] ?? '').toString();
            if (lOrderId.isNotEmpty && lOrderId != '-') {
              coveredOrderIds.add(lOrderId);
            }
          }

          final isCaptured = linkedPayment?['captured'] == true || linkedPayment?['isCaptured'] == true;
          final isLiveVerified = linkedPayment?['liveVerified'] == true || linkedPayment?['status'] == 'success';
          final paymentStatus = (linkedPayment?['status'] ?? data['paymentStatus'] ?? (isCaptured ? 'success' : 'unpaid')).toString();
          final isVerified = paymentStatus == 'success' && isCaptured;
          final isActive = data['isSubscriptionActive'] == true;

          DateTime? expiry;
          final rawExpiry = data['subscriptionExpiry'] ?? linkedPayment?['expiryDate'];
          if (rawExpiry is Timestamp) {
            expiry = rawExpiry.toDate();
          } else if (rawExpiry != null) {
            expiry = DateTime.tryParse(rawExpiry.toString());
          }

          final hasValidSubscription = isActive && expiry != null && expiry.isAfter(now);

          if (hasValidSubscription) {
            activePaid++;
          } else {
            unpaidPending++;
          }

          if (expiry != null) {
            final diff = expiry.difference(now).inDays;
            if (diff < 0 || diff <= 7) {
              expiringExpired++;
              renewalDueEstimated += 399.0;
            }
          } else if (!hasValidSubscription) {
            renewalDueEstimated += 399.0;
          }

          // Merge enriched payment attributes into provider map
          final orderId = storedOrderId.isNotEmpty
              ? storedOrderId
              : (linkedPayment?['orderId'] ?? linkedPayment?['id'] ?? '-').toString();
          final payId = (linkedPayment?['paymentId'] ?? linkedPayment?['razorpayPaymentId'] ?? data['paymentId'] ?? '-').toString();
          final amount = (linkedPayment?['amount'] as num?)?.toDouble() ??
              (data['paymentAmount'] as num?)?.toDouble() ??
              0.0;
          final paymentDate = _extractDateTime(linkedPayment?['verifiedAt'] ?? linkedPayment?['createdAt'] ?? data['paymentVerifiedAt']);
          final plan = (linkedPayment?['planName'] ?? data['subscriptionPlanName'] ?? data['subscriptionPlan'] ?? linkedPayment?['planId'] ?? 'Basic').toString();
          final planTier = (linkedPayment?['planTier'] ?? data['subscriptionPlanTier'] ?? 'normal').toString();
          final approvalStatus = (linkedPayment?['adminApprovalStatus'] ?? data['adminApprovalStatus'] ?? data['subscriptionApprovalStatus'] ?? (isActive ? 'approved' : (paymentStatus == 'success' ? 'pending_approval' : 'none'))).toString();
          final isConsumed = linkedPayment?['isConsumed'] == true || linkedPayment?['isApproved'] == true;

          loadedProviders.add({
            ...data,
            'paymentOrderId': orderId,
            'paymentId': payId,
            'paymentAmount': amount,
            'paymentStatus': paymentStatus,
            'paymentDateTime': paymentDate,
            'subscriptionPlan': plan,
            'planTier': planTier,
            'subscriptionExpiryDate': expiry,
            'subscriptionApprovalStatus': approvalStatus,
            'adminApprovalStatus': approvalStatus,
            'paymentVerified': isVerified,
            'captured': isCaptured,
            'liveVerified': isLiveVerified,
            'isConsumed': isConsumed,
          });
        }

        // Add any additional or orphan payments from loadedPayments (e.g. multiple captured payments like double orders)
        for (final p in loadedPayments) {
          final oId = (p['orderId'] ?? p['id'] ?? '').toString();
          if (oId.isNotEmpty && !coveredOrderIds.contains(oId)) {
            coveredOrderIds.add(oId);
            final pId = (p['providerId'] ?? '').toString();
            final provProfile = rawProvidersById[pId] ?? {};
            final pStatus = (p['status'] ?? 'pending').toString();
            final isCap = p['captured'] == true || p['isCaptured'] == true;
            final isLiveVer = p['liveVerified'] == true || pStatus == 'success';
            final isVer = pStatus == 'success' && isCap;
            final expiry = _extractDateTime(p['expiryDate']);
            final approvalStatus = (p['adminApprovalStatus'] ?? (isVer ? 'pending_approval' : 'none')).toString();
            final isConsumed = p['isConsumed'] == true || p['isApproved'] == true;

            loadedProviders.add({
              ...provProfile,
              'id': pId,
              'name': (provProfile['name'] ?? provProfile['businessName'] ?? p['providerName'] ?? p['userName'] ?? 'Service Provider').toString(),
              'phone': (provProfile['phone'] ?? provProfile['phoneNumber'] ?? p['phone'] ?? p['phoneNumber'] ?? '-').toString(),
              'paymentOrderId': oId,
              'paymentId': (p['paymentId'] ?? p['razorpayPaymentId'] ?? '-').toString(),
              'paymentAmount': (p['amount'] as num?)?.toDouble() ?? 0.0,
              'paymentStatus': pStatus,
              'paymentDateTime': _extractDateTime(p['verifiedAt'] ?? p['createdAt']),
              'subscriptionPlan': (p['planName'] ?? p['planId'] ?? 'Basic').toString(),
              'planTier': (p['planTier'] ?? 'normal').toString(),
              'subscriptionExpiryDate': expiry,
              'subscriptionApprovalStatus': approvalStatus,
              'adminApprovalStatus': approvalStatus,
              'paymentVerified': isVer,
              'captured': isCap,
              'liveVerified': isLiveVer,
              'isConsumed': isConsumed,
              'isSubscriptionActive': false,
              'status': provProfile['status'] ?? 'pendingReview',
            });
          }
        }

        // Ingest Professional Shops with their active/historical subscriptions into loadedProviders
        for (final entry in diamondShopsById.entries) {
          final sId = entry.key;
          final shop = entry.value;
          final isSubActive = shop['isSubscriptionActive'] == true;

          final shopPayments = rawDiamondPayments.where((p) =>
              (p['shopId'] ?? p['ownerUid'] ?? '').toString() == sId).toList();
          shopPayments.sort((a, b) {
            final aT = _extractDateTime(a['createdAt'] ?? a['verifiedAt']);
            final bT = _extractDateTime(b['createdAt'] ?? b['verifiedAt']);
            if (aT != null && bT != null) return bT.compareTo(aT);
            return 0;
          });
          final latestShopPay = shopPayments.isNotEmpty ? shopPayments.first : null;

          final storedOrderId = (shop['paymentOrderId'] ?? latestShopPay?['orderId'] ?? latestShopPay?['id'] ?? '-').toString();
          final payId = (shop['paymentId'] ?? latestShopPay?['paymentId'] ?? '-').toString();
          final amount = (shop['paymentAmount'] as num?)?.toDouble() ??
              (latestShopPay?['amount'] as num?)?.toDouble() ??
              0.0;

          DateTime? expiry;
          final rawExpiry = shop['subscriptionExpiry'];
          if (rawExpiry is Timestamp) {
            expiry = rawExpiry.toDate();
          } else if (rawExpiry != null) {
            expiry = DateTime.tryParse(rawExpiry.toString());
          }

          final hasValidSubscription = isSubActive && expiry != null && expiry.isAfter(now);
          if (hasValidSubscription) {
            activePaid++;
          } else if (shop['status'] == 'approved') {
            unpaidPending++;
          }

          if (expiry != null) {
            final diff = expiry.difference(now).inDays;
            if (diff < 0 || diff <= 7) {
              expiringExpired++;
            }
          }

          if (storedOrderId.isNotEmpty && storedOrderId != '-') {
            coveredOrderIds.add(storedOrderId);
          }

          final isPaySuccess = isSubActive || (latestShopPay?['status'] == 'activated');
          final shopName = (shop['shopName'] ?? 'Pro Store').toString();
          final ownerName = (shop['ownerName'] ?? 'Seller').toString();
          final planName = (shop['subscriptionPlanName'] ?? latestShopPay?['planName'] ?? 'Basic').toString();

          loadedProviders.add({
            ...shop,
            'id': sId,
            'providerId': sId,
            'name': '$shopName ($ownerName)',
            'businessName': shopName,
            'ownerName': ownerName,
            'phone': (shop['ownerPhone'] ?? shop['contactPhone'] ?? shop['phone'] ?? '-').toString(),
            'email': (shop['ownerEmail'] ?? '-').toString(),
            'paymentOrderId': storedOrderId,
            'paymentId': payId,
            'paymentAmount': amount,
            'paymentStatus': isPaySuccess ? 'success' : 'unpaid',
            'paymentDateTime': _extractDateTime(shop['subscriptionActivatedAt'] ?? latestShopPay?['verifiedAt'] ?? latestShopPay?['createdAt']),
            'subscriptionPlan': '$planName (Pro)',
            'planTier': 'professional',
            'subscriptionExpiryDate': expiry,
            'subscriptionApprovalStatus': 'approved',
            'adminApprovalStatus': 'approved',
            'paymentVerified': isPaySuccess,
            'captured': isPaySuccess,
            'liveVerified': isPaySuccess,
            'isConsumed': true,
            'isSubscriptionActive': isSubActive,
            'isProfessionalSeller': true,
            'status': shop['status'] ?? 'approved',
          });
        }

        // Priority sort: pending_approval first, then verified success, then recent date
        loadedProviders.sort((a, b) {
          final aPending = a['subscriptionApprovalStatus'] == 'pending_approval';
          final bPending = b['subscriptionApprovalStatus'] == 'pending_approval';
          if (aPending && !bPending) return -1;
          if (!aPending && bPending) return 1;

          final aVerified = a['paymentVerified'] == true;
          final bVerified = b['paymentVerified'] == true;
          if (aVerified && !bVerified) return -1;
          if (!aVerified && bVerified) return 1;

          final aDate = a['paymentDateTime'] as DateTime?;
          final bDate = b['paymentDateTime'] as DateTime?;
          if (aDate != null && bDate != null) return bDate.compareTo(aDate);
          return 0;
        });

      } catch (provErr) {
        debugPrint('⚠️ [PaymentsPage] Providers subscription scan note: $provErr');
      }

      // 4. Calculate Verified Financial Metrics (Unique Verified Records Only)
      int successCount = 0;
      double collectedSum = 0.0;
      int refCount = 0;
      double refSum = 0.0;
      int pending = 0;
      int failed = 0;
      int unverified = 0;

      final Set<String> processedOrderIds = {};

      for (final p in loadedPayments) {
        final orderId = (p['orderId'] ?? p['id'] ?? '').toString();
        final status = (p['status'] ?? 'pending').toString().toLowerCase();
        final amountNum = (p['amount'] as num?)?.toDouble() ?? 0.0;
        final hasSignature = (p['signature'] as String?)?.isNotEmpty == true;

        if (status == 'success') {
          if (!processedOrderIds.contains(orderId)) {
            processedOrderIds.add(orderId);
            successCount++;
            collectedSum += amountNum;
          }
        } else if (status == 'refunded') {
          refCount++;
          refSum += amountNum;
        } else if (status == 'failed' || status == 'cancelled') {
          failed++;
        } else {
          pending++;
          if (!hasSignature) {
            unverified++;
          }
        }
      }

      // Calculate pending approvals count: Providers with verified payment waiting for admin activation
      int pendingApprovals = 0;
      for (final p in loadedProviders) {
        final approval = (p['subscriptionApprovalStatus'] ?? '').toString();
        final isCap = p['captured'] == true;
        final isConsumed = p['isConsumed'] == true;
        if (approval == 'pending_approval' && isCap && !isConsumed) {
          pendingApprovals++;
        }
      }

      setState(() {
        _allPayments = loadedPayments;
        _allProviders = loadedProviders;

        _totalVerifiedCount = successCount;
        _totalCollectedAmount = collectedSum;
        _refundsCount = refCount;
        _refundsAmount = refSum;
        _netRevenue = collectedSum - refSum;
        _pendingCount = pending;
        _failedCount = failed;
        _unverifiedCount = unverified;

        _totalProvidersCount = loadedProviders.length;
        _pendingApprovalsCount = pendingApprovals;
        _activePaidSubscriptionsCount = activePaid;
        _unpaidPendingProvidersCount = unpaidPending;
        _expiringOrExpiredCount = expiringExpired;
        _prospectiveRenewalAmount = renewalDueEstimated;

        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [PaymentsPage] Error loading payment audit: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveAndActivateSubscription(Map<String, dynamic> item) async {
    final providerId = (item['id'] ?? item['providerId'] ?? '').toString();
    final orderId = (item['paymentOrderId'] ?? item['orderId'] ?? item['id'] ?? '').toString();
    final name = (item['name'] ?? item['businessName'] ?? item['fullName'] ?? 'Service Provider').toString();
    final phone = (item['phone'] ?? item['phoneNumber'] ?? '-').toString();
    final planName = (item['subscriptionPlan'] ?? 'starter_monthly').toString();
    final amount = (item['paymentAmount'] as num?)?.toDouble() ?? (item['amount'] as num?)?.toDouble() ?? 0.0;
    final paymentId = (item['paymentId'] ?? '-').toString();
    final paymentStatus = (item['paymentStatus'] ?? item['status'] ?? 'pending').toString().toLowerCase();

    final isCaptured = item['captured'] == true;
    final isLiveVerified = item['liveVerified'] == true || paymentStatus == 'success';
    final approvalStatus = (item['adminApprovalStatus'] ?? item['subscriptionApprovalStatus'] ?? '').toString();
    final isConsumed = item['isConsumed'] == true;

    if (paymentStatus != 'success' || !isCaptured || !isLiveVerified || approvalStatus != 'pending_approval' || isConsumed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ सुरक्षा रोक: केवल वास्तविक सत्यापित व कैप्चर (Captured & Live-Verified) भुगतान जो पहले स्वीकृत न हुआ हो, उसे ही सक्रिय किया जा सकता है।'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.success, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'सब्सक्रिप्शन अनुमोदन व सक्रिय करें? (Approve & Activate)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('प्रदाता: $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('मोबाइल: $phone', style: const TextStyle(fontSize: 12)),
                    Text('UID: $providerId', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textMuted)),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('प्लान: $planName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('राशि: ₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Order ID: $orderId', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                    Text('Payment Ref: $paymentId', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'सुरक्षा व सक्रियता विवरण:\n'
                '• सर्वर पर Razorpay भुगतान की अंतिम वैधता जांची जाएगी।\n'
                '• प्रदाता का सब्सक्रिप्शन तुरंत सक्रिय (Active) हो जाएगा।\n'
                '• चयनित प्लान के अनुसार 30 दिन या 1 वर्ष की समाप्ति तिथि जोड़ी जाएगी।\n'
                '• यदि प्रदाता स्वीकृत है, तो वह ग्राहक ऐप पर तुरंत लाइव दिखाई देगा।\n'
                '• एडमिन की इस कार्रवाई का अपरिवर्तनीय ऑडिट लॉग दर्ज होगा।',
                style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('हाँ, सक्रिय करें (Confirm & Activate)'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('adminApproveSubscription');
      final resp = await callable.call({
        'providerId': providerId,
        'orderId': orderId,
      });

      if (mounted) Navigator.pop(context); // close loader

      if (resp.data != null && resp.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ सब्सक्रिप्शन सफलतापूर्वक सक्रिय हो गया! समाप्ति: ${resp.data['expiryDate'] ?? ""}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await _loadAllPaymentData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('सक्रियण विफल: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _rejectSubscription(Map<String, dynamic> item) async {
    final providerId = (item['id'] ?? item['providerId'] ?? '').toString();
    final orderId = (item['paymentOrderId'] ?? item['orderId'] ?? item['id'] ?? '').toString();
    final name = (item['name'] ?? item['businessName'] ?? item['fullName'] ?? 'Service Provider').toString();
    final planName = (item['subscriptionPlan'] ?? 'Subscription').toString();
    final amount = (item['paymentAmount'] as num?)?.toDouble() ?? (item['amount'] as num?)?.toDouble() ?? 0.0;

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.danger, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'सब्सक्रिप्शन भुगतान अस्वीकृत करें? (Reject)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('प्रदाता: $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('UID: $providerId', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text('प्लान: $planName | राशि: ₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                    Text('Order ID: $orderId', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'अस्वीकृति का कारण दर्ज करें (Rejection Reason):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'उदा. संदिग्ध भुगतान, गलत प्रदाता विवरण, या रद्द अनुरोध',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              const Text(
                '• इस कार्रवाई से प्रदाता का यह सब्सक्रिप्शन अनुरोध अस्वीकृत हो जाएगा।\n'
                '• यदि प्रदाता की पहले से कोई वैध सदस्यता चल रही है, तो वह अप्रभावित रहेगी।\n'
                '• सर्वर पर सुरक्षित ऑडिट लॉग दर्ज होगा।',
                style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('हाँ, अस्वीकृत करें (Reject Payment)'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('adminRejectSubscription');
      final resp = await callable.call({
        'providerId': providerId,
        'orderId': orderId,
        'reason': reasonController.text.trim(),
      });

      if (mounted) Navigator.pop(context); // close loader

      if (resp.data != null && resp.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ सब्सक्रिप्शन भुगतान सफलतापूर्वक अस्वीकृत कर दिया गया।'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        await _loadAllPaymentData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('अस्वीकृति विफल: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();
    final now = DateTime.now();

    // 1. Filter Payments
    List<Map<String, dynamic>> resPayments = _allPayments.where((p) {
      if (query.isNotEmpty) {
        final orderId = (p['orderId'] ?? p['id'] ?? '').toString().toLowerCase();
        final payId = (p['paymentId'] ?? p['razorpayPaymentId'] ?? '').toString().toLowerCase();
        final provider = (p['providerName'] ?? p['userName'] ?? p['providerId'] ?? '').toString().toLowerCase();
        final plan = (p['planName'] ?? p['planId'] ?? '').toString().toLowerCase();

        final matches = orderId.contains(query) ||
            payId.contains(query) ||
            provider.contains(query) ||
            plan.contains(query);
        if (!matches) return false;
      }

      if (_selectedStatusFilter != 'all') {
        final status = (p['status'] ?? 'pending').toString().toLowerCase();
        if (_selectedStatusFilter == 'success' && status != 'success') return false;
        if (_selectedStatusFilter == 'pending' && (status == 'success' || status == 'failed' || status == 'cancelled')) {
          return false;
        }
        if (_selectedStatusFilter == 'failed' && (status != 'failed' && status != 'cancelled')) {
          return false;
        }
        if (_selectedStatusFilter == 'refunded' && status != 'refunded') return false;
      }

      if (_selectedDateFilter != 'all') {
        final createdDate = _extractDateTime(p['createdAt'] ?? p['verifiedAt']);
        if (createdDate == null) return false;

        if (_selectedDateFilter == 'today') {
          final isSameDay = createdDate.year == now.year &&
              createdDate.month == now.month &&
              createdDate.day == now.day;
          if (!isSameDay) return false;
        } else if (_selectedDateFilter == '7days') {
          if (now.difference(createdDate).inDays > 7) return false;
        } else if (_selectedDateFilter == '30days') {
          if (now.difference(createdDate).inDays > 30) return false;
        }
      }

      return true;
    }).toList();

    // 2. Filter Providers
    List<Map<String, dynamic>> resProviders = _allProviders.where((p) {
      if (query.isNotEmpty) {
        final name = (p['name'] ?? p['businessName'] ?? p['fullName'] ?? '').toString().toLowerCase();
        final phone = (p['phone'] ?? p['phoneNumber'] ?? '').toString().toLowerCase();
        final email = (p['email'] ?? p['registeredEmail'] ?? '').toString().toLowerCase();
        final cat = (p['category'] ?? p['serviceCategory'] ?? '').toString().toLowerCase();
        final id = (p['id'] ?? '').toString().toLowerCase();
        final orderId = (p['paymentOrderId'] ?? p['orderId'] ?? '').toString().toLowerCase();
        final payId = (p['paymentId'] ?? '').toString().toLowerCase();
        final plan = (p['subscriptionPlan'] ?? '').toString().toLowerCase();

        final matches = name.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            cat.contains(query) ||
            id.contains(query) ||
            orderId.contains(query) ||
            payId.contains(query) ||
            plan.contains(query);
        if (!matches) return false;
      }

      final isVerified = p['paymentVerified'] == true;
      final isActive = p['isSubscriptionActive'] == true;
      final expiry = _extractDateTime(p['subscriptionExpiry'] ?? p['subscriptionExpiryDate']);
      final hasActivePaidSub = isVerified && isActive && expiry != null && expiry.isAfter(now);
      final paymentStatus = (p['paymentStatus'] ?? '').toString().toLowerCase();
      final approvalStatus = (p['adminApprovalStatus'] ?? p['subscriptionApprovalStatus'] ?? '').toString().toLowerCase();
      final isCaptured = p['captured'] == true;
      final isLiveVerified = p['liveVerified'] == true || paymentStatus == 'success';
      final isConsumed = p['isConsumed'] == true;
      final isPendingApproval = isCaptured &&
          isLiveVerified &&
          paymentStatus == 'success' &&
          approvalStatus == 'pending_approval' &&
          !isConsumed;

      // Tier Filter Enforcement (Normal vs Premium vs Professional)
      if (_selectedTierFilter != 'all') {
        final tier = (p['planTier'] ?? p['subscriptionPlanTier'] ?? 'normal').toString().toLowerCase();
        if (_selectedTierFilter == 'normal') {
          if (tier != 'normal' && tier.isNotEmpty) return false;
        } else if (_selectedTierFilter == 'premium') {
          if (tier != 'premium') return false;
        } else if (_selectedTierFilter == 'professional') {
          if (tier != 'professional') return false;
        }
      }

      // Tab-specific enforcement:
      if (_activeTabIndex == 0) {
        // Tab 0: Strictly Pending Admin Approval (Verified Payment + Pending Approval)
        if (!isPendingApproval) return false;
      } else if (_activeTabIndex == 1) {
        // Tab 1: Strictly Approved Paid Active Subscriptions (Server-Verified Payment + Active + Unexpired)
        if (!hasActivePaidSub) return false;
      } else if (_activeTabIndex == 2) {
        // Tab 2: All Subscriptions with Status Filter Dropdown
        if (_selectedStatusFilter != 'all') {
          if (_selectedStatusFilter == 'pending_approval') {
            if (!isPendingApproval) return false;
          } else if (_selectedStatusFilter == 'rejected') {
            if (approvalStatus != 'rejected') return false;
          } else if (_selectedStatusFilter == 'paid' || _selectedStatusFilter == 'active') {
            if (!hasActivePaidSub) return false;
          } else if (_selectedStatusFilter == 'unpaid') {
            if (paymentStatus == 'success') return false;
          } else if (_selectedStatusFilter == 'expired') {
            if (expiry == null || !expiry.isBefore(now)) return false;
          } else if (_selectedStatusFilter == 'failed') {
            if (paymentStatus != 'failed' && paymentStatus != 'cancelled') return false;
          }
        }
      }

      if (_selectedDateFilter != 'all') {
        final pDate = _extractDateTime(p['paymentDateTime'] ?? p['paymentVerifiedAt'] ?? p['createdAt']);
        if (pDate == null) return false;

        if (_selectedDateFilter == 'today') {
          final isSameDay = pDate.year == now.year && pDate.month == now.month && pDate.day == now.day;
          if (!isSameDay) return false;
        } else if (_selectedDateFilter == '7days') {
          if (now.difference(pDate).inDays > 7) return false;
        } else if (_selectedDateFilter == '30days') {
          if (now.difference(pDate).inDays > 30) return false;
        }
      }

      return true;
    }).toList();

    setState(() {
      _filteredPayments = resPayments;
      _filteredProviders = resProviders;
      _currentPaymentPage = 1;
      _currentProviderPage = 1;
    });
  }

  DateTime? _extractDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    return DateTime.tryParse(val.toString());
  }

  String _maskSensitive(String? text, {int visiblePrefix = 4, int visibleSuffix = 4}) {
    if (text == null || text.trim().isEmpty) return '-';
    final trimmed = text.trim();
    if (trimmed.length <= (visiblePrefix + visibleSuffix)) return trimmed;
    final prefix = trimmed.substring(0, visiblePrefix);
    final suffix = trimmed.substring(trimmed.length - visibleSuffix);
    return '$prefix...$suffix';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label क्लिपबोर्ड पर कॉपी किया गया'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showProviderSubscriptionDialog(Map<String, dynamic> provider) {
    final name = (provider['name'] ?? provider['businessName'] ?? 'Service Provider').toString();
    final businessName = (provider['businessName'] ?? '-').toString();
    final phone = (provider['phone'] ?? provider['phoneNumber'] ?? '-').toString();
    final category = (provider['category'] ?? provider['serviceCategory'] ?? '-').toString();
    final providerId = (provider['id'] ?? '-').toString();
    final profileStatus = (provider['status'] ?? 'pendingReview').toString();

    final isPaymentVerified = provider['paymentVerified'] == true;
    final paymentStatus = (provider['paymentStatus'] ?? (isPaymentVerified ? 'paid' : 'unpaid')).toString();
    final isSubActive = provider['isSubscriptionActive'] == true;
    final planName = (provider['subscriptionPlan'] ?? 'starter_monthly').toString();
    final orderId = (provider['paymentOrderId'] ?? provider['orderId'] ?? '-').toString();
    final paymentId = (provider['paymentId'] ?? '-').toString();

    final startDate = _extractDateTime(provider['subscriptionStartDate'] ?? provider['subscriptionStart'] ?? provider['createdAt']);
    final expiryDate = _extractDateTime(provider['subscriptionExpiry']);

    final now = DateTime.now();
    final isExpiryValid = expiryDate != null && expiryDate.isAfter(now);
    final isLiveOnApp = (profileStatus == 'approved' || provider['isVerified'] == true) &&
        isPaymentVerified &&
        isSubActive &&
        isExpiryValid;

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    int? daysRemaining;
    if (expiryDate != null) {
      daysRemaining = expiryDate.difference(now).inDays;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isLiveOnApp ? AppColors.successBg : AppColors.warningBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isLiveOnApp ? Icons.verified_user_rounded : Icons.lock_clock_rounded,
                color: isLiveOnApp ? AppColors.success : AppColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'सब्सक्रिप्शन व भुगतान स्थिति (Provider Subscription Audit)',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visibility Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isLiveOnApp ? AppColors.successBg : AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isLiveOnApp ? AppColors.success.withValues(alpha: 0.3) : AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLiveOnApp ? Icons.check_circle_rounded : Icons.visibility_off_rounded,
                        color: isLiveOnApp ? AppColors.success : AppColors.danger,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLiveOnApp
                                  ? 'ग्राहक ऐप पर लाइव व दृश्यमान (Live on Customer App)'
                                  : 'ग्राहक ऐप पर अदृश्य (Hidden from Customer App)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isLiveOnApp ? AppColors.success : AppColors.danger,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isLiveOnApp
                                  ? 'यह प्रोवाइडर ग्राहक ऐप पर सर्च, कैटेगरी और डिटेल्स पेज पर पूरी तरह लाइव है।'
                                  : (!isPaymentVerified
                                      ? 'भुगतान असत्यापित (paymentVerified: false) होने के कारण ग्राहक ऐप व डेटाबेस रूल्स इसे छिपा रहे हैं।'
                                      : (expiryDate == null || !isExpiryValid
                                          ? 'सब्सक्रिप्शन अवधि समाप्त (Expired) होने के कारण प्रोफाइल छिपी हुई है।'
                                          : 'प्रोफाइल अप्रूव न होने के कारण अदृश्य है।')),
                              style: TextStyle(
                                fontSize: 12,
                                color: isLiveOnApp ? AppColors.textSecondary : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('प्रोवाइडर विवरण (Provider Info)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                const Divider(height: 12),
                _buildDetailRow('बिजनेस का नाम (Business)', businessName),
                _buildDetailRow('मोबाइल नंबर (Phone)', phone, canCopy: true),
                _buildDetailRow('सर्विस श्रेणी (Category)', category),
                _buildDetailRow('प्रोवाइडर आईडी (UID)', providerId, canCopy: true),
                _buildDetailRow('प्रोफाइल स्वीकृति स्थिति', profileStatus),

                const SizedBox(height: 12),
                const Text('सब्सक्रिप्शन विवरण (Subscription Details)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                const Divider(height: 12),
                _buildDetailRow('प्लान नाम (Plan Name)', planName),
                _buildDetailRow('सब्सक्रिप्शन सक्रिय (Active)', isSubActive ? 'सक्रिय (Active)' : 'निष्क्रिय (Inactive)',
                    badgeColor: isSubActive ? AppColors.success : AppColors.danger),
                if (startDate != null)
                  _buildDetailRow('प्रारंभ तिथि (Start Date)', dateFormat.format(startDate)),
                _buildDetailRow(
                  'समाप्ति तिथि (Expiry Date)',
                  expiryDate != null ? dateFormat.format(expiryDate) : 'अनिर्धारित (No Expiry Set)',
                  badgeColor: isExpiryValid ? AppColors.success : AppColors.danger,
                ),
                _buildDetailRow(
                  'अवधि शेष (Remaining Days)',
                  daysRemaining != null
                      ? (daysRemaining >= 0 ? '$daysRemaining दिन शेष' : 'समाप्त हो चुका (${daysRemaining.abs()} दिन पूर्व)')
                      : 'कोई वैध अवधि नहीं (भुगतान आवश्यक)',
                  badgeColor: (daysRemaining != null && daysRemaining >= 0) ? AppColors.success : AppColors.warning,
                ),

                const SizedBox(height: 12),
                const Text('रेजरपे लेन-देन सत्यापन (Razorpay Payment Audit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                const Divider(height: 12),
                _buildDetailRow(
                  'भुगतान सत्यापन (Payment Verified)',
                  isPaymentVerified ? 'सत्यापित (Cryptographically Validated)' : 'असत्यापित / लंबित (Unverified)',
                  badgeColor: isPaymentVerified ? AppColors.success : AppColors.danger,
                ),
                _buildDetailRow('भुगतान स्थिति (Status)', paymentStatus),
                _buildDetailRow('रेजरपे आर्डर आईडी (Order ID)', orderId, canCopy: orderId != '-'),
                _buildDetailRow('रेजरपे पेमेंट आईडी (Payment ID)', paymentId, canCopy: paymentId != '-'),
              ],
            ),
          ),
        ),
        actions: [
          if (orderId != '-' || paymentId != '-')
            TextButton.icon(
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: const Text('गेटवे लॉग्स में देखें (View in Logs)'),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _activeTabIndex = 1;
                  _searchQuery = (paymentId != '-' ? paymentId : orderId);
                  _applyFilters();
                });
              },
            ),
          if (isPaymentVerified && (provider['subscriptionApprovalStatus'] != 'approved' && provider['subscriptionApprovalStatus'] != 'rejected')) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('अस्वीकृत करें (Reject)'),
              onPressed: () {
                Navigator.pop(ctx);
                _rejectSubscription(provider);
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.verified_user_rounded, size: 16),
              label: const Text('सक्रिय करें (Approve & Activate)'),
              onPressed: () {
                Navigator.pop(ctx);
                _approveAndActivateSubscription(provider);
              },
            ),
          ],
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('बंद करें (Close)'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetailsDialog(Map<String, dynamic> item) {
    final orderId = (item['orderId'] ?? item['id'] ?? '-').toString();
    final paymentId = (item['paymentId'] ?? item['razorpayPaymentId'] ?? '-').toString();
    final providerName = (item['providerName'] ?? item['userName'] ?? 'Service Provider').toString();
    final providerId = (item['providerId'] ?? '-').toString();
    final planName = (item['planName'] ?? item['planId'] ?? 'Subscription').toString();
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final status = (item['status'] ?? 'pending').toString();
    final signature = (item['signature'] as String? ?? '');
    final isVerifiedSignature = signature.isNotEmpty && signature != 'test_sig';

    final createdDate = _extractDateTime(item['createdAt']);
    final verifiedDate = _extractDateTime(item['verifiedAt']);
    final expiryDate = _extractDateTime(item['expiryDate']);

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'ट्रांजेक्शन विवरण (Transaction Audit)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: status == 'success' ? AppColors.successBg : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: status == 'success' ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('भुगतान स्थिति (Status)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          StatusBadge.fromStatus(status),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('कुल राशि (Amount)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text('₹$amount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildDetailRow('रेजरपे आर्डर आईडी (Order ID)', orderId, canCopy: true),
                _buildDetailRow('रेजरपे पेमेंट आईडी (Payment ID)', paymentId, canCopy: true),
                if (item['isProfessional'] == true) ...[
                  _buildDetailRow('दुकान का प्रकार (Store Type)', '💎 Professional Seller Marketplace', badgeColor: Colors.purple),
                  if (item['shopName'] != null)
                    _buildDetailRow('स्टोर का नाम (Store Name)', item['shopName'].toString()),
                ],
                _buildDetailRow('सर्विस प्रोवाइडर (Provider)', providerName),
                _buildDetailRow('प्रोवाइडर आईडी (Provider UID)', providerId, canCopy: true),
                _buildDetailRow('सब्सक्रिप्शन प्लान (Plan)', planName),
                _buildDetailRow(
                  'सर्वर सिग्नेचर (HMAC-SHA256)',
                  isVerifiedSignature ? 'सत्यापित (Cryptographically Validated)' : 'अप्रमाणित या टेस्ट',
                  badgeColor: isVerifiedSignature ? AppColors.success : AppColors.warning,
                ),
                if (createdDate != null)
                  _buildDetailRow('आर्डर निर्माण समय (Created At)', dateFormat.format(createdDate)),
                if (verifiedDate != null)
                  _buildDetailRow('सत्यापन समय (Verified At)', dateFormat.format(verifiedDate)),
                if (expiryDate != null)
                  _buildDetailRow('सब्सक्रिप्शन समाप्ति (Expiry Date)', dateFormat.format(expiryDate)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('बंद करें (Close)'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool canCopy = false, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: badgeColor ?? AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canCopy && value != '-') ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _copyToClipboard(value, label),
                    child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mode status
    final rawKey = (_paymentConfig?['razorpay_key_id'] ?? _paymentConfig?['keyId'] ?? '').toString();
    final isLive = rawKey.startsWith('rzp_live_');
    final isConfigured = rawKey.isNotEmpty;

    // Paginated rows based on active tab
    final totalPayments = _filteredPayments.length;
    final totalProviders = _filteredProviders.length;

    final startPayIndex = (_currentPaymentPage - 1) * _rowsPerPage;
    final endPayIndex = (startPayIndex + _rowsPerPage).clamp(0, totalPayments);
    final pagePayments = (startPayIndex < totalPayments) ? _filteredPayments.sublist(startPayIndex, endPayIndex) : [];

    final startProvIndex = (_currentProviderPage - 1) * _rowsPerPage;
    final endProvIndex = (startProvIndex + _rowsPerPage).clamp(0, totalProviders);
    final pageProviders = (startProvIndex < totalProviders) ? _filteredProviders.sublist(startProvIndex, endProvIndex) : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Banner & Gateway Mode Status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payments_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Payment & Subscription Management',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 12),
                          // Gateway Mode Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLive ? AppColors.successBg : AppColors.warningBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isLive ? AppColors.success : AppColors.warning,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLive ? Icons.check_circle : Icons.shield_outlined,
                                  size: 14,
                                  color: isLive ? AppColors.success : AppColors.warning,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isLive
                                      ? 'RAZORPAY LIVE MODE'
                                      : (isConfigured ? 'RAZORPAY TEST MODE' : 'GATEWAY UNCONFIGURED'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isLive ? AppColors.success : AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'सुरक्षित रेजरपे गेटवे और वास्तविक फायरस्टोर सब्सक्रिप्शन ऑडिट (Real Server Validation & Public Visibility Enforcement)',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadAllPaymentData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceSubtle,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('रिफ्रेश (Refresh)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Metrics Summary Cards (Responsive Grid)
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1200 ? 4 : (width > 700 ? 2 : 1);

              final cards = [
                StatCard(
                  title: 'कुल प्राप्त शुद्ध राजस्व (Net Revenue)',
                  value: '₹${_netRevenue.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.success,
                  subtitle: 'सत्यापित: ₹${_totalCollectedAmount.toStringAsFixed(0)} | रिफंड ($_refundsCount): ₹${_refundsAmount.toStringAsFixed(0)}',
                ),
                StatCard(
                  title: 'सत्यापित सफल भुगतान (Verified)',
                  value: '$_totalVerifiedCount',
                  icon: Icons.verified_rounded,
                  color: AppColors.primary,
                  subtitle: 'केवल अधिकृत सर्वर से सत्यापित लेन-देन',
                ),
                StatCard(
                  title: 'सक्रिय सशुल्क सदस्य (Paid & Live)',
                  value: '$_activePaidSubscriptionsCount',
                  icon: Icons.card_membership_rounded,
                  color: AppColors.success,
                  subtitle: 'ग्राहक ऐप पर सक्रिय व लाइव प्रोवाइडर',
                ),
                StatCard(
                  title: 'अनपेड / पेंडिंग प्रोवाइडर (Unpaid)',
                  value: '$_unpaidPendingProvidersCount',
                  icon: Icons.lock_clock_rounded,
                  color: AppColors.warning,
                  subtitle: 'ग्राहक ऐप से अदृश्य (भुगतान लंबित)',
                ),
                StatCard(
                  title: 'कुल पंजीकृत प्रोवाइडर (Total Providers)',
                  value: '$_totalProvidersCount',
                  icon: Icons.people_outline_rounded,
                  color: AppColors.primary,
                  subtitle: 'फायरस्टोर डेटाबेस में कुल पंजीकृत प्रोफाइल्स',
                ),
                StatCard(
                  title: 'समाप्त / नवीनीकरण देय (Due Soon)',
                  value: '$_expiringOrExpiredCount',
                  icon: Icons.alarm_rounded,
                  color: AppColors.danger,
                  subtitle: '7 दिनों में समाप्त या एक्सपायर्ड सब्सक्रिप्शन',
                ),
                StatCard(
                  title: 'लंबित लेन-देन (Pending Gateway Orders)',
                  value: '$_pendingCount',
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.accent,
                  subtitle: 'अपुष्ट: $_unverifiedCount | विफल: $_failedCount',
                ),
                StatCard(
                  title: 'अनुमानित देय राशि (Estimated Renewal)',
                  value: '₹${_prospectiveRenewalAmount.toStringAsFixed(0)}',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.secondary,
                  subtitle: 'अनपेड व देय प्रोवाइडर्स का संभावित राजस्व',
                ),
              ];

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 158,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (ctx, idx) => cards[idx],
              );
            },
          ),
          const SizedBox(height: 24),

          // 3. Tab Switcher (4 Dedicated Views)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // TAB 0: ⏳ Pending Approvals
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_activeTabIndex != 0) {
                        setState(() {
                          _activeTabIndex = 0;
                          _selectedStatusFilter = 'all';
                          _searchQuery = '';
                          _applyFilters();
                        });
                      }
                    },
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _activeTabIndex == 0 ? Colors.amber.shade50 : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTabIndex == 0 ? Colors.amber.shade800 : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.hourglass_top_rounded,
                            size: 18,
                            color: _activeTabIndex == 0 ? Colors.amber.shade900 : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'लंबित अनुमोदन (Pending Approvals)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _activeTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                              color: _activeTabIndex == 0 ? Colors.amber.shade900 : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 0 ? Colors.amber.shade800 : AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_pendingApprovalsCount',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _activeTabIndex == 0 ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 48, color: AppColors.border),

                // TAB 1: ✓ Approved Subscriptions
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_activeTabIndex != 1) {
                        setState(() {
                          _activeTabIndex = 1;
                          _selectedStatusFilter = 'all';
                          _searchQuery = '';
                          _applyFilters();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _activeTabIndex == 1 ? AppColors.successBg : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTabIndex == 1 ? AppColors.success : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: _activeTabIndex == 1 ? AppColors.success : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'स्वीकृत सशुल्क सदस्य (Approved Subscriptions)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _activeTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                              color: _activeTabIndex == 1 ? AppColors.success : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 1 ? AppColors.success : AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_activePaidSubscriptionsCount',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _activeTabIndex == 1 ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 48, color: AppColors.border),

                // TAB 2: 👥 All Providers & History
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_activeTabIndex != 2) {
                        setState(() {
                          _activeTabIndex = 2;
                          _selectedStatusFilter = 'all';
                          _searchQuery = '';
                          _applyFilters();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _activeTabIndex == 2 ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTabIndex == 2 ? AppColors.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            size: 18,
                            color: _activeTabIndex == 2 ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'सभी प्रदाता व इतिहास (All Records)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _activeTabIndex == 2 ? FontWeight.bold : FontWeight.w500,
                              color: _activeTabIndex == 2 ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 2 ? AppColors.primary : AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_allProviders.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _activeTabIndex == 2 ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 48, color: AppColors.border),

                // TAB 3: 💳 Razorpay Payment Logs
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_activeTabIndex != 3) {
                        setState(() {
                          _activeTabIndex = 3;
                          _selectedStatusFilter = 'all';
                          _searchQuery = '';
                          _applyFilters();
                        });
                      }
                    },
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _activeTabIndex == 3 ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: _activeTabIndex == 3 ? AppColors.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: _activeTabIndex == 3 ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'रेजरपे गेटवे लॉग्स (Razorpay Logs)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _activeTabIndex == 3 ? FontWeight.bold : FontWeight.w500,
                              color: _activeTabIndex == 3 ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == 3 ? AppColors.primary : AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_allPayments.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _activeTabIndex == 3 ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Search and Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search Field
                SizedBox(
                  width: 320,
                  height: 40,
                  child: TextField(
                    onChanged: (val) {
                      _searchQuery = val;
                      _applyFilters();
                    },
                    decoration: InputDecoration(
                      hintText: _activeTabIndex == 3
                          ? 'ऑर्डर ID, पेमेंट ID या प्रोवाइडर खोजें...'
                          : 'नाम, मोबाइल, ईमेल, श्रेणी या ऑर्डर ID खोजें...',
                      hintStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),

                // Dynamic Status Filter Dropdown (Active for Tab 2 & Tab 3)
                if (_activeTabIndex == 2 || _activeTabIndex == 3)
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatusFilter,
                        icon: const Icon(Icons.filter_list, size: 18),
                        style: AppTextStyles.body,
                        items: _activeTabIndex == 2
                            ? const [
                                DropdownMenuItem(value: 'all', child: Text('सभी प्रदाता व भुगतान (All Records)')),
                                DropdownMenuItem(value: 'pending_approval', child: Text('⏳ अनुमोदन लंबित (Pending Admin Approval)')),
                                DropdownMenuItem(value: 'paid', child: Text('🟢 सशुल्क व सक्रिय (Active & Live)')),
                                DropdownMenuItem(value: 'unpaid', child: Text('🟠 अनपेड / गेटवे लंबित (Unpaid / Pending)')),
                                DropdownMenuItem(value: 'expired', child: Text('🔴 समाप्त सब्सक्रिप्शन (Expired)')),
                                DropdownMenuItem(value: 'failed', child: Text('❌ विफल / रद्द (Failed / Cancelled)')),
                              ]
                            : const [
                                DropdownMenuItem(value: 'all', child: Text('सभी भुगतान स्थिति (All)')),
                                DropdownMenuItem(value: 'success', child: Text('केवल सफल (Verified Success)')),
                                DropdownMenuItem(value: 'pending', child: Text('लंबित (Pending)')),
                                DropdownMenuItem(value: 'failed', child: Text('विफल (Failed)')),
                                DropdownMenuItem(value: 'refunded', child: Text('रिफंड (Refunded)')),
                              ],
                        onChanged: (val) {
                          if (val != null) {
                            _selectedStatusFilter = val;
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                  ),

                // Plan Tier Filter Dropdown (Normal vs Premium)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTierFilter,
                      icon: const Icon(Icons.layers_rounded, size: 18),
                      style: AppTextStyles.body,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('सभी श्रेणियां (All Tiers)')),
                        DropdownMenuItem(value: 'normal', child: Text('📦 केवल Normal प्लान्स')),
                        DropdownMenuItem(value: 'premium', child: Text('⭐ केवल Premium प्लान्स')),
                        DropdownMenuItem(value: 'professional', child: Text('💎 केवल Professional Seller')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedTierFilter = val;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                ),

                // Date Filter Dropdown
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDateFilter,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      style: AppTextStyles.body,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('सभी समय (All Time)')),
                        DropdownMenuItem(value: 'today', child: Text('आज (Today)')),
                        DropdownMenuItem(value: '7days', child: Text('पिछले 7 दिन (Last 7 Days)')),
                        DropdownMenuItem(value: '30days', child: Text('पिछले 30 दिन (Last 30 Days)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _selectedDateFilter = val;
                          _applyFilters();
                        }
                      },
                    ),
                  ),
                ),

                // Record Count summary
                Text(
                  _activeTabIndex == 3
                      ? 'प्रदर्शित: $totalPayments ट्रांजेक्शन रिकॉर्ड'
                      : 'प्रदर्शित: $totalProviders प्रदाता रिकॉर्ड',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Main Content: Tab 0, 1, 2 (Provider Subscriptions Table) or Tab 3 (Transactions Data Table)
          if (_activeTabIndex != 3)
            _buildProviderSubscriptionsTable(pageProviders, startProvIndex, endProvIndex, totalProviders)
          else
            _buildTransactionsTable(pagePayments, startPayIndex, endPayIndex, totalPayments),
        ],
      ),
    );
  }

  // TAB 0: Provider Subscriptions Table (14 Attributes)
  Widget _buildProviderSubscriptionsTable(
    List<dynamic> pageItems,
    int startIndex,
    int endIndex,
    int totalRows,
  ) {
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(50.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (pageItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(50.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.badge_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'कोई प्रदाता सब्सक्रिप्शन रिकॉर्ड नहीं मिला',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'फिल्टर या खोज क्वेरी रीसेट करके पुनः देखें।',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 320),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.surfaceSubtle),
                  headingTextStyle: AppTextStyles.bodyBold.copyWith(fontSize: 12, color: AppColors.textSecondary),
                  dataTextStyle: AppTextStyles.body.copyWith(fontSize: 12),
                  horizontalMargin: 16,
                  columnSpacing: 18,
                  columns: const [
                    DataColumn(label: Text('PROVIDER & UID')), // 1
                    DataColumn(label: Text('PHONE')), // 2
                    DataColumn(label: Text('PLAN')), // 3
                    DataColumn(label: Text('AMOUNT')), // 4
                    DataColumn(label: Text('PAYMENT STATUS')), // 5
                    DataColumn(label: Text('ORDER & PAYMENT ID')), // 6
                    DataColumn(label: Text('PAYMENT DATE/TIME')), // 7
                    DataColumn(label: Text('SUBSCRIPTION STATUS')), // 8
                    DataColumn(label: Text('START & EXPIRY')), // 9
                    DataColumn(label: Text('APPROVAL & ACTION')), // 10
                  ],
                  rows: pageItems.map((p) {
                    final name = (p['name'] ?? p['businessName'] ?? p['fullName'] ?? 'Service Provider').toString();
                    final business = (p['businessName'] ?? '').toString();
                    final providerId = (p['id'] ?? p['providerId'] ?? '-').toString();
                    final phone = (p['phone'] ?? p['phoneNumber'] ?? '-').toString();

                    final isPaymentVerified = p['paymentVerified'] == true;
                    final paymentStatus = (p['paymentStatus'] ?? (isPaymentVerified ? 'success' : 'unpaid')).toString();
                    final amount = (p['paymentAmount'] as num?)?.toDouble() ?? (p['amount'] as num?)?.toDouble() ?? 0.0;
                    final planName = (p['subscriptionPlan'] ?? 'starter_monthly').toString();
                    final orderId = (p['paymentOrderId'] ?? p['orderId'] ?? '-').toString();
                    final paymentId = (p['paymentId'] ?? '-').toString();

                    final startDate = _extractDateTime(p['subscriptionStartDate'] ?? p['subscriptionStart'] ?? p['createdAt']);
                    final expiryDate = _extractDateTime(p['subscriptionExpiry'] ?? p['subscriptionExpiryDate']);
                    final paymentDate = _extractDateTime(p['paymentDateTime'] ?? p['paymentVerifiedAt'] ?? p['createdAt']);

                    final isExpiryValid = expiryDate != null && expiryDate.isAfter(now);
                    final isSubActive = p['isSubscriptionActive'] == true;
                    final approvalStatus = (p['subscriptionApprovalStatus'] ?? (isSubActive ? 'approved' : (paymentStatus == 'success' ? 'pending_approval' : 'none'))).toString();

                    int? daysLeft;
                    if (expiryDate != null) {
                      daysLeft = expiryDate.difference(now).inDays;
                    }

                    final isCaptured = p['captured'] == true;
                    final isLiveVerified = p['liveVerified'] == true || paymentStatus == 'success';
                    final isConsumed = p['isConsumed'] == true;
                    final canApproveOrder = paymentStatus == 'success' && isCaptured && isLiveVerified && approvalStatus == 'pending_approval' && !isConsumed;

                    return DataRow(
                      cells: [
                        // 1. PROVIDER & UID
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isSubActive
                                    ? AppColors.successBg
                                    : (approvalStatus == 'pending_approval' ? Colors.indigo.shade50 : AppColors.surfaceSubtle),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSubActive
                                        ? AppColors.success
                                        : (approvalStatus == 'pending_approval' ? Colors.indigo : AppColors.textSecondary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 150),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    if (business.isNotEmpty && business != name)
                                      Text(business, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    Row(
                                      children: [
                                        Text(
                                          _maskSensitive(providerId, visiblePrefix: 4, visibleSuffix: 4),
                                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textMuted),
                                        ),
                                        if (providerId != '-') ...[
                                          const SizedBox(width: 2),
                                          InkWell(
                                            onTap: () => _copyToClipboard(providerId, 'UID'),
                                            child: const Icon(Icons.copy_rounded, size: 10, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 2. PHONE
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(phone, style: const TextStyle(fontSize: 12)),
                              if (phone != '-') ...[
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _copyToClipboard(phone, 'Phone'),
                                  child: const Icon(Icons.copy_rounded, size: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // 3. PLAN & TYPE (NEW VS RENEWAL)
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blueGrey.shade200),
                                ),
                                child: Text(
                                  planName.toUpperCase(),
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (p['isProfessionalSeller'] == true || p['planTier'] == 'professional')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.purple.shade300),
                                  ),
                                  child: Text(
                                    '💎 प्रो सेलर (Marketplace)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade900,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: (p['isRenewal'] == true || p['isRenewalEligible'] == true)
                                        ? Colors.orange.shade50
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: (p['isRenewal'] == true || p['isRenewalEligible'] == true)
                                          ? Colors.orange.shade300
                                          : Colors.blue.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    (p['isRenewal'] == true || p['isRenewalEligible'] == true) ? 'रिन्यूअल (Renewal)' : 'नया (New Sub)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: (p['isRenewal'] == true || p['isRenewalEligible'] == true)
                                          ? Colors.orange.shade900
                                          : Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // 4. AMOUNT
                        DataCell(
                          Text(
                            amount > 0 ? '₹${amount.toStringAsFixed(0)}' : '₹0',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ),

                        // 5. PAYMENT STATUS
                        DataCell(
                          paymentStatus == 'success' || isPaymentVerified
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.successBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 11, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text('Verified', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.success)),
                                    ],
                                  ),
                                )
                              : StatusBadge.fromStatus(paymentStatus),
                        ),

                        // 6. ORDER & PAYMENT ID
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Ord: ${_maskSensitive(orderId, visiblePrefix: 5, visibleSuffix: 4)}',
                                    style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
                                  ),
                                  if (orderId != '-') ...[
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _copyToClipboard(orderId, 'Order ID'),
                                      child: const Icon(Icons.copy_rounded, size: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Pay: ${_maskSensitive(paymentId, visiblePrefix: 5, visibleSuffix: 4)}',
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary),
                                  ),
                                  if (paymentId != '-') ...[
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _copyToClipboard(paymentId, 'Payment ID'),
                                      child: const Icon(Icons.copy_rounded, size: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 7. PAYMENT DATE/TIME
                        DataCell(
                          Text(
                            paymentDate != null ? DateFormat('dd MMM yyyy\nhh:mm a').format(paymentDate) : '-',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),

                        // 8. SUBSCRIPTION STATUS
                        DataCell(
                          approvalStatus == 'pending_approval'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.indigo.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.hourglass_top_rounded, size: 11, color: Colors.indigo.shade800),
                                      const SizedBox(width: 4),
                                      Text('Pending Approval', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                                    ],
                                  ),
                                )
                              : (isSubActive && isExpiryValid
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.successBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, size: 11, color: AppColors.success),
                                          SizedBox(width: 4),
                                          Text('Active', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.success)),
                                        ],
                                      ),
                                    )
                                  : (expiryDate != null && !isExpiryValid
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.dangerBg,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.cancel_outlined, size: 11, color: AppColors.danger),
                                              SizedBox(width: 4),
                                              Text('Expired', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.danger)),
                                            ],
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.warningBg,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('Inactive', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.warning)),
                                        ))),
                        ),

                        // 9. START & EXPIRY
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                startDate != null ? 'Start: ${DateFormat("dd MMM yy").format(startDate)}' : 'Start: -',
                                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                              ),
                              Text(
                                expiryDate != null ? 'Exp: ${DateFormat("dd MMM yy").format(expiryDate)}' : 'Exp: Not Set',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isExpiryValid ? AppColors.textPrimary : AppColors.danger,
                                ),
                              ),
                              if (daysLeft != null)
                                Text(
                                  daysLeft >= 0 ? '$daysLeft days left' : 'Expired',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: daysLeft >= 0 ? AppColors.success : AppColors.danger,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // 10. APPROVAL & ACTION
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canApproveOrder) ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.verified_user_rounded, size: 14),
                                  label: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _approveAndActivateSubscription(p),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(color: AppColors.danger),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.cancel_outlined, size: 14),
                                  label: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _rejectSubscription(p),
                                ),
                              ] else if (approvalStatus == 'rejected')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.cancel, size: 12, color: AppColors.danger),
                                      SizedBox(width: 4),
                                      Text('Rejected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger)),
                                    ],
                                  ),
                                )
                              else if (approvalStatus == 'approved' || isSubActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.successBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 12, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text('Approved', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                                    ],
                                  ),
                                )
                              else
                                Text(paymentStatus == 'pending' ? 'गेटवे लंबित' : 'अनपेड', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                                tooltip: 'सब्सक्रिप्शन विवरण देखें (Inspect)',
                                onPressed: () => _showProviderSubscriptionDialog(p),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

          // Pagination Footer
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'प्रदर्शित: $startIndex - $endIndex / कुल $totalRows प्रदाता',
                  style: AppTextStyles.caption,
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _currentProviderPage > 1
                          ? () => setState(() => _currentProviderPage--)
                          : null,
                      child: const Text('पिछला (Previous)'),
                    ),
                    const SizedBox(width: 8),
                    Text('Page $_currentProviderPage', style: AppTextStyles.bodyBold),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: endIndex < totalRows
                          ? () => setState(() => _currentProviderPage++)
                          : null,
                      child: const Text('अगला (Next)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Razorpay Payment Logs Table
  Widget _buildTransactionsTable(
    List<dynamic> pageItems,
    int startIndex,
    int endIndex,
    int totalRows,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(50.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (pageItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(50.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'कोई भुगतान ट्रांजेक्शन रिकॉर्ड नहीं मिला',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'जब प्रोवाइडर ऐप से लाइव भुगतान पूरा होगा, तो सत्यापित रिकॉर्ड यहाँ दिखाई देंगे।',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 320),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.surfaceSubtle),
                  headingTextStyle: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: AppColors.textSecondary),
                  dataTextStyle: AppTextStyles.body.copyWith(fontSize: 13),
                  horizontalMargin: 16,
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('ORDER ID')),
                    DataColumn(label: Text('PAYMENT ID')),
                    DataColumn(label: Text('PROVIDER / USER')),
                    DataColumn(label: Text('PLAN')),
                    DataColumn(label: Text('AMOUNT')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('DATE & TIME')),
                    DataColumn(label: Text('ACTIONS')),
                  ],
                  rows: pageItems.map((p) {
                    final orderId = (p['orderId'] ?? p['id'] ?? '-').toString();
                    final paymentId = (p['paymentId'] ?? p['razorpayPaymentId'] ?? '-').toString();
                    final providerName = (p['providerName'] ?? p['userName'] ?? p['providerId'] ?? 'Service Provider').toString();
                    final planName = (p['planName'] ?? p['planId'] ?? 'Plan').toString();
                    final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                    final status = (p['status'] ?? 'pending').toString();

                    final createdDate = _extractDateTime(p['createdAt'] ?? p['verifiedAt']);
                    final dateStr = createdDate != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdDate)
                        : '-';

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_maskSensitive(orderId, visiblePrefix: 6, visibleSuffix: 4)),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _copyToClipboard(orderId, 'Order ID'),
                                child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(_maskSensitive(paymentId, visiblePrefix: 5, visibleSuffix: 4)),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(providerName, overflow: TextOverflow.ellipsis),
                                if (p['isProfessional'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: Colors.purple.shade200),
                                    ),
                                    child: const Text('💎 Pro Seller', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.purple)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          Text(planName),
                        ),
                        DataCell(
                          Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        DataCell(
                          StatusBadge.fromStatus(status),
                        ),
                        DataCell(
                          Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                            tooltip: 'विवरण देखें (Inspect)',
                            onPressed: () => _showTransactionDetailsDialog(p),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

          // Pagination Footer
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'प्रदर्शित: $startIndex - $endIndex / कुल $totalRows लेन-देन',
                  style: AppTextStyles.caption,
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _currentPaymentPage > 1
                          ? () => setState(() => _currentPaymentPage--)
                          : null,
                      child: const Text('पिछला (Previous)'),
                    ),
                    const SizedBox(width: 8),
                    Text('Page $_currentPaymentPage', style: AppTextStyles.bodyBold),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: endIndex < totalRows
                          ? () => setState(() => _currentPaymentPage++)
                          : null,
                      child: const Text('अगला (Next)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
