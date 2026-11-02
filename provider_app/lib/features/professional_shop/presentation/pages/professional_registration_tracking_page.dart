import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';
import '../../../auth/presentation/bloc/provider_auth_bloc.dart';
import '../../../auth/presentation/bloc/provider_auth_event.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';

/// 💎 PROFESSIONAL SELLER REGISTRATION TRACKING SCREEN
/// Implements Screen 2 ("REGISTRATION STATUS") of the Reference E-Commerce Seller Workspace.
/// Displays a real-time, 5-stage milestone tracking timeline.
/// STRICT GUARANTEE: Never falls back to Normal Provider Leads or Plumber Dashboard.
class ProfessionalRegistrationTrackingPage extends StatefulWidget {
  final ProfessionalShopProfileEntity? shop;
  final ProviderProfileEntity profile;
  final VoidCallback? onRefresh;
  final ProfessionalProviderRemoteDataSource? dataSource;

  const ProfessionalRegistrationTrackingPage({
    super.key,
    this.shop,
    required this.profile,
    this.onRefresh,
    this.dataSource,
  });

  @override
  State<ProfessionalRegistrationTrackingPage> createState() => _ProfessionalRegistrationTrackingPageState();
}

class _ProfessionalRegistrationTrackingPageState extends State<ProfessionalRegistrationTrackingPage> {
  late final ProfessionalProviderRemoteDataSource? _dataSource;
  bool _isRefreshing = false;
  late ProfessionalShopProfileEntity? _currentShop;

