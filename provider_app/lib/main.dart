import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/firebase/firebase_options.dart';
import 'core/config/emulator_config.dart';
import 'core/constants/app_brand.dart';
import 'core/constants/app_colors.dart';
import 'core/widgets/app_logo.dart';
import 'core/widgets/whatsapp_image_viewer.dart';
import 'core/utils/app_image_utils.dart';
import 'features/analytics/presentation/pages/analytics_page.dart';
import 'features/auth/data/datasources/firebase_provider_remote_data_source.dart';
import 'features/auth/data/repositories/provider_repository_impl.dart';
import 'features/auth/domain/entities/provider_profile_entity.dart';
import 'features/auth/domain/repositories/provider_repository.dart';
import 'features/auth/presentation/bloc/provider_auth_bloc.dart';
import 'features/auth/presentation/bloc/provider_auth_event.dart';
import 'features/auth/presentation/bloc/provider_auth_state.dart';
import 'features/auth/presentation/pages/account_blocked_page.dart';
import 'features/auth/presentation/pages/provider_category_selection_page.dart';
import 'features/auth/presentation/pages/provider_profile_setup_page.dart';
import 'features/auth/presentation/pages/provider_multi_step_registration_page.dart';
import 'features/settings/presentation/pages/provider_edit_profile_page.dart';
import 'features/auth/domain/entities/custom_service_application_entity.dart';
import 'features/auth/data/models/custom_service_application_model.dart';
import 'features/auth/presentation/widgets/other_service_details_modal.dart';
import 'features/auth/presentation/pages/provider_login_page.dart';
import 'features/leads/presentation/pages/leads_page.dart';
import 'features/notifications/presentation/pages/notifications_page.dart';
import 'features/reviews/presentation/pages/reviews_page.dart';
import 'features/settings/presentation/pages/provider_business_profile_screen.dart';
import 'features/subscription/presentation/pages/subscription_page.dart';
import 'features/listings/presentation/pages/provider_listings_page.dart';
import 'core/services/app_notification_service.dart';
import 'core/config/maps_config.dart';
import 'core/config/razorpay_payment_config.dart';
import 'core/services/remote_config_service.dart';
import 'core/widgets/app_update_dialog.dart';
import 'core/widgets/maintenance_screen.dart';
import 'core/services/web_host_bridge.dart';
import 'core/utils/notification_read_helper.dart';
import 'features/support/presentation/pages/support_page.dart';
import 'features/professional_shop/data/datasources/professional_provider_remote_data_source.dart';
import 'features/professional_shop/domain/entities/professional_shop_profile_entity.dart';
import 'features/professional_shop/presentation/pages/professional_shop_workspace_screen.dart';
import 'features/professional_shop/presentation/pages/professional_registration_tracking_page.dart';
import 'features/professional_shop/presentation/pages/professional_shop_resolution_error_view.dart';

bool isProviderFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final options = EmulatorConfig.getEffectiveOptions(DefaultFirebaseOptions.currentPlatform);
    await Firebase.initializeApp(
      options: options,
    );
    isProviderFirebaseInitialized = true;
    debugPrint('🔥 [JAMUI SERVICES] Provider App Firebase Initialized Successfully');

    try {
      await EmulatorConfig.configureEmulators();
    } on EmulatorSafetyException catch (e) {
      runApp(FatalEmulatorHaltApp(message: e.message));
      return;
    }

    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        debugPrint('✅ [JAMUI SERVICES] Web Auth Persistence configured to LOCAL storage');
      } catch (persistErr) {
        debugPrint('⚠️ [JAMUI SERVICES] Web Persistence notice: $persistErr');
      }
    } else {
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    // Accelerate first paint: Initialize non-blocking background configurations asynchronously
    MapsConfig.initAuthListener();
    unawaited(MapsConfig.fetchFromCloud());
    unawaited(RazorpayPaymentConfig.fetchFromCloud());
    unawaited(AppNotificationService.initialize(userType: 'provider'));
    unawaited(RemoteConfigService().initialize());
  } catch (e, stackTrace) {
    isProviderFirebaseInitialized = false;
    debugPrint('⚠️ [JAMUI SERVICES] Provider App Firebase Initialization Error: $e');
    debugPrint('Stack trace: $stackTrace');
  }

  runApp(const JamuiServiceProviderApp());
}

class JamuiServiceProviderApp extends StatelessWidget {
  final ProviderRepository? providerRepository;

  const JamuiServiceProviderApp({super.key, this.providerRepository});

  @override
  Widget build(BuildContext context) {
    final repo = providerRepository ??
        ProviderRepositoryImpl(
          remoteDataSource: FirebaseProviderRemoteDataSource(),
        );

    return MultiBlocProvider(
      providers: [
        BlocProvider<ProviderAuthBloc>(
          create: (_) => ProviderAuthBloc(providerRepository: repo)..add(CheckAuthStatusEvent()),
        ),
      ],
      child: MaterialApp(
        title: 'Jamui Services Partner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          textTheme: GoogleFonts.interTextTheme(),
        ),
        home: const AuthRouterScreen(),
      ),
    );
  }
}

class AuthRouterScreen extends StatefulWidget {
  const AuthRouterScreen({super.key});

  @override
  State<AuthRouterScreen> createState() => _AuthRouterScreenState();
}

class _AuthRouterScreenState extends State<AuthRouterScreen> {
  bool _isUpdateRequired = false;
  bool _isInitialAuthChecked = false;
  StreamSubscription<bool>? _forceUpdateSub;
  Timer? _initialSplashTimeout;

