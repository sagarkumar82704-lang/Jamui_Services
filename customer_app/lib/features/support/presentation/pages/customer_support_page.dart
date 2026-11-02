import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/company_settings_service.dart';

class CustomerSupportPage extends StatefulWidget {
  const CustomerSupportPage({super.key});

  @override
  State<CustomerSupportPage> createState() => _CustomerSupportPageState();
}

class _CustomerSupportPageState extends State<CustomerSupportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategory = 'सेवा गुणवत्ता (Service Quality)';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'सेवा गुणवत्ता (Service Quality)',
    'भुगतान / बिलिंग (Payment & Billing)',
    'कारीगर / पार्टनर समस्या (Provider Issue)',
    'बुकिंग / शेड्यूलिंग (Booking Issue)',
    'ऐप / तकनीकी समस्या (App & Technical)',
    'अन्य सामान्य सुझाव (General Inquiry)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('शिकायत दर्ज करने के लिए कृपया पहले लॉगिन करें'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final compRef = FirebaseFirestore.instance.collection('complaints').doc();
      final ticketNumber =
          'TKT-CUST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final userPhone = user.phoneNumber ?? '';
      final userEmail = user.email ?? 'Not provided';
      final userName = (user.displayName?.trim().isNotEmpty == true)
          ? user.displayName!.trim()
          : (userPhone.isNotEmpty ? 'Customer ($userPhone)' : 'Customer');

      final description = _descriptionController.text.trim();
      final subject = _subjectController.text.trim();

      final nowTimestamp = Timestamp.now();

      final ticketData = {
        'ticketId': ticketNumber,
        'complaintId': compRef.id,
        'id': compRef.id,
        'ownerUid': user.uid,
        'customerId': user.uid,
        'ownerRole': 'customer',
        'sourceApp': 'customer_app',
        'senderName': userName,
        'senderPhone': userPhone,
        'senderEmail': userEmail,
        'category': _selectedCategory,
        'subject': subject,
        'description': description,
        'message': description, // backwards compatibility
        'status': 'Open',
        'statusHistory': [
          {
            'status': 'Open',
            'changedBy': 'customer',
            'timestamp': nowTimestamp,
            'note': 'Ticket created by customer',
          }
        ],
        'messages': [
          {
            'senderId': user.uid,
            'senderRole': 'customer',
            'senderName': userName,
            'message': description,
            'timestamp': nowTimestamp,
          }
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': 'customer',
      };

      await compRef.set(ticketData);

      if (mounted) {
        _subjectController.clear();
        _descriptionController.clear();
        setState(() => _isSubmitting = false);

        _showSuccessDialog(ticketNumber, subject);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('शिकायत भेजने में त्रुटि: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(String ticketId, String subject) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 54,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'शिकायत दर्ज हो गई है!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'आपकी शिकायत सुरक्षित रूप से दर्ज कर ली गई है। हमारा सपोर्ट स्टाफ जल्द आपसे संपर्क करेगा।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'टिकट आईडी (Ticket ID)',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        ticketId,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                    tooltip: 'Copy Ticket ID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: ticketId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ticket ID क्लिपबोर्ड में कॉपी हो गया!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _tabController.animateTo(1); // switch to My Tickets tab
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('मेरे टिकट्स देखें (View My Tickets)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'सहायता एवं शिकायत (Help & Support)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.add_comment_rounded, size: 18), text: 'नया टिकट (Raise)'),
            Tab(icon: Icon(Icons.confirmation_number_rounded, size: 18), text: 'मेरे टिकट्स (My Tickets)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRaiseTicketTab(),
          _buildMyTicketsTab(),
        ],
      ),
    );
  }

  Widget _buildRaiseTicketTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCanonicalHelplineCard(),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.report_problem_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'नई शिकायत दर्ज करें (Raise Complaint)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'शिकायत की श्रेणी (Category)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCategory = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'शिकायत का विषय (Subject)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      hintText: 'उदा. कारिगर समय पर नहीं पहुंचा / अधिक शुल्क लिया',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'कृपया विषय दर्ज करें' : null,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'विस्तृत विवरण (Description)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'अपनी समस्या का पूरा विवरण यहाँ लिखें...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'कृपया विवरण दर्ज करें' : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitComplaint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'शिकायत सबमिट करें (Submit Ticket)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Realtime Stream of canonical Helpline details from Firestore `app_settings/company`
  Widget _buildCanonicalHelplineCard() {
    return StreamBuilder<CompanySettingsEntity>(
      stream: CompanySettingsService().getSettingsStream(),
      initialData: CompanySettingsService().currentSettings,
      builder: (context, snapshot) {
        final settings = snapshot.data ?? CompanySettingsEntity.fallback();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.headset_mic_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${settings.companyName} सपोर्ट हेल्पलाइन',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'कार्य समय: ${settings.workingHours} | तुरंत सहायता के लिए संपर्क करें:',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => CompanySettingsService.launchCall(settings.supportPhone),
                      icon: const Icon(Icons.call_rounded, size: 16, color: Colors.green),
                      label: Text(
                        settings.supportPhone,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => CompanySettingsService.launchWhatsApp(settings.supportWhatsapp),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyTicketsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'अपने टिकट्स देखने के लिए कृपया पहले लॉगिन करें।',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('customerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 14),
                const Text(
                  'कोई शिकायत टिकट नहीं मिला',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'यदि आपको कोई समस्या है, तो आप नया टिकट दर्ज कर सकते हैं।',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('शिकायत दर्ज करें'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          );
        }

        // Sort locally by timestamp descending
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs)
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTs = aData['createdAt'] as Timestamp?;
            final bTs = bData['createdAt'] as Timestamp?;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildTicketCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildTicketCard(String docId, Map<String, dynamic> data) {
    final ticketId = data['ticketId']?.toString() ?? 'TKT-${docId.substring(0, 8)}';
    final subject = data['subject']?.toString() ?? 'शिकायत';
    final description = data['description']?.toString() ?? data['message']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'Open';
    final category = data['category']?.toString() ?? 'General';
    final messages = (data['messages'] as List<dynamic>?) ?? [];

    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openTicketDetailModal(docId, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ticketId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subject,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      if (messages.isNotEmpty) ...[
                        Icon(Icons.forum_outlined, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '${messages.length} संदेश',
                          style: TextStyle(fontSize: 11.5, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (createdAt != null)
                        Text(
                          DateFormat('dd MMM, hh:mm a').format(createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String displayStatus = status;

    switch (status.toLowerCase()) {
      case 'open':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        displayStatus = 'Open (लंबित)';
        break;
      case 'in progress':
      case 'inprogress':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        displayStatus = 'In Progress (प्रगति पर)';
        break;
      case 'waiting for response':
      case 'waiting':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        displayStatus = 'Waiting (प्रतीक्षारत)';
        break;
      case 'resolved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        displayStatus = 'Resolved (समाधानित)';
        break;
      case 'closed':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        displayStatus = 'Closed (बंद)';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.black87;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  /// Full conversation & reply modal for customer
  void _openTicketDetailModal(String docId, Map<String, dynamic> initialData) {
    final replyController = TextEditingController();
    bool isReplying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('complaints').doc(docId).snapshots(),
              builder: (context, snapshot) {
                final data = (snapshot.data?.data() as Map<String, dynamic>?) ?? initialData;
                final ticketId = data['ticketId']?.toString() ?? 'TKT-${docId.substring(0, 8)}';
                final subject = data['subject']?.toString() ?? 'शिकायत टिकट';
                final status = data['status']?.toString() ?? 'Open';
                final isClosed = status.toLowerCase() == 'closed';
                final messages = (data['messages'] as List<dynamic>?) ?? [];

                return Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        ticketId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusBadge(status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subject,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ],
                        ),
                      ),

                      // Closed ticket warning banner
                      if (isClosed)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.grey.shade200,
                          child: const Row(
                            children: [
                              Icon(Icons.lock_rounded, size: 16, color: Colors.grey),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'यह टिकट बंद (Closed) है। नई समस्या के लिए कृपया नया टिकट बनाएं।',
                                  style: TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Messages List
                      Expanded(
                        child: messages.isEmpty
                            ? const Center(child: Text('कोई संदेश नहीं है।'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: messages.length,
                                itemBuilder: (context, i) {
                                  final m = messages[i] as Map<String, dynamic>;
                                  final role = m['senderRole']?.toString() ?? 'customer';
                                  final isAdmin = role.toLowerCase() == 'admin';
                                  final text = m['message']?.toString() ?? '';
                                  final senderName = m['senderName']?.toString() ?? (isAdmin ? 'Admin' : 'You');

                                  DateTime? msgTime;
                                  final ts = m['timestamp'];
                                  if (ts is Timestamp) msgTime = ts.toDate();

                                  return Align(
                                    alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAdmin ? const Color(0xFFF1F5F9) : AppColors.primary,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(14),
                                          topRight: const Radius.circular(14),
                                          bottomLeft: Radius.circular(isAdmin ? 2 : 14),
                                          bottomRight: Radius.circular(isAdmin ? 14 : 2),
                                        ),
                                        border: isAdmin ? Border.all(color: const Color(0xFFCBD5E1)) : null,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isAdmin)
                                                const Padding(
                                                  padding: EdgeInsets.only(right: 4.0),
                                                  child: Icon(Icons.shield_rounded, size: 12, color: AppColors.primary),
                                                ),
                                              Text(
                                                isAdmin ? 'Jamui Service Support' : senderName,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isAdmin ? AppColors.primary : Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            text,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isAdmin ? Colors.black87 : Colors.white,
                                              height: 1.3,
                                            ),
                                          ),
                                          if (msgTime != null) ...[
                                            const SizedBox(height: 4),
                                            Align(
                                              alignment: Alignment.bottomRight,
                                              child: Text(
                                                DateFormat('hh:mm a').format(msgTime),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isAdmin ? Colors.grey.shade600 : Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Reply input box
                      if (!isClosed)
                        Container(
                          padding: EdgeInsets.only(
                            left: 12,
                            right: 12,
                            top: 8,
                            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: replyController,
                                  decoration: InputDecoration(
                                    hintText: 'उत्तर लिखें (Reply)...',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: isReplying
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.send_rounded, color: AppColors.primary),
                                onPressed: isReplying
                                    ? null
                                    : () async {
                                        final text = replyController.text.trim();
                                        if (text.isEmpty) return;

                                        final messenger = ScaffoldMessenger.of(context);
                                        setSheetState(() => isReplying = true);
                                        try {
                                          final user = FirebaseAuth.instance.currentUser;
                                          final newMsg = {
                                            'senderId': user?.uid ?? '',
                                            'senderRole': 'customer',
                                            'senderName': user?.displayName ?? 'Customer',
                                            'message': text,
                                            'timestamp': Timestamp.now(),
                                          };

                                          await FirebaseFirestore.instance
                                              .collection('complaints')
                                              .doc(docId)
                                              .update({
                                            'messages': FieldValue.arrayUnion([newMsg]),
                                            'lastMessageAt': FieldValue.serverTimestamp(),
                                            'lastMessageBy': 'customer',
                                            'updatedAt': FieldValue.serverTimestamp(),
                                            // If it was waiting for response, move to in progress
                                            if (status == 'Waiting for Response')
                                              'status': 'In Progress',
                                          });

                                          replyController.clear();
                                        } catch (e) {
                                          if (mounted) {
                                            messenger.showSnackBar(
                                              SnackBar(content: Text('उत्तर भेजने में त्रुटि: $e')),
                                            );
                                          }
                                        } finally {
                                          setSheetState(() => isReplying = false);
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
