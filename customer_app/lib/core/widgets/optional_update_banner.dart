import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/app_update_manager.dart';
import '../services/customer_app_settings_service.dart';

/// Optional dismissible update banner for home screen
class OptionalUpdateBanner extends StatefulWidget {
  final AppUpdateDecision decision;
  final VoidCallback? onDismiss;

  const OptionalUpdateBanner({
    super.key,
    required this.decision,
    this.onDismiss,
  });

  @override
  State<OptionalUpdateBanner> createState() => _OptionalUpdateBannerState();
}

class _OptionalUpdateBannerState extends State<OptionalUpdateBanner> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed || !widget.decision.isOptional || !widget.decision.isBannerEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            const Color(0xFFEFF6FF),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.decision.updateTitle.isNotEmpty
                            ? widget.decision.updateTitle
                            : 'नया अपडेट उपलब्ध',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v${widget.decision.latestVersion}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.decision.updateMessage.isNotEmpty
                        ? widget.decision.updateMessage
                        : 'नए फीचर्स एवं बेहतर परफॉरमेंस के लिए अभी अपडेट करें।',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                AppUpdateManager.startImmediateUpdate(
                  customStoreUrl: widget.decision.playStoreUrl,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'अपडेट',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                setState(() => _isDismissed = true);
                widget.onDismiss?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
