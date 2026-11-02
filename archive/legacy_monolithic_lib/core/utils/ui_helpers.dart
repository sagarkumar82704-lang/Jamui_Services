import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

/// [UIHelpers] UI को रेस्पॉन्सिव, क्लीन और स्पेसिंग को सरल बनाने वाले हेल्पर्स प्रदान करता है।
class UIHelpers {
  UIHelpers._();

  // Vertical Spacings
  static const Widget verticalSpaceExtraSmall = SizedBox(height: 4.0);
  static const Widget verticalSpaceSmall = SizedBox(height: 8.0);
  static const Widget verticalSpaceMedium = SizedBox(height: 16.0);
  static const Widget verticalSpaceLarge = SizedBox(height: 24.0);
  static const Widget verticalSpaceExtraLarge = SizedBox(height: 32.0);

  // Horizontal Spacings
  static const Widget horizontalSpaceExtraSmall = SizedBox(width: 4.0);
  static const Widget horizontalSpaceSmall = SizedBox(width: 8.0);
  static const Widget horizontalSpaceMedium = SizedBox(width: 16.0);
  static const Widget horizontalSpaceLarge = SizedBox(width: 24.0);

  // Modern Toast / SnackBar Alert
  static void showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  // Currency Formatter (उदा: ₹ 499)
  static String formatCurrency(num amount) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
    return format.format(amount);
  }

  // Number Formatter (उदा: 1,248 views)
  static String formatCount(num count) {
    final format = NumberFormat.compact(locale: 'en_IN');
    return format.format(count);
  }
}
