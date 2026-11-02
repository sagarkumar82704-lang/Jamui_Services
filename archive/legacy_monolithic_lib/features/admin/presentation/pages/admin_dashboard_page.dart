import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bar_header.dart';

/// [AdminDashboardPage] एडमिनिस्ट्रेटर का मास्टर डैशबोर्ड है जहाँ वह प्रोवाइडर वेरिफिकेशन, सब्सक्रिप्शन रेवेन्यू और कैटेगरी कंट्रोल करता है।
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: const AppBarHeader(
        title: 'JAMUI SERVICE एडमिन पोर्टल',
        subtitle: 'मास्टर कंट्रोल पैनल',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue & Growth Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'मासिक सब्सक्रिप्शन रेवेन्यू',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '₹ 48,500',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('एक्टिव प्रोवाइडर्स: 142', style: TextStyle(color: AppColors.accentLight, fontSize: 12)),
                      Text('आज की नई लीड्स: 320', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Management Quick Actions
            const Text(
              'प्रबंधन मॉड्यूल्स (Admin Controls)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            _buildAdminMenuTile(
              title: 'KYC एवं प्रोवाइडर वेरिफिकेशन',
              subtitle: '12 नए प्रोवाइडर अप्रूवल के लिए पेंडिंग हैं',
              icon: Icons.verified_user_outlined,
              badgeCount: 12,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _buildAdminMenuTile(
              title: 'सर्विस कैटेगरी एवं रेट-कार्ड',
              subtitle: 'कैटेगरीज जोड़ें, हटाएं या प्राथमिकता बदलें',
              icon: Icons.category_outlined,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _buildAdminMenuTile(
              title: 'सब्सक्रिप्शन प्लान्स एवं मूल्य निर्धारण',
              subtitle: 'Basic, Standard, Premium प्लान कॉन्फ़िगर करें',
              icon: Icons.card_membership_outlined,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _buildAdminMenuTile(
              title: 'कस्टमर शिकायतें एवं विवाद निवारण',
              subtitle: '2 शिकायतें समाधान के लिए प्रतीक्षारत हैं',
              icon: Icons.report_problem_outlined,
              badgeCount: 2,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminMenuTile({
    required String title,
    required String subtitle,
    required IconData icon,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: badgeCount != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              )
            : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
      ),
    );
  }
}
