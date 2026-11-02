import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CategoryBadgeTheme {
  final String? emoji;
  final IconData? icon;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const CategoryBadgeTheme({
    this.emoji,
    this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
  });
}

class ProviderCategoryBadge extends StatelessWidget {
  final String categoryTitle;
  final double fontSize;
  final int additionalCategoriesCount;
  final VoidCallback? onTap;

  const ProviderCategoryBadge({
    super.key,
    required this.categoryTitle,
    this.fontSize = 10.5,
    this.additionalCategoriesCount = 0,
    this.onTap,
  });

  static CategoryBadgeTheme getThemeForCategory(String category) {
    final lower = category.toLowerCase().trim();

    // 1. Electrician
    if (lower.contains('electric') ||
        lower.contains('बिजली') ||
        lower.contains('इलेक्ट्रीशियन') ||
        lower.contains('वायरिंग') ||
        lower.contains('lighting')) {
      return const CategoryBadgeTheme(
        emoji: '⚡',
        bgColor: Color(0xFFE0F2FE),
        borderColor: Color(0xFFBAE6FD),
        textColor: Color(0xFF0284C7),
      );
    }

    // 2. Water Tank Cleaning (check before plumber so tank is distinct)
    if (lower.contains('tank') ||
        lower.contains('टैंक') ||
        lower.contains('वॉटर टैंक') ||
        lower.contains('टंकी')) {
      return const CategoryBadgeTheme(
        emoji: '💧',
        bgColor: Color(0xFFE0F7FA),
        borderColor: Color(0xFFB2EBF2),
        textColor: Color(0xFF00838F),
      );
    }

    // 3. Plumber
    if (lower.contains('plumb') ||
        lower.contains('plimber') ||
        lower.contains('नल') ||
        lower.contains('प्लंबर') ||
        lower.contains('पाइप')) {
      return const CategoryBadgeTheme(
        emoji: '🔧',
        bgColor: Color(0xFFF0FDF4),
        borderColor: Color(0xFFBBF7D0),
        textColor: Color(0xFF15803D),
      );
    }

    // 4. Auto / Bike / Car Mechanic
    if (lower.contains('mechanic') ||
        lower.contains('मैकेनिक') ||
        lower.contains('बाइक') ||
        lower.contains('कार') ||
        lower.contains('auto') ||
        lower.contains('garage') ||
        lower.contains('गैरेज') ||
        lower.contains('motorcycle') ||
        lower.contains('वाहन')) {
      return const CategoryBadgeTheme(
        emoji: '🚗',
        bgColor: Color(0xFFFFF7ED),
        borderColor: Color(0xFFFED7AA),
        textColor: Color(0xFFC2410C),
      );
    }

    // 5. AC & Refrigeration
    if (lower.contains('ac') ||
        lower.contains('एसी') ||
        lower.contains('refrigerat') ||
        lower.contains('फ्रिज') ||
        lower.contains('कूलर') ||
        lower.contains('hvac')) {
      return const CategoryBadgeTheme(
        emoji: '❄️',
        bgColor: Color(0xFFF0FDFA),
        borderColor: Color(0xFF99F6E4),
        textColor: Color(0xFF0F766E),
      );
    }

    // 6. Carpenter
    if (lower.contains('carpenter') ||
        lower.contains('बढ़ई') ||
        lower.contains('लकड़ी') ||
        lower.contains('फर्नीचर') ||
        lower.contains('carpentry')) {
      return const CategoryBadgeTheme(
        emoji: '🪚',
        bgColor: Color(0xFFFEF3C7),
        borderColor: Color(0xFFFDE68A),
        textColor: Color(0xFF92400E),
      );
    }

    // 7. Painter
    if (lower.contains('paint') ||
        lower.contains('पेंटर') ||
        lower.contains('पुट्टी') ||
        lower.contains('रंग') ||
        lower.contains('पुताई')) {
      return const CategoryBadgeTheme(
        emoji: '🎨',
        bgColor: Color(0xFFFAF5FF),
        borderColor: Color(0xFFE9D5FF),
        textColor: Color(0xFF7E22CE),
      );
    }

    // 8. Cleaning
    if (lower.contains('clean') ||
        lower.contains('सफाई') ||
        lower.contains('झाड़ू') ||
        lower.contains('housekeeping')) {
      return const CategoryBadgeTheme(
        emoji: '🧹',
        bgColor: Color(0xFFECFDF5),
        borderColor: Color(0xFFA7F3D0),
        textColor: Color(0xFF047857),
      );
    }

    // 9. Pest Control
    if (lower.contains('pest') ||
        lower.contains('दीमक') ||
        lower.contains('कीट') ||
        lower.contains('कीटनाशक')) {
      return const CategoryBadgeTheme(
        emoji: '🛡️',
        bgColor: Color(0xFFF7FEE7),
        borderColor: Color(0xFFD9F99D),
        textColor: Color(0xFF4D7C0F),
      );
    }

    // 10. Locksmith
    if (lower.contains('lock') ||
        lower.contains('ताला') ||
        lower.contains('चाबी')) {
      return const CategoryBadgeTheme(
        emoji: '🔑',
        bgColor: Color(0xFFF1F5F9),
        borderColor: Color(0xFFCBD5E1),
        textColor: Color(0xFF334155),
      );
    }

    // 11. Home Appliances
    if (lower.contains('appliance') ||
        lower.contains('उपकरण') ||
        lower.contains('washing machine') ||
        lower.contains('वाशिंग मशीन') ||
        lower.contains('microwave')) {
      return const CategoryBadgeTheme(
        emoji: '🔌',
        bgColor: Color(0xFFEEF2FF),
        borderColor: Color(0xFFC7D2FE),
        textColor: Color(0xFF4338CA),
      );
    }

    // 12. Default Service Partner
    return const CategoryBadgeTheme(
      emoji: '✨',
      bgColor: Color(0xFFF8FAFC),
      borderColor: Color(0xFFE2E8F0),
      textColor: AppColors.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanTitle = categoryTitle.trim().isNotEmpty
        ? categoryTitle.trim()
        : 'सर्विस पार्टनर';
    final theme = getThemeForCategory(cleanTitle);

    Widget badgeContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.2),
      decoration: BoxDecoration(
        color: theme.bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.borderColor, width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (theme.emoji != null) ...[
            Text(
              theme.emoji!,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 3.5),
          ] else if (theme.icon != null) ...[
            Icon(
              theme.icon,
              size: fontSize + 1,
              color: theme.textColor,
            ),
            const SizedBox(width: 3.5),
          ],
          Flexible(
            child: Text(
              cleanTitle,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
                height: 1.15,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (additionalCategoriesCount > 0) ...[
            const SizedBox(width: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+$additionalCategoriesCount',
                style: TextStyle(
                  fontSize: fontSize * 0.85,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: badgeContent,
      );
    }

    return badgeContent;
  }
}
