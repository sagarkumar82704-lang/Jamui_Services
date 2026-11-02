import 'dart:math';
import 'package:flutter/material.dart';

/// Bundled Demo Placeholder Item for Admin Panel
/// Visually marked as temporary/demo so admins never mistake it for a real saved asset.
class AdminPlaceholderItem {
  final String id;
  final String titleHindi;
  final String titleEnglish;
  final String tag;
  final IconData icon;
  final Color startColor;
  final Color endColor;

  const AdminPlaceholderItem({
    required this.id,
    required this.titleHindi,
    required this.titleEnglish,
    required this.tag,
    required this.icon,
    required this.startColor,
    required this.endColor,
  });

  /// The virtual URI scheme that is NEVER saved to Firestore or uploaded to R2
  String get virtualUri => 'placeholder://$id';
}

/// Centralized Manager for Admin Temporary Placeholder Images
/// Requirements:
/// 1. Local/bundled only - Zero external network calls.
/// 2. Clearly distinguished visually with "DEMO PLACEHOLDER / NOT SAVED" watermarks.
/// 3. Never saved to Firestore as real R2 object keys.
class AdminPlaceholderImages {
  AdminPlaceholderImages._();

  static final Random _random = Random();

  static const String placeholderScheme = 'placeholder://';

  /// Pre-defined curated Category Placeholders
  static final List<AdminPlaceholderItem> categoryPlaceholders = [
    const AdminPlaceholderItem(
      id: 'category/home_electric',
      titleHindi: 'इलेक्ट्रीशियन सेवा (डेमो)',
      titleEnglish: 'Electrical & Power Services',
      tag: 'इलेक्ट्रिकल',
      icon: Icons.electrical_services_rounded,
      startColor: Color(0xFF1E3A8A), // Deep Indigo
      endColor: Color(0xFF3B82F6),   // Vivid Blue
    ),
    const AdminPlaceholderItem(
      id: 'category/plumbing_water',
      titleHindi: 'प्लंबिंग व सेनेटरी (डेमो)',
      titleEnglish: 'Plumbing & Pipe Repair',
      tag: 'प्लंबिंग',
      icon: Icons.plumbing_rounded,
      startColor: Color(0xFF065F46), // Emerald
      endColor: Color(0xFF10B981),   // Bright Green
    ),
    const AdminPlaceholderItem(
      id: 'category/carpentry_wood',
      titleHindi: 'बढ़ई व फर्नीचर (डेमो)',
      titleEnglish: 'Carpentry & Woodwork',
      tag: 'बढ़ई',
      icon: Icons.carpenter_rounded,
      startColor: Color(0xFF78350F), // Warm Amber
      endColor: Color(0xFFF59E0B),   // Gold
    ),
    const AdminPlaceholderItem(
      id: 'category/cleaning_sanitization',
      titleHindi: 'सफाई व सैनिटाइजेशन (डेमो)',
      titleEnglish: 'Home Cleaning & Wash',
      tag: 'सफाई',
      icon: Icons.cleaning_services_rounded,
      startColor: Color(0xFF4C1D95), // Deep Violet
      endColor: Color(0xFF8B5CF6),   // Purple
    ),
    const AdminPlaceholderItem(
      id: 'category/appliance_repair',
      titleHindi: 'उपकरण मरम्मत (डेमो)',
      titleEnglish: 'AC & Appliance Repair',
      tag: 'अप्लायंस',
      icon: Icons.kitchen_rounded,
      startColor: Color(0xFF831843), // Crimson Rose
      endColor: Color(0xFFEC4899),   // Pink
    ),
    const AdminPlaceholderItem(
      id: 'category/unisex_salon',
      titleHindi: 'यूनिसेक्स सैलून (डेमो)',
      titleEnglish: 'Unisex Salon & Grooming',
      tag: 'सैलून',
      icon: Icons.content_cut_rounded,
      startColor: Color(0xFF831843), // Rich Crimson
      endColor: Color(0xFFF43F5E),   // Rose
    ),
  ];

  /// Pre-defined curated Banner Placeholders
  static final List<AdminPlaceholderItem> bannerPlaceholders = [
    const AdminPlaceholderItem(
      id: 'banner/festival_sale',
      titleHindi: 'त्योहार विशेष धमाका 50% छूट (डेमो बैनर)',
      titleEnglish: 'Festival Special Offer - Up to 50% Off',
      tag: 'त्योहार ऑफर',
      icon: Icons.campaign_rounded,
      startColor: Color(0xFF991B1B), // Crimson Red
      endColor: Color(0xFFEF4444),   // Bright Red
    ),
    const AdminPlaceholderItem(
      id: 'banner/verified_experts',
      titleHindi: '100% सत्यापित कारीगर व मिस्त्री (डेमो बैनर)',
      titleEnglish: 'Verified & Police Checked Service Experts',
      tag: 'सत्यापित एक्सपर्ट्स',
      icon: Icons.verified_user_rounded,
      startColor: Color(0xFF0F766E), // Teal
      endColor: Color(0xFF14B8A6),   // Cyan Teal
    ),
    const AdminPlaceholderItem(
      id: 'banner/express_booking',
      titleHindi: '30 मिनट में त्वरित होम सर्विस (डेमो बैनर)',
      titleEnglish: 'Instant Express Booking at Doorstep',
      tag: 'त्वरित सेवा',
      icon: Icons.bolt_rounded,
      startColor: Color(0xFFD97706), // Amber
      endColor: Color(0xFFFBBF24),   // Yellow Gold
    ),
  ];

  /// Returns whether a given URI or key is a temporary placeholder
  static bool isPlaceholder(String? path) {
    if (path == null) return false;
    final clean = path.trim();
    return clean.startsWith(placeholderScheme) || clean.contains('demo_placeholder');
  }

  /// Get random Category Placeholder
  static AdminPlaceholderItem getRandomCategoryPlaceholder({String? excludeId}) {
    final available = categoryPlaceholders.where((p) => p.id != excludeId).toList();
    if (available.isEmpty) return categoryPlaceholders.first;
    return available[_random.nextInt(available.length)];
  }

  /// Get random Banner Placeholder
  static AdminPlaceholderItem getRandomBannerPlaceholder({String? excludeId}) {
    final available = bannerPlaceholders.where((p) => p.id != excludeId).toList();
    if (available.isEmpty) return bannerPlaceholders.first;
    return available[_random.nextInt(available.length)];
  }

  /// Builds a prominent, visually unambiguous Demo Placeholder preview widget
  static Widget buildPlaceholderWidget({
    required AdminPlaceholderItem placeholder,
    double? width,
    double? height,
    bool isBanner = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [placeholder.startColor, placeholder.endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Background Icon Pattern
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              placeholder.icon,
              size: (height != null && height > 100) ? 90 : 54,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Warning Demo Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.8), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amberAccent),
                      SizedBox(width: 4),
                      Text(
                        'डेमो प्लेसहोल्डर (अस्थायी / Not Saved)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  placeholder.titleHindi,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  placeholder.titleEnglish,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
