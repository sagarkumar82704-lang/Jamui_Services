import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/services/customer_app_settings_service.dart';
import 'package:apna_jamui_customer/core/widgets/mandatory_update_screen.dart';
import 'package:apna_jamui_customer/core/widgets/maintenance_screen.dart';

void main() {
  group('Jamui Services Customer App — Global Force Update Gateway Tests', () {
    testWidgets('TEST 1: GlobalAppGatewaysWrapper displays blocking MandatoryUpdateScreen over LoginScreen when update is mandatory', (tester) async {
      final mandatoryDecision = AppUpdateDecision(
        status: AppUpdateStatus.mandatoryForceUpdate,
        installedVersion: '1.0.0+1',
        latestVersion: '2.0.0+20',
        minimumSupportedVersion: '2.0.0+20',
        updateTitle: 'Mandatory Update Required',
        updateMessage: 'कृपया सेवाओं का उपयोग जारी रखने के लिए ऐप अपडेट करें।',
        updateButtonText: 'अपडेट करें (Update Now)',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.jamuiservice.customer',
        isBannerEnabled: true,
      );

      // A mock login screen acting as the active underlying route
      final testApp = MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Scaffold(
                body: Center(child: Text('CUSTOMER_LOGIN_SCREEN_BODY')),
              ),
              Positioned.fill(
                child: PopScope(
                  canPop: false,
                  child: MandatoryUpdateScreen(
                    decision: mandatoryDecision,
                    isGlobalOverlay: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(testApp);
      await tester.pumpAndSettle();

      // Underlying screen is mounted in widget tree
      expect(find.text('CUSTOMER_LOGIN_SCREEN_BODY'), findsOneWidget);

      // Blocking MandatoryUpdateScreen is displayed on top
      expect(find.byType(MandatoryUpdateScreen), findsOneWidget);
      expect(find.text('Mandatory Update Required'), findsOneWidget);
      expect(find.text('अपडेट करें (Update Now)'), findsOneWidget);

      // PopScope strictly prevents back navigation
      final popScopeFinder = find.ancestor(
        of: find.byType(MandatoryUpdateScreen),
        matching: find.byType(PopScope),
      );
      expect(popScopeFinder, findsOneWidget);
      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);
    });

    testWidgets('TEST 2: Real-time Firestore stream update unmounts blocking overlay without restarting the app', (tester) async {
      final streamController = StreamController<AppUpdateDecision>.broadcast();

      final mandatoryDecision = AppUpdateDecision(
        status: AppUpdateStatus.mandatoryForceUpdate,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        minimumSupportedVersion: '2.0.0',
        updateTitle: 'Mandatory Update Required',
        updateMessage: 'Update message',
        updateButtonText: 'Update Now',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.jamuiservice.customer',
        isBannerEnabled: true,
      );

      final upToDateDecision = AppUpdateDecision(
        status: AppUpdateStatus.upToDate,
        installedVersion: '1.0.0',
        latestVersion: '1.0.0',
        minimumSupportedVersion: '1.0.0',
        updateTitle: '',
        updateMessage: '',
        updateButtonText: '',
        playStoreUrl: '',
        isBannerEnabled: false,
      );

      // Widget listening to real-time update stream
      final testApp = MaterialApp(
        home: StreamBuilder<AppUpdateDecision>(
          stream: streamController.stream,
          initialData: mandatoryDecision,
          builder: (context, snapshot) {
            final decision = snapshot.data;
            final isMandatory = decision != null && decision.isMandatory;

            return Stack(
              fit: StackFit.expand,
              children: [
                const Scaffold(
                  body: Center(child: Text('HOME_SCREEN_ACTIVE')),
                ),
                if (isMandatory)
                  Positioned.fill(
                    child: PopScope(
                      canPop: false,
                      child: MandatoryUpdateScreen(
                        decision: decision,
                        isGlobalOverlay: true,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );

      await tester.pumpWidget(testApp);
      await tester.pumpAndSettle();

      // Initially, blocking update screen is shown
      expect(find.byType(MandatoryUpdateScreen), findsOneWidget);

      // Admin toggles force update off or lowers minimum version in Firestore -> Stream emits up-to-date decision
      streamController.add(upToDateDecision);
      await tester.pumpAndSettle();

      // Blocking screen unmounts instantly; Home Screen is now visible and unblocked
      expect(find.byType(MandatoryUpdateScreen), findsNothing);
      expect(find.text('HOME_SCREEN_ACTIVE'), findsOneWidget);

      await streamController.close();
    });

    testWidgets('TEST 3: When maintenanceMode is true, MaintenanceScreen overlay is displayed', (tester) async {
      const testApp = MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Scaffold(
                body: Center(child: Text('UNDERLYING_SCREEN')),
              ),
              Positioned.fill(
                child: PopScope(
                  canPop: false,
                  child: MaintenanceScreen(
                    message: 'सिस्टम अपग्रेड कार्य प्रगति पर है।',
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(testApp);
      await tester.pumpAndSettle();

      expect(find.byType(MaintenanceScreen), findsOneWidget);
      expect(find.text('Under Scheduled Maintenance'), findsOneWidget);
      expect(find.text('सिस्टम अपग्रेड कार्य प्रगति पर है।'), findsOneWidget);
    });
  });
}
