import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_bar_header.dart';
import '../../../../shared/widgets/custom_text_field.dart';

/// [CustomerHomePage] ग्राहक का मुख्य होमपेज है जहाँ वह जमुई के सभी सर्विस कैटेगरीज और प्रोवाइडर्स देख सकता है।
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _currentNavIndex = 0;

  final List<Map<String, dynamic>> _quickCategories = [
    {'name': 'इलेक्ट्रीशियन', 'icon': Icons.bolt_rounded, 'color': Color(0xFFF59E0B)},
    {'name': 'प्लंबर', 'icon': Icons.plumbing_rounded, 'color': Color(0xFF3B82F6)},
    {'name': 'कारपेंटर', 'icon': Icons.handyman_rounded, 'color': Color(0xFF8B5CF6)},
    {'name': 'AC रिपेयर', 'icon': Icons.ac_unit_rounded, 'color': Color(0xFF06B6D4)},
    {'name': 'पेंटर', 'icon': Icons.format_paint_rounded, 'color': Color(0xFFEC4899)},
    {'name': 'RO सर्विस', 'icon': Icons.water_drop_rounded, 'color': Color(0xFF10B981)},
    {'name': 'वाशिंग मशीन', 'icon': Icons.local_laundry_service_rounded, 'color': Color(0xFF6366F1)},
    {'name': 'सभी सेवाएँ', 'icon': Icons.grid_view_rounded, 'color': Color(0xFF64748B)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBarHeader(
        title: 'JAMUI SERVICE',
        locationName: 'जमुई मेन मार्केट (811307)',
        notificationCount: 2,
        onLocationTap: () {
          // लोकेशन सेलेक्टर
        },
        onNotificationTap: () {
          // नोटिफिकेशन्स
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            const CustomTextField(
              hintText: 'प्लंबर, इलेक्ट्रीशियन, AC रिपेयर खोजें...',
              prefixIcon: Icons.search_rounded,
            ),
            const SizedBox(height: 20),

            // Zero Commission Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '0% कमीशन • सीधा संपर्क',
                          style: TextStyle(
                            color: AppColors.accentLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'जमुई के सबसे भरोसेमंद\nकारीगरों से सीधे जुड़ें',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.verified_user_rounded, color: Colors.white, size: 48),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Categories Section
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'लोकप्रिय सेवाएँ (Categories)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'सभी देखें',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _quickCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.82,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final cat = _quickCategories[index];
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (cat['color'] as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 26),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['name'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Nearby Verified Providers Section
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'नजदीकी वेरिफाइड कारीगर',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'फ़िल्टर करें',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sample Provider Card
            _buildSampleProviderCard(
              name: 'राजेश कुमार (Rajesh Electricals)',
              category: 'इलेक्ट्रीशियन • 8 वर्ष अनुभव',
              rating: '4.8 (124 रिव्यू)',
              distance: '1.2 किमी दूर • जमुई टाउन',
              price: 'विजिट चार्ज: ₹150',
            ),
            const SizedBox(height: 12),
            _buildSampleProviderCard(
              name: 'अमित प्लंबिंग वर्क्स',
              category: 'प्लंबर & सेनेटरी • 5 वर्ष अनुभव',
              rating: '4.9 (89 रिव्यू)',
              distance: '2.5 किमी दूर • महिसौरी चौक',
              price: 'विजिट चार्ज: ₹199',
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
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'होम'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'कैटेगरी'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'बुकिंग'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'प्रोफ़ाइल'),
        ],
      ),
    );
  }

  Widget _buildSampleProviderCard({
    required String name,
    required String category,
    required String rating,
    required String distance,
    required String price,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.verified, color: AppColors.primary, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(category, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.accent, size: 16),
                        const SizedBox(width: 4),
                        Text(rating, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        const Icon(Icons.near_me_rounded, color: AppColors.textMuted, size: 12),
                        const SizedBox(width: 3),
                        Text(distance, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF25D366)),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 12, color: Color(0xFF25D366))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.call, size: 16, color: Colors.white),
                    label: const Text('कॉल करें', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
