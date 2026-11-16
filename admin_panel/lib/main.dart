import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/datasources/firebase_admin_auth_remote_data_source.dart';
import 'features/auth/data/repositories/admin_auth_repository_impl.dart';
import 'features/auth/presentation/bloc/admin_auth_bloc.dart';
import 'features/auth/presentation/bloc/admin_auth_event.dart';
import 'features/auth/presentation/bloc/admin_auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/categories/data/datasources/firebase_category_remote_data_source.dart';
import 'features/categories/data/repositories/category_repository_impl.dart';
import 'features/categories/presentation/bloc/category_bloc.dart';
import 'features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/layout/presentation/pages/main_layout_page.dart';
import 'config/firebase/firebase_options.dart';
import 'core/config/app_environment.dart';
import 'core/config/emulator_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    AppEnvironmentConfig.logEnvironment('Admin Panel');
    final options = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(
      options: options,
    );

    if (AppEnvironmentConfig.isEmulator) {
      try {
        await EmulatorConfig.configureEmulators();
      } on EmulatorSafetyException catch (e) {
        runApp(FatalEmulatorHaltApp(message: e.message));
        return;
      }
    }
  } catch (e) {
    debugPrint("🚨 [JAMUI SERVICES] Admin Panel Environment/Firebase Initialization Error: $e");
    runApp(FatalEmulatorHaltApp(message: e.toString()));
    return;
  }

  final authDataSource = FirebaseAdminAuthRemoteDataSource();
  final authRepository = AdminAuthRepositoryImpl(remoteDataSource: authDataSource);
  final dashboardDataSource = FirebaseDashboardRemoteDataSource();
  final categoryDataSource = FirebaseCategoryRemoteDataSource();
  final categoryRepository = CategoryRepositoryImpl(remoteDataSource: categoryDataSource);

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AdminAuthBloc>(
          create: (_) => AdminAuthBloc(authRepository: authRepository)..add(CheckSessionEvent()),
        ),
        BlocProvider<DashboardBloc>(
          create: (_) => DashboardBloc(dataSource: dashboardDataSource)..add(FetchDashboardStatsEvent()),
        ),
        BlocProvider<CategoryBloc>(
          create: (_) => CategoryBloc(repository: categoryRepository),
        ),
      ],
      child: const JamuiServiceAdminApp(),
    ),
  );
}

class JamuiServiceAdminApp extends StatelessWidget {
  const JamuiServiceAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JAMUI SERVICE — Admin Web Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: BlocBuilder<AdminAuthBloc, AdminAuthState>(
        builder: (context, state) {
          if (state is AdminAuthenticated) {
            return const MainLayoutPage();
          } else if (state is AdminAuthInitial) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else {
            return const LoginPage();
          }
        },
      ),
    );
  }
}
