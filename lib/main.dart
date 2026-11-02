// JAMUI SERVICES — Multi-App Monorepo Entry Point
// 
// When run on Web / Chrome, this directly boots into the Admin Panel.
// Individual apps can also be launched directly:
// 1. Admin Panel:   cd admin_panel   && flutter run -d chrome
// 2. Customer App:  cd customer_app  && flutter run
// 3. Provider App:  cd provider_app  && flutter run

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:apna_jamui_admin/main.dart' as admin_app;

void main() async {
  // On Web (Chrome, Edge, etc.), launch Admin Web Panel directly!
  if (kIsWeb) {
    admin_app.main();
    return;
  }

  // Fallback for non-web environments: Interactive App Launcher
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C7A60)),
        useMaterial3: true,
      ),
      home: const WorkspaceLauncherScreen(),
    ),
  );
}

class WorkspaceLauncherScreen extends StatelessWidget {
  const WorkspaceLauncherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C7A60),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(Icons.handyman_rounded, color: Colors.white, size: 42),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'JAMUI SERVICES',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Multi-App Workspace Launcher',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Open Admin Panel Button
                  ElevatedButton.icon(
                    onPressed: () {
                      admin_app.main();
                    },
                    icon: const Icon(Icons.admin_panel_settings_rounded, size: 22),
                    label: const Text(
                      'एडमिन पैनल खोलें (Open Admin Panel)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0C7A60),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Instructions Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'डायरेक्ट कमांड से रन करने के लिए:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCodeSnippet('Admin Web:', 'cd admin_panel && flutter run -d chrome'),
                        const SizedBox(height: 6),
                        _buildCodeSnippet('Customer App:', 'cd customer_app && flutter run'),
                        const SizedBox(height: 6),
                        _buildCodeSnippet('Provider App:', 'cd provider_app && flutter run'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeSnippet(String label, String command) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            command,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
