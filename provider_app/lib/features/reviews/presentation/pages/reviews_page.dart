import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';

class ReviewsPage extends StatelessWidget {
  final ProviderProfileEntity profile;

  const ReviewsPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ग्राहकों की समीक्षाएं व रेटिंग', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: ResponsiveContentContainer(
          maxWidth: 960,
          padding: ResponsiveLayout.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rating Overview Card
              Container(
                padding: EdgeInsets.all(ResponsiveLayout.isSmallMobile(context) ? 14 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${profile.rating}',
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.accent),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < profile.rating.floor() ? Icons.star_rounded : Icons.star_half_rounded,
                              color: AppColors.gold,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${profile.ratingCount} ग्राहकों की कुल रेटिंग', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('100% सत्यापित ग्राहक', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                        SizedBox(height: 4),
                        Text('• सेवा गुणवत्ता: उत्कृष्ट', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('• व्यवहार व समय: उत्तम', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('• वाजिब विज़िटिंग फीस', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text('हालिया समीक्षाएं (Reviews List)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reviews')
                    .where('providerId', isEqualTo: profile.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text('अभी तक कोई कस्टमर रिव्यू नहीं मिला है।', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ),
                    );
                  }

                  return ResponsiveCardGrid(
                    tabletColumns: 2,
                    desktopColumns: 2,
                    largeDesktopColumns: 2,
                    spacing: 12,
                    runSpacing: 0,
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['customerName'] as String?) ?? 'ग्राहक';
                      final comment = (data['comment'] as String?) ?? '';
                      final rating = (data['rating'] as num?)?.toDouble() ?? 5.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: AppColors.gold, size: 14),
                                    const SizedBox(width: 4),
                                    Text('$rating', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(comment, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
