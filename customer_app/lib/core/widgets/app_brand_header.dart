import 'package:flutter/material.dart';
import '../constants/app_brand.dart';
import '../constants/app_colors.dart';
import 'app_logo.dart';

/// Reusable Unified App Brand Header Widget
/// 
/// Displays the official App Logo + App Name + Optional Subtitle/Tagline.
/// Configurable for Splash, AppBar, Drawer, and Setup screens.
class AppBrandHeader extends StatelessWidget {
  final double logoSize;
  final double titleSize;
  final double? subtitleSize;
  final bool showTagline;
  final bool isHorizontal;
  final Color? titleColor;
  final Color? subtitleColor;
  final CrossAxisAlignment alignment;

  const AppBrandHeader({
    super.key,
    this.logoSize = 36,
    this.titleSize = 18,
    this.subtitleSize,
    this.showTagline = false,
    this.isHorizontal = true,
    this.titleColor,
    this.subtitleColor,
    this.alignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      AppBrand.appName,
      style: TextStyle(
        fontSize: titleSize,
        fontWeight: FontWeight.w900,
        color: titleColor ?? AppColors.textPrimary,
        letterSpacing: isHorizontal ? -0.3 : 1.2,
      ),
    );

    final subtitleWidget = showTagline
        ? Text(
            AppBrand.taglineHindi,
            style: TextStyle(
              fontSize: subtitleSize ?? (titleSize * 0.55),
              fontWeight: FontWeight.w600,
              color: subtitleColor ?? AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
            textAlign: isHorizontal ? TextAlign.start : TextAlign.center,
          )
        : const SizedBox.shrink();

    if (isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment,
        children: [
          AppLogo(size: logoSize, borderRadius: BorderRadius.circular(logoSize * 0.22)),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              if (showTagline) subtitleWidget,
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        AppLogo(size: logoSize, showShadow: true, borderRadius: BorderRadius.circular(logoSize * 0.22)),
        const SizedBox(height: 16),
        titleWidget,
        if (showTagline) ...[
          const SizedBox(height: 6),
          subtitleWidget,
        ],
      ],
    );
  }
}
