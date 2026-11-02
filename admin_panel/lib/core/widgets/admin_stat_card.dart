import 'package:flutter/material.dart';
import '../constants/admin_colors.dart';

class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final IconData icon;
  final Color iconColor;
  final bool isHighlight;

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.iconColor,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHighlight) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF064E3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFA7F3D0)),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: iconColor == AdminColors.accentAmber ? AdminColors.accentAmber : AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: const TextStyle(fontSize: 11.5, color: AdminColors.textMuted),
          ),
        ],
      ),
    );
  }
}
