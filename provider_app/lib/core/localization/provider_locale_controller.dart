import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central reactive locale controller for Apna Jamui Provider App.
///
/// Features:
/// - Supports Hindi ('hi') and English ('en')
/// - Default is 'hi' (Hindi) for fresh installation
/// - Persists selection to SharedPreferences under key 'provider_language_code'
/// - Completely independent of Customer App preferences
/// - ChangeNotifier-based reactive updates: triggers immediate widget rebuilds without restart
class ProviderLocaleController extends ChangeNotifier {
  ProviderLocaleController._();
  static final ProviderLocaleController instance = ProviderLocaleController._();

  static const String prefKey = 'provider_language_code';
  static const String defaultLocale = 'hi';

  String _code = defaultLocale;

  String get currentLocale => _code;
  bool get isHindi => _code == 'hi';
  bool get isEnglish => _code == 'en';

  /// Initializes the locale from SharedPreferences. Call before runApp in main().
  Future<void> init({SharedPreferences? prefs}) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final saved = p.getString(prefKey);
      if (saved == 'en' || saved == 'hi') {
        _code = saved!;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ProviderLocaleController] Init error: $e');
    }
  }

  /// Sets locale to 'hi' or 'en', notifies listeners immediately, and persists to storage.
  Future<void> setLocale(String code, {SharedPreferences? prefs}) async {
    final cleanCode = code.trim().toLowerCase();
    if (cleanCode != 'hi' && cleanCode != 'en') return;
    if (_code == cleanCode) return;

    _code = cleanCode;
    notifyListeners();

    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setString(prefKey, cleanCode);
    } catch (e) {
      debugPrint('[ProviderLocaleController] Save error: $e');
    }
  }

  /// Toggles between Hindi and English reactively.
  Future<void> toggleLocale({SharedPreferences? prefs}) async {
    await setLocale(isHindi ? 'en' : 'hi', prefs: prefs);
  }

  /// Direct reset for test suites
  @visibleForTesting
  void resetForTest([String code = defaultLocale]) {
    _code = code;
  }
}
