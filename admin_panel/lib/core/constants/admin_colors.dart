import 'package:flutter/material.dart';

abstract class AdminColors {
  // Brand & Sidebar Colors (Modern Dark Navy SaaS Style)
  static const Color sidebarBackground = Color(0xFF0F172A); // Deep Slate Navy
  static const Color sidebarHeader = Color(0xFF0B1329);
  static const Color sidebarHover = Color(0xFF1E293B);
  static const Color sidebarActive = Color(0xFF0D6E57); // Jamui Emerald Active

  // Primary & Accents
  static const Color primary = Color(0xFF0F172A);
  static const Color primaryDark = Color(0xFF020617);
  static const Color accentEmerald = Color(0xFF0D6E57);
  static const Color accentEmeraldLight = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentRed = Color(0xFFEF4444);

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardHeader = Color(0xFFF1F5F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderMedium = Color(0xFFCBD5E1);

  // Status Colors (Badges)
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusPendingText = Color(0xFF92400E);

  static const Color statusApprovedBg = Color(0xFFD1FAE5);
  static const Color statusApprovedText = Color(0xFF065F46);

  static const Color statusRejectedBg = Color(0xFFFEE2E2);
  static const Color statusRejectedText = Color(0xFF991B1B);

  static const Color statusBlockedBg = Color(0xFFF1F5F9);
  static const Color statusBlockedText = Color(0xFF475569);
}
