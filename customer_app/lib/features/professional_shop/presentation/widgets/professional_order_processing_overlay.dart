import 'dart:ui';
import 'package:flutter/material.dart';
import '../localization/ecom_strings.dart';
import '../theme/ecom_theme.dart';

/// Full-screen or modal animated overlay shown while `placeDiamondOrder` is being processed.
///
/// Features:
/// 1. Immediately blocks all user interaction and prevents back navigation (`PopScope(canPop: false)`).
/// 2. Slightly dims the checkout background with an elegant blurred backdrop.
/// 3. Animates a floating/pulsing package & shopping bag icon using native Flutter [AnimationController].
/// 4. Displays clear Hindi progress messages: "आपका ऑर्डर प्रोसेस हो रहा है..." and "कृपया प्रतीक्षा करें।".
/// 5. Features a smooth branded progress bar and secure transaction badge.
class ProfessionalOrderProcessingOverlay extends StatefulWidget {
  final String? customTitle;
  final String? customSubtitle;

  const ProfessionalOrderProcessingOverlay({
    super.key,
    this.customTitle,
    this.customSubtitle,
  });

  /// Static helper to display the overlay via a barrier-locked modal dialog.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      barrierLabel: 'OrderProcessingBarrier',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, anim1, anim2) {
        return const ProfessionalOrderProcessingOverlay();
      },
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// Static helper to safely dismiss the overlay dialog if mounted.
  static void hide(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  State<ProfessionalOrderProcessingOverlay> createState() => _ProfessionalOrderProcessingOverlayState();
}

class _ProfessionalOrderProcessingOverlayState extends State<ProfessionalOrderProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _curvedAnim;
  late final Animation<double> _floatAnim;
  late final Animation<double> _pulseScaleAnim;
  late final Animation<double> _glowPulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _curvedAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );

    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(_curvedAnim);
    _pulseScaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(_curvedAnim);
    _glowPulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_curvedAnim);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.customTitle ?? EcomStrings.orderProcessingTitle;
    final subtitle = widget.customSubtitle ?? EcomStrings.orderProcessingSubtitle;

    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                decoration: BoxDecoration(
                  color: EcomColors.surface,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: EcomColors.primary.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated floating package & shopping bag icon
                    AnimatedBuilder(
                      animation: _curvedAnim,
                      builder: (context, _) {
                        return Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: Transform.scale(
                            scale: _pulseScaleAnim.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer pulsing soft-green glow ring
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: EcomColors.primary.withValues(
                                      alpha: 0.08 * _glowPulseAnim.value,
                                    ),
                                  ),
                                ),
                                // Inner soft green background
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: EcomColors.softGreen,
                                    border: Border.all(
                                      color: EcomColors.primary.withValues(alpha: 0.25),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_rounded,
                                    color: EcomColors.primary,
                                    size: 34,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 22),

                    // Primary Hindi Message
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: EcomColors.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Secondary Hindi Message
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: EcomColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Smooth Branded Linear Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const SizedBox(
                        height: 5,
                        width: double.infinity,
                        child: LinearProgressIndicator(
                          backgroundColor: EcomColors.softGreen,
                          valueColor: AlwaysStoppedAnimation<Color>(EcomColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Security & Platform Trust Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: EcomColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: EcomColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 13,
                            color: EcomColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              EcomStrings.secureTransaction,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: EcomColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
