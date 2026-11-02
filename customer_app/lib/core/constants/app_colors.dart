import 'package:flutter/material.dart';

/// [AppColors] कस्टमर ऐप के लिए ब्रांड कलर्स प्रदान करता है।
abstract class AppColors {
  static const Color primary = Color(0xFF073F38);
  static const Color primaryLight = Color(0xFF12685D);
  static const Color primaryDark = Color(0xFF052F2A);

  static const Color creamWhite = Color(0xFFFFF8ED);
  static const Color secondary = Color(0xFFFF891B);
  static const Color accent = secondary;
  static const Color accentLight = Color(0xFFFFE5CC);
  static const Color gold = Color(0xFFFFB800);

  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFFF891B);
  static const Color error = Color(0xFFEF4444);

  static const Color background = Color(0xFFFFF8ED);
  static const Color backgroundLight = Color(0xFFFFF8ED);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF202522);
  static const Color textSecondary = Color(0xFF68716D);
  static const Color textMuted = Color(0xFF8B938F);

  static const Color border = Color(0xFFEAE4D9);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF073F38), Color(0xFF12685D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
