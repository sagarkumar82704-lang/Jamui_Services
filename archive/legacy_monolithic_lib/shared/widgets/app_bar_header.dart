import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// [AppBarHeader] कस्टमर और प्रोवाइडर ऐप के लिए एक आकर्षक टॉप हेडर विजेट है।
/// इसमें लोकेशन चिप और नोटिफिकेशन बटन पहले से इंटीग्रेटेड है।
class AppBarHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final String? locationName;
  final VoidCallback? onLocationTap;
  final VoidCallback? onNotificationTap;
  final int notificationCount;
  final bool showBackButton;

  const AppBarHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.locationName,
    this.onLocationTap,
    this.onNotificationTap,
    this.notificationCount = 0,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 40, bottom: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (showBackButton) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (locationName != null) ...[
                    InkWell(
                      onTap: onLocationTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            locationName!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (onNotificationTap != null)
            Stack(
              children: [
                IconButton(
                  onPressed: onNotificationTap,
                  icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 26),
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
