import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState extends State<CustomerNotificationsPage> {
  int _limit = 30;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'सूचनाएं (Notifications)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.creamWhite,
            ),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
        ),
        body: const Center(
          child: Text('सूचनाएं देखने के लिए कृपया पहले लॉगिन करें'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'सूचनाएं (Notifications)',
          style: TextStyle(
            color: AppColors.creamWhite,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.creamWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', whereIn: [currentUser.uid, 'all', 'all_customers'])
            .orderBy('createdAt', descending: true)
            .limit(_limit)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 56,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'कोई नई सूचना नहीं है।',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'आपके अनुरोधों और बुकिंग की स्थिति यहाँ दिखेगी',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          final hasMore = docs.length >= _limit;

          return ListView.builder(
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
                          _limit += 30;
                        });
                      },
                    ),
                  ),
                );
              }

              final data = docs[index].data() as Map<String, dynamic>;
              final title = (data['title'] as String?) ?? 'सूचना';
              final message = (data['message'] as String?) ?? '';
              final isRead = (data['isRead'] as bool?) ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isRead
                      ? Colors.white
                      : AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
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
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
