import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/phone_login_page.dart';
import '../../features/customer_home/presentation/pages/customer_home_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/provider_dashboard/presentation/pages/provider_dashboard_page.dart';
import '../../features/role_selection/presentation/pages/role_selection_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../di/injection_container.dart';

/// [AppRoutes] एप्लिकेशन के सभी नेविगेशन रूट्स को सेंट्रलाइज्ड तरीके से संभालता है।
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String roleSelection = '/role-selection';
  static const String phoneLogin = '/phone-login';
  static const String otpVerification = '/otp-verification';
  static const String customerHome = '/customer-home';
  static const String providerDashboard = '/provider-dashboard';
  static const String adminDashboard = '/admin-dashboard';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionPage());
      case phoneLogin:
        final role = settings.arguments as UserRole? ?? UserRole.customer;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => InjectionContainer.instance.createAuthBloc(),
            child: PhoneLoginPage(selectedRole: role),
          ),
        );
      case otpVerification:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => InjectionContainer.instance.createAuthBloc(),
            child: OtpVerificationPage(
              verificationId: args['verificationId'] as String? ?? '',
              phoneNumber: args['phoneNumber'] as String? ?? '',
              selectedRole: args['selectedRole'] as UserRole? ?? UserRole.customer,
              resendToken: args['resendToken'] as int?,
            ),
          ),
        );
      case customerHome:
        return MaterialPageRoute(builder: (_) => const CustomerHomePage());
      case providerDashboard:
        return MaterialPageRoute(builder: (_) => const ProviderDashboardPage());
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardPage());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
