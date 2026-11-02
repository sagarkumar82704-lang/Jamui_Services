import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// [AppEmptyState] — खाली स्क्रीन (Empty State) दिखाने वाला कॉमन विजेट।
/// 
/// जब भी किसी लिस्ट में कोई डेटा नहीं होता (जैसे 'कोई कारीगर नहीं', 'कोई बुकिंग नहीं'),
/// तब इस विजेट का इस्तेमाल किया जाता है।
/// 
/// ## इस्तेमाल करने का तरीका:
/// ```dart
/// AppEmptyState(
///   icon: Icons.search_off_rounded,
///   title: 'कोई कारीगर उपलब्ध नहीं है',
///   subtitle: 'कृपया किसी अन्य इलाके या श्रेणी का चयन करें।',
///   actionLabel: 'फ़िल्टर हटाएं',
///   onAction: () => resetFilters(),
/// )
/// ```
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: iconSize, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
