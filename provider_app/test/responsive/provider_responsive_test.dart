import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/core/utils/responsive_layout.dart';
import 'package:apna_jamui_provider/core/widgets/responsive_shell.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_bloc.dart';
import 'package:apna_jamui_provider/features/auth/presentation/pages/provider_login_page.dart';
import 'package:apna_jamui_provider/features/auth/presentation/pages/provider_register_page.dart';
import '../features/auth/provider_auth_bloc_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const representativeSizes = <String, Size>{
    'Small Mobile (320x720)': Size(320, 720),
    'Standard Mobile (360x800)': Size(360, 800),
    'Standard Mobile (390x844)': Size(390, 844),
    'Large Mobile (430x932)': Size(430, 932),
    'Tablet Portrait (768x1024)': Size(768, 1024),
    'Tablet Landscape (1024x768)': Size(1024, 768),
    'Laptop (1366x768)': Size(1366, 768),
    'Desktop HD (1440x900)': Size(1440, 900),
    'Large Desktop FHD (1920x1080)': Size(1920, 1080),
  };

  group('ResponsiveLayout Breakpoints Unit Tests', () {
    test('Correctly identifies device categories', () {
      expect(ResponsiveLayout.getDeviceSize(320), ProviderDeviceSize.smallMobile);
      expect(ResponsiveLayout.getDeviceSize(360), ProviderDeviceSize.smallMobile);
      expect(ResponsiveLayout.getDeviceSize(361), ProviderDeviceSize.standardMobile);
      expect(ResponsiveLayout.getDeviceSize(390), ProviderDeviceSize.standardMobile);
      expect(ResponsiveLayout.getDeviceSize(430), ProviderDeviceSize.standardMobile);
      expect(ResponsiveLayout.getDeviceSize(431), ProviderDeviceSize.largeMobile);
      expect(ResponsiveLayout.getDeviceSize(599), ProviderDeviceSize.largeMobile);
      expect(ResponsiveLayout.getDeviceSize(600), ProviderDeviceSize.tablet);
      expect(ResponsiveLayout.getDeviceSize(768), ProviderDeviceSize.tablet);
      expect(ResponsiveLayout.getDeviceSize(1023), ProviderDeviceSize.tablet);
      expect(ResponsiveLayout.getDeviceSize(1024), ProviderDeviceSize.laptop);
      expect(ResponsiveLayout.getDeviceSize(1366), ProviderDeviceSize.laptop);
      expect(ResponsiveLayout.getDeviceSize(1440), ProviderDeviceSize.laptop);
      expect(ResponsiveLayout.getDeviceSize(1441), ProviderDeviceSize.largeDesktop);
      expect(ResponsiveLayout.getDeviceSize(1920), ProviderDeviceSize.largeDesktop);
    });

    test('KPI columns adapt correctly by screen width', () {
      expect(ResponsiveLayout.kpiColumnsForWidth(320), 2);
      expect(ResponsiveLayout.kpiColumnsForWidth(390), 2);
      expect(ResponsiveLayout.kpiColumnsForWidth(500), 2);
      expect(ResponsiveLayout.kpiColumnsForWidth(768), 3);
      expect(ResponsiveLayout.kpiColumnsForWidth(1024), 4);
      expect(ResponsiveLayout.kpiColumnsForWidth(1366), 4);
      expect(ResponsiveLayout.kpiColumnsForWidth(1920), 4);
    });
  });

  group('Representative 9-Viewport Zero-Overflow Widget Tests', () {
    for (final entry in representativeSizes.entries) {
      testWidgets('ProviderLoginPage renders without error or overflow at ${entry.key}', (tester) async {
        final mockRepo = MockProviderRepository(currentProfile: null);
        final bloc = ProviderAuthBloc(providerRepository: mockRepo);

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<ProviderAuthBloc>.value(
              value: bloc,
              child: const ProviderLoginPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Jamui Services'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ProviderRegisterPage renders without error or overflow at ${entry.key}', (tester) async {
        final mockRepo = MockProviderRepository(currentProfile: null);
        final bloc = ProviderAuthBloc(providerRepository: mockRepo);

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<ProviderAuthBloc>.value(
              value: bloc,
              child: const ProviderRegisterPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Seller Account'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ResponsiveWorkspaceShell Navigation Architecture Tests', () {
    const destinations = [
      WorkspaceNavDestination(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'डैशबोर्ड'),
      WorkspaceNavDestination(icon: Icons.flash_on_outlined, activeIcon: Icons.flash_on_rounded, label: 'लीड्स'),
      WorkspaceNavDestination(icon: Icons.list_alt_rounded, activeIcon: Icons.list_alt_rounded, label: 'लिस्टिंग्स'),
      WorkspaceNavDestination(icon: Icons.insights_rounded, activeIcon: Icons.insights_rounded, label: 'एनालिटिक्स'),
      WorkspaceNavDestination(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'प्रोफाइल'),
    ];

    testWidgets('Renders BottomNavigationBar on Mobile (< 600px)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveWorkspaceShell(
            body: const Center(child: Text('Workspace Body')),
            currentIndex: 0,
            onSelectIndex: (_) {},
            destinations: destinations,
            brandTitle: 'Jamui Services',
            brandSubtitle: 'Service Partner',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('Renders NavigationRail on Tablet (600–1023px)', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveWorkspaceShell(
            body: const Center(child: Text('Workspace Body')),
            currentIndex: 0,
            onSelectIndex: (_) {},
            destinations: destinations,
            brandTitle: 'Jamui Services',
            brandSubtitle: 'Service Partner',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('Renders Professional Sidebar on Laptop/Desktop (>= 1024px)', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveWorkspaceShell(
            body: const Center(child: Text('Workspace Body')),
            currentIndex: 0,
            onSelectIndex: (_) {},
            destinations: destinations,
            brandTitle: 'Jamui Services Partner',
            brandSubtitle: 'Service Partner',
            statusBadgeText: 'Online (सक्रिय)',
            isStatusPositive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jamui Services Partner'), findsOneWidget);
      expect(find.text('Online (सक्रिय)'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('Responsive Screenshot Captures (Mobile, Tablet, Desktop)', () {
    Future<void> captureWidgetScreenshot({
      required WidgetTester tester,
      required Widget widget,
      required Size size,
      required String filename,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repaintBoundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintBoundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: widget,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary = repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          try {
            final image = await boundary.toImage(pixelRatio: 1.0).timeout(const Duration(seconds: 3));
            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              final pngBytes = byteData.buffer.asUint8List();
              final file = File(filename);
              await file.parent.create(recursive: true);
              await file.writeAsBytes(pngBytes);
            }
          } catch (_) {
            // Headless software rasterizer fallback
          }
        }
      });
    }

    testWidgets('Capture Mobile Screenshot (390x844)', (tester) async {
      final mockRepo = MockProviderRepository(currentProfile: null);
      final bloc = ProviderAuthBloc(providerRepository: mockRepo);

      await captureWidgetScreenshot(
        tester: tester,
        widget: BlocProvider<ProviderAuthBloc>.value(
          value: bloc,
          child: const ProviderLoginPage(),
        ),
        size: const Size(390, 844),
        filename: 'D:/jamui_service/provider_app/test/screenshots/provider_mobile_390x844.png',
      );
    });

    testWidgets('Capture Tablet Screenshot (768x1024)', (tester) async {
      const destinations = [
        WorkspaceNavDestination(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'डैशबोर्ड'),
        WorkspaceNavDestination(icon: Icons.flash_on_outlined, activeIcon: Icons.flash_on_rounded, label: 'लीड्स'),
        WorkspaceNavDestination(icon: Icons.list_alt_rounded, activeIcon: Icons.list_alt_rounded, label: 'लिस्टिंग्स'),
        WorkspaceNavDestination(icon: Icons.insights_rounded, activeIcon: Icons.insights_rounded, label: 'एनालिटिक्स'),
        WorkspaceNavDestination(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'प्रोफाइल'),
      ];

      await captureWidgetScreenshot(
        tester: tester,
        widget: ResponsiveWorkspaceShell(
          body: Container(
            color: const Color(0xFFF8FAFC),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tablet_mac_rounded, size: 64, color: Color(0xFF1A73E8)),
                  SizedBox(height: 12),
                  Text('Tablet Balanced Layout (768x1024)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('NavigationRail on left with 2-column cards', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          currentIndex: 0,
          onSelectIndex: (_) {},
          destinations: destinations,
          brandTitle: 'Jamui Services',
          brandSubtitle: 'Partner Hub',
        ),
        size: const Size(768, 1024),
        filename: 'D:/jamui_service/provider_app/test/screenshots/provider_tablet_768x1024.png',
      );
    });

    testWidgets('Capture Desktop Screenshot (1366x768)', (tester) async {
      const destinations = [
        WorkspaceNavDestination(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'डैशबोर्ड'),
        WorkspaceNavDestination(icon: Icons.flash_on_outlined, activeIcon: Icons.flash_on_rounded, label: 'लीड्स'),
        WorkspaceNavDestination(icon: Icons.list_alt_rounded, activeIcon: Icons.list_alt_rounded, label: 'लिस्टिंग्स'),
        WorkspaceNavDestination(icon: Icons.insights_rounded, activeIcon: Icons.insights_rounded, label: 'एनालिटिक्स'),
        WorkspaceNavDestination(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'प्रोफाइल'),
      ];

      await captureWidgetScreenshot(
        tester: tester,
        widget: ResponsiveWorkspaceShell(
          body: Container(
            color: const Color(0xFFF8FAFC),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.desktop_windows_rounded, size: 64, color: Color(0xFF0F766E)),
                  SizedBox(height: 12),
                  Text('Laptop / Desktop Full Sidebar Layout (1366x768)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('Full left sidebar with partner branding and responsive max-width main frame', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          currentIndex: 0,
          onSelectIndex: (_) {},
          destinations: destinations,
          brandTitle: 'Jamui Services Partner',
          brandSubtitle: 'Electronics & Repair Workshop',
          statusBadgeText: 'Online (सक्रिय)',
          isStatusPositive: true,
        ),
        size: const Size(1366, 768),
        filename: 'D:/jamui_service/provider_app/test/screenshots/provider_desktop_1366x768.png',
      );
    });
  });
}

