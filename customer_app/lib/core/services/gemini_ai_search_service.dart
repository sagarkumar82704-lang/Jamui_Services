import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/gemini_ai_config.dart';
import 'customer_app_settings_service.dart';
import '../../features/discovery/domain/entities/ai_search_intent_entity.dart';
import '../../features/discovery/domain/entities/service_category_entity.dart';

/// Production-Grade Google Gemini AI Intent Classification Service.
///
/// Capabilities:
/// 1. Understands colloquial spoken Hindi, Bhojpuri, Maithili, Hinglish, & English.
/// 2. Maps customer problems directly to real, active Firestore categories & sub-services.
/// 3. Multi-model resilience: Auto-retries across candidate models (`gemini-2.0-flash`, `gemini-1.5-flash-latest`, `gemini-1.5-flash`).
/// 4. Handles both standard Google AI Studio Keys (`AIzaSy...`) and OAuth/Bearer tokens (`AQ...`, `ya29...`).
class GeminiAISearchService {
  static const List<String> _candidateModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-pro',
  ];

  /// Classifies user search/voice query using Google Gemini AI
  static Future<AISearchIntentEntity?> classifyIntent({
    required String query,
    required List<ServiceCategoryEntity> availableCategories,
    String? preferredArea,
    Duration timeout = const Duration(milliseconds: 3000),
    http.Client? httpClient,
  }) async {
    // 0. Firestore Customer App Settings Kill-Switch Check
    if (!CustomerAppSettingsService().isGeminiAiSearchEnabled) {
      debugPrint('⚡ [Gemini AI] AI Search is temporarily disabled via Customer App Settings. Using resilient local dynamic matcher.');
      return null;
    }

    final apiKey = GeminiAiConfig.apiKey;
    if (!GeminiAiConfig.isConfigured || apiKey.isEmpty) {
      debugPrint(
        '⚠️ [Gemini AI] API Key is NOT configured in Firestore (app_config/ai). Using resilient local dynamic matcher.',
      );
      return null;
    }

    final activeCats = availableCategories.where((c) => c.isActive).toList();
    if (activeCats.isEmpty) {
      debugPrint(
        '⚠️ [Gemini AI] No active categories found in database to match against.',
      );
      return null;
    }

    final categoriesContext = activeCats
        .map(
          (c) => {
            'id': c.id,
            'titleHindi': c.titleHindi,
            'titleEnglish': c.titleEnglish,
            'subServices': c.subServices,
            'commonProblems': c.commonProblems,
            'description': c.description,
          },
        )
        .toList();

    final promptText = _buildPrompt(
      query: query,
      categoriesJson: jsonEncode(categoriesContext),
      preferredArea: preferredArea,
    );

    final requestBody = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': promptText},
          ],
        },
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.1,
        'maxOutputTokens': 400,
      },
    };

    final client = httpClient ?? http.Client();

    // Determine authorization headers
    final isBearerToken =
        apiKey.startsWith('AQ.') || apiKey.startsWith('ya29.');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (isBearerToken) {
      headers['Authorization'] = 'Bearer $apiKey';
    } else {
      headers['x-goog-api-key'] = apiKey;
    }

    // Try primary model first, then candidate cascade if 404 occurs
    final modelsToTry = [
      GeminiAiConfig.model,
      ..._candidateModels.where((m) => m != GeminiAiConfig.model),
    ];

    for (final model in modelsToTry) {
      try {
        final queryParam = isBearerToken ? '' : '?key=$apiKey';
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent$queryParam',
        );

        debugPrint(
          '🚀 [Gemini AI] Calling Google Gemini API ($model) for query: "$query"...',
        );

        final response = await client
            .post(url, headers: headers, body: jsonEncode(requestBody))
            .timeout(timeout);

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final candidates = responseData['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final candidate = candidates.first as Map<String, dynamic>;
            final content = candidate['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final rawJsonText = parts.first['text'] as String?;
              if (rawJsonText != null && rawJsonText.trim().isNotEmpty) {
                final result = _parseGeminiJsonResponse(
                  rawJsonText.trim(),
                  activeCats,
                  query,
                );
                if (result != null) {
                  if (result.categoryId != null) {
                    debugPrint(
                      '✅ [Gemini AI] HIT SUCCESS -> Matched: "${result.categoryTitleHindi} / ${result.categoryTitleEnglish}" (ID: ${result.categoryId}, Confidence: ${result.confidence})',
                    );
                  } else {
                    debugPrint(
                      'ℹ️ [Gemini AI] NO MATCH -> Query "$query" is not available in active categories.',
                    );
                  }
                  return result;
                }
              }
            }
          }
        } else if (response.statusCode == 404) {
          debugPrint(
            '⚠️ [Gemini AI] Model $model returned 404, trying next model in cascade...',
          );
          continue;
        } else {
          debugPrint(
            '❌ [Gemini AI] HTTP ${response.statusCode} Error: ${response.body}',
          );
          break; // Non-404 error (e.g. quota 429 or auth 403), stop cascade
        }
      } catch (e) {
        debugPrint('❌ [Gemini AI] Exception on model $model: $e');
        break;
      }
    }

    if (httpClient == null) {
      client.close();
    }

    return null;
  }

  static String _buildPrompt({
    required String query,
    required String categoriesJson,
    String? preferredArea,
  }) {
    return '''
You are the AI Semantic Intent Classifier for "JAMUI SERVICES", a hyperlocal on-demand service app in Jamui, Bihar, India.

A customer has spoken or typed a search query in Hindi, Bhojpuri, Maithili, Hinglish, or English.
Match their request strictly against the PROVIDED AVAILABLE CATEGORIES ONLY.

Customer Query: "$query"
${preferredArea != null ? 'Customer Preferred Area: "$preferredArea"' : ''}

Available Active Categories in Jamui:
$categoriesJson

CRITICAL RULES:
1. Understand colloquial Hindi/Bhojpuri expressions:
   - "पंखा खराब है", "पंखा बनाने वाला", "बिजली ठीक करने वाला", "बिजली मिस्त्री", "शॉर्ट सर्किट", "लाइट खराब" -> Electrician category
   - "नल से पानी टपक रहा है", "पाइप लीक", "नल बनाने वाला", "पानी की टंकी", "प्लंबर" -> Plumber category
   - "AC ठंडा नहीं कर रहा", "कूलर रिपेयर" -> AC/Cooler category (if available)
2. STRICT CATEGORY REJECTION:
   - If the user asks for a service that is NOT IN THE AVAILABLE CATEGORIES LIST (e.g., "watch banane wala", "घड़ी बनाने वाला", "कार मैकेनिक", "डॉक्टर", "टेलर", "वकील"), YOU MUST SET "categoryId": null, "confidence": 0.0!
   - DO NOT guess or hallucinate an unavailable category.
3. Output STRICT JSON only with this schema:

{
  "categoryId": "string or null",
  "categoryTitleHindi": "string or null",
  "categoryTitleEnglish": "string or null",
  "serviceTitle": "string or null",
  "extractedProblem": "string",
  "extractedArea": "string or null",
  "isUrgent": true or false,
  "confidence": 0.95,
  "explanation": "Short reason"
}
''';
  }

  static AISearchIntentEntity? _parseGeminiJsonResponse(
    String rawJson,
    List<ServiceCategoryEntity> activeCategories,
    String originalQuery,
  ) {
    try {
      String cleaned = rawJson.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final Map<String, dynamic> data = jsonDecode(cleaned);
      final String? returnedCatId = data['categoryId'];
      final double confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
      final String? serviceTitle = data['serviceTitle'];
      final String? extractedProblem =
          data['extractedProblem'] ?? originalQuery;
      final String? extractedArea = data['extractedArea'];
      final bool isUrgent = data['isUrgent'] == true;

      if (returnedCatId != null &&
          returnedCatId.isNotEmpty &&
          returnedCatId.toLowerCase() != 'null' &&
          confidence >= 0.40) {
        ServiceCategoryEntity? matchedCat;
        for (final c in activeCategories) {
          if (c.id == returnedCatId) {
            matchedCat = c;
            break;
          }
        }
        if (matchedCat == null) {
          final titleHi = (data['categoryTitleHindi'] ?? '')
              .toString()
              .toLowerCase();
          final titleEn = (data['categoryTitleEnglish'] ?? '')
              .toString()
              .toLowerCase();
          for (final c in activeCategories) {
            if (c.titleHindi.toLowerCase() == titleHi ||
                c.titleEnglish.toLowerCase() == titleEn) {
              matchedCat = c;
              break;
            }
          }
        }

        if (matchedCat != null) {
          return AISearchIntentEntity(
            intentType: AISearchIntentType.serviceSearch,
            categoryId: matchedCat.id,
            categoryTitleHindi: matchedCat.titleHindi,
            categoryTitleEnglish: matchedCat.titleEnglish,
            serviceTitle:
                serviceTitle ??
                (matchedCat.subServices.isNotEmpty
                    ? matchedCat.subServices.first
                    : null),
            extractedProblem: extractedProblem ?? originalQuery,
            extractedArea: extractedArea,
            isUrgent: isUrgent,
            confidence: confidence,
            suggestedSubServices: matchedCat.subServices,
          );
        }
      }

      // No category matched
      return AISearchIntentEntity(
        intentType: AISearchIntentType.noMatch,
        confidence: confidence < 0.3 ? confidence : 0.0,
        extractedProblem: extractedProblem ?? originalQuery,
        clarificationMessage:
            '“$originalQuery” अभी यह सेवा Jamui Services पर उपलब्ध नहीं है। हम आपकी आवश्यकता समझते हैं और जल्द से जल्द अधिक से अधिक सेवाएँ आप तक पहुँचाने का प्रयास कर रहे हैं.\n\nआपके सहयोग और विश्वास के लिए धन्यवाद! ❤️',
      );
    } catch (e) {
      debugPrint('⚠️ [Gemini AI] JSON parse error: $e for raw: $rawJson');
      return null;
    }
  }
}
