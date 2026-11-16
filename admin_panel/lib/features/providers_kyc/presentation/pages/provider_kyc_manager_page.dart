import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/admin_image_utils.dart';
import '../../../../core/widgets/whatsapp_image_viewer.dart';
import '../../domain/entities/admin_provider_kyc_entity.dart';
import '../bloc/admin_kyc_bloc.dart';
import '../bloc/admin_kyc_event.dart';
import '../bloc/admin_kyc_state.dart';

class ProviderKycManagerPage extends StatefulWidget {
  const ProviderKycManagerPage({super.key});

  @override
  State<ProviderKycManagerPage> createState() => _ProviderKycManagerPageState();
}

class _ProviderKycManagerPageState extends State<ProviderKycManagerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _viewCertificateDocument(AdminProviderKycEntity item) async {
    final rawKey = item.experienceCertificateUrl.trim();
    if (rawKey.isEmpty) return;

    // 1. If it's a legacy external/Firebase Storage URL and not an R2 key or private bucket, open directly
    if ((rawKey.startsWith('http://') || rawKey.startsWith('https://')) &&
        !rawKey.contains('.r2.cloudflarestorage.com') &&
        !rawKey.contains('jamui-services-private')) {
      WhatsAppImageViewerDialog.show(
        context,
        imageUrl: rawKey,
        title: 'अनुभव प्रमाण पत्र: ${item.fullName}',
        subtitle: item.previousOrganization.isNotEmpty ? item.previousOrganization : item.businessName,
      );
      return;
    }

    // 2. Clean key if wrapped in URL structure
    String cleanKey = rawKey;
    if (cleanKey.startsWith('http://') || cleanKey.startsWith('https://')) {
      try {
        final uri = Uri.parse(cleanKey);
        cleanKey = uri.path;
        if (cleanKey.startsWith('/')) cleanKey = cleanKey.substring(1);
        if (cleanKey.startsWith('jamui-services-private-staging/')) {
          cleanKey = cleanKey.replaceFirst('jamui-services-private-staging/', '');
        } else if (cleanKey.startsWith('jamui-services-private-prod/')) {
          cleanKey = cleanKey.replaceFirst('jamui-services-private-prod/', '');
        }
      } catch (_) {}
    }

    // 3. Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF0F172A)),
                SizedBox(height: 16),
                Text(
                  'सुरक्षित प्रमाण पत्र लोड हो रहा है...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('getSecureDocumentViewUrl');
      final response = await callable.call(<String, dynamic>{
        'objectKey': cleanKey,
      }).timeout(const Duration(seconds: 15));

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final data = response.data;
      final viewUrl = (data is Map) ? (data['viewUrl'] as String?) : null;

      if (viewUrl != null && viewUrl.isNotEmpty) {
        if (mounted) {
          WhatsAppImageViewerDialog.show(
            context,
            imageUrl: viewUrl,
            title: 'अनुभव प्रमाण पत्र: ${item.fullName}',
            subtitle: item.previousOrganization.isNotEmpty ? item.previousOrganization : item.businessName,
          );
        }
      } else {
        throw Exception('सुरक्षित देखने का लिंक प्राप्त नहीं हुआ।');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('दस्तावेज़ खोलने में त्रुटि: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminKycBloc, AdminKycState>(
      listener: (context, state) {
        if (state is AdminKycActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
        } else if (state is AdminKycError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        if (state is AdminKycLoading) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
        }

        final requests = state is AdminKycLoaded ? state.requests : <AdminProviderKycEntity>[];
        final pending = requests.where((r) => r.status == AdminKycStatus.pendingReview).toList();
        final approved = requests.where((r) => r.status == AdminKycStatus.approved).toList();
        final rejected = requests.where((r) => r.status == AdminKycStatus.rejected).toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'प्रोवाइडर KYC एवं सत्यापन प्रबंधन',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'कुल ${requests.length} प्रोवाइडर पंजीकृत • ${pending.length} पेंडिंग सत्यापन',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.read<AdminKycBloc>().add(const LoadKycRequestsEvent()),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('रिफ्रेश'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF0F172A),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF0F172A),
                  tabs: [
                    Tab(text: 'पेंडिंग (${pending.length})'),
                    Tab(text: 'सत्यापित / स्वीकृत (${approved.length})'),
                    Tab(text: 'अस्वीकृत (${rejected.length})'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildKycList(pending, isPending: true),
                    _buildKycList(approved, isPending: false),
                    _buildKycList(rejected, isPending: false),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKycList(List<AdminProviderKycEntity> list, {required bool isPending}) {
    if (list.isEmpty) {
      return const Center(
        child: Text('कोई प्रोवाइडर डेटा उपलब्ध नहीं है', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Round Circular Avatar with Tap Zoom
              GestureDetector(
                onTap: () {
                  if (item.profileImageUrl.isNotEmpty) {
                    WhatsAppImageViewerDialog.show(
                      context,
                      imageUrl: item.profileImageUrl,
                      title: 'प्रोफाइल फोटो: ${item.fullName}',
                      subtitle: item.businessName,
                    );
                  }
                },
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
                  backgroundImage: AdminImageUtils.getImageProvider(item.profileImageUrl),
                  child: AdminImageUtils.getImageProvider(item.profileImageUrl) == null
                      ? const Icon(Icons.person, color: Color(0xFF0F172A), size: 28)
                      : null,
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(item.categoryTitle, style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'दुकान: ${item.businessName} • इलाका: ${item.jamuiArea}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('फोन: ${item.phoneNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            if (item.experienceCertificateUrl.isNotEmpty) {
                              _viewCertificateDocument(item);
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'सर्टिफिकेट: ${item.experienceCertificateStatus == "verified" ? "सत्यापित (Verified ✓)" : (item.experienceCertificateStatus == "pendingReview" ? "समीक्षाधीन (Pending Review ⏳)" : "उपलब्ध नहीं (Not Uploaded)")}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: item.experienceCertificateStatus == "verified"
                                      ? Colors.green.shade800
                                      : (item.experienceCertificateStatus == "pendingReview" ? Colors.amber.shade900 : Colors.grey),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.experienceCertificateUrl.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.zoom_in, size: 16, color: Colors.blue),
                              ],
                            ],
                          ),
                        ),
                        if (item.previousOrganization.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Text('संस्थान: ${item.previousOrganization}', style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w600)),
                        ],
                        const SizedBox(width: 12),
                        Text('विज़िटिंग फीस: ₹${item.visitingCharge.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              if (isPending) ...[
                OutlinedButton(
                  onPressed: () => _showRejectDialog(context, item.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('अस्वीकृत करें'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    context.read<AdminKycBloc>().add(ApproveKycEvent(item.id));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('स्वीकृत करें (Approve)'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.status == AdminKycStatus.approved
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.status == AdminKycStatus.approved ? 'सत्यापित (Approved)' : 'अस्वीकृत (Rejected)',
                    style: TextStyle(
                      color: item.status == AdminKycStatus.approved ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context, String providerId) {
    final reasonController = TextEditingController(text: 'आधार दस्तावेज़ स्पष्ट नहीं है');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('KYC अस्वीकृत करने का कारण', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'कारण (Rejection Reason)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('रद्द करें'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                Navigator.pop(dialogCtx);
                context.read<AdminKycBloc>().add(RejectKycEvent(providerId: providerId, reason: reason));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('अस्वीकृत करें'),
            ),
          ],
        );
      },
    );
  }
}
