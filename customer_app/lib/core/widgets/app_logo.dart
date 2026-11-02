import 'package:flutter/material.dart';
import '../constants/app_brand.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showShadow;

  const AppLogo({
    super.key,
    this.size = 48,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;

    Widget imageWidget = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: Image.asset(
        AppBrand.logoAsset,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          width: effectiveWidth,
          height: effectiveHeight,
          decoration: BoxDecoration(
            color: AppBrand.primaryColor,
            borderRadius: borderRadius ?? BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.handyman_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );

    if (showShadow) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
