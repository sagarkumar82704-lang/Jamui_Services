import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceSearchState {
  idle,
  initializing,
  listening,
  processing,
  success,
  error,
  permissionDenied,
  unavailable,
}

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  String _selectedLocaleId = 'hi_IN';

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isInitialized;

  /// Initialize Speech Recognition engine
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('⚠️ [SpeechService] Speech error: ${error.errorMsg} (permanent: ${error.permanent})');
        },
        onStatus: (String status) {
          debugPrint('🎙️ [SpeechService] Status: $status');
        },
        debugLogging: kDebugMode,
      );

      if (_isInitialized) {
        // Probe available locales to select best Hindi or Hinglish/English locale
        final locales = await _speechToText.locales();
        final hasHindi = locales.any((l) => l.localeId.startsWith('hi'));
        final hasIndianEnglish = locales.any((l) => l.localeId == 'en_IN');

        if (hasHindi) {
          _selectedLocaleId = locales.firstWhere((l) => l.localeId.startsWith('hi')).localeId;
        } else if (hasIndianEnglish) {
          _selectedLocaleId = 'en_IN';
        } else {
          final systemLocale = await _speechToText.systemLocale();
          _selectedLocaleId = systemLocale?.localeId ?? 'en_US';
        }
        debugPrint('🎙️ [SpeechService] Selected speech locale: $_selectedLocaleId');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('⚠️ [SpeechService] Init exception: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start Listening for speech
  Future<void> startListening({
    required Function(String transcript, bool isFinal) onResult,
    required Function(double level) onSoundLevelChange,
    required Function(String error) onError,
    required VoidCallback onDone,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        onError('Voice search उपलब्ध नहीं है। कृपया text search करें।');
        return;
      }
    }

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            onDone();
          }
        },
        onSoundLevelChange: onSoundLevelChange,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
          localeId: _selectedLocaleId,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [SpeechService] startListening error: $e');
      onError('Voice search में समस्या आई। Retry करें।');
    }
  }

  /// Stop listening immediately
  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}
  }

  /// Cancel listening immediately
  Future<void> cancelListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
    } catch (_) {}
  }
}
