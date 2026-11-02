import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// [CustomButton] एक पुनः प्रयोज्य (Reusable) ग्रेडिएंट और सॉलिड बटन है।
/// इसमें लोडिंग स्टेट (Spinner) और डिसेबल्ड स्टेट इन-बिल्ट है।
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final double height;
  final double? width;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.height = 50,
    this.width,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? double.infinity;

    if (isOutlined) {
      return SizedBox(
        width: effectiveWidth,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: backgroundColor ?? AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _buildChild(textColor ?? AppColors.primary),
        ),
      );
    }

    return Container(
      width: effectiveWidth,
      height: height,
      decoration: BoxDecoration(
        gradient: (onPressed == null || isLoading)
            ? null
            : (backgroundColor != null ? null : AppColors.primaryGradient),
        color: (onPressed == null || isLoading)
            ? AppColors.border
            : (backgroundColor ?? AppColors.primary),
        borderRadius: BorderRadius.circular(12),
        boxShadow: (onPressed == null || isLoading)
            ? []
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: _buildChild(textColor ?? Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
