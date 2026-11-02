import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../reviews/data/services/customer_review_service.dart';
import '../widgets/submit_review_dialog.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _leadsStream;
  String? _subscribedUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  void _ensureLeadsStream(String userId) {
    if (_subscribedUserId == userId && _leadsStream != null) return;
    _subscribedUserId = userId;
    _leadsStream = FirebaseFirestore.instance
        .collection('leads')
        .where('customerId', isEqualTo: userId)
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String name, String category) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final normalized = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final msg = Uri.encodeComponent(
      'नमस्ते $name, मेरी $category सेवा अनुरोध के संबंध में बात करनी है।',
    );
    final uri = Uri.parse('https://wa.me/$normalized?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _cancelBookingRequest(String leadId, String providerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'अनुरोध रद्द करें (Cancel Request)?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          '$providerName को भेजा गया सेवा अनुरोध रद्द करना चाहते हैं?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'नहीं (No)',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('हाँ, रद्द करें'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('leads').doc(leadId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('सेवा अनुरोध सफलतापूर्वक रद्द कर दिया गया है।'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('रद्द करने में त्रुटि: $e'),
          ),
        );
      }
    }
  }

  void _showBookingDetailsSheet(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final leadId = (item['id'] ?? '').toString();
    final providerId = (item['providerId'] ?? '').toString();
    final providerName =
        (item['providerName'] ?? item['businessName'] ?? 'Provider').toString();
    final providerPhone = (item['providerPhone'] ?? '').toString();
    final category = (item['categoryTitle'] ?? 'Service').toString();
    final status = (item['status'] ?? 'pending').toString();
    final desc = (item['description'] ?? '').toString();
    final slot = (item['preferredTimeSlot'] ?? '').toString();
    final address =
        (item['customerAddress'] ?? item['address'] ?? 'जमुई, बिहार')
            .toString();
    final hasReviewed = item['hasReviewed'] == true;
    final reviewRating = (item['reviewRating'] as num?)?.toDouble() ?? 5.0;

    String dateStr = 'हाल ही में';
    final createdAt = item['createdAt'];
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      dateStr =
          '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    Color statusColor = Colors.orange;
    String statusText = 'पेंडिंग (कारीगर की स्वीकृति का इंतज़ार)';
    if (status == 'accepted') {
      statusColor = Colors.blue;
      statusText = 'स्वीकृत 🟢 (कारीगर आपसे संपर्क करेगा)';
    } else if (status == 'completed') {
      statusColor = Colors.green;
      statusText = 'कार्य पूर्ण (Completed) ✓';
    } else if (status == 'rejected' || status == 'cancelled') {
      statusColor = Colors.red;
      statusText = status == 'cancelled'
          ? 'ग्राहक द्वारा रद्द (Cancelled)'
          : 'कारीगर द्वारा अस्वीकृत (Rejected)';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'कारीगर: $providerName',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),

              // Booking Details List
              _buildDetailItem(
                Icons.info_outline,
                'अनुरोध स्थिति',
                statusText,
                statusColor,
              ),
              _buildDetailItem(
                Icons.calendar_today_rounded,
                'अनुरोध समय',
                dateStr,
                AppColors.textPrimary,
              ),
              if (slot.isNotEmpty)
                _buildDetailItem(
                  Icons.access_time_rounded,
                  'पसंदीदा समय',
                  slot,
                  AppColors.textPrimary,
                ),
              _buildDetailItem(
                Icons.location_on_outlined,
                'सेवा स्थल / पता',
                address,
                AppColors.textPrimary,
              ),
              if (desc.isNotEmpty)
                _buildDetailItem(
                  Icons.notes_rounded,
                  'समस्या / विवरण',
                  desc,
                  AppColors.textPrimary,
                ),
              _buildDetailItem(
                Icons.tag_rounded,
                'रेफरेंस आईडी',
                leadId.isNotEmpty ? leadId : 'JAM-REQ',
                Colors.grey,
              ),

              const SizedBox(height: 20),

              // Action Buttons inside sheet
              if (providerPhone.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openWhatsApp(
                          providerPhone,
                          providerName,
                          category,
                        ),
                        icon: const Icon(
                          Icons.chat,
                          size: 16,
                          color: Color(0xFF25D366),
                        ),
                        label: const Text(
                          'WhatsApp',
                          style: TextStyle(
                            color: Color(0xFF25D366),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF25D366)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _makePhoneCall(providerPhone),
                        icon: const Icon(
                          Icons.call,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'कॉल करें',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Cancel button if pending
              if (status == 'pending') ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _cancelBookingRequest(leadId, providerName);
                  },
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'अनुरोध रद्द करें (Cancel Request)',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],

              // Rating button if completed
              if (status == 'completed') ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final currentUid = FirebaseAuth.instance.currentUser?.uid;
                    if (currentUid != null) {
                      final rev = await CustomerReviewService()
                          .getReviewForBooking(
                            bookingId: leadId,
                            customerId: currentUid,
                          );
                      if (context.mounted) {
                        SubmitReviewDialog.show(
                          context,
                          providerId: providerId,
                          providerName: providerName,
                          leadId: leadId,
                          serviceTitle: category,
                          existingReview: rev,
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    hasReviewed
                        ? 'समीक्षा संपादित करें (${reviewRating.toInt()} ⭐)'
                        : 'रेटिंग व समीक्षा दें (Rate Service)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    IconData icon,
    String title,
    String value,
    Color valColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: valColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _subscribedUserId = null;
      _leadsStream = null;
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'मेरी बुकिंग व सेवा इतिहास',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: AppColors.creamWhite,
            ),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 52,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'सेवा इतिहास देखने के लिए कृपया लॉगिन करें',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    _ensureLeadsStream(currentUser.uid);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'मेरी बुकिंग्स व सेवा इतिहास (History)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.creamWhite,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.creamWhite.withValues(alpha: 0.75),
          indicatorColor: AppColors.accent,
          isScrollable: true,
          tabs: const [
            Tab(text: 'सभी'),
            Tab(text: 'पेंडिंग'),
            Tab(text: 'स्वीकृत'),
            Tab(text: 'पूर्ण'),
            Tab(text: 'रद्द / अस्वीकृत'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _leadsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('डेटा लोड करने में त्रुटि: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.assignment_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'कोई बुकिंग या अनुरोध उपलब्ध नहीं है',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'होम स्क्रीन से किसी भी कारीगर को सेवा अनुरोध भेजें',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final allLeads = docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          // Sort client-side by date descending
          allLeads.sort((a, b) {
            final aTime = a['createdAt'] is Timestamp
                ? (a['createdAt'] as Timestamp).toDate()
                : DateTime(2020);
            final bTime = b['createdAt'] is Timestamp
                ? (b['createdAt'] as Timestamp).toDate()
                : DateTime(2020);
            return bTime.compareTo(aTime);
          });

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLeadsList(allLeads),
              _buildLeadsList(
                allLeads.where((l) => l['status'] == 'pending').toList(),
              ),
              _buildLeadsList(
                allLeads.where((l) => l['status'] == 'accepted').toList(),
              ),
              _buildLeadsList(
                allLeads.where((l) => l['status'] == 'completed').toList(),
              ),
              _buildLeadsList(
                allLeads
                    .where(
                      (l) =>
                          l['status'] == 'rejected' ||
                          l['status'] == 'cancelled',
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeadsList(List<Map<String, dynamic>> leads) {
    if (leads.isEmpty) {
      return const Center(
        child: Text(
          'इस श्रेणी में कोई रिकॉर्ड नहीं है',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: leads.length,
      itemBuilder: (context, index) {
        final item = leads[index];
        final leadId = (item['id'] ?? '').toString();
        final providerId = (item['providerId'] ?? '').toString();
        final providerName =
            (item['providerName'] ?? item['businessName'] ?? 'Provider')
                .toString();
        final category = (item['categoryTitle'] ?? 'Service').toString();
        final status = (item['status'] ?? 'pending').toString();
        final desc = (item['description'] ?? '').toString();
        final slot = (item['preferredTimeSlot'] ?? '').toString();
        final hasReviewed = item['hasReviewed'] == true;
        final reviewRating = (item['reviewRating'] as num?)?.toDouble() ?? 5.0;

        Color statusColor = Colors.orange;
        String statusText = 'पेंडिंग (Pending)';
        if (status == 'accepted') {
          statusColor = Colors.blue;
          statusText = 'स्वीकृत (Accepted) 🟢';
        } else if (status == 'completed') {
          statusColor = Colors.green;
          statusText = 'पूर्ण (Completed) ✓';
        } else if (status == 'rejected' || status == 'cancelled') {
          statusColor = Colors.red;
          statusText = status == 'cancelled'
              ? 'रद्द (Cancelled)'
              : 'अस्वीकृत (Rejected)';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0.8,
          child: InkWell(
            onTap: () => _showBookingDetailsSheet(context, item),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          providerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'श्रेणी: $category',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'विवरण: $desc',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (slot.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'समय: $slot',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],

                  // Action area
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'विवरण देखें',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () =>
                            _showBookingDetailsSheet(context, item),
                      ),
                      if (status == 'pending')
                        TextButton.icon(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'रद्द करें',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              _cancelBookingRequest(leadId, providerName),
                        ),
                      if (status == 'completed')
                        ElevatedButton.icon(
                          icon: const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          label: Text(
                            hasReviewed
                                ? 'समीक्षा बदलें (${reviewRating.toInt()} ⭐)'
                                : 'रेटिंग दें',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            final currentUid =
                                FirebaseAuth.instance.currentUser?.uid;
                            if (currentUid != null) {
                              final rev = await CustomerReviewService()
                                  .getReviewForBooking(
                                    bookingId: leadId,
                                    customerId: currentUid,
                                  );
                              if (context.mounted) {
                                SubmitReviewDialog.show(
                                  context,
                                  providerId: providerId,
                                  providerName: providerName,
                                  leadId: leadId,
                                  serviceTitle: category,
                                  existingReview: rev,
                                );
                              }
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
