import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// [PrimaryButton] — पूरे ऐप में इस्तेमाल होने वाला मुख्य बटन विजेट।
///
/// यह लोडिंग स्पिनर, आइकन, डिसेबल्ड स्टेट और यूनिफ़ॉर्म स्टाइलिंग को खुद संभालता है।
///
/// ## इस्तेमाल करने का तरीका:
/// ```dart
/// PrimaryButton(
///   text: 'लॉगिन करें',
///   isLoading: state is Loading,
///   onPressed: () => submitForm(),
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final double? width;
  final double borderRadius;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.height = 48,
    this.width,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.accent,
          foregroundColor: textColor ?? AppColors.textPrimary,
          elevation: 0,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textPrimary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor ?? AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
