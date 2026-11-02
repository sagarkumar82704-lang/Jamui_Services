import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../home/presentation/pages/customer_main_shell.dart';
import '../../../provider_portal/presentation/pages/provider_native_host_screen.dart';
import '../../domain/entities/customer_entity.dart';

class RoleSelectionDialog extends StatelessWidget {
  final CustomerEntity customer;
  final Map<String, dynamic> providerData;
  final bool isProviderApproved;
  final String providerStatus;
  final String? rejectionReason;
  final VoidCallback onSignOut;

  const RoleSelectionDialog({
    super.key,
    required this.customer,
    required this.providerData,
    required this.isProviderApproved,
    required this.providerStatus,
    this.rejectionReason,
    required this.onSignOut,
  });

  static Future<void> show(
    BuildContext context, {
    required CustomerEntity customer,
    required Map<String, dynamic> providerData,
    required bool isProviderApproved,
    required String providerStatus,
    String? rejectionReason,
    required VoidCallback onSignOut,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoleSelectionDialog(
        customer: customer,
        providerData: providerData,
        isProviderApproved: isProviderApproved,
        providerStatus: providerStatus,
        rejectionReason: rejectionReason,
        onSignOut: onSignOut,
      ),
    );
  }

  void _onSelectCustomer(BuildContext context) {
    Navigator.pop(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const CustomerMainShell()),
      (route) => false,
    );
  }

  void _onSelectProvider(BuildContext context) {
    Navigator.pop(context);

    if (isProviderApproved) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProviderNativeHostScreen()),
      );
    } else {
      _showPendingReviewModal(context);
    }
  }

  void _showPendingReviewModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              providerStatus == 'rejected'
                  ? Icons.cancel_outlined
                  : Icons.hourglass_top_rounded,
              color: providerStatus == 'rejected' ? Colors.red : Colors.amber.shade800,
            ),
            const SizedBox(width: 8),
            Text(
              providerStatus == 'rejected'
                  ? 'सत्यापन अस्वीकृत'
                  : 'सत्यापन प्रक्रियाधीन',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              providerStatus == 'rejected'
                  ? (rejectionReason?.isNotEmpty == true
                      ? 'अस्वीकृति का कारण: $rejectionReason'
                      : 'एडमिन द्वारा आपके विवरण या दस्तावेज़ अस्वीकृत किए गए हैं।')
                  : 'आपका पार्टनर प्रोफ़ाइल वर्तमान में एडमिन समीक्षाधीन (Under Review) है। सत्यापन पूर्ण होते ही आपको पार्टनर डैशबोर्ड का पूर्ण एक्सेस मिलेगा।',
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 12),
            const Text(
              'तब तक आप ग्राहक के रूप में Jamui Services का उपयोग जारी रख सकते हैं।',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProviderNativeHostScreen()),
              );
            },
            child: const Text('प्रोफ़ाइल विवरण देखें'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const CustomerMainShell()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('ग्राहक डैशबोर्ड खोलें', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerTitle = (providerData['businessName'] as String?)?.isNotEmpty == true
        ? providerData['businessName'] as String
        : (providerData['fullName'] as String? ?? 'कारीगर पार्टनर');
    final providerCategory = (providerData['primaryCategoryTitle'] as String?)?.isNotEmpty == true
        ? providerData['primaryCategoryTitle'] as String
        : 'लोकल सर्विस प्रोवाइडर';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const AppLogo(
                  size: 42,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'खाता चुनें (Select Profile)',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'आप इस मोबाइल नंबर से दोनों रूप में पंजीकृत हैं',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 20),
                  tooltip: 'लॉगआउट करें',
                  onPressed: onSignOut,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. Customer Option Card
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onSelectCustomer(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  customer.fullName.isNotEmpty ? customer.fullName : 'ग्राहक खाता',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Customer', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${customer.jamuiArea} • सेवाएं बुक करें व कारीगर खोजें',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Provider Option Card
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onSelectProvider(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    providerTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isProviderApproved
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isProviderApproved ? 'सत्यापित' : 'समीक्षाधीन',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isProviderApproved ? Colors.green.shade800 : Colors.amber.shade900,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$providerCategory • लीड्स व पार्टनर डैशबोर्ड',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFD97706), size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
