import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/notification_read_helper.dart';

class NotificationsPage extends StatefulWidget {
  final String providerId;

  const NotificationsPage({super.key, required this.providerId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int _limit = 25;
  bool _isMarkingAllRead = false;

  @override
  void initState() {
    super.initState();
    _loadReadBroadcastIds();
  }

  Future<void> _loadReadBroadcastIds() async {
    await NotificationReadHelper.init(widget.providerId);
    if (mounted) setState(() {});
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(date.year, date.month, date.day);

    final timeStr = DateFormat('hh:mm a').format(date);
    if (notificationDate == today) {
      return 'आज, $timeStr';
    } else if (notificationDate == today.subtract(const Duration(days: 1))) {
      return 'कल, $timeStr';
    } else {
      return '${DateFormat('dd MMM yyyy').format(date)}, $timeStr';
    }
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    final unreadPersonalDocs = <QueryDocumentSnapshot>[];
    final unreadBroadcastIds = <String>[];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final isPersonal = data['userId'] == widget.providerId;
      if (isPersonal) {
        if ((data['isRead'] as bool? ?? false) == false) {
          unreadPersonalDocs.add(doc);
        }
      } else {
        if (!NotificationReadHelper.isNotificationRead(
          docId: doc.id,
          data: data,
          providerId: widget.providerId,
        )) {
          unreadBroadcastIds.add(doc.id);
        }
      }
    }

    if (unreadPersonalDocs.isEmpty && unreadBroadcastIds.isEmpty) return;

    setState(() => _isMarkingAllRead = true);
    try {
      // 1. Mark personal notifications read in Firestore
      if (unreadPersonalDocs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in unreadPersonalDocs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }

      // 2. Mark broadcast notifications read locally per provider (without mutating shared Firestore doc)
      if (unreadBroadcastIds.isNotEmpty) {
        await NotificationReadHelper.markBroadcastsRead(unreadBroadcastIds, widget.providerId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('सभी सूचनाएं पढ़ी हुई चिह्नित कर दी गईं।'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [Notifications] Failed to mark all as read: $e');
    } finally {
      if (mounted) setState(() => _isMarkingAllRead = false);
    }
  }

  Future<void> _markSingleAsRead(DocumentReference ref, String docId, Map<String, dynamic> data) async {
    final isPersonal = data['userId'] == widget.providerId;
    if (isPersonal) {
      final isRead = (data['isRead'] as bool?) ?? false;
      if (!isRead) {
        try {
          await ref.update({'isRead': true});
        } catch (e) {
          debugPrint('⚠️ [Notifications] Failed to mark notification as read: $e');
        }
      }
    } else {
      // Broadcast notification: mark read locally for this provider
      await NotificationReadHelper.markBroadcastRead(docId, widget.providerId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'सूचनाएं (Notifications)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', whereIn: [widget.providerId, 'all', 'all_providers'])
            .orderBy('createdAt', descending: true)
            .limit(_limit)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('कोई नई सूचना नहीं है।', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('सेवा अनुरोध और बुकिंग अलर्ट यहाँ दिखेंगे', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            );
          }

          final unreadCount = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return !NotificationReadHelper.isNotificationRead(
              docId: doc.id,
              data: data,
              providerId: widget.providerId,
            );
          }).length;

          final hasMore = docs.length >= _limit;

          return Column(
            children: [
              // Unread summary bar & Mark all as read button
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.accent.withValues(alpha: 0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$unreadCount अपठित सूचना${unreadCount > 1 ? 'एं' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                      TextButton(
                        onPressed: _isMarkingAllRead ? null : () => _markAllAsRead(docs),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _isMarkingAllRead
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              )
                            : const Text(
                                'सब पढ़ा हुआ चिह्नित करें',
                                style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == docs.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: TextButton.icon(
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            label: Text(
                              'और पुरानी सूचनाएं देखें (${docs.length} लोड हैं)',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _limit += 25;
                              });
                            },
                          ),
                        ),
                      );
                    }

                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['title'] as String?) ?? 'नोटिफिकेशन';
                    final message = (data['message'] as String?) ?? '';
                    final isRead = NotificationReadHelper.isNotificationRead(
                      docId: doc.id,
                      data: data,
                      providerId: widget.providerId,
                    );
                    final createdAt = data['createdAt'] as Timestamp?;
                    final timeFormatted = _formatTimestamp(createdAt);

                    return InkWell(
                      onTap: () => _markSingleAsRead(doc.reference, doc.id, data),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.white : AppColors.accent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRead ? AppColors.border : AppColors.accent.withValues(alpha: 0.3),
                            width: isRead ? 1.0 : 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isRead ? Icons.notifications_none : Icons.notifications_active,
                              color: isRead ? AppColors.textMuted : AppColors.accent,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.accent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (timeFormatted.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      timeFormatted,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isRead ? AppColors.textMuted : AppColors.accent,
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
