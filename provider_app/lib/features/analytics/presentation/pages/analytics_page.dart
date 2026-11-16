import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/provider_stats_service.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';

class AnalyticsPage extends StatefulWidget {
  final ProviderProfileEntity profile;

  const AnalyticsPage({super.key, required this.profile});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'परफॉरमेंस एनालिटिक्स व इंसाइट्स',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        child: ResponsiveContentContainer(
          padding: ResponsiveLayout.pagePadding(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWideKpi = constraints.maxWidth >= 680;
              final isTwoColPanels = constraints.maxWidth >= 900;

              final statTiles = [
                _buildStatTile('कुल प्रोफाइल व्यूज', '${widget.profile.totalViews}', Icons.visibility_outlined, AppColors.accent),
                _buildStatTile('डायरेक्ट फोन कॉल्स', '${widget.profile.totalCalls}', Icons.phone_in_talk_outlined, AppColors.info),
                _buildStatTile('व्हाट्सएप चैट इनक्वायरी', '${widget.profile.totalWhatsAppClicks}', Icons.chat_bubble_outline, const Color(0xFF25D366)),
                _buildStatTile('औसत स्टार रेटिंग', '${widget.profile.rating} ★', Icons.star_rounded, AppColors.gold),
              ];

              final mlSection = StreamBuilder<ProviderStats>(
                stream: ProviderStatsService.statsStream(widget.profile.id),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? ProviderStats.empty(widget.profile.id);
                  return _buildMLStatsSection(stats);
                },
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'रियल-टाइम परफॉरमेंस समरी',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (isWideKpi)
                    Row(
                      children: [
                        Expanded(child: statTiles[0]),
                        const SizedBox(width: 12),
                        Expanded(child: statTiles[1]),
                        const SizedBox(width: 12),
                        Expanded(child: statTiles[2]),
                        const SizedBox(width: 12),
                        Expanded(child: statTiles[3]),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: statTiles[0]),
                            const SizedBox(width: 10),
                            Expanded(child: statTiles[1]),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: statTiles[2]),
                            const SizedBox(width: 10),
                            Expanded(child: statTiles[3]),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  if (isTwoColPanels)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: mlSection),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: _buildInsightsCard(),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    mlSection,
                    const SizedBox(height: 20),
                    _buildInsightsCard(),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMLStatsSection(ProviderStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'लीड परफॉरमेंस इंडेक्स',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'यह स्कोर आपकी सर्च रैंकिंग को प्रभावित करता है',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D6E57), Color(0xFF1A9E7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMLMetric(
                      label: 'प्रदर्शन स्कोर',
                      value: '${stats.performanceScore}/100',
                      icon: Icons.auto_graph_rounded,
                      isLight: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMLMetric(
                      label: 'कुल लीड्स मिलीं',
                      value: '${stats.totalLeadsReceived}',
                      icon: Icons.inbox_rounded,
                      isLight: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMLMetric(
                      label: 'स्वीकृति दर',
                      value: stats.acceptanceRateDisplay,
                      icon: Icons.check_circle_outline,
                      isLight: true,
                      subtitle: '${stats.totalAccepted} स्वीकृत',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMLMetric(
                      label: 'पूर्णता दर',
                      value: stats.completionRateDisplay,
                      icon: Icons.task_alt_rounded,
                      isLight: true,
                      subtitle: '${stats.totalCompleted} पूर्ण',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Visual progress bar for performance score
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'सर्च रैंकिंग में आपकी स्थिति',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: stats.performanceScore / 100.0,
                      minHeight: 10,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPerformanceLabel(stats.performanceScore),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (stats.totalLeadsReceived == 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBE6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFF8F00), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'अभी तक कोई लीड नहीं मिली। जब ग्राहक आपको सर्विस रिक्वेस्ट भेजेंगे, यहाँ आपका परफॉरमेंस स्कोर दिखेगा।',
                    style: TextStyle(fontSize: 11, color: Color(0xFF5D4037)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getPerformanceLabel(int score) {
    if (score >= 80) return '🌟 उत्कृष्ट — आप शीर्ष रैंकिंग में हैं!';
    if (score >= 60) return '✅ अच्छा — और सुधार करने की गुंजाइश है।';
    if (score >= 40) return '⚠️ सामान्य — लीड स्वीकृति बढ़ाएं।';
    if (score > 0) return '🔴 कमजोर — रिस्पॉन्स रेट सुधारें।';
    return '—  डेटा एकत्र हो रहा है...';
  }

  Widget _buildMLMetric({
    required String label,
    required String value,
    required IconData icon,
    bool isLight = false,
    String? subtitle,
  }) {
    final textColor = isLight ? Colors.white : AppColors.textPrimary;
    final subColor = isLight ? Colors.white70 : AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: isLight ? Colors.white70 : AppColors.accent, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textColor)),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: subColor, fontWeight: FontWeight.w500)),
        if (subtitle != null)
          Text(subtitle,
              style: TextStyle(fontSize: 10, color: subColor)),
      ],
    );
  }

  Widget _buildInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text('बिजनेस ग्रोथ इंसाइट्स',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _buildInsightItem(
              'आपकी प्रोफाइल जमुई के ${widget.profile.jamuiArea} इलाके में एक्टिवली दिखाई जा रही है।'),
          _buildInsightItem(
              'लीड्स जल्दी Accept करने से आपका Performance Score बढ़ता है और आप ऊपर दिखते हैं।'),
          _buildInsightItem(
              'KYC वेरीफाइड बैज रहने से आपकी प्रोफाइल पर व्यूज 40% अधिक आते हैं।'),
          _buildInsightItem(
              'Completion Rate जितना ऊँचा, उतना आपका ML Ranking Score मजबूत।'),
        ],
      ),
    );
  }

  Widget _buildStatTile(
      String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(count,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color)),
          const SizedBox(height: 4),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.accent)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3))),
        ],
      ),
    );
  }
}
