import 'package:flutter/material.dart';

/// [AppColors] JAMUI SERVICE प्रोजेक्ट के लिए एक एकीकृत (Unified) कलर पैलेट प्रदान करता है।
/// यहाँ हर रंग का उद्देश्य स्पष्ट रूप से परिभाषित है ताकि UI में एकरूपता बनी रहे।
abstract class AppColors {
  // Brand Primary & Accent (जमुई की पहचान: समृद्ध हरा और गहरा नेवी)
  static const Color primary = Color(0xFF0D6E57); // Deep Jamui Emerald
  static const Color primaryLight = Color(0xFF159677);
  static const Color primaryDark = Color(0xFF084B3B);
  
  static const Color secondary = Color(0xFF1E293B); // Royal Slate Navy
  static const Color secondaryLight = Color(0xFF334155);
  
  static const Color accent = Color(0xFFF59E0B); // Sunset Gold / Amber for Ratings & CTA
  static const Color accentLight = Color(0xFFFDE68A);

  // Status Colors (स्टेटस और अलर्ट के रंग)
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444);   // Coral Red
  static const Color info = Color(0xFF3B82F6);    // Sky Blue

  // Neutral Backgrounds & Cards (लाइट और डार्क मोड के लिए न्यूट्रल शेड्स)
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);

  // Text Colors (टेक्स्ट के रंग)
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textLight = Color(0xFFFFFFFF);

  // Border & Divider
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);
  static const Color divider = Color(0xFFF1F5F9);

  // Gradients (प्रीमियम कार्ड्स और बटन्स के लिए)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0D6E57), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
