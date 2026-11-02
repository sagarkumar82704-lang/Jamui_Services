import 'dart:async';
import 'package:flutter/material.dart';

import '../services/customer_app_settings_service.dart';
import 'maintenance_screen.dart';
import 'mandatory_update_screen.dart';

/// [GlobalAppGatewaysWrapper]
///
/// Global root gateway wrapper installed at `MaterialApp.builder`.
/// Continuously observes Firestore `app_settings/customer_app` via real-time stream.
///
/// Key Guarantees:
/// 1. If maintenance mode is active in Firestore -> displays full-screen non-dismissible maintenance UI.
/// 2. If force update is active and installed version < minimumSupportedVersion -> displays
///    full-screen non-dismissible blocking update UI (`PopScope(canPop: false)`).
/// 3. Applies globally across ALL routes (Splash, Login, Registration, OTP, Home, Profile, Deep links).
/// 4. When Firestore setting changes in real time (e.g. forceUpdateEnabled set to false or
///    minimumSupportedVersion lowered), the blocking UI unmounts INSTANTLY without restarting the app.
/// 5. Back navigation, gestures, or route pushes cannot bypass the blocking UI.
/// 6. Safe lifecycle handling: rechecks on `AppLifecycleState.resumed` (when returning from Play Store).
/// 7. Graceful offline/error handling: fallback defaults prevent white screen or crashes.
class GlobalAppGatewaysWrapper extends StatefulWidget {
  final Widget child;

  const GlobalAppGatewaysWrapper({
    super.key,
    required this.child,
  });

  @override
  State<GlobalAppGatewaysWrapper> createState() => _GlobalAppGatewaysWrapperState();
}

class _GlobalAppGatewaysWrapperState extends State<GlobalAppGatewaysWrapper>
    with WidgetsBindingObserver {
  AppUpdateDecision? _updateDecision;
  bool _isMaintenanceMode = false;
  String _maintenanceMessage = '';

  StreamSubscription<AppUpdateDecision>? _updateSub;
  StreamSubscription<CustomerAppSettings>? _settingsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGateways();
  }

  void _initGateways() {
    final settingsService = CustomerAppSettingsService();

    // 1. Initial cached/fallback evaluation
    _isMaintenanceMode = settingsService.currentSettings.maintenanceMode;
    _maintenanceMessage = settingsService.currentSettings.maintenanceMessage;

    settingsService.evaluateUpdateStatus().then((decision) {
      if (mounted) {
        setState(() => _updateDecision = decision);
      }
    }).catchError((_) {});

    // 2. Realtime Firestore stream subscription (snapshots on `app_settings/customer_app`)
    _updateSub = settingsService.updateDecisionStream.listen(
      (decision) {
        if (!mounted) return;
        setState(() => _updateDecision = decision);
      },
      onError: (err) {
        debugPrint('⚠️ [GlobalAppGatewaysWrapper] updateDecisionStream error: $err');
      },
    );

    _settingsSub = settingsService.settingsStream.listen(
      (settings) {
        if (!mounted) return;
        setState(() {
          _isMaintenanceMode = settings.maintenanceMode;
          _maintenanceMessage = settings.maintenanceMessage;
        });
      },
      onError: (err) {
        debugPrint('⚠️ [GlobalAppGatewaysWrapper] settingsStream error: $err');
      },
    );
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _settingsSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check Firestore settings & version comparator when app resumes (e.g. from Google Play Store)
      CustomerAppSettingsService().refreshSettings().then((_) {
        return CustomerAppSettingsService().evaluateUpdateStatus();
      }).then((decision) {
        if (mounted) {
          setState(() => _updateDecision = decision);
        }
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = _updateDecision != null && _updateDecision!.isMandatory;
    final isMaintenance = _isMaintenanceMode;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Underlying active route (preserved underneath)
          widget.child,

          // Full-screen blocking Maintenance Mode Overlay
          if (isMaintenance)
            Positioned.fill(
              child: PopScope(
                canPop: false,
                child: MaintenanceScreen(
                  message: _maintenanceMessage,
                ),
              ),
            )
          // Full-screen blocking Global Mandatory Force Update Overlay
          else if (isMandatory)
            Positioned.fill(
              child: PopScope(
                canPop: false,
                child: MandatoryUpdateScreen(
                  decision: _updateDecision!,
                  isGlobalOverlay: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
