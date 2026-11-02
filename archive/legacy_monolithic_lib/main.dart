import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/app_environment.dart';
import 'config/firebase/firebase_options.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/constants/app_strings.dart';
import 'core/di/injection_container.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. वातावरण सेट करें (डेवलपमेंट मोड में सुरक्षित टेस्टिंग)
  AppConfig.setEnvironment(AppEnvironmentType.dev);

  // 2. BLoC Logger शुरू करें
  Bloc.observer = AppBlocObserver();

  // 3. Dependency Injection इनिशियलाइज़ करें
  InjectionContainer.instance.init();

  // 4. Firebase सुरक्षित रूप से प्रारंभ करें (Try-Catch के साथ)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      debugPrint('🔥 [Firebase Initialized Successfully]: Project jamui-services');
      debugPrint('🛡️ [Environment Active]: ${AppConfig.environment.name.toUpperCase()} (Production Database is Protected)');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️ [Firebase Init Warning]: $e');
    }
  }

  runApp(const ApnaJamuiApp());
}

/// [ApnaJamuiApp] एप्लिकेशन का मुख्य रूट विजेट है।
class ApnaJamuiApp extends StatelessWidget {
  const ApnaJamuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
