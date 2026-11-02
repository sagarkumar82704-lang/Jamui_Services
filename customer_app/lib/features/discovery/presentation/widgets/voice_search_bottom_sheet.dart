import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ai_search_intent_service.dart';
import '../../../../core/services/speech_service.dart';
import '../../domain/entities/ai_search_intent_entity.dart';
import '../../domain/entities/service_category_entity.dart';

class VoiceSearchBottomSheet extends StatefulWidget {
  final List<ServiceCategoryEntity> availableCategories;
  final Function(String query, AISearchIntentEntity? intent) onSearchSelected;

  const VoiceSearchBottomSheet({
    super.key,
    required this.availableCategories,
    required this.onSearchSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ServiceCategoryEntity> availableCategories,
    required Function(String query, AISearchIntentEntity? intent) onSearchSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceSearchBottomSheet(
        availableCategories: availableCategories,
        onSearchSelected: onSearchSelected,
      ),
    );
  }

  @override
  State<VoiceSearchBottomSheet> createState() => _VoiceSearchBottomSheetState();
}

class _VoiceSearchBottomSheetState extends State<VoiceSearchBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final SpeechService _speechService = SpeechService();
  VoiceSearchState _state = VoiceSearchState.initializing;
  String _transcript = '';
  String _errorMessage = '';
  double _soundLevel = 0.0;
  AISearchIntentEntity? _detectedIntent;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startListeningFlow();
  }

  @override
  void dispose() {
    _speechService.cancelListening();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startListeningFlow() async {
    setState(() {
      _state = VoiceSearchState.initializing;
      _transcript = '';
      _errorMessage = '';
      _detectedIntent = null;
    });

    final available = await _speechService.initialize();
    if (!available) {
      if (!mounted) return;
      setState(() {
        _state = VoiceSearchState.unavailable;
        _errorMessage = 'Voice search उपलब्ध नहीं है। कृपया text search करें।';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _state = VoiceSearchState.listening);

    await _speechService.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _transcript = words;
        });
        if (isFinal && words.trim().isNotEmpty) {
          _processIntent(words);
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = level);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _state = VoiceSearchState.error;
          _errorMessage = err;
        });
      },
      onDone: () {
        if (!mounted) return;
        if (_transcript.trim().isNotEmpty && _state == VoiceSearchState.listening) {
          _processIntent(_transcript);
        }
      },
    );
  }

  Future<void> _processIntent(String query) async {
    if (_state == VoiceSearchState.processing) return;

    setState(() => _state = VoiceSearchState.processing);
    await _speechService.stopListening();

    try {
      final intent = await AISearchIntentService.extractIntent(
        query: query,
        availableCategories: widget.availableCategories,
      );

      if (!mounted) return;

      if (intent.categoryId != null && intent.intentType != AISearchIntentType.noMatch) {
        setState(() {
          _detectedIntent = intent;
          _state = VoiceSearchState.success;
        });

        // Brief pause so user sees the smart match confirmation, then trigger search
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        Navigator.pop(context);
        widget.onSearchSelected(query, intent);
      } else {
        // No matching category in active database (e.g. watch repair, doctor, lawyer)
        setState(() {
          _detectedIntent = intent;
          _state = VoiceSearchState.error;
          _errorMessage = intent.clarificationMessage ?? '“$query” से संबंधित सेवा अभी जमुई में उपलब्ध नहीं है। कृपया उपलब्ध सेवाओं में से चुनें।';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = VoiceSearchState.error;
        _errorMessage = 'Search समझने में समस्या आई। कृपया दोबारा प्रयास करें।';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),

          // Header Title
          Text(
            _getHeaderTitle(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle / Prompt
          Text(
            _getSubtitleText(),
            style: TextStyle(
              fontSize: 13,
              color: _state == VoiceSearchState.error ? Colors.red.shade700 : AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Animated Central Microphone Visualizer
          _buildMicVisualizer(),
          const SizedBox(height: 24),

          // Real-time Live Spoken Transcript Box
          if (_transcript.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.record_voice_over_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        _state == VoiceSearchState.listening ? 'आप बोल रहे हैं...' : 'आपकी बात:',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '“$_transcript”',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Matched Intent Feedback
          if (_detectedIntent != null && _detectedIntent!.categoryId != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'स्मार्ट मैच: ${_detectedIntent!.categoryTitleHindi ?? _detectedIntent!.categoryTitleEnglish}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Bottom Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildMicVisualizer() {
    final isListening = _state == VoiceSearchState.listening;
    final isProcessing = _state == VoiceSearchState.processing;
    final isError = _state == VoiceSearchState.error || _state == VoiceSearchState.unavailable;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Ripple
          if (isListening)
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
            ),

          // Inner Ripple
          if (isListening)
            Container(
              width: 90 + (_soundLevel * 1.5).clamp(0.0, 25.0),
              height: 90 + (_soundLevel * 1.5).clamp(0.0, 25.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),

          // Main Microphone Button
          GestureDetector(
            onTap: () {
              if (isListening) {
                if (_transcript.trim().isNotEmpty) {
                  _processIntent(_transcript);
                } else {
                  _speechService.stopListening();
                  setState(() => _state = VoiceSearchState.idle);
                }
              } else {
                _startListeningFlow();
              }
            },
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isError
                    ? Colors.red
                    : (isProcessing ? Colors.orange : AppColors.primary),
                boxShadow: [
                  BoxShadow(
                    color: (isError ? Colors.red : AppColors.primary).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: isProcessing
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isError
                            ? Icons.mic_off_rounded
                            : (isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                        color: Colors.white,
                        size: 34,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_state == VoiceSearchState.error || _state == VoiceSearchState.unavailable) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Text Search करें'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _startListeningFlow,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry करें'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }

    if (_state == VoiceSearchState.listening) {
      return TextButton.icon(
        onPressed: () {
          if (_transcript.trim().isNotEmpty) {
            _processIntent(_transcript);
          } else {
            _speechService.cancelListening();
            Navigator.pop(context);
          }
        },
        icon: Icon(
          _transcript.trim().isNotEmpty ? Icons.arrow_forward_rounded : Icons.close,
          size: 16,
          color: AppColors.primary,
        ),
        label: Text(
          _transcript.trim().isNotEmpty ? 'Search करें' : 'रद्द करें (Cancel)',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _getHeaderTitle() {
    switch (_state) {
      case VoiceSearchState.initializing:
        return 'शुरू हो रहा है...';
      case VoiceSearchState.listening:
        return '🎤 सुन रहे हैं... बोलिए';
      case VoiceSearchState.processing:
        return '🧠 AI आपकी समस्या को समझ रहा है...';
      case VoiceSearchState.success:
        final catTitle = _detectedIntent?.categoryTitleHindi ?? _detectedIntent?.categoryTitleEnglish;
        return catTitle != null ? '✅ $catTitle श्रेणी मिल गई!' : '✅ सेवा मिल गई!';
      case VoiceSearchState.error:
        if (_detectedIntent?.intentType == AISearchIntentType.noMatch) {
          return '❌ सेवा उपलब्ध नहीं है';
        }
        return 'खोज में समस्या';
      case VoiceSearchState.unavailable:
      case VoiceSearchState.permissionDenied:
        return 'Voice Search अनुपलब्ध';
      case VoiceSearchState.idle:
        return 'बोलकर सर्च करें';
    }
  }

  String _getSubtitleText() {
    switch (_state) {
      case VoiceSearchState.initializing:
        return 'माइक्रोफोन तैयार किया जा रहा है...';
      case VoiceSearchState.listening:
        return 'अपनी आवश्यकता या सेवा के बारे में बोलें...';
      case VoiceSearchState.processing:
        return 'उपलब्ध श्रेणियों व कारीगरों से मिलान किया जा रहा है...';
      case VoiceSearchState.success:
        return 'नजदीकी उपलब्ध कारीगर खोजे जा रहे हैं...';
      case VoiceSearchState.error:
      case VoiceSearchState.unavailable:
      case VoiceSearchState.permissionDenied:
        return _errorMessage.isNotEmpty ? _errorMessage : 'कृपया दोबारा प्रयास करें या टेक्स्ट से खोजें।';
      case VoiceSearchState.idle:
        return 'माइक पर टैप करके अपनी समस्या बोलें।';
    }
  }
}
