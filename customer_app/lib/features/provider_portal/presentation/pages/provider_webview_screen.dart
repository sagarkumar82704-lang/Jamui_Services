import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../core/config/app_environment.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/provider_app_launcher_service.dart';
import '../../../../core/widgets/app_logo.dart';

/// [ProviderWebViewScreen]
/// Hosts the Jamui Services Provider Flutter Web application seamlessly
/// inside the Customer App with zero blank-screen flashing, real-time loading
/// progress, branded logout transition, fresh build cache invalidation,
/// and back-navigation safety.
/// Real loading stages for Jamui Services Provider WebView
enum ProviderLoadStage {
  connecting,          // 1. “Connection establish ho raha hai…”
  loadingBundle,       // 2. “Provider App load ho raha hai…”
  preparingDashboard,  // 3. “Dashboard taiyar ho raha hai…”
  takingLonger,        // Slow network: “Load hone mein thoda samay lag raha hai…”
}

/// [ProviderWebViewScreen]
/// Hosts the Jamui Services Provider Flutter Web application seamlessly
/// inside the Customer App with zero blank-screen flashing, real-time loading
/// progress, branded logout transition, fresh build cache invalidation,
/// and back-navigation safety.
class ProviderWebViewScreen extends StatefulWidget {
  final String? initialUrl;

  const ProviderWebViewScreen({super.key, this.initialUrl});

  @visibleForTesting
  static Set<String> get trustedHostsForTesting => _ProviderWebViewScreenState._trustedProviderHosts;

  @visibleForTesting
  static bool isTrustedUrlForTesting(String? urlStr) => _ProviderWebViewScreenState.isTrustedUrl(urlStr);

  @override
  State<ProviderWebViewScreen> createState() => _ProviderWebViewScreenState();
}

