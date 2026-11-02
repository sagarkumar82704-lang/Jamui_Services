import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _targetAudience = 'all';
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcastNotification() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSending = true);

    try {
      final fs = FirebaseFirestore.instance;
      final admin = FirebaseAuth.instance.currentUser;
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();

      // 1. Save to broadcast_notifications collection
      final broadcastDoc = fs.collection('broadcast_notifications').doc();
      await broadcastDoc.set({
        'id': broadcastDoc.id,
        'title': title,
        'message': body,
        'targetAudience': _targetAudience, // 'all', 'customers', 'providers'
        'sentBy': admin?.email ?? 'Master Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Add broadcast notification entries into notifications collection
      // (Broadcast tags 'all', 'customers', 'providers' are automatically read by Customer & Provider apps)
      final batch = fs.batch();

      if (_targetAudience == 'all' || _targetAudience == 'customers') {
        final custNotif = fs.collection('notifications').doc();
        batch.set(custNotif, {
          'userId': 'all_customers',
          'title': title,
          'message': body,
          'type': 'broadcast',
          'targetAudience': 'customers',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (_targetAudience == 'all' || _targetAudience == 'providers') {
        final provNotif = fs.collection('notifications').doc();
        batch.set(provNotif, {
          'userId': 'all_providers',
          'title': title,
          'message': body,
          'type': 'broadcast',
          'targetAudience': 'providers',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Also create general 'all' tag
      final generalNotif = fs.collection('notifications').doc();
      batch.set(generalNotif, {
        'userId': 'all',
        'title': title,
        'message': body,
        'type': 'broadcast',
        'targetAudience': _targetAudience,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        setState(() => _isSending = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Text('पुश नोटिफिकेशन सफलतापूर्वक भेजा गया! ($_targetAudience) 🟢'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('सूचना भेजने में त्रुटि: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Broadcast Form Box
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FCM Push Notification Broadcaster', style: AppTextStyles.h2),
                          const SizedBox(height: 2),
                          Text(
                            'जमुई क्षेत्र के ग्राहकों और कारीगरों को तुरंत पुश नोटिफिकेशन भेजें',
                            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Notification Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'सूचना शीर्षक (Notification Title) *',
                      hintText: 'उदा. विशेष ऑफर 20% छूट / नई सेवाएं उपलब्ध!',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'शीर्षक आवश्यक है' : null,
                  ),
                  const SizedBox(height: 16),

                  // Message Body
                  TextFormField(
                    controller: _bodyController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'संदेश विवरण (Message Body) *',
                      hintText: 'उदा. आज ही जमुई के वेरिफाइड इलेक्ट्रीशियन व प्लंबर बुक करें और पाएं विशेष छूट...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'संदेश विवरण आवश्यक है' : null,
                  ),
                  const SizedBox(height: 16),

                  // Target Audience Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _targetAudience,
                    decoration: const InputDecoration(
                      labelText: 'लक्षित दर्शक (Target Audience)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('सभी उपयोगकर्ता (Customers & Providers)')),
                      DropdownMenuItem(value: 'customers', child: Text('केवल ग्राहक (Customers Only)')),
                      DropdownMenuItem(value: 'providers', child: Text('केवल कारीगर (Providers Only)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _targetAudience = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Send Button
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendBroadcastNotification,
                    icon: _isSending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_isSending ? 'भेजा जा रहा है...' : 'पुश नोटिफिकेशन प्रसारित करें (Broadcast)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Broadcast History Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('हाल में भेजे गए प्रसारण (Broadcast History)', style: AppTextStyles.h3.copyWith(fontSize: 16)),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('broadcast_notifications')
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text('अभी तक कोई प्रसारण नहीं भेजा गया है।')),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final title = (data['title'] ?? 'Title').toString();
                        final msg = (data['message'] ?? '').toString();
                        final audience = (data['targetAudience'] ?? 'all').toString();
                        final sentBy = (data['sentBy'] ?? 'Admin').toString();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE2E8F0),
                            child: Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('$msg\nलक्षित: $audience | द्वारा: $sentBy', style: const TextStyle(fontSize: 11.5)),
                          isThreeLine: true,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