  @override
  void initState() {
    super.initState();
    _checkAppUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebHostBridge.notify('FLUTTER_MOUNTED');
    });

    // Safety timeout: If auth check hangs indefinitely (e.g. offline/network delay),
    // safely transition to unauthenticated login screen after 6 seconds so user is never trapped
    _initialSplashTimeout = Timer(const Duration(seconds: 6), () {
      if (!_isInitialAuthChecked && mounted) {
        debugPrint('⚠️ [AuthRouterScreen] Initial auth check safety timeout reached, unlocking login page');
        setState(() {
          _isInitialAuthChecked = true;
        });
        WebHostBridge.notify('PROVIDER_READY');
      }
    });

    if (!kIsWeb) {
      _forceUpdateSub = RemoteConfigService().forceUpdateStream.listen(
        (isReq) {
          if (mounted) {
            setState(() => _isUpdateRequired = isReq);
          }
        },
        onError: (err) {
          debugPrint('⚠️ [AuthRouterScreen] forceUpdateStream notice: $err');
        },
      );
    }
  }

  @override
  void dispose() {
    _initialSplashTimeout?.cancel();
    _forceUpdateSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAppUpdate() async {
    // Only native mobile platforms require force store updates
    if (kIsWeb) return;

    try {
      final isRequired = await RemoteConfigService().isForceUpdateRequired();
      if (mounted && isRequired) {
        setState(() {
          _isUpdateRequired = true;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // 0. Firebase Initialization Failure Gate
    if (!isProviderFirebaseInitialized) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 72, showShadow: true),
                const SizedBox(height: 24),
                const Text(
                  'सर्वर से कनेक्शन में समस्या',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Jamui Services से कनेक्ट नहीं हो पा रहा है। कृपया अपना इंटरनेट कनेक्शन जांचें और पुनः प्रयास करें।',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<ProviderAuthBloc>().add(CheckAuthStatusEvent());
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text(
                    'पुनः प्रयास करें (Retry)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final remoteConfig = RemoteConfigService();

    // 1. Maintenance Mode Gate
    if (remoteConfig.isMaintenanceMode) {
      return MaintenanceScreen(message: remoteConfig.maintenanceMessage);
    }

    // 2. Force Update Gate (Native APK only)
    if (_isUpdateRequired && !kIsWeb) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: AppUpdateDialog(
            updateUrl: remoteConfig.updateAppUrl,
            latestVersion: remoteConfig.latestVersion,
          ),
        ),
      );
    }

    return BlocConsumer<ProviderAuthBloc, ProviderAuthState>(
      listenWhen: (previous, current) {
        return current is ProviderAuthenticated ||
            current is ProviderUnauthenticated ||
            current is ProviderProfileIncomplete ||
            current is ProviderAccountBlockedState ||
            current is ProviderAuthError ||
            current is ProviderKycSubmittedSuccess;
      },
      listener: (context, state) {
        if (!_isInitialAuthChecked && mounted) {
          _initialSplashTimeout?.cancel();
          setState(() {
            _isInitialAuthChecked = true;
          });
        }
      },
      buildWhen: (previous, current) {
        if (identical(previous, current)) return false;
        if (previous.runtimeType == current.runtimeType) {
          if (previous is ProviderAuthenticated && current is ProviderAuthenticated) {
            final p1 = previous.profile;
            final p2 = current.profile;
            return p1.id != p2.id ||
                p1.status != p2.status ||
                p1.isSubscriptionActive != p2.isSubscriptionActive ||
                p1.isActive != p2.isActive ||
                p1.categoryType != p2.categoryType ||
                p1.isDeleted != p2.isDeleted;
          }
          if (previous is ProviderProfileIncomplete && current is ProviderProfileIncomplete) {
            final p1 = previous.profile;
            final p2 = current.profile;
            return p1.id != p2.id ||
                p1.primaryCategoryId != p2.primaryCategoryId ||
                p1.currentStep != p2.currentStep ||
                p1.isDeleted != p2.isDeleted;
          }
        }
        return current is ProviderAuthenticated ||
            current is ProviderKycSubmittedSuccess ||
            current is ProviderProfileIncomplete ||
            current is ProviderAccountBlockedState ||
            current is ProviderUnauthenticated ||
            current is ProviderAuthInitial;
      },
      builder: (context, state) {
        // Show branded splash screen ONLY during initial startup check
        if (!_isInitialAuthChecked || state is ProviderAuthInitial) {
          return const ProviderSplashView();
        }

        if (state is ProviderAccountBlockedState) {
          return AccountBlockedPage(
            key: const ValueKey('account_blocked_page'),
            reason: state.reason,
          );
        }

        if (state is ProviderAuthenticated) {
          if (state.profile.isDeleted) {
            return AccountBlockedPage(
              key: const ValueKey('account_deleted_page'),
              reason: state.profile.deletionReason ??
                  'This provider account has been deactivated by administrator. Please contact Jamui Services support.',
            );
          }
          return ProviderRoleAwareWorkspace(
            key: ValueKey('workspace_${state.profile.id}'),
            profile: state.profile,
          );
        }

        if (state is ProviderKycSubmittedSuccess && state.profile != null) {
          if (state.profile!.isDeleted) {
            return AccountBlockedPage(
              key: const ValueKey('account_deleted_page_kyc'),
              reason: state.profile!.deletionReason ??
                  'This provider account has been deactivated by administrator. Please contact Jamui Services support.',
            );
          }
          return ProviderRoleAwareWorkspace(
            key: ValueKey('workspace_${state.profile!.id}'),
            profile: state.profile!,
          );
        }

        if (state is ProviderProfileIncomplete) {
          if (state.profile.isDeleted) {
            return AccountBlockedPage(
              key: const ValueKey('account_deleted_page_incomplete'),
              reason: state.profile.deletionReason ??
                  'This provider account has been deactivated by administrator. Please contact Jamui Services support.',
            );
          }
          if (state.profile.primaryCategoryId.isEmpty) {
            return ProviderCategorySelectionPage(
              key: ValueKey('cat_sel_${state.profile.id}'),
              providerUid: state.profile.id,
            );
          }
          return ProviderProfileSetupPage(
            key: ValueKey('setup_${state.profile.id}_${state.profile.primaryCategoryId}'),
            providerUid: state.profile.id,
            categoryId: state.profile.primaryCategoryId,
            categoryTitle: state.profile.primaryCategoryTitle,
            categoryType: state.profile.categoryType,
            subServices: state.profile.subServices,
          );
        }

        return const ProviderLoginPage(key: ValueKey('provider_login_page'));
      },
    );
  }
}

class ProviderSplashView extends StatefulWidget {
  const ProviderSplashView({super.key});

  @override
  State<ProviderSplashView> createState() => _ProviderSplashViewState();
}

class _ProviderSplashViewState extends State<ProviderSplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo is 100% visible from Frame 1 (no transparent start)
              ScaleTransition(
                scale: _scaleAnimation,
                child: const AppLogo(
                  size: 96,
                  showShadow: true,
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'JAMUI SERVICES PARTNER',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'सेवा प्रदाता एवं पार्टनर वर्कस्पेस',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProviderRoleAwareWorkspace extends StatefulWidget {
  final ProviderProfileEntity profile;

  const ProviderRoleAwareWorkspace({super.key, required this.profile});

  @override
  State<ProviderRoleAwareWorkspace> createState() => _ProviderRoleAwareWorkspaceState();
}

class _ProviderRoleAwareWorkspaceState extends State<ProviderRoleAwareWorkspace> {
  final ProfessionalProviderRemoteDataSource _dataSource = ProfessionalProviderRemoteDataSource();
  ProfessionalShopProfileEntity? _shopProfile;
  StreamSubscription<ProfessionalShopProfileEntity?>? _shopSub;
  late bool _isLoading;
  bool _isShopResolved = false;

  /// Authoritative check: Determines whether this user belongs to the Professional Seller domain.
  /// STRICT ARCHITECTURAL RULE: Never uses hardcoded category IDs (like cat_grocery).
  /// Role is determined solely by verified businessType, professional role flags, and shop ownership.
  bool _isProfessionalDomain(ProviderProfileEntity prof) {
    if (prof.isProfessional == true || prof.isDiamond == true) return true;
    final bType = prof.businessType.toLowerCase().trim();
    if (bType == 'professional_seller' || bType == 'ecommerce_seller' || bType == 'shopkeeper') {
      return true;
    }
    final cType = prof.categoryType.toLowerCase().trim();
    if (cType == 'professional' || cType == 'diamond' || cType == 'marketplace' || cType == 'ecommerce') {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _checkRole();
    _subscribeToShopStream(widget.profile.id);
  }

  @override
  void dispose() {
    _shopSub?.cancel();
    super.dispose();
  }

  void _subscribeToShopStream(String uid) {
    _shopSub?.cancel();
    _shopSub = _dataSource.streamShopProfile(uid, ownerUid: uid).listen((updatedShop) {
      if (mounted && updatedShop != null) {
        setState(() {
          _shopProfile = updatedShop;
          _isShopResolved = true;
        });
      }
    }, onError: (_) {});
  }

  Future<void> _checkRole() async {
    // Authoritatively resolve shop with strict ownerUid == currentUid verification
    final shop = await _dataSource.resolveVerifiedShop(widget.profile.id);
    if (mounted) {
      setState(() {
        _shopProfile = shop;
        _isShopResolved = true;
        _isLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProviderRoleAwareWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      setState(() {
        _isLoading = true;
        _shopProfile = null;
        _isShopResolved = false;
      });
      _subscribeToShopStream(widget.profile.id);
      _checkRole();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isProDomain = _isProfessionalDomain(widget.profile) || _shopProfile != null;

    // --- CASE 1: NORMAL SERVICE PROVIDER (Plumber, Electrician, Carpenter, Salon, etc.) ---
    // STRICT ZERO-TOUCH GUARANTEE: Never touches Normal Provider Leads or Bookings
    if (!isProDomain) {
      return ProviderWorkspaceScreen(profile: widget.profile);
    }

    // --- CASE 2: PROFESSIONAL SELLER DOMAIN ---
    // STRICT GUARANTEE: Any detected Professional Seller NEVER falls back to Normal Provider Dashboard

    // Sub-case 2A: Profile claims Professional Seller, but no verified shop record with ownerUid == currentUid exists
    if (_shopProfile == null) {
      return ProfessionalShopResolutionErrorView(
        profile: widget.profile,
        onRetry: () {
          setState(() => _isLoading = true);
          _checkRole();
        },
      );
    }

    final shop = _shopProfile!;

    // Mandatory Security Check: ownerUid must strictly match authenticated profile id
    if (shop.ownerUid != widget.profile.id) {
      return ProfessionalShopResolutionErrorView(
        profile: widget.profile,
        onRetry: () {
          setState(() => _isLoading = true);
          _checkRole();
        },
      );
    }

    // Sub-case 2B: Account Rejected by Admin
    if (shop.status.toLowerCase() == 'rejected' || widget.profile.status == ProviderAccountStatus.rejected) {
      return const AccountBlockedPage(
        reason: 'आपकी दुकान का पंजीकरण व्यवस्थापक (Admin) द्वारा अस्वीकृत कर दिया गया है। कृपया सहायता हेतु Jamui Services सपोर्ट से संपर्क करें।',
      );
    }

    // Sub-case 2C: Account Suspended or Inactivated by Admin (Punitive Action)
    // NOTE: isOpen == false is merchant operational toggle and is NOT suspension
    if (shop.status.toLowerCase() == 'suspended' ||
        shop.status.toLowerCase() == 'blocked' ||
        shop.isActive == false ||
        widget.profile.status == ProviderAccountStatus.suspended ||
        widget.profile.status == ProviderAccountStatus.blocked) {
      return const AccountBlockedPage(
        reason: 'आपकी दुकान को व्यवस्थापक (Admin) द्वारा निलंबित कर दिया गया है। अधिक जानकारी व सहायता के लिए कृपया Jamui Services सपोर्ट से संपर्क करें।',
      );
    }

    // Sub-case 2D: Registration Under Review / Approval Pending
    if (shop.status.toLowerCase() == 'pending' ||
        shop.status.toLowerCase() == 'pendingreview' ||
        shop.status.toLowerCase() == 'draft' ||
        !shop.isApproved) {
      return ProfessionalRegistrationTrackingPage(
        shop: shop,
        profile: widget.profile,
        onRefresh: _checkRole,
      );
    }

    // Sub-case 2E: Approved Shopkeeper
    // Evaluate Subscription Expiry Fail-Safe: null or past expiry is strictly treated as expired
    final bool isSubscriptionValid = shop.isSubscriptionActive &&
        shop.subscriptionExpiry != null &&
        shop.subscriptionExpiry!.isAfter(DateTime.now());

    // If subscription is expired or inactive, allow workspace access with subscription renewal prompt
    // NEVER fall back to plumber leads!
    return ProfessionalShopWorkspaceScreen(
      shop: shop,
    );
  }
}

class ProviderWorkspaceScreen extends StatefulWidget {
  final ProviderProfileEntity? profile;

  const ProviderWorkspaceScreen({super.key, this.profile});

  @override
  State<ProviderWorkspaceScreen> createState() => _ProviderWorkspaceScreenState();
}

class _ProviderWorkspaceScreenState extends State<ProviderWorkspaceScreen> {
  int _currentIndex = 0;
  Stream<QuerySnapshot>? _notificationStream;
  Stream<DocumentSnapshot>? _providerDocStream;
  String? _cachedProfileId;

  void _ensureStreams(String profileId) {
    if (_cachedProfileId != profileId) {
      _cachedProfileId = profileId;
      _notificationStream = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', whereIn: [profileId, 'all', 'all_providers'])
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();
      _providerDocStream = FirebaseFirestore.instance
          .collection('providers')
          .doc(profileId)
          .snapshots();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _ensureStreams(widget.profile!.id);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebHostBridge.notify('PROVIDER_READY');
    });
  }

  @override
  Widget build(BuildContext context) {
    ProviderProfileEntity? profile = widget.profile;
    if (profile == null) {
      final authState = context.watch<ProviderAuthBloc>().state;
      if (authState is ProviderAuthenticated) {
        profile = authState.profile;
      } else if (authState is ProviderKycSubmittedSuccess && authState.profile != null) {
        profile = authState.profile;
      }
    }

    if (profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    _ensureStreams(profile.id);

    final pages = [
      _buildDashboardView(context, profile),
      profile.hasPaidSubscription ? LeadsPage(profile: profile) : _buildRestrictedLeadsView(context, profile),
      AnalyticsPage(profile: profile),
      ProviderBusinessProfileScreen(profile: profile),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'डैशबोर्ड'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'लीड्स'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'एनालिटिक्स'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'प्रोफाइल'),
        ],
      ),
    );
  }

  Widget _buildDashboardView(BuildContext context, ProviderProfileEntity profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inactive Account by Admin Warning Banner
          if (!profile.isActive) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade300, width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.pause_circle_filled_rounded, color: Colors.red.shade800, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'खाता एडमिन द्वारा निष्क्रिय किया गया है (Account Inactive)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.deactivationReason?.isNotEmpty == true
                              ? 'कारण: ${profile.deactivationReason}'
                              : 'आपकी प्रोफाइल ग्राहक ऐप पर अस्थायी रूप से छिपाई गई है और नई लीड्स बंद हैं। पुनः सक्रिय करने हेतु एडमिन से संपर्क करें।',
                          style: TextStyle(fontSize: 11.5, color: Colors.red.shade800, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Custom Dashboard Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (profile.profileImageUrl.isNotEmpty) {
                          WhatsAppImageViewerDialog.show(
                            context,
                            imageUrl: profile.profileImageUrl,
                            title: profile.fullName,
                            subtitle: profile.businessName,
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<ProviderAuthBloc>(),
                                child: ProviderEditProfilePage(profile: profile),
                              ),
                            ),
                          );
                        }
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        backgroundImage: AppImageUtils.getImageProvider(profile.profileImageUrl),
                        onBackgroundImageError: profile.profileImageUrl.isNotEmpty
                            ? (e, s) => debugPrint('Dashboard avatar load notice: $e')
                            : null,
                        child: profile.profileImageUrl.isEmpty
                            ? const Icon(Icons.person, color: AppColors.accent, size: 26)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<ProviderAuthBloc>(),
                                child: ProviderEditProfilePage(profile: profile),
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.businessName.isNotEmpty ? profile.businessName : profile.fullName,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${profile.primaryCategoryTitle.isNotEmpty ? profile.primaryCategoryTitle : 'सर्विस प्रोवाइडर'} • ${profile.jamuiArea}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                      tooltip: 'ग्राहक ऐप पर वापस जाएं',
                      onPressed: () => Navigator.pop(context),
                    ),
                  StreamBuilder<QuerySnapshot>(
                    stream: _notificationStream,
                    builder: (context, notifSnap) {
                      NotificationReadHelper.init(profile.id);
                      final unreadCount = notifSnap.data?.docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return !NotificationReadHelper.isNotificationRead(
                          docId: d.id,
                          data: data,
                          providerId: profile.id,
                        );
                      }).length ?? 0;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: Icon(
                              unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                              color: unreadCount > 0 ? AppColors.accent : AppColors.primary,
                            ),
                            tooltip: 'सूचनाएं',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NotificationsPage(providerId: profile.id),
                                ),
                              );
                              if (context.mounted) {
                                (context as Element).markNeedsBuild();
                              }
                            },
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text(
                                  unreadCount >= 10 ? '9+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: AppColors.accent),
                    tooltip: 'प्रोफ़ाइल संपादित करें (Edit Profile)',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ProviderAuthBloc>(),
                            child: ProviderEditProfilePage(profile: profile),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Availability Switch Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      profile.isAvailable ? Icons.circle : Icons.circle_outlined,
                      color: profile.isAvailable ? AppColors.success : AppColors.textMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      profile.isAvailable ? 'ड्यूटी पर (Online for Leads)' : 'ऑफलाइन (Offline)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: profile.isAvailable ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: profile.isAvailable,
                  activeThumbColor: AppColors.success,
                  activeTrackColor: AppColors.success.withValues(alpha: 0.3),
                  onChanged: (val) {
                    if (val == true && !profile.isActive) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('⚠️ आपका खाता एडमिन द्वारा निष्क्रिय किया गया है${profile.deactivationReason != null && profile.deactivationReason!.isNotEmpty ? ' (${profile.deactivationReason})' : ''}। कृपया सहायता के लिए एडमिन से संपर्क करें।'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    if (val == true && profile.isSubscriptionPendingApproval) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⏳ आपका भुगतान सत्यापित हो चुका है, किंतु एडमिन अनुमोदन लंबित है। अनुमोदन के बाद ही आप ऑनलाइन हो सकते हैं।'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      return;
                    }
                    if (val == true && !profile.hasPaidSubscription) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ ऑनलाइन होने हेतु सक्रिय पेड सब्सक्रिप्शन अनिवार्य है। कृपया प्लान चुनें।'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ProviderAuthBloc>(),
                            child: SubscriptionPage(profile: profile),
                          ),
                        ),
                      );
                      return;
                    }
                    if (profile.isOtherService && profile.customServiceStatus != 'approved') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ आपकी विशेष सेवा अभी एडमिन समीक्षाधीन है। अनुमोदन के बाद ही सामान्य लीड्स प्राप्त होंगी।'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      return;
                    }
                    context.read<ProviderAuthBloc>().add(ToggleAvailabilityEvent(val));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Profile Summary & Completion Progress Card
          _buildProfileSummaryCard(context, profile),
          const SizedBox(height: 14),

          // Custom Service Status Banner (Live Realtime Stream)
          _buildCustomServiceStatusBanner(context, profile),

          // KYC Status Banner
          _buildKycStatusBanner(context, profile),
          const SizedBox(height: 14),

          // Subscription / Payment Status Banner
          _buildSubscriptionPaymentBanner(context, profile),
          const SizedBox(height: 20),

          // Quick Navigation Menu Grid
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'लिस्टिंग्स व मीडिया',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.accent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderListingsPage(profile: profile))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'समीक्षाएं (Reviews)',
                  icon: Icons.star_rate_rounded,
                  color: AppColors.gold,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsPage(profile: profile))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'सहायता टिकट (Support)',
                  icon: Icons.support_agent_rounded,
                  color: AppColors.primary,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupportPage(profile: profile))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  title: 'सब्सक्रिप्शन प्लान्स',
                  icon: Icons.workspace_premium,
                  color: Colors.purple.shade700,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionPage(profile: profile))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Real Performance Metrics Header
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('मासिक परफॉरमेंस एनालिटिक्स', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('Real Firestore Counters', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),

          // Real Stat Cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _buildStatCard('Profile Views', '${profile.totalViews}', Icons.visibility_outlined, AppColors.accent, 'ग्राहकों की खोज'),
              _buildStatCard('Call Clicks', '${profile.totalCalls}', Icons.phone_in_talk_outlined, AppColors.info, 'सीधे फोन कॉल्स'),
              _buildStatCard('WhatsApp Clicks', '${profile.totalWhatsAppClicks}', Icons.chat_bubble_outline, const Color(0xFF25D366), 'व्हाट्सएप चैट'),
              _buildStatCard('रेटिंग व स्कोर', '${profile.rating} ★', Icons.star_rate_rounded, AppColors.gold, '${profile.ratingCount} रिव्यूज'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomServiceStatusBanner(BuildContext context, ProviderProfileEntity profile) {
    if (!profile.isOtherService) return const SizedBox.shrink();

    return StreamBuilder<CustomServiceApplicationEntity?>(
      stream: context.read<ProviderAuthBloc>().providerRepository.watchCustomServiceApplication(profile.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final app = snapshot.data;
        if (app == null) return const SizedBox.shrink();

        Color bannerBg;
        Color borderColor;
        Color textColor;
        IconData icon;
        String title;
        String message;
        Widget? actionButton;

        switch (app.status) {
          case CustomServiceStatus.none:
            return const SizedBox.shrink();

          case CustomServiceStatus.pendingReview:
            bannerBg = Colors.amber.shade50;
            borderColor = Colors.amber.shade300;
            textColor = Colors.amber.shade900;
            icon = Icons.hourglass_top_rounded;
            title = 'विशेष सेवा समीक्षाधीन (Awaiting Admin Review)';
            message = 'प्रस्तावित सेवा: "${app.serviceName}"\n'
                'आपकी कस्टम सेवा समीक्षा के लिए सबमिट हो चुकी है। एडमिन द्वारा अनुमोदन के बाद यह श्रेणी आपकी प्रोफ़ाइल में सक्रिय होगी।';
            break;

          case CustomServiceStatus.approved:
            bannerBg = Colors.green.shade50;
            borderColor = Colors.green.shade300;
            textColor = Colors.green.shade800;
            icon = Icons.verified_user_rounded;
            title = 'विशेष सेवा स्वीकृत (Service Approved by Admin)';
            message = 'स्वीकृत सेवा श्रेणी: "${app.mappedCategoryTitle ?? app.serviceName}"\n'
                '${(app.adminFeedback != null && app.adminFeedback!.isNotEmpty) ? "एडमिन संदेश: ${app.adminFeedback}\n" : ""}'
                'बधाई! आपकी सेवा श्रेणी सक्रिय कर दी गई है।';
            break;

          case CustomServiceStatus.rejected:
            bannerBg = Colors.red.shade50;
            borderColor = Colors.red.shade300;
            textColor = Colors.red.shade800;
            icon = Icons.cancel_outlined;
            title = 'विशेष सेवा आवेदन अस्वीकृत (Application Rejected)';
            message = 'प्रस्तावित सेवा: "${app.serviceName}"\n'
                'अस्वीकृति का कारण: ${app.adminFeedback ?? "एडमिन द्वारा आवेदन अस्वीकृत किया गया है।"}';
            actionButton = Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('नई सेवा के लिए आवेदन करें', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                  side: BorderSide(color: Colors.red.shade400),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ProviderAuthBloc>(),
                        child: ProviderMultiStepRegistrationPage(initialProfile: profile, initialStep: 1),
                      ),
                    ),
                  );
                },
              ),
            );
            break;

          case CustomServiceStatus.moreInfoRequired:
            bannerBg = Colors.deepOrange.shade50;
            borderColor = Colors.deepOrange.shade300;
            textColor = Colors.deepOrange.shade900;
            icon = Icons.contact_support_outlined;
            title = 'अतिरिक्त जानकारी आवश्यक (More Information Required)';
            message = 'प्रस्तावित सेवा: "${app.serviceName}"\n'
                'एडमिन संदेश: ${app.adminFeedback ?? "कृपया अपने कार्य व अनुभव का और स्पष्ट विवरण प्रदान करें।"}\n'
                'समीक्षा आगे बढ़ाने हेतु कृपया नीचे बटन दबाकर विवरण अपडेट करें।';
            actionButton = Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('विवरण अपडेट करें (Update Info)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final updated = await OtherServiceDetailsModal.show(
                    context,
                    initialFullName: app.providerName,
                    initialPhoneNumber: app.phoneNumber,
                    initialFullAddress: app.fullAddress,
                    initialJamuiArea: app.jamuiArea,
                    initialExperienceYears: app.experienceYears,
                    initialVisitingCharge: app.visitingCharge,
                    existingData: OtherServiceData(
                      serviceName: app.serviceName,
                      serviceDescription: app.serviceDescription,
                      offeredServices: app.offeredServices,
                      fullName: app.providerName,
                      phoneNumber: app.phoneNumber,
                      fullAddress: app.fullAddress,
                      jamuiArea: app.jamuiArea,
                      experienceYears: app.experienceYears,
                      visitingCharge: app.visitingCharge,
                    ),
                  );

                  if (updated != null && context.mounted) {
                    final newApp = CustomServiceApplicationModel(
                      id: app.id,
                      providerId: app.providerId,
                      providerName: updated.fullName,
                      phoneNumber: updated.phoneNumber,
                      serviceName: updated.serviceName,
                      serviceDescription: updated.serviceDescription,
                      offeredServices: updated.offeredServices,
                      experienceYears: updated.experienceYears,
                      visitingCharge: updated.visitingCharge,
                      fullAddress: updated.fullAddress,
                      jamuiArea: updated.jamuiArea,
                      status: CustomServiceStatus.pendingReview,
                      createdAt: app.createdAt,
                      updatedAt: DateTime.now(),
                    );
                    await context.read<ProviderAuthBloc>().providerRepository.submitCustomServiceApplication(newApp);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ अपडेट किया गया विवरण एडमिन को पुनः भेजा गया है।'), backgroundColor: AppColors.success),
                      );
                    }
                  }
                },
              ),
            );
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: textColor, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actionButton != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: actionButton,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildKycStatusBanner(BuildContext context, ProviderProfileEntity profile) {
    Color bannerBg;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    switch (profile.kycStatus) {
      case ProviderKycStatus.approved:
        bannerBg = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green.shade800;
        icon = Icons.verified_user_rounded;
        title = 'वेरिफाइड सर्विस प्रोवाइडर (KYC Approved)';
        subtitle = 'आपकी प्रोफाइल जमुई के ग्राहकों को सबसे ऊपर दिखाई जा रही है।';
        break;
      case ProviderKycStatus.pendingReview:
        bannerBg = Colors.amber.withValues(alpha: 0.15);
        textColor = Colors.amber.shade900;
        icon = Icons.hourglass_top_rounded;
        title = 'सत्यापन प्रक्रियाधीन (Under Admin Review)';
        subtitle = profile.rejectionReason != null && profile.rejectionReason!.isNotEmpty
            ? 'एडमिन रिस्पॉन्स: ${profile.rejectionReason}'
            : AppBrand.kycApprovedMessage;
        break;
      case ProviderKycStatus.rejected:
        bannerBg = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red.shade800;
        icon = Icons.cancel_outlined;
        title = 'सत्यापन अस्वीकृत: ${profile.rejectionReason ?? 'दस्तावेज़ या विवरण अस्पष्ट है'}';
        subtitle = AppBrand.kycRejectedMessage;
        break;
      case ProviderKycStatus.notSubmitted:
        bannerBg = Colors.orange.withValues(alpha: 0.12);
        textColor = Colors.orange.shade900;
        icon = Icons.warning_amber_rounded;
        title = 'प्रोफ़ाइल सत्यापन पूरा करें और वेरिफाइड बैज पाएं';
        subtitle = 'सत्यापन के बिना आपकी प्रोफाइल ग्राहकों को नीचे दिखेगी।';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.85))),
              ],
            ),
          ),
          if (profile.kycStatus != ProviderKycStatus.approved)
            TextButton(
              onPressed: () {
                if (profile.kycStatus == ProviderKycStatus.pendingReview) {
                  _showAdminReviewModal(context, profile);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ProviderAuthBloc>(),
                        child: ProviderEditProfilePage(profile: profile),
                      ),
                    ),
                  );
                }
              },
              child: Text(
                profile.kycStatus == ProviderKycStatus.pendingReview ? 'रिव्यू देखें' : 'पूरा करें',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPaymentBanner(BuildContext context, ProviderProfileEntity profile) {
    // 1. If provider is NOT approved, KYC status banner handles the messaging.
    if (profile.status != ProviderAccountStatus.approved) {
      return const SizedBox.shrink();
    }

    // 2. Case: Payment verification in progress
    if (profile.paymentStatus == 'pending_verification') {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'भुगतान सत्यापन प्रक्रियाधीन (Verifying Payment)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'रेजरपे से भुगतान की पुष्टि की जा रही है। पुष्टि होते ही आपकी प्रोफाइल स्वतः लाइव हो जाएगी।',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2.5 Case: Payment verified, awaiting Admin manual activation
    if (profile.isSubscriptionPendingApproval) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.indigo.shade300, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.indigo.shade800, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'भुगतान सत्यापित — एडमिन अनुमोदन लंबित',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo.shade900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Payment Verified — Admin Approval Pending',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.indigo.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'आपका सब्सक्रिप्शन भुगतान सफलतापूर्वक प्राप्त व सत्यापित हो गया है। एडमिन द्वारा अनुमोदन (Approval) मिलते ही आपकी सेवाएं लाइव हो जाएंगी और कस्टमर ऐप पर दिखाई देंगी।',
              style: TextStyle(fontSize: 11.5, color: Colors.indigo.shade900, height: 1.4),
            ),
            if (profile.paymentOrderId != null || profile.paymentId != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 14, color: Colors.indigo.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Order: ${profile.paymentOrderId ?? "-"} | Ref: ${profile.paymentId ?? "-"}',
                        style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Colors.indigo.shade900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // 3. Case: Expired Subscription
    if (profile.isSubscriptionExpired) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade300, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade800, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'सब्सक्रिप्शन समाप्त हो चुका है (Subscription Expired)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'कस्टमर ऐप पर अपनी प्रोफाइल पुनः लाइव करने व सीधी लीड्स प्राप्त करने के लिए रिन्यू करें।',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<ProviderAuthBloc>(),
                        child: SubscriptionPage(profile: profile),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('तुरंत रिन्यू करें (Renew Now)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 4. Case: Unpaid / Missing Payment (Approved provider with no verified payment)
    if (!profile.hasPaidSubscription) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade400, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'सब्सक्रिप्शन भुगतान लंबित (Subscription Payment Pending)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'आपकी प्रोफ़ाइल स्वीकृत है! कस्टमर ऐप पर जमुई के ग्राहकों को दिखने व नई लीड्स पाने के लिए कृपया सब्सक्रिप्शन प्लान सक्रिय करें।',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0% कमीशन • 100% सीधी कमाई',
                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<ProviderAuthBloc>(),
                          child: SubscriptionPage(profile: profile),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium, size: 16),
                  label: const Text('प्लान चुनें व भुगतान करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 5. Case: Active Paid Subscription Card with Live Quota Stream
    final expiry = profile.subscriptionExpiry;
    final now = DateTime.now();
    final daysRemaining = expiry != null ? expiry.difference(now).inDays : 0;
    final expiryFormatted = expiry != null ? '${expiry.day}/${expiry.month}/${expiry.year}' : 'सक्रिय';

    return StreamBuilder<DocumentSnapshot>(
      stream: _providerDocStream,
      builder: (context, snap) {
        final pData = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final isPremium = (pData['isPremiumEligible'] as bool?) ?? false;

        final rawLimits = pData['planLimits'] as Map<String, dynamic>?;
        final maxListings = (rawLimits?['maxActiveListings'] as num?)?.toInt() ?? 1;
        final maxImages = (rawLimits?['maxImagesPerProvider'] as num?)?.toInt() ?? 3;
        final maxStorageBytes = (rawLimits?['maxTotalStorageBytes'] as num?)?.toInt() ?? (6 * 1024 * 1024);

        final rawUsage = pData['storageUsage'] as Map<String, dynamic>?;
        final totalImages = (rawUsage?['totalImagesCount'] as num?)?.toInt() ?? 0;
        final totalBytesUsed = (rawUsage?['totalBytesUsed'] as num?)?.toInt() ?? 0;

        final usedMb = totalBytesUsed / (1024 * 1024);
        final maxMb = maxStorageBytes / (1024 * 1024);
        final remainingMb = (maxMb - usedMb).clamp(0.0, maxMb);
        final storageProgress = (totalBytesUsed / (maxStorageBytes > 0 ? maxStorageBytes : 1)).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Plan Name, Premium Badge, Validity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: AppColors.gold, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '${profile.subscriptionPlan.toUpperCase()} PLAN',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  if (isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.gold),
                      ),
                      child: const Text('⭐ प्रीमियम पात्र', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'वैधता: $expiryFormatted ($daysRemaining दिन शेष) • $maxListings एक्टिव लिस्टिंग्स सीमा',
                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
              const Divider(color: Colors.white24, height: 18),

              // Storage and Image Usage Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'क्लाउड स्टोरेज: ${usedMb.toStringAsFixed(1)} / ${maxMb.toStringAsFixed(1)} MB (${remainingMb.toStringAsFixed(1)} MB शेष)',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'फ़ोटोज़: $totalImages / $maxImages',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: storageProgress,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    storageProgress >= 0.85 ? Colors.redAccent : AppColors.gold,
                  ),
                  minHeight: 5,
                ),
              ),

              if (storageProgress >= 0.85) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amberAccent),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'स्टोरेज कोटा समाप्त होने वाला है! नई फ़ोटोज़ हेतु प्लान अपग्रेड करें।',
                        style: TextStyle(fontSize: 10.5, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.inventory_2_outlined, size: 15, color: Colors.white),
                      label: const Text('मेरी लिस्टिंग्स', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProviderListingsPage(profile: profile),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.upgrade_rounded, size: 16),
                      label: const Text('अपग्रेड करें', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubscriptionPage(profile: profile),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRestrictedLeadsView(BuildContext context, ProviderProfileEntity profile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_clock_rounded, size: 54, color: Colors.amber.shade800),
            ),
            const SizedBox(height: 20),
            const Text(
              'ग्राहक लीड्स केवल पेड सब्सक्राइबर्स के लिए',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'जमुई के ग्राहकों द्वारा भेजी गई नई सर्विस लीड्स, फोन कॉल्स और कार्य विवरण देखने के लिए अपना बिजनेस सब्सक्रिप्शन प्लान सक्रिय करें।',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ProviderAuthBloc>(),
                      child: SubscriptionPage(profile: profile),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.workspace_premium, size: 18),
              label: const Text('सब्सक्रिप्शन प्लान चुनें व सक्रिय करें', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminReviewModal(BuildContext context, ProviderProfileEntity profile) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'सत्यापन समीक्षा (Admin Review)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'एडमिन रिस्पॉन्स / स्थिति (Admin Response):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.rejectionReason != null && profile.rejectionReason!.isNotEmpty
                            ? profile.rejectionReason!
                            : AppBrand.kycUnderReviewMessage,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('सत्यापन चरण (Verification Timeline):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                _buildTimelineStep(AppBrand.kycStep1Title, true, isDone: true),
                _buildTimelineStep(AppBrand.kycStep2Title, true, isCurrent: true),
                _buildTimelineStep(AppBrand.kycStep3Title, false),
                const Divider(height: 24),
                const Text('सबमिट की गई जानकारी (Submitted Data):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text('नाम: ${profile.fullName}'),
                Text('दुकान: ${profile.businessName}'),
                Text('मुख्य कैटगरी: ${profile.primaryCategoryTitle}'),
                Text('वर्कप्लेस फोटो: ${profile.businessImageUrl.isNotEmpty ? "Uploaded ✓" : "Missing ✗"}'),
                Text('अनुभव प्रमाण पत्र: ${profile.experienceCertificateStatus == "verified" ? "Verified ✓" : (profile.experienceCertificateStatus == "pendingReview" ? "⏳ Verification Pending" : "Not Uploaded")}'),
                Text('स्थान: ${profile.jamuiArea} (${profile.latitude.toStringAsFixed(4)}, ${profile.longitude.toStringAsFixed(4)})'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ठीक है (Close)'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ProviderAuthBloc>(),
                      child: ProviderEditProfilePage(profile: profile),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('विवरण अपडेट करें'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineStep(String label, bool isReached, {bool isDone = false, bool isCurrent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : (isCurrent ? Icons.motion_photos_on : Icons.radio_button_unchecked),
            color: isDone ? Colors.green : (isCurrent ? Colors.amber.shade800 : Colors.grey),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.normal,
                color: isDone ? Colors.green.shade900 : (isCurrent ? Colors.amber.shade900 : Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(sub, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildProfileSummaryCard(BuildContext context, ProviderProfileEntity profile) {
    final completion = profile.completionPercentage;
    final missing = profile.missingFields;
    final isComplete = missing.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isComplete ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
                    color: isComplete ? AppColors.success : AppColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Profile Summary',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete ? AppColors.success.withValues(alpha: 0.1) : AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isComplete ? AppColors.success : AppColors.gold),
                ),
                child: Text(
                  isComplete ? '100% Complete' : '${missing.length} Details Missing',
                  style: TextStyle(
                    color: isComplete ? AppColors.success : AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion $completion%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(
                '$completion / 100%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completion / 100.0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                completion == 100 ? AppColors.success : (completion >= 70 ? AppColors.gold : AppColors.error),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isComplete
                      ? 'आपकी प्रोफाइल 100% पूर्ण है। संपादन हेतु नीचे बटन दबाएं।'
                      : 'ग्राहकों का भरोसा प्राप्त करने के लिए अपनी प्रोफाइल पूरी करें।',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  if (isComplete) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<ProviderAuthBloc>(),
                          child: ProviderEditProfilePage(profile: profile),
                        ),
                      ),
                    );
                  } else {
                    _showMissingDetailsModal(context, profile);
                  }
                },
                icon: Icon(isComplete ? Icons.edit_note_rounded : Icons.check_circle_outline, size: 14),
                label: Text(isComplete ? 'Edit Profile' : 'Complete Profile', style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMissingDetailsModal(BuildContext context, ProviderProfileEntity profile) {
    final missing = profile.missingFields;
    final completion = profile.completionPercentage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_turned_in_rounded, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Profile Completion $completion%',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: missing.isEmpty ? AppColors.success.withValues(alpha: 0.1) : AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  missing.isEmpty ? '100% प्रोफाइल पूर्ण है' : '${missing.length} Details Missing (अधूरी जानकारी)',
                  style: TextStyle(
                    color: missing.isEmpty ? AppColors.success : AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (missing.isNotEmpty) ...[
                const Text(
                  'निम्नलिखित फ़ील्ड्स भरना अनिवार्य है:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Column(
                  children: missing.map((f) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              f,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                          const Text('अधूरा', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.verified, color: AppColors.success, size: 48),
                        SizedBox(height: 8),
                        Text('आपकी प्रोफाइल 100% पूरी हो चुकी है!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<ProviderAuthBloc>(),
                          child: ProviderEditProfilePage(profile: profile),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(missing.isEmpty ? 'प्रोफाइल संपादित करें (Edit Profile)' : 'अभी पूरा करें व सेव करें (Complete Now & Edit)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
