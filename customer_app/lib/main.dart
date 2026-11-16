import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/firebase/firebase_options.dart';
import 'core/config/app_environment.dart';
import 'core/config/emulator_config.dart';
import 'core/config/gemini_ai_config.dart';
import 'core/config/maps_config.dart';
import 'core/services/app_notification_service.dart';
import 'core/services/customer_app_settings_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/global_app_gateways_wrapper.dart';
import 'features/favourites/data/services/customer_favourites_service.dart';
import 'features/auth/data/datasources/firebase_customer_auth_remote_data_source.dart';
import 'features/auth/data/repositories/customer_auth_repository_impl.dart';
import 'features/auth/presentation/bloc/customer_auth_bloc.dart';
import 'features/discovery/data/datasources/firebase_customer_discovery_remote_data_source.dart';
import 'features/discovery/data/repositories/customer_discovery_repository_impl.dart';
import 'features/discovery/domain/repositories/customer_discovery_repository.dart';
import 'features/discovery/presentation/bloc/discovery_bloc.dart';
import 'features/home/presentation/pages/customer_main_shell.dart';
import 'features/location/data/datasources/location_local_data_source.dart';
import 'features/location/data/datasources/location_remote_data_source.dart';
import 'features/location/data/repositories/location_repository_impl.dart';
import 'features/location/presentation/bloc/location_bloc.dart';
import 'features/splash/presentation/pages/splash_screen.dart';
import 'features/professional_shop/presentation/bloc/professional_cart_bloc.dart';

export 'features/home/presentation/pages/customer_home_screen.dart';
export 'features/home/presentation/pages/customer_main_shell.dart';

bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register global crash prevention hooks before any async code runs
  FlutterError.onError = (errorDetails) {
    debugPrint('⚠️ [Flutter Framework Error] ${errorDetails.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('⚠️ [Platform Error] $error');
    return true; // Prevents app termination on uncaught async errors
  };

  SharedPreferences? sharedPreferences;
  try {
    sharedPreferences = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('⚠️ [JAMUI SERVICES] SharedPreferences Init Error: $e');
  }

  try {
    AppEnvironmentConfig.logEnvironment('Customer App');
    final options = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(
      options: options,
    );
    isFirebaseInitialized = true;
    debugPrint('🔥 [JAMUI SERVICES] Customer App Firebase Initialized Successfully');

    if (AppEnvironmentConfig.isEmulator) {
      try {
        await EmulatorConfig.configureEmulators();
      } on EmulatorSafetyException catch (e) {
        runApp(FatalEmulatorHaltApp(message: e.message));
        return;
      }
    }
    
    // Initialize Auth Listeners safely
    try {
      MapsConfig.initAuthListener();
      GeminiAiConfig.initAuthListener();
      CustomerFavouritesService().initAuthListener();
    } catch (_) {}

    // Asynchronously fetch non-critical cloud configs in background without delaying runApp
    unawaited(Future.wait([
      MapsConfig.fetchFromCloud().timeout(const Duration(seconds: 4), onTimeout: () {}).catchError((_) {}),
      GeminiAiConfig.fetchFromCloud().timeout(const Duration(seconds: 4), onTimeout: () {}).catchError((_) {}),
      AppNotificationService.initialize(userType: 'customer').timeout(const Duration(seconds: 4), onTimeout: () {}).catchError((_) {}),
      CustomerAppSettingsService()
          .initialize()
          .timeout(const Duration(seconds: 4), onTimeout: () => CustomerAppSettings.fallback())
          .catchError((_) => CustomerAppSettings.fallback()),
    ]).catchError((_) => <void>[]));
  } catch (e, stackTrace) {
    isFirebaseInitialized = false;
    debugPrint('🚨 [JAMUI SERVICES] Customer App Environment/Firebase Initialization Error: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(FatalEmulatorHaltApp(message: e.toString()));
    return;
  }

  runApp(JamuiServiceCustomerApp(sharedPreferences: sharedPreferences));
}

void unawaited(Future<void>? future) {}

class JamuiServiceCustomerApp extends StatelessWidget {
  final CustomerDiscoveryRepository? discoveryRepository;
  final SharedPreferences? sharedPreferences;

  const JamuiServiceCustomerApp({
    super.key,
    this.discoveryRepository,
    this.sharedPreferences,
  });

  @override
  Widget build(BuildContext context) {
    final repo = discoveryRepository ??
        CustomerDiscoveryRepositoryImpl(
          remoteDataSource: FirebaseCustomerDiscoveryRemoteDataSource(),
        );

    final authRepo = CustomerAuthRepositoryImpl(
      remoteDataSource: FirebaseCustomerAuthRemoteDataSource(),
    );

    final locationRepo = LocationRepositoryImpl(
      remoteDataSource: LocationRemoteDataSourceImpl(),
      localDataSource: LocationLocalDataSourceImpl(
        prefs: sharedPreferences,
      ),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<CustomerAuthBloc>(
          create: (_) => CustomerAuthBloc(authRepository: authRepo),
        ),
        BlocProvider<DiscoveryBloc>(
          create: (_) => DiscoveryBloc(discoveryRepository: repo),
        ),
        BlocProvider<LocationBloc>(
          create: (_) => LocationBloc(locationRepository: locationRepo),
        ),
        BlocProvider<ProfessionalCartBloc>(
          create: (_) => ProfessionalCartBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Jamui Services',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          return GlobalAppGatewaysWrapper(child: child ?? const SizedBox.shrink());
        },
        home: const SplashScreen(),
        routes: {
          '/main': (context) => const CustomerMainShell(),
        },
      ),
    );
  }
}