class _ProviderWebViewScreenState extends State<ProviderWebViewScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  double _loadingProgress = 0.0;
  bool _isLoading = true;
  bool _showOverlay = true;
  bool _hasInitialLoadCompleted = false;
  bool _isLoggingOut = false;
  bool _hasLoggedOut = false;
  bool _hasError = false;
  bool _isTimedOut = false;
  String? _errorMessage;

  ProviderLoadStage _currentStage = ProviderLoadStage.connecting;
  DateTime _loadStartTime = DateTime.now();
  Timer? _slowWarningTimer;
  Timer? _timeoutTimer;
  Timer? _safetyFallbackTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  String get _targetUrl =>
      widget.initialUrl ?? ProviderAppLauncherService.providerWebUrl;

  String get _stageLabel {
    switch (_currentStage) {
      case ProviderLoadStage.connecting:
        return 'Connection establish ho raha hai…';
      case ProviderLoadStage.loadingBundle:
        return 'Provider App load ho raha hai…';
      case ProviderLoadStage.preparingDashboard:
        return 'Dashboard taiyar ho raha hai…';
      case ProviderLoadStage.takingLonger:
        return 'Load hone mein thoda samay lag raha hai…';
    }
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startTimeoutTimer();
    _initWebViewController();
  }

  @override
  void dispose() {
    _cancelAllTimers();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimeoutTimer() {
    _slowWarningTimer?.cancel();
    _timeoutTimer?.cancel();

    // 10-second warning for slow connections
    _slowWarningTimer = Timer(const Duration(seconds: 10), () {
      if (_isLoading && mounted && !_hasError && !_isTimedOut) {
        setState(() {
          _currentStage = ProviderLoadStage.takingLonger;
        });
        debugPrint('⏱️ [ProviderWebView] Loading taking longer than 10s...');
      }
    });

    // 22-second loading safety net for slow 2G/3G connections
    _timeoutTimer = Timer(const Duration(seconds: 22), () {
      if (_isLoading && mounted && !_hasError) {
        setState(() {
          _isTimedOut = true;
        });
        debugPrint('⏱️ [ProviderWebView] 22s Timeout triggered');
      }
    });
  }

  void _cancelAllTimers() {
    _slowWarningTimer?.cancel();
    _timeoutTimer?.cancel();
    _safetyFallbackTimer?.cancel();
  }

  void _dismissOverlay([String reason = '']) {
    _cancelAllTimers();
    if (mounted) {
      final elapsed = DateTime.now().difference(_loadStartTime).inMilliseconds;
      debugPrint('⏱️ [ProviderWebView] Overlay dismissed ($reason) in ${elapsed}ms');
      setState(() {
        _hasInitialLoadCompleted = true;
        _isLoading = false;
        _isLoggingOut = false;
        _isTimedOut = false;
      });
    }
  }

  void _initWebViewController() {
    final controller = WebViewController();

    // Enable unrestricted JavaScript for Flutter Web engine & Firebase Auth
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(Colors.white);

    // Platform-specific enhancements
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);

      // Enable local file & content URI access for image pickers
      androidController.setAllowFileAccess(true);
      androidController.setAllowContentAccess(true);

      // Automatically grant WebRTC camera/microphone permissions if requested by the web app
      androidController.setOnPlatformPermissionRequest((request) async {
        await request.grant();
      });

      // Intercept HTML file inputs (<input type="file">) and delegate to native Camera/Gallery
      androidController.setOnShowFileSelector((FileSelectorParams params) async {
        return await _handleAndroidFileSelection(params);
      });

      // Enable HTML5 geolocation prompt handling for trusted origins
      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          final uri = Uri.tryParse(request.origin);
          final isAllowed = uri != null && _isTrustedOriginUri(uri);
          debugPrint('🌐 [ProviderWebView] Geolocation prompt origin=${request.origin}, allow=$isAllowed');
          return GeolocationPermissionsResponse(allow: isAllowed, retain: isAllowed);
        },
        onHidePrompt: () {},
      );
    }

    // Set Chrome Mobile User-Agent to avoid WebView bot rejection
    controller.setUserAgent(
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
    );

    // Direct Two-Way Communication Bridge with Provider Web App
    controller.addJavaScriptChannel(
      'JamuiHost',
      onMessageReceived: (JavaScriptMessage message) {
        _handleHostMessage(message.message);
      },
    );

    controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          if (mounted) {
            setState(() {
              _loadingProgress = progress / 100.0;
            });
          }
        },
        onPageStarted: (String url) {
          if (mounted) {
            final isFirstLoad = !_hasInitialLoadCompleted;
            setState(() {
              _isLoading = true;
              if (isFirstLoad) {
                _showOverlay = true;
                _currentStage = ProviderLoadStage.connecting;
              }
              _hasError = false;
              _isTimedOut = false;
              _errorMessage = null;
              _loadStartTime = DateTime.now();
            });
            if (isFirstLoad) {
              _startTimeoutTimer();
            }
            debugPrint('⏱️ [ProviderWebView] Page started loading: $url (initial=$isFirstLoad)');
          }
        },
        onPageFinished: (String url) {
          final elapsed = DateTime.now().difference(_loadStartTime).inMilliseconds;
          debugPrint('⏱️ [ProviderWebView] Base HTML loaded in ${elapsed}ms');
          if (mounted && _currentStage == ProviderLoadStage.connecting) {
            setState(() {
              _currentStage = ProviderLoadStage.loadingBundle;
            });
          }
          // Responsive safety net: If host bridge signal doesn't arrive within 4 seconds after onPageFinished,
          // dismiss overlay gracefully so user is never delayed
          _safetyFallbackTimer?.cancel();
          _safetyFallbackTimer = Timer(const Duration(seconds: 4), () {
            if (_isLoading && mounted && !_hasError) {
              _dismissOverlay('safety_timeout_after_html');
            }
          });
        },
        onWebResourceError: (WebResourceError error) {
          final desc = error.description.toUpperCase();
          final failingUrl = error.url ?? '';
          final isUnknownScheme = desc.contains('ERR_UNKNOWN_URL_SCHEME') || error.errorCode == -10;

          // If the resource error is simply due to Chromium encountering an unhandled scheme
          // (such as an external UPI app intent from Razorpay iframe), do NOT crash the WebView into the "No Internet" error state!
          if (isUnknownScheme) {
            final uri = Uri.tryParse(failingUrl);
            final scheme = uri?.scheme.toLowerCase() ?? '';
            final isPaymentOrIntent = _trustedPaymentSchemes.contains(scheme) ||
                scheme == 'intent' ||
                _isTrustedPaymentIntent(failingUrl);

            if (isPaymentOrIntent) {
              debugPrint('ℹ️ [ProviderWebView] Intercepted payment scheme in onWebResourceError: $failingUrl');
              unawaited(_handlePaymentScheme(failingUrl));
              return;
            } else if (failingUrl.isEmpty) {
              // Sub-resource or iframe intent dispatched without failingUrl populated by Chromium
              debugPrint('ℹ️ [ProviderWebView] Suppressed sub-resource ERR_UNKNOWN_URL_SCHEME');
              return;
            }
          }

          // Genuine network errors (DNS failure, timeout, connection refused, 404, etc.)
          final isMain = error.isForMainFrame ?? true;
          if (isMain && mounted) {
            _cancelAllTimers();
            debugPrint('❌ [ProviderWebView] Main-frame resource error: ${error.description}');
            setState(() {
              _hasError = true;
              _isLoading = false;
              _isLoggingOut = false;
              _errorMessage = error.description;
            });
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;

          final scheme = uri.scheme.toLowerCase();

          // 1. Standard Web Navigation (HTTP / HTTPS)
          // Allow partner portal, Razorpay checkout frames, Firebase Auth, and 3D Secure / OTP pages
          if (scheme == 'http' || scheme == 'https') {
            return NavigationDecision.navigate;
          }

          // 2. Trusted Payment & UPI Schemes (upi, tez, phonepe, paytmmp, etc.)
          if (_trustedPaymentSchemes.contains(scheme)) {
            _handlePaymentScheme(request.url);
            return NavigationDecision.prevent;
          }

          // 3. Android Intent URI Scheme handling (e.g. intent://pay?...#Intent;scheme=upi;package=...;end)
          if (scheme == 'intent' && _isTrustedPaymentIntent(request.url)) {
            _handlePaymentScheme(request.url);
            return NavigationDecision.prevent;
          }

          // 4. Safe External Communication Schemes (tel, whatsapp, mailto, sms)
          if (_trustedCommunicationSchemes.contains(scheme)) {
            launchUrl(uri, mode: LaunchMode.externalApplication).catchError((e) {
              debugPrint('⚠️ Could not launch external URI: $uri ($e)');
              return false;
            });
            return NavigationDecision.prevent;
          }

          // 5. Block unknown, arbitrary, or hazardous schemes (javascript, file, content, data, etc.)
          debugPrint('🚫 Blocked navigation to unsupported scheme: $scheme in WebView');
          return NavigationDecision.prevent;
        },
      ),
    );

    // Initial load: standard caching allowed so return visits revalidate with 304 Not Modified
    controller.loadRequest(Uri.parse(_targetUrl));

    _controller = controller;
  }

  static const _intentChannel = MethodChannel('com.jamuiservice.customer/intent_launcher');

  static const Set<String> _trustedPaymentSchemes = {
    'upi',
    'tez',
    'phonepe',
    'paytmmp',
    'paytm',
    'gpay',
    'bhim',
    'cred',
    'credpay',
    'mobikwik',
  };

  static const Set<String> _trustedCommunicationSchemes = {
    'tel',
    'whatsapp',
    'mailto',
    'sms',
  };

  bool _isTrustedPaymentIntent(String rawUrl) {
    if (!rawUrl.startsWith('intent://') && !rawUrl.startsWith('intent:#Intent')) {
      return false;
    }
    final lower = rawUrl.toLowerCase();
    // Must contain trusted payment scheme or package
    final hasPaymentScheme = lower.contains('scheme=upi') ||
        lower.contains('scheme=tez') ||
        lower.contains('scheme=phonepe') ||
        lower.contains('scheme=paytmmp') ||
        lower.contains('scheme=paytm') ||
        lower.contains('scheme=cred') ||
        lower.contains('scheme=bhim') ||
        lower.contains('data=upi');

    final hasPaymentPackage = lower.contains('package=com.google.android.apps.nbu.paisa.user') ||
        lower.contains('package=com.phonepe.app') ||
        lower.contains('package=net.one97.paytm') ||
        lower.contains('package=in.org.npci.upiapp') ||
        lower.contains('package=com.dreamplug.androidapp');

    return hasPaymentScheme || hasPaymentPackage;
  }

  Future<void> _handlePaymentScheme(String rawUrl) async {
    try {
      debugPrint('💳 [ProviderWebView] Launching payment URI: $rawUrl');

      // 1. Try Native Android Intent Launcher via MethodChannel (uses Intent.parseUri)
      if (Platform.isAndroid) {
        try {
          final res = await _intentChannel.invokeMethod('launchPaymentIntent', {'uri': rawUrl});
          if (res is Map) {
            final status = res['status'] as String?;
            if (status == 'launched') {
              debugPrint('✅ [ProviderWebView] Native payment intent launched successfully');
              return;
            } else if (status == 'fallback') {
              final fallbackUrl = res['fallbackUrl'] as String?;
              if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
                final fallbackUri = Uri.tryParse(fallbackUrl);
                if (fallbackUri != null) {
                  await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
                  return;
                }
              }
            } else if (status == 'not_installed') {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('भुगतान के लिए संबंधित UPI ऐप (Google Pay/PhonePe/Paytm) डिवाइस पर नहीं मिला। कृपया दूसरा UPI विकल्प या QR कोड चुनें।'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
              return;
            }
          }
        } catch (channelErr) {
          debugPrint('⚠️ [ProviderWebView] MethodChannel intent launcher error: $channelErr');
        }
      }

      // 2. Direct url_launcher fallback (for direct upi:// or extracted scheme)
      final uri = Uri.tryParse(rawUrl);
      if (uri != null && uri.scheme.isNotEmpty && uri.scheme != 'intent') {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }

      // 3. Extracted UPI fallback for intent:// URLs
      if (rawUrl.startsWith('intent://') || rawUrl.startsWith('intent:#Intent')) {
        final upiFallback = _extractUpiUriFromIntent(rawUrl);
        if (upiFallback != null) {
          final launched = await launchUrl(upiFallback, mode: LaunchMode.externalApplication);
          if (launched) return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('UPI ऐप खोलने में असमर्थ। कृपया दूसरा भुगतान विकल्प चुनें।'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [ProviderWebView] Failed to handle payment scheme ($rawUrl): $e');
    }
  }

  Uri? _extractUpiUriFromIntent(String rawUrl) {
    try {
      // E.g.: intent://pay?pa=...#Intent;scheme=upi;end
      if (rawUrl.startsWith('intent://')) {
        final cleanRaw = rawUrl.replaceFirst('intent://', 'upi://').split('#Intent;').first;
        return Uri.tryParse(cleanRaw);
      }
      // E.g.: intent:#Intent;action=android.intent.action.VIEW;data=upi%3A%2F%2Fpay%3F...;end
      final dataMatch = RegExp(r'data=([^;]+)').firstMatch(rawUrl);
      if (dataMatch != null) {
        final decoded = Uri.decodeComponent(dataMatch.group(1)!);
        return Uri.tryParse(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Production-only trusted hosts
  static const Set<String> _productionTrustedHosts = {
    'jamui-provider.web.app',
    'jamui-provider.firebaseapp.com',
  };

  /// Staging-only trusted hosts (jamui-services-staging)
  static const Set<String> _stagingTrustedHosts = {
    'jamui-services-staging-provider.web.app',
    'jamui-services-staging-provider.firebaseapp.com',
  };

  /// Environment-specific trusted hosts resolver.
  /// Staging strictly trusts ONLY approved staging hosts.
  /// Production strictly trusts ONLY production hosts.
  /// Never combines them into one interchangeable global allowlist.
  static Set<String> get _trustedProviderHosts {
    switch (AppEnvironmentConfig.current) {
      case AppEnvironment.staging:
        return _stagingTrustedHosts;
      case AppEnvironment.emulator:
        return const {'10.0.2.2', 'localhost', '127.0.0.1'};
      case AppEnvironment.production:
        return _productionTrustedHosts;
    }
  }

  static bool isTrustedUrl(String? urlStr) {
    if (urlStr == null || urlStr.isEmpty) return false;
    final uri = Uri.tryParse(urlStr);
    if (uri == null) return false;
    return isTrustedOriginUri(uri);
  }

  static bool isTrustedOriginUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    if (scheme == 'https') {
      return _trustedProviderHosts.contains(host);
    }

    if (kDebugMode && scheme == 'http') {
      return host == 'localhost' || host == '127.0.0.1';
    }

    return false;
  }

  bool _isTrustedProviderUrl(String? urlStr) => isTrustedUrl(urlStr);

  bool _isTrustedOriginUri(Uri uri) => isTrustedOriginUri(uri);

  void _handleHostMessage(String message) async {
    final trimmed = message.trim();
    debugPrint('📡 [JamuiHost] Received message: $trimmed');

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      _handleHostJsonMessage(trimmed);
      return;
    }

    switch (trimmed) {
      case 'HTML_READY':
        if (mounted && _isLoading) {
          setState(() {
            _currentStage = ProviderLoadStage.loadingBundle;
          });
        }
        break;

      case 'FLUTTER_MOUNTED':
        if (mounted && _isLoading) {
          setState(() {
            _currentStage = ProviderLoadStage.preparingDashboard;
          });
        }
        break;

      case 'PROVIDER_READY':
        _dismissOverlay('host_bridge_provider_ready');
        break;

      case 'PROVIDER_LOGOUT_STARTED':
        if (mounted) {
          setState(() {
            _isLoggingOut = true;
            _isLoading = true;
            _showOverlay = true;
            _loadingProgress = 0.0;
          });
        }
        break;

      case 'PROVIDER_LOGOUT_SUCCESS':
        _hasLoggedOut = true;
        try {
          await _controller.clearCache();
        } catch (_) {}

        // Reload fresh unauthenticated login page with anti-cache headers
        _controller.loadRequest(
          Uri.parse(ProviderAppLauncherService.providerWebUrl),
          headers: const {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        );

        if (mounted) {
          setState(() {
            _isLoggingOut = false;
          });
        }
        break;

      case 'PROVIDER_LOGOUT_ERROR':
        if (mounted) {
          setState(() {
            _isLoggingOut = false;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('लॉगआउट में समस्या हुई। कृपया पुनः प्रयास करें।'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        break;
    }
  }

  Future<void> _handleHostJsonMessage(String jsonStr) async {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final action = map['action'] as String? ?? '';
      final requestId = map['requestId'] as String? ?? '';

      debugPrint('📡 [JamuiHost] Bridge action: $action, requestId: $requestId');

      if (action == 'GET_NATIVE_LOCATION') {
        await _handleNativeLocationRequest(requestId);
      }
    } catch (e) {
      debugPrint('⚠️ [JamuiHost] Error parsing host JSON message: $e');
    }
  }

  final Set<String> _processedLocationRequestIds = {};

  Future<void> _handleNativeLocationRequest(String requestId) async {
    // 0. Deduplicate and reject stale or duplicate location requests
    if (requestId.trim().isEmpty) {
      debugPrint('⚠️ [JamuiHost] Ignored empty requestId for location');
      return;
    }
    if (_processedLocationRequestIds.contains(requestId)) {
      debugPrint('⚠️ [JamuiHost] Ignored duplicate location request: $requestId');
      return;
    }
    _processedLocationRequestIds.add(requestId);
    if (_processedLocationRequestIds.length > 100) {
      _processedLocationRequestIds.remove(_processedLocationRequestIds.first);
    }

    // 1. Strict Origin Verification: ensure current WebView page is trusted
    String? currentUrl;
    try {
      currentUrl = await _controller.currentUrl();
    } catch (_) {}

    if (!_isTrustedProviderUrl(currentUrl)) {
      debugPrint('🚫 [JamuiHost] Rejected native location: Untrusted origin ($currentUrl)');
      _sendNativeLocationResponse({
        'requestId': requestId,
        'success': false,
        'error': 'UNTRUSTED_ORIGIN',
        'message': 'असुरक्षित अथवा अमान्य वेबपेज से लोकेशन अनुरोध अस्वीकृत किया गया।',
      });
      return;
    }

    // 2. Check Device GPS / Location Service
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        debugPrint('⚠️ [JamuiHost] Device GPS service is disabled');
        _sendNativeLocationResponse({
          'requestId': requestId,
          'success': false,
          'error': 'LOCATION_DISABLED',
          'message': 'डिवाइस का GPS / लोकेशन बंद है। कृपया इसे सेटिंग्स से चालू करें।',
        });
        return;
      }
    } catch (e) {
      debugPrint('⚠️ [JamuiHost] Location service check failed: $e');
    }

    // 3. Runtime Location Permission Request
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ [JamuiHost] Location permission denied: $permission');
        _sendNativeLocationResponse({
          'requestId': requestId,
          'success': false,
          'error': 'PERMISSION_DENIED',
          'message': 'लोकेशन अनुमति (Location Permission) अस्वीकृत की गई। कृपया ऐप सेटिंग्स से अनुमति दें।',
        });
        return;
      }
    } catch (e) {
      debugPrint('⚠️ [JamuiHost] Location permission request failed: $e');
      _sendNativeLocationResponse({
        'requestId': requestId,
        'success': false,
        'error': 'PERMISSION_DENIED',
        'message': 'लोकेशन अनुमति जांच में समस्या हुई: $e',
      });
      return;
    }

    // 4. Fetch Native High-Accuracy GPS Position with 25s timeout
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );

      debugPrint('📍 [JamuiHost] Native GPS coordinates obtained: ${position.latitude}, ${position.longitude}, acc=±${position.accuracy}m');

      _sendNativeLocationResponse({
        'requestId': requestId,
        'success': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'source': 'native_gps',
      });
    } catch (e) {
      debugPrint('❌ [JamuiHost] Geolocator.getCurrentPosition error: $e');
      _sendNativeLocationResponse({
        'requestId': requestId,
        'success': false,
        'error': 'LOCATION_TIMEOUT',
        'message': 'GPS लोकेशन प्राप्त करने में समय सीमा (25s) समाप्त हो गई। कृपया खुले स्थान में जाएं और पुनः प्रयास करें।',
      });
    }
  }

  void _sendNativeLocationResponse(Map<String, dynamic> responseMap) {
    if (!mounted) return;
    try {
      final jsonPayload = jsonEncode(responseMap);
      final jsArg = jsonEncode(jsonPayload);
      _controller.runJavaScript(
        'if (window.__onJamuiLocationResponse) { window.__onJamuiLocationResponse($jsArg); }',
      );
    } catch (e) {
      debugPrint('⚠️ [JamuiHost] Failed to send location response to WebView: $e');
    }
  }

  /// Handles HTML file selection dialogs (<input type="file">) originating inside WebView
  /// Dispatches to native Android Camera or Gallery via [ImagePicker]
  Future<List<String>> _handleAndroidFileSelection(FileSelectorParams params) async {
    try {
      final picker = ImagePicker();

      // Check if video file requested
      final isVideo = params.acceptTypes.any((t) => t.toLowerCase().contains('video'));
      if (isVideo) {
        final XFile? video = await picker.pickVideo(
          source: params.isCaptureEnabled ? ImageSource.camera : ImageSource.gallery,
        );
        if (video != null) {
          final uriString = video.path.startsWith('content://') || video.path.startsWith('file://')
              ? video.path
              : Uri.file(video.path).toString();
          return [uriString];
        }
        return [];
      }

      // If the HTML input specifically requested camera capture (e.g. capture="environment" or "user")
      if (params.isCaptureEnabled) {
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (photo != null) {
          final uriString = photo.path.startsWith('content://') || photo.path.startsWith('file://')
              ? photo.path
              : Uri.file(photo.path).toString();
          return [uriString];
        }
        return [];
      }

      // If multiple files are permitted
      if (params.mode == FileSelectorMode.openMultiple) {
        final List<XFile> photos = await picker.pickMultiImage(
          imageQuality: 85,
        );
        if (photos.isNotEmpty) {
          return photos.map((p) {
            return p.path.startsWith('content://') || p.path.startsWith('file://')
                ? p.path
                : Uri.file(photoPath(p.path)).toString();
          }).toList();
        }
        return [];
      }

      // Default: Pick single image from device Gallery
      final XFile? photo = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (photo != null) {
        final uriString = photo.path.startsWith('content://') || photo.path.startsWith('file://')
            ? photo.path
            : Uri.file(photo.path).toString();
        return [uriString];
      }
    } catch (e) {
      debugPrint('WebView file picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('फोटो लोड करने में समस्या: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    return [];
  }

  String photoPath(String p) => p;

  Future<void> _handleBackPress() async {
    // If logout is in progress or user just logged out, exit directly to Customer App
    if (_isLoggingOut || _hasLoggedOut) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      if (await _controller.canGoBack()) {
        await _controller.goBack();
        return;
      }
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _reload() async {
    _cancelAllTimers();
    setState(() {
      _hasInitialLoadCompleted = false;
      _hasError = false;
      _isTimedOut = false;
      _isLoading = true;
      _showOverlay = true;
      _isLoggingOut = false;
      _loadingProgress = 0.0;
      _errorMessage = null;
      _currentStage = ProviderLoadStage.connecting;
    });
    _startTimeoutTimer();

    try {
      await _controller.clearCache();
    } catch (_) {}

    _controller.loadRequest(
      Uri.parse(_targetUrl),
      headers: const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'वापस जाएं (Back)',
            onPressed: _handleBackPress,
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jamui Partner Portal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'सेवा प्रदाता पोर्टल (Provider Portal)',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'रिफ्रेश करें (Reload fresh build)',
              onPressed: _reload,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'बंद करें (Exit to Customer App)',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          bottom: (_isLoading || _isLoggingOut)
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 && !_isLoggingOut
                        ? _loadingProgress
                        : null,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.amberAccent,
                    ),
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // 1. Core Web View
              WebViewWidget(controller: _controller),

              // 2. Branded Smooth Loading / Logout Transition Overlay (Immediate from frame 1)
              if (_showOverlay)
                IgnorePointer(
                  ignoring: !_isLoading && !_isLoggingOut,
                  child: AnimatedOpacity(
                    opacity: (_isLoading || _isLoggingOut) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 350),
                    onEnd: () {
                      if (!_isLoading && !_isLoggingOut && mounted) {
                        setState(() => _showOverlay = false);
                      }
                    },
                    child: _buildBrandedLoadingOverlay(),
                  ),
                ),

              // 3. Slow Network Timeout Warning View
              if (_isTimedOut && !_hasError && _isLoading)
                _buildTimeoutOverlay(),

              // 4. Main-Frame Network Connection Error View
              if (_hasError) _buildErrorView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandedLoadingOverlay() {
    final title = _isLoggingOut
        ? 'सुरक्षित रूप से लॉगआउट हो रहा है…'
        : 'Provider Services khol rahe hain…';
    final subtitle = _isLoggingOut
        ? 'कृपया कुछ पल इंतज़ार करें…'
        : 'Aapka dashboard taiyar ho raha hai. Kripya kuch pal intezar karein.';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Branded Logo with soft pulse & shadow
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const AppLogo(size: 68, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 28),

              // Heading
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Subtext
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 26),

              // Stage Status Pill (Event-driven)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _currentStage == ProviderLoadStage.takingLonger
                      ? Colors.amber.shade50
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _currentStage == ProviderLoadStage.takingLonger
                        ? Colors.amber.shade300
                        : AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _currentStage == ProviderLoadStage.takingLonger
                              ? Colors.amber.shade800
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _stageLabel,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _currentStage == ProviderLoadStage.takingLonger
                              ? Colors.amber.shade900
                              : AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Smooth Indeterminate Progress Bar
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeoutOverlay() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 48,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Provider Services abhi load nahi ho pa rahi hain.',
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'नेटवर्क कमजोर होने या सर्वर रिस्पांस में देरी के कारण पोर्टल लोड नहीं हो सका। कृपया दोबारा प्रयास करें या बाद में चेक करें।',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Dobara Try Karein',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                  label: Text(
                    'Wapas Jayein',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'इंटरनेट कनेक्शन समस्या',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ??
                    'Jamui Services पार्टनर पोर्टल लोड नहीं हो सका। कृपया अपना इंटरनेट कनेक्शन जांचें और पुनः प्रयास करें।',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Dobara Try Karein',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                  label: Text(
                    'Wapas Jayein',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

