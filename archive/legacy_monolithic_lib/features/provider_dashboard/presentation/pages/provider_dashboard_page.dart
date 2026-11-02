import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bar_header.dart';

/// [ProviderDashboardPage] सर्विस प्रोवाइडर का मुख्य वर्कस्पेस है जहाँ वह अपनी लाइव एनालिटिक्स (Views, Calls, WhatsApp, Leads) और सब्सक्रिप्शन देखता है।
class ProviderDashboardPage extends StatefulWidget {
  const ProviderDashboardPage({super.key});

  @override
  State<ProviderDashboardPage> createState() => _ProviderDashboardPageState();
}

class _ProviderDashboardPageState extends State<ProviderDashboardPage> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBarHeader(
        title: 'राजेश इलेक्ट्रिकल वर्क्स',
        subtitle: 'प्रोवाइडर डैशबोर्ड • जमुई',
        notificationCount: 5,
        onNotificationTap: () {},
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscription Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.workspace_premium, color: AppColors.accent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Premium Plan',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              Text(
                                'वैधता: 24 दिन शेष (15 Oct 2026)',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: const Text(
                          'सक्रिय (Active)',
                          style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Performance Analytics Header
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'इस महीने की परफॉरमेंस (Analytics)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  'Sept 2026',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Analytics Metrics Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildMetricCard(
                  title: 'Profile Views',
                  value: '1,248',
                  subtitle: '+18% पिछले माह से',
                  icon: Icons.visibility_outlined,
                  color: AppColors.primary,
                ),
                _buildMetricCard(
                  title: 'Call Clicks',
                  value: '186',
                  subtitle: 'सीधे ग्राहकों से',
                  icon: Icons.phone_in_talk_outlined,
                  color: AppColors.info,
                ),
                _buildMetricCard(
                  title: 'WhatsApp Clicks',
                  value: '74',
                  subtitle: 'सीधी चैट इन्क्वायरी',
                  icon: Icons.chat_bubble_outline,
                  color: const Color(0xFF25D366),
                ),
                _buildMetricCard(
                  title: 'Total Leads',
                  value: '92',
                  subtitle: '38 बुकिंग्स स्वीकार कीं',
                  icon: Icons.assignment_outlined,
                  color: AppColors.accent,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Inquiries / Leads
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'हालिया कस्टमर लीड्स (Recent Leads)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  'सभी देखें',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildLeadItem(
              customerName: 'अमित कुमार सिंह',
              serviceName: 'शॉर्ट सर्किट व वायरिंग रिपेयर',
              time: '15 मिनट पहले',
              type: 'Call Inquiry',
              location: 'बोधि वन रोड, जमुई',
            ),
            const SizedBox(height: 8),
            _buildLeadItem(
              customerName: 'सुनील वर्णवाल',
              serviceName: 'फैन और स्विच बोर्ड इंस्टालेशन',
              time: '2 घंटे पहले',
              type: 'WhatsApp Inquiry',
              location: 'स्टेशन रोड, जमुई',
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) => setState(() => _currentNavIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'डैशबोर्ड'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'लीड्स'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'एनालिटिक्स'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'प्रोफ़ाइल'),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildLeadItem({
    required String customerName,
    required String serviceName,
    required String time,
    required String type,
    required String location,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_callback_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(serviceName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Text(location, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
