import 'dart:async';
import 'package:flutter/material.dart';

import '../constants/app_brand.dart';
import '../constants/app_colors.dart';
import '../services/app_update_manager.dart';
import '../services/customer_app_settings_service.dart';
import '../../features/home/presentation/pages/customer_main_shell.dart';
import 'app_logo.dart';

/// Mandatory Non-Dismissible Force Update Screen
/// Locks the user until the application is updated to the required version
class MandatoryUpdateScreen extends StatefulWidget {
  final AppUpdateDecision decision;
  final bool isGlobalOverlay;
  final VoidCallback? onDismiss;

  const MandatoryUpdateScreen({
    super.key,
    required this.decision,
    this.isGlobalOverlay = false,
    this.onDismiss,
  });

  @override
  State<MandatoryUpdateScreen> createState() => _MandatoryUpdateScreenState();
}

class _MandatoryUpdateScreenState extends State<MandatoryUpdateScreen>
    with WidgetsBindingObserver {
  late AppUpdateDecision _decision;
  bool _isChecking = false;
  StreamSubscription<AppUpdateDecision>? _updateSub;

  @override
  void initState() {
    super.initState();
    _decision = widget.decision;
    WidgetsBinding.instance.addObserver(this);
    if (!widget.isGlobalOverlay) {
      _listenToLiveUpdateStream();
    }
  }

  @override
  void didUpdateWidget(covariant MandatoryUpdateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decision != widget.decision) {
      setState(() => _decision = widget.decision);
    }
  }

  void _listenToLiveUpdateStream() {
    try {
      _updateSub = CustomerAppSettingsService().updateDecisionStream.listen(
        (decision) {
          if (!mounted) return;
          if (!decision.isMandatory) {
            _navigateToApp();
          } else {
            setState(() => _decision = decision);
          }
        },
        onError: (err) {
          debugPrint('⚠️ [MandatoryUpdateScreen] updateDecisionStream error: $err');
        },
      );
    } catch (e) {
      debugPrint('⚠️ [MandatoryUpdateScreen] _listenToLiveUpdateStream error: $e');
    }
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user switches back from Google Play Store to the app
    if (state == AppLifecycleState.resumed) {
      _recheckVersion(showFeedbackIfStillOld: false);
    }
  }

  Future<void> _handleUpdateTap() async {
    await AppUpdateManager.startImmediateUpdate(
      customStoreUrl: _decision.playStoreUrl,
    );
  }

  Future<void> _recheckVersion({bool showFeedbackIfStillOld = true}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      await CustomerAppSettingsService().refreshSettings();
      final newDecision = await CustomerAppSettingsService().evaluateUpdateStatus();

      if (!mounted) return;

      if (!newDecision.isMandatory) {
        _navigateToApp();
        return;
      }

      setState(() {
        _decision = newDecision;
        _isChecking = false;
      });

      if (showFeedbackIfStillOld && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'वर्तमान वर्शन (${newDecision.installedVersion}) अभी भी न्यूनतम आवश्यक वर्शन (${newDecision.minimumSupportedVersion}) से कम है। कृपया Play Store से अपडेट पूरा करें।',
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _navigateToApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('ऐप सफलतापूर्वक अपडेट हो गया है!'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (widget.onDismiss != null) {
      widget.onDismiss!();
      return;
    }

    if (widget.isGlobalOverlay) {
      // Global overlay unmounts automatically when decision is no longer mandatory
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CustomerMainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Strictly prevent popping with back button or gesture
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              children: [
                const Spacer(flex: 1),

                // App Branding with Pulse Logo
                const AppLogo(
                  size: 96,
                  showShadow: true,
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                ),
                const SizedBox(height: 16),
                const Text(
                  AppBrand.appName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppBrand.taglineHindi,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),

                const Spacer(flex: 2),

                // Update Icon & Title
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 52,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  _decision.updateTitle.isNotEmpty
                      ? _decision.updateTitle
                      : 'New Update Available',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Message from Cloud Firestore (app_settings/customer_app)
                Text(
                  _decision.updateMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Version comparison chips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'आपका वर्शन',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _decision.installedVersion,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 28, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text(
                            'आवश्यक न्यूनतम',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _decision.minimumSupportedVersion,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 28, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text(
                            'नवीनतम वर्शन',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _decision.latestVersion,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Update Now Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _handleUpdateTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 22),
                    label: Text(
                      _decision.updateButtonText.isNotEmpty
                          ? _decision.updateButtonText
                          : 'Update Now',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Recheck button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton.icon(
                    onPressed: _isChecking ? null : () => _recheckVersion(showFeedbackIfStillOld: true),
                    icon: _isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                    label: const Text(
                      'अपडेट की जाँच करें (Check Status)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
