import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_network_or_base64_image.dart';

class CategoryImageWidget extends StatelessWidget {
  final String imageUrl;
  final String categoryTitle;
  final String iconName;
  final double size;
  final double imageSize;
  final Color backgroundColor;
  final Color iconColor;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final EdgeInsets padding;

  const CategoryImageWidget({
    super.key,
    required this.imageUrl,
    this.categoryTitle = '',
    this.iconName = '',
    this.size = 54,
    this.imageSize = 42,
    this.backgroundColor = const Color(0xFFF1F5F9),
    this.iconColor = AppColors.primary,
    this.borderRadius,
    this.fit = BoxFit.contain,
    this.padding = const EdgeInsets.all(6),
  });

  static IconData resolveCategoryIcon({
    String iconName = '',
    String title = '',
  }) {
    final lowerIcon = iconName.toLowerCase().trim();
    switch (lowerIcon) {
      case 'ac_unit':
      case 'ac':
      case 'hvac':
        return Icons.ac_unit_rounded;
      case 'cleaning_services':
      case 'cleaning':
      case 'clean':
        return Icons.cleaning_services_rounded;
      case 'format_paint':
      case 'paint':
      case 'painting':
        return Icons.format_paint_rounded;
      case 'bolt':
      case 'electric':
      case 'electrician':
        return Icons.bolt_rounded;
      case 'plumbing':
      case 'plumber':
      case 'water_drop':
        return Icons.plumbing_rounded;
      case 'handyman':
      case 'build':
      case 'repair':
      case 'home_repair_service':
        return Icons.home_repair_service_rounded;
      case 'pest_control':
      case 'pest':
        return Icons.pest_control_rounded;
      case 'carpenter':
      case 'carpentry':
        return Icons.carpenter_rounded;
      case 'two_wheeler':
      case 'bike':
      case 'motorcycle':
        return Icons.two_wheeler_rounded;
      case 'directions_car':
      case 'car':
        return Icons.directions_car_rounded;
      case 'local_laundry_service':
      case 'laundry':
        return Icons.local_laundry_service_rounded;
      case 'kitchen':
      case 'appliances':
        return Icons.kitchen_rounded;
      case 'lock':
      case 'locksmith':
        return Icons.lock_rounded;
      case 'content_cut':
      case 'salon':
      case 'unisex_salon':
      case 'scissors':
      case 'hair':
      case 'barber':
        return Icons.content_cut_rounded;
    }

    // Secondary Title-based resolution if iconName is empty or generic
    final lowerTitle = title.toLowerCase().trim();
    if (lowerTitle.contains('salon') || lowerTitle.contains('सैलून') || lowerTitle.contains('hair') || lowerTitle.contains('बाल') || lowerTitle.contains('grooming') || lowerTitle.contains('unisex')) {
      return Icons.content_cut_rounded;
    }
    if (lowerTitle.contains('electric') || lowerTitle.contains('बिजली') || lowerTitle.contains('इलेक्ट्रीशियन')) {
      return Icons.bolt_rounded;
    }
    if (lowerTitle.contains('tank') || lowerTitle.contains('टैंक') || lowerTitle.contains('टंकी')) {
      return Icons.water_drop_rounded;
    }
    if (lowerTitle.contains('plumb') || lowerTitle.contains('plimber') || lowerTitle.contains('नल')) {
      return Icons.plumbing_rounded;
    }
    if (lowerTitle.contains('mechanic') || lowerTitle.contains('मैकेनिक') || lowerTitle.contains('बाइक') || lowerTitle.contains('कार') || lowerTitle.contains('auto')) {
      return Icons.directions_car_rounded;
    }
    if (lowerTitle.contains('ac') || lowerTitle.contains('एसी') || lowerTitle.contains('फ्रिज') || lowerTitle.contains('कूलर')) {
      return Icons.ac_unit_rounded;
    }
    if (lowerTitle.contains('paint') || lowerTitle.contains('पेंटर') || lowerTitle.contains('पुट्टी')) {
      return Icons.format_paint_rounded;
    }
    if (lowerTitle.contains('carpenter') || lowerTitle.contains('बढ़ई') || lowerTitle.contains('लकड़ी')) {
      return Icons.carpenter_rounded;
    }
    if (lowerTitle.contains('clean') || lowerTitle.contains('सफाई')) {
      return Icons.cleaning_services_rounded;
    }
    if (lowerTitle.contains('pest') || lowerTitle.contains('कीट') || lowerTitle.contains('दीमक')) {
      return Icons.pest_control_rounded;
    }
    if (lowerTitle.contains('appliance') || lowerTitle.contains('उपकरण')) {
      return Icons.kitchen_rounded;
    }
    if (lowerTitle.contains('lock') || lowerTitle.contains('ताला')) {
      return Icons.lock_rounded;
    }

    return Icons.handyman_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(14);
    final fallbackIcon = resolveCategoryIcon(
      iconName: iconName,
      title: categoryTitle,
    );
    final cleanUrl = imageUrl.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: effectiveBorderRadius,
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.08),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: cleanUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: AppNetworkOrBase64Image(
                    imageUrl: cleanUrl,
                    fit: fit,
                    width: imageSize,
                    height: imageSize,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(
                        fallbackIcon,
                        color: iconColor,
                        size: imageSize * 0.58,
                      ),
                    ),
                  ),
                ),
              )
            : Center(
                child: Icon(
                  fallbackIcon,
                  color: iconColor,
                  size: imageSize * 0.58,
                ),
              ),
      ),
    );
  }
}
