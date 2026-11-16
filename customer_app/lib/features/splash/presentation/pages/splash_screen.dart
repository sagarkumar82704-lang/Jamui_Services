import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_brand.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../auth/presentation/bloc/customer_auth_bloc.dart';
import '../../../auth/presentation/bloc/customer_auth_event.dart';
import '../../../auth/presentation/bloc/customer_auth_state.dart';
import '../../../auth/presentation/pages/customer_profile_setup_screen.dart';
import '../../../auth/presentation/pages/customer_login_screen.dart';
import '../../../discovery/presentation/bloc/discovery_bloc.dart';
import '../../../discovery/presentation/bloc/discovery_event.dart';
import '../../../location/domain/entities/customer_location_entity.dart';
import '../../../location/presentation/bloc/location_bloc.dart';
import '../../../location/presentation/bloc/location_event.dart';
import '../../../../core/services/customer_app_settings_service.dart';
import '../../../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  Timer? _safetyTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();

    // Start instant initialization and navigation pipeline
    _executeStartupSequence();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _executeStartupSequence() async {
    // 1. Guaranteed safety timer: in worst case (offline/hung), navigate after 4.0s
    _safetyTimer = Timer(const Duration(milliseconds: 4000), () {
      if (!_hasNavigated && mounted) {
        _safeDirectNavigate();
      }
    });

    try {
      // 2. Minimum splash presentation duration for premium feel (1.0 second)
      final splashDelay = Future.delayed(const Duration(milliseconds: 1000));

      // 3. Concurrent gateway check (Firestore Stream / CustomerAppSettings Force Update) with timeout
      final gatewayCheck = _checkGatewaysFast();

      // Wait for both splash delay and gateway check
      await Future.wait([splashDelay, gatewayCheck]);

      if (_hasNavigated || !mounted) return;

      // 4. Perform auth routing
      _routeUser();
    } catch (e) {
      debugPrint('⚠️ [SplashScreen] Startup sequence safe fallback: $e');
      if (!_hasNavigated && mounted) {
        _safeDirectNavigate();
      }
    }
  }

  Future<bool> _checkGatewaysFast() async {
    try {
      final appSettingsService = CustomerAppSettingsService();
      // Fast Firestore check (Realtime, authoritative)
      await appSettingsService.evaluateUpdateStatus().timeout(
            const Duration(seconds: 4),
            onTimeout: () => appSettingsService.evaluateUpdateStatus(overrideCurrentVersion: null),
          );

      // Gateways (Force Update and Maintenance Mode) are globally managed by GlobalAppGatewaysWrapper
      return true;
    } catch (e) {
      debugPrint('⚠️ [SplashScreen] Gateways check exception: $e');
      return true;
    }
  }

  void _routeUser() {
    if (_hasNavigated || !mounted) return;
    context.read<CustomerAuthBloc>().add(const CheckCustomerAuthStatusEvent());
  }

  void _safeDirectNavigate() {
    if (_hasNavigated || !mounted) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _navigateToHome();
        return;
      }
    } catch (_) {}
    _navigateToLogin();
  }

  Future<void> _navigateToHome() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _safetyTimer?.cancel();

    // Fast fetch cached location
    CustomerLocationEntity? cachedLoc;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cached_customer_location_v3') ??
          prefs.getString('cached_customer_location_v2');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        cachedLoc = CustomerLocationEntity.fromMap(map);
      }
    } catch (_) {}

    if (mounted) {
      if (cachedLoc != null && cachedLoc.placeName.isNotEmpty) {
        context.read<DiscoveryBloc>().add(LoadDiscoveryDataEvent(
              customerLatitude: cachedLoc.latitude,
              customerLongitude: cachedLoc.longitude,
              customerAreaName: cachedLoc.placeName,
              customerVillage: cachedLoc.village,
              customerBlock: cachedLoc.block,
            ));
      } else {
        context.read<DiscoveryBloc>().add(const LoadDiscoveryDataEvent());
      }
      context.read<LocationBloc>().add(const LoadSavedLocationEvent());

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const CustomerMainShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 250),
        ),
      );
    }
  }

  void _navigateToLogin() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _safetyTimer?.cancel();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const CustomerLoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  void _navigateToProfileSetup(String userId, String? email, String phoneNumber) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _safetyTimer?.cancel();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => CustomerProfileSetupScreen(
          userId: userId,
          email: email,
          phoneNumber: phoneNumber,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CustomerAuthBloc, CustomerAuthState>(
      listener: (context, state) {
        if (state is CustomerAuthenticatedState) {
          _navigateToHome();
        } else if (state is CustomerProfileSetupRequiredState) {
          _navigateToProfileSetup(state.userId, state.email, state.phoneNumber);
        } else if (state is CustomerUnauthenticatedState) {
          _navigateToLogin();
        } else if (state is CustomerAuthFailureState) {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              _navigateToHome();
              return;
            }
          } catch (_) {}
          _navigateToLogin();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF9FAFB),
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: const AppLogo(
                    size: 110,
                    showShadow: true,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                ),
                const SizedBox(height: 24),
                const Column(
                  children: [
                    Text(
                      AppBrand.appName,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      AppBrand.taglineHindi,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 44),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
