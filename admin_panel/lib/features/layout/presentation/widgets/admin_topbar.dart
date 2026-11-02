import 'package:flutter/material.dart';
import '../../../../core/constants/admin_colors.dart';

class AdminTopbar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRefresh;
  final VoidCallback? onMenuToggle;

  const AdminTopbar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    this.onMenuToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AdminColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (onMenuToggle != null) ...[
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: AdminColors.textPrimary),
                  onPressed: onMenuToggle,
                ),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AdminColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: AdminColors.textSecondary),
                label: const Text('रिफ्रेश', style: TextStyle(fontSize: 12.5, color: AdminColors.textSecondary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AdminColors.borderMedium),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AdminColors.statusApprovedBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AdminColors.statusApprovedText, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'लाइव डेटाबेस',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AdminColors.statusApprovedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
