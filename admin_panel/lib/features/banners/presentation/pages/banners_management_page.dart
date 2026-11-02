import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/datasources/admin_banner_remote_data_source.dart';
import '../../domain/entities/admin_banner_entity.dart';
import '../widgets/add_edit_banner_dialog.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';

class BannersManagementPage extends StatefulWidget {
  const BannersManagementPage({super.key});

  @override
  State<BannersManagementPage> createState() => _BannersManagementPageState();
}

class _BannersManagementPageState extends State<BannersManagementPage> {
  final AdminBannerRemoteDataSource _dataSource = FirebaseAdminBannerRemoteDataSource();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<AdminBannerEntity>>(
        stream: _dataSource.watchAllBanners(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final banners = snapshot.data ?? [];
          final activeCount = banners.where((b) => b.isActive && !b.isExpired).length;
          final totalImpressions = banners.fold<int>(0, (sum, b) => sum + b.impressions);
          final totalClicks = banners.fold<int>(0, (sum, b) => sum + b.clicks);
          final avgCtr = totalImpressions > 0 ? (totalClicks / totalImpressions) * 100 : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Add Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('प्रायोजित बैनर प्रबंधन (Sponsor Banners)', style: AppTextStyles.h2),
                        const SizedBox(height: 4),
                        Text(
                          'कस्टमर ऐप होम स्क्रीन पर दिखाए जाने वाले विज्ञापनों और प्रायोजित अभियानों को नियंत्रित करें',
                          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        AddEditBannerDialog.show(
                          context,
                          onSave: (newBanner) async {
                            await _dataSource.createBanner(newBanner);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('बैनर सफलतापूर्वक प्रकाशित किया गया! 🟢'), backgroundColor: Colors.green),
                              );
                            }
                          },
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('नया बैनर जोड़ें'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Metrics Grid
                Row(
                  children: [
                    _buildMetricCard('कुल बैनर्स', '${banners.length}', Icons.view_carousel_outlined, Colors.blue),
                    const SizedBox(width: 16),
                    _buildMetricCard('सक्रिय विज्ञापन', '$activeCount', Icons.check_circle_outline, Colors.green),
                    const SizedBox(width: 16),
                    _buildMetricCard('कुल व्यूज (Impressions)', '$totalImpressions', Icons.visibility_outlined, Colors.purple),
                    const SizedBox(width: 16),
                    _buildMetricCard('कुल क्लिक्स (Clicks)', '$totalClicks', Icons.touch_app_outlined, Colors.orange),
                    const SizedBox(width: 16),
                    _buildMetricCard('औसत CTR', '${avgCtr.toStringAsFixed(1)}%', Icons.analytics_outlined, Colors.teal),
                  ],
                ),
                const SizedBox(height: 28),

                // Banners List / Table
                Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Text(
                          'सक्रिय एवं शेड्यूल्ड बैनर सूची (${banners.length})',
                          style: AppTextStyles.h3.copyWith(fontSize: 15),
                        ),
                      ),
                      const Divider(height: 1),
                      if (banners.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(48.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.campaign_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('अभी तक कोई बैनर नहीं बनाया गया है।', style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('नया बैनर बनाने के लिए ऊपर दिए गए बटन पर क्लिक करें।', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: banners.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final b = banners[index];
                            return _buildBannerListItem(context, b);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerListItem(BuildContext context, AdminBannerEntity banner) {
    final isExpired = banner.isExpired;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          // Banner Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: banner.imageUrl.isNotEmpty
                ? AppNetworkOrBase64Image(
                    imageUrl: banner.imageUrl,
                    width: 100,
                    height: 56,
                    fit: BoxFit.cover,
                  )
                : Container(width: 100, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.image)),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (banner.isSponsored)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Text('Sponsored • ${banner.sponsorName}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                      ),
                    Text(banner.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'टारगेट: ${banner.targetType.label} (${banner.targetId.isNotEmpty ? banner.targetId : "Home"}) • बटन: "${banner.ctaText}" • प्राथमिकता: ${banner.priority}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Dates & Status
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'अवधि: ${banner.startAt != null ? "${banner.startAt!.day}/${banner.startAt!.month}" : "Any"} → ${banner.endAt != null ? "${banner.endAt!.day}/${banner.endAt!.month}/${banner.endAt!.year}" : "Never"}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                if (isExpired)
                  const Text('समाप्त (Expired)', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold))
                else if (banner.isActive)
                  const Text('सक्रिय (Active 🟢)', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))
                else
                  const Text('निष्क्रिय (Inactive ⏸️)', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Performance Stats
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('व्यूज: ${banner.impressions} | क्लिक्स: ${banner.clicks}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                Text('CTR: ${banner.ctr.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Active Switch & Actions
          Switch(
            value: banner.isActive,
            onChanged: (val) {
              _dataSource.toggleBannerStatus(banner.id, val);
            },
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'संपादित करें',
            onPressed: () {
              AddEditBannerDialog.show(
                context,
                banner: banner,
                onSave: (updated) async {
                  await _dataSource.updateBanner(updated);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('बैनर अपडेट किया गया! 🟢'), backgroundColor: Colors.green),
                    );
                  }
                },
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'हटाएं',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('बैनर हटाएं?'),
                  content: Text('क्या आप सचमुच "${banner.title}" बैनर को हटाना चाहते हैं?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('हटाएं', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _dataSource.deleteBanner(banner.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
