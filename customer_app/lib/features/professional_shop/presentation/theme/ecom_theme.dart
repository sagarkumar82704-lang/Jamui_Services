import 'package:flutter/material.dart';

/// Design tokens strictly scoped to Professional Seller Mini E-commerce Store.
/// Based directly on the reference design specifications:
/// - Light Green and White theme
/// - Rounded cards, modern headers, and clear visual hierarchy
class EcomColors {
  EcomColors._();

  static const Color primary = Color(0xFF087443);       // Vibrant Forest Green
  static const Color primaryDark = Color(0xFF075638);    // Deep Header Green
  static const Color background = Color(0xFFF7F9F7);    // Clean Light Canvas
  static const Color surface = Color(0xFFFFFFFF);        // Pure White Surface
  static const Color softGreen = Color(0xFFE9F5EC);     // Mint Pill / Tag Background
  static const Color accentOrange = Color(0xFFFF8A24);  // Discount Pill & % Tags
  static const Color textPrimary = Color(0xFF172B24);   // Dark Charcoal Text
  static const Color textSecondary = Color(0xFF66766D); // Muted Slate Text
  static const Color textTertiary = Color(0xFF94A3B8);  // Light Placeholder Text
  static const Color border = Color(0xFFE5EAE7);         // Subtle Border
  static const Color divider = Color(0xFFECF0EE);        // Hairline Divider
  static const Color cardBorder = Color(0xFFE5EAE7);    // Card outline
  static const Color ratingGold = Color(0xFFF59E0B);    // Star Rating Color

  /// Card elevation shadow — returns a `List<BoxShadow>` for use in `BoxDecoration.boxShadow`
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF087443).withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Floating bottom bar shadow — returns a `List<BoxShadow>`
  static List<BoxShadow> get floatingBarShadow => [
        BoxShadow(
          color: const Color(0xFF075638).withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ];
}