  @override
  void initState() {
    super.initState();
    _currentShop = widget.shop;
    _dataSource = widget.dataSource;
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      final source = _dataSource ?? ProfessionalProviderRemoteDataSource();
      final updated = await source.resolveVerifiedShop(widget.profile.id);
      if (mounted) {
        setState(() {
          _currentShop = updated;
          _isRefreshing = false;
        });
        if (widget.onRefresh != null) {
          widget.onRefresh!();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('लॉग आउट करें?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('क्या आप अपने सेलर खाते से लॉग आउट करना चाहते हैं?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProviderAuthBloc>().add(SignOutEvent());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('लॉग आउट'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopName = _currentShop?.shopName.isNotEmpty == true
        ? _currentShop!.shopName
        : (widget.profile.businessName.isNotEmpty ? widget.profile.businessName : widget.profile.fullName);
    final categoryTitle = _currentShop?.demandCategoryTitle.isNotEmpty == true
        ? _currentShop!.demandCategoryTitle
        : (widget.profile.primaryCategoryTitle.isNotEmpty ? widget.profile.primaryCategoryTitle : 'Professional Seller');
    final area = _currentShop?.jamuiArea.isNotEmpty == true
        ? _currentShop!.jamuiArea
        : (widget.profile.jamuiArea.isNotEmpty ? widget.profile.jamuiArea : 'Jamui, Bihar');

    // Milestones state evaluation
    final bool isDocsUnderReview = widget.profile.kycStatus == ProviderKycStatus.pendingReview ||
        _currentShop?.status.toLowerCase() == 'pending';
    final bool isSubVerificationPending = (_currentShop?.isApproved == true) &&
        !(_currentShop?.isSubscriptionActive ?? false);
    final bool isApprovalPending = (_currentShop?.status.toLowerCase() == 'pending' ||
        _currentShop?.status.toLowerCase() == 'pendingreview' ||
        !(_currentShop?.isApproved ?? false));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: const AppLogo(size: 32),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'JAMUI SERVICES',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Professional Seller Hub',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'लॉग आउट',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFF0F766E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shop Header Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCEEAD6)),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF137333), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            categoryTitle,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            area,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFC2410C)),
                          SizedBox(width: 4),
                          Text(
                            'प्रक्रियाधीन',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Title: Registration Tracking
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registration Tracking',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'पंजीकरण स्थिति',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 5-Stage Vertical Timeline Card (Matching Reference Image Screen 2)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildTimelineStep(
                      stepNumber: 1,
                      title: 'Registration Submitted',
                      subtitle: 'पंजीकरण विवरण सफलतापूर्वक दर्ज हो गया',
                      state: TimelineState.completed,
                      isLast: false,
                    ),
                    _buildTimelineStep(
                      stepNumber: 2,
                      title: 'Documents Under Review',
                      subtitle: isDocsUnderReview ? 'दुकान व प्रोफ़ाइल विवरण की जांच जारी है' : 'सत्यापन संपन्न',
                      state: isDocsUnderReview ? TimelineState.active : TimelineState.completed,
                      isLast: false,
                    ),
                    _buildTimelineStep(
                      stepNumber: 3,
                      title: 'Subscription Verification',
                      subtitle: isSubVerificationPending ? 'प्लान सक्रियता की प्रतीक्षा है' : 'सब्सक्रिप्शन सत्यापित',
                      state: isSubVerificationPending
                          ? TimelineState.active
                          : (isApprovalPending ? TimelineState.pending : TimelineState.completed),
                      isLast: false,
                    ),
                    _buildTimelineStep(
                      stepNumber: 4,
                      title: 'Admin Approval Pending',
                      subtitle: isApprovalPending ? 'एडमिन द्वारा अंतिम सत्यापन प्रक्रियाधीन है' : 'स्वीकृत',
                      state: isApprovalPending ? TimelineState.active : TimelineState.completed,
                      isLast: false,
                    ),
                    _buildTimelineStep(
                      stepNumber: 5,
                      title: 'Approved & Live',
                      subtitle: 'कस्टमर ऐप पर दुकान लाइव हो जाएगी',
                      state: !isApprovalPending ? TimelineState.completed : TimelineState.pending,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Status Guidance Notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF15803D), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'आपकी प्रोफेशनल दुकान का विवरण Jamui Services एडमिन टीम के पास समीक्षा हेतु है। सत्यापन पूर्ण होते ही आपको सेलर डैशबोर्ड का सीधा ऐक्सेस मिल जाएगा।',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Primary Action: Refresh Status Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isRefreshing ? null : _handleRefresh,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: Text(
                    _isRefreshing ? 'स्थिति जांची जा रही है...' : 'स्थिति पुनः जांचें (Refresh)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary Action: Help Desk / WhatsApp Support
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('सहायता के लिए Jamui Services सपोर्ट: +91 98765 43210 पर संपर्क करें'),
                        backgroundColor: Color(0xFF0F766E),
                      ),
                    );
                  },
                  icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF0F766E), size: 20),
                  label: const Text(
                    'हेल्प डेस्क से संपर्क करें (Customer Support)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required int stepNumber,
    required String title,
    required String subtitle,
    required TimelineState state,
    required bool isLast,
  }) {
    Color nodeColor;
    Widget nodeIcon;

    switch (state) {
      case TimelineState.completed:
        nodeColor = const Color(0xFF16A34A);
        nodeIcon = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
        break;
      case TimelineState.active:
        nodeColor = const Color(0xFFEAB308);
        nodeIcon = const Icon(Icons.schedule_rounded, color: Colors.white, size: 14);
        break;
      case TimelineState.pending:
        nodeColor = const Color(0xFFCBD5E1);
        nodeIcon = Text(
          '$stepNumber',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        );
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Indicator with connecting line
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: nodeColor,
                shape: BoxShape.circle,
                boxShadow: state == TimelineState.active
                    ? [
                        BoxShadow(
                          color: nodeColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(child: nodeIcon),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                color: state == TimelineState.completed ? const Color(0xFF16A34A) : Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Right: Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: state == TimelineState.pending ? const Color(0xFF64748B) : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  if (state == TimelineState.completed)
                    const Text(
                      'Completed',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    )
                  else if (state == TimelineState.active)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF9C3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF854D0E)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: state == TimelineState.pending ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

enum TimelineState { completed, active, pending }
