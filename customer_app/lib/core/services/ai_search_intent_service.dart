import 'package:flutter/foundation.dart';
import '../config/gemini_ai_config.dart';
import '../../features/discovery/domain/entities/ai_search_intent_entity.dart';
import '../../features/discovery/domain/entities/service_category_entity.dart';
import 'gemini_ai_search_service.dart';

class SearchSuggestionItem {
  final String title;
  final String? subtitle;
  final String? categoryId;
  final String? categoryName;
  final String? tradeType;
  final String searchQuery;
  final bool isTypoCorrection;
  final bool isTrending;
  final AISearchIntentEntity? intent;

  const SearchSuggestionItem({
    required this.title,
    this.subtitle,
    this.categoryId,
    this.categoryName,
    this.tradeType,
    required this.searchQuery,
    this.isTypoCorrection = false,
    this.isTrending = false,
    this.intent,
  });
}

class AISearchIntentService {
  // Configurable confidence thresholds
  static const double directMatchThreshold = 0.70;
  static const double suggestionThreshold = 0.40;

  /// Main intent extraction pipeline (Database-First Waterfall for Zero Bill & Maximum Speed)
  static Future<AISearchIntentEntity> extractIntent({
    required String query,
    required List<ServiceCategoryEntity> availableCategories,
    String? preferredArea,
    Duration backendTimeout = const Duration(milliseconds: 1500),
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const AISearchIntentEntity(
        intentType: AISearchIntentType.noMatch,
        confidence: 0.0,
      );
    }

    // 1. FAST-PATH: Direct Exact/Substring Match on Real Active Categories
    final fastMatch = _checkDirectCategoryMatch(cleanQuery, availableCategories);
    if (fastMatch != null) {
      debugPrint('⚡ [AISearchIntent] Exact Category Match: ${fastMatch.categoryTitleHindi} (Fast path)');
      return fastMatch;
    }

    // 2. GOOGLE GEMINI AI LLM BRAIN (If Configured)
    if (GeminiAiConfig.isConfigured) {
      debugPrint('🤖 [AISearchIntent] Calling Gemini AI Semantic Engine for: "$cleanQuery"...');
      try {
        final geminiResult = await GeminiAISearchService.classifyIntent(
          query: cleanQuery,
          availableCategories: availableCategories,
          preferredArea: preferredArea,
          timeout: const Duration(milliseconds: 3000),
        );

        if (geminiResult != null) {
          final validated = _validateIntentResult(geminiResult, availableCategories);
          if (validated != null) {
            debugPrint('✨ [AISearchIntent] Gemini AI resolved intent: ${validated.categoryTitleHindi} (Confidence: ${validated.confidence})');
            return validated;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [AISearchIntentService] Gemini AI classification error: $e');
      }
    }

    // 3. DATABASE DEEP LOCAL MATCH (Checks subServices, commonProblems, trade keywords & Fuzzy Typo Tolerance)
    final localMatch = _matchLocallyAgainstRealCategories(
      query: cleanQuery,
      availableCategories: availableCategories,
      preferredArea: preferredArea,
    );

    // If local database engine found a confident match
    if (localMatch.intentType == AISearchIntentType.serviceSearch &&
        localMatch.categoryId != null) {
      debugPrint('🎯 [AISearchIntent] Local Match: ${localMatch.categoryTitleHindi} (Confidence: ${localMatch.confidence})');
      return localMatch;
    }

    return localMatch;
  }

  /// Levenshtein Distance for fuzzy typo detection
  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = (a.codeUnitAt(i) == b.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((curr, next) => curr < next ? curr : next);
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }

  /// Live Search Suggestions Generator (Flipkart / Amazon Style)
  static List<SearchSuggestionItem> getLiveSuggestions({
    required String query,
    required List<ServiceCategoryEntity> availableCategories,
    AISearchIntentEntity? currentIntent,
  }) {
    final cleanQuery = query.trim().toLowerCase();

    // 1. If empty query: Return Trending / Most Popular Services in Jamui
    if (cleanQuery.isEmpty) {
      return _getTrendingSuggestions(availableCategories);
    }

    final List<SearchSuggestionItem> suggestions = [];
    final Set<String> addedKeys = {};

    // Helper to add unique suggestion
    void addSuggestion(SearchSuggestionItem item) {
      final key = '${item.title.toLowerCase()}_${item.categoryId ?? ""}';
      if (!addedKeys.contains(key) && suggestions.length < 6) {
        addedKeys.add(key);
        suggestions.add(item);
      }
    }

    // A. Typo / Phonetic Spell Correction Check (Did you mean?)
    final typoMatch = _checkTypoCorrection(cleanQuery, availableCategories);
    if (typoMatch != null) {
      addSuggestion(typoMatch);
    }

    // B. AI / Intent Match if available
    if (currentIntent != null &&
        currentIntent.isDirectMatch &&
        currentIntent.categoryId != null) {
      addSuggestion(
        SearchSuggestionItem(
          title: currentIntent.categoryTitleHindi ?? currentIntent.categoryTitleEnglish ?? 'सेवा',
          subtitle: '⚡ AI स्मार्ट मैच (बेस्ट सेवा)',
          categoryId: currentIntent.categoryId,
          categoryName: currentIntent.categoryTitleHindi,
          tradeType: currentIntent.categoryTitleEnglish,
          searchQuery: currentIntent.categoryTitleHindi ?? query,
          intent: currentIntent,
        ),
      );
    }

    // C. Search Categories by Name (Hindi + English)
    for (final cat in availableCategories) {
      if (!cat.isActive) continue;
      final hi = cat.titleHindi.toLowerCase();
      final en = cat.titleEnglish.toLowerCase();

      if (hi.contains(cleanQuery) || en.contains(cleanQuery) || _isFuzzyMatch(cleanQuery, en) || _isFuzzyMatch(cleanQuery, hi)) {
        addSuggestion(
          SearchSuggestionItem(
            title: cat.titleHindi,
            subtitle: 'मुख्य श्रेणी • ${cat.titleEnglish}',
            categoryId: cat.id,
            categoryName: cat.titleHindi,
            tradeType: cat.titleEnglish,
            searchQuery: cat.titleHindi,
          ),
        );
      }
    }

    // D. Search Sub-Services & Common Problems
    for (final cat in availableCategories) {
      if (!cat.isActive) continue;

      for (final sub in cat.subServices) {
        final subLower = sub.toLowerCase();
        if (subLower.contains(cleanQuery) || _isFuzzyMatch(cleanQuery, subLower)) {
          addSuggestion(
            SearchSuggestionItem(
              title: sub,
              subtitle: 'सेवा • ${cat.titleHindi}',
              categoryId: cat.id,
              categoryName: cat.titleHindi,
              tradeType: cat.titleEnglish,
              searchQuery: sub,
            ),
          );
        }
      }

      for (final prob in cat.commonProblems) {
        final probLower = prob.toLowerCase();
        if (probLower.contains(cleanQuery) || _isFuzzyMatch(cleanQuery, probLower)) {
          addSuggestion(
            SearchSuggestionItem(
              title: prob,
              subtitle: 'समस्या समाधान • ${cat.titleHindi}',
              categoryId: cat.id,
              categoryName: cat.titleHindi,
              tradeType: cat.titleEnglish,
              searchQuery: prob,
            ),
          );
        }
      }
    }

    // E. Search Domain Trade Keywords
    for (final entry in _tradeKeywords.entries) {
      for (final kw in entry.value) {
        if (kw.toLowerCase().contains(cleanQuery) || _isFuzzyMatch(cleanQuery, kw.toLowerCase())) {
          final matchedCat = _findCategoryForTrade(entry.key, availableCategories);
          if (matchedCat != null) {
            addSuggestion(
              SearchSuggestionItem(
                title: kw,
                subtitle: 'सुझाव • ${matchedCat.titleHindi}',
                categoryId: matchedCat.id,
                categoryName: matchedCat.titleHindi,
                tradeType: matchedCat.titleEnglish,
                searchQuery: kw,
              ),
            );
          }
        }
      }
    }

    return suggestions;
  }

  static bool _isFuzzyMatch(String query, String target) {
    if (query.length < 3 || target.length < 3) return false;
    final dist = _levenshteinDistance(query, target);
    if (query.length <= 4 && dist <= 1) return true;
    if (query.length > 4 && dist <= 2) return true;
    return false;
  }

  /// Typo and Phonetic Dictionary Mapper for Hinglish/Hindi
  static SearchSuggestionItem? _checkTypoCorrection(
    String query,
    List<ServiceCategoryEntity> categories,
  ) {
    const typoDictionary = {
      // Electrician typos
      'bijli': 'electrician', 'bigli': 'electrician', 'bijlee': 'electrician', 'bijly': 'electrician',
      'electrisian': 'electrician', 'electisian': 'electrician', 'electrican': 'electrician', 'elec': 'electrician',
      'panka': 'electrician', 'fan': 'electrician', 'fann': 'electrician', 'pankha': 'electrician',
      'swich': 'electrician', 'bord': 'electrician', 'wairing': 'electrician', 'viring': 'electrician',
      'inwarter': 'electrician', 'invator': 'electrician', 'invartar': 'electrician',
      
      // Plumber typos
      'palmar': 'plumber', 'plambr': 'plumber', 'plambrr': 'plumber', 'plimbr': 'plumber', 'palambar': 'plumber',
      'palambhar': 'plumber', 'nalwala': 'plumber', 'nalmistri': 'plumber', 'nal': 'plumber', 'pipe': 'plumber',
      'tanki': 'plumber', 'leakege': 'plumber', 'likage': 'plumber', 'panikotanki': 'plumber',

      // Appliance / AC / Fridge typos
      'a c': 'appliance', 'ac': 'appliance', 'frij': 'appliance', 'fridge': 'appliance', 'fridg': 'appliance',
      'refrijerator': 'appliance', 'wasinmasin': 'appliance', 'washing': 'appliance', 'coler': 'appliance',
      'kooler': 'appliance', 'cooler': 'appliance',

      // Carpenter typos
      'carpanter': 'carpenter', 'karpanter': 'carpenter', 'carpentar': 'carpenter', 'barhai': 'carpenter',
      'badhai': 'carpenter', 'darwaja': 'carpenter', 'darwaza': 'carpenter', 'khidki': 'carpenter', 'palang': 'carpenter',

      // Painter typos
      'pentar': 'painter', 'penter': 'painter', 'paintar': 'painter', 'rangwala': 'painter', 'putti': 'painter',
      'rangai': 'painter', 'chuna': 'painter',

      // Cleaning typos
      'safai': 'cleaning', 'safaiwala': 'cleaning', 'jhadu': 'cleaning', 'pocha': 'cleaning', 'clen': 'cleaning',
      'clining': 'cleaning', 'clean': 'cleaning',

      // RO / Water purifier
      'aquadart': 'ro', 'aquaguard': 'ro', 'waterfilter': 'ro', 'filter': 'ro', 'purifier': 'ro',
    };

    // Check direct typo dictionary
    for (final entry in typoDictionary.entries) {
      if (query == entry.key || _isFuzzyMatch(query, entry.key)) {
        final matchedCat = _findCategoryForTrade(entry.value, categories);
        if (matchedCat != null) {
          return SearchSuggestionItem(
            title: matchedCat.titleHindi,
            subtitle: 'क्या आप ढूंढ रहे हैं: "${matchedCat.titleHindi} (${matchedCat.titleEnglish})"?',
            categoryId: matchedCat.id,
            categoryName: matchedCat.titleHindi,
            tradeType: matchedCat.titleEnglish,
            searchQuery: matchedCat.titleHindi,
            isTypoCorrection: true,
          );
        }
      }
    }

    return null;
  }

  static ServiceCategoryEntity? _findCategoryForTrade(
    String tradeKey,
    List<ServiceCategoryEntity> categories,
  ) {
    for (final cat in categories) {
      if (!cat.isActive) continue;
      final en = cat.titleEnglish.toLowerCase();
      final hi = cat.titleHindi.toLowerCase();

      if (tradeKey == 'electrician' && (en.contains('electr') || hi.contains('बिजली') || hi.contains('इलेक्ट्रीशियन'))) return cat;
      if (tradeKey == 'plumber' && (en.contains('plumb') || hi.contains('नल') || hi.contains('प्लंबर'))) return cat;
      if (tradeKey == 'appliance' && (en.contains('appliance') || en.contains('ac') || hi.contains('एसी') || hi.contains('उपकरण'))) return cat;
      if (tradeKey == 'carpenter' && (en.contains('carpent') || hi.contains('बढ़ई') || hi.contains('लकड़ी'))) return cat;
      if (tradeKey == 'painter' && (en.contains('paint') || hi.contains('पेंट'))) return cat;
      if (tradeKey == 'cleaning' && (en.contains('clean') || hi.contains('सफाई'))) return cat;
      if (tradeKey == 'ro' && (en.contains('ro') || en.contains('water') || hi.contains('वाटर') || hi.contains('आरओ'))) return cat;
    }
    return null;
  }

  static List<SearchSuggestionItem> _getTrendingSuggestions(
    List<ServiceCategoryEntity> categories,
  ) {
    final List<SearchSuggestionItem> trending = [];
    final popularKeys = [
      {'trade': 'electrician', 'fallbackHi': 'इलेक्ट्रीशियन', 'sub': 'पंखा, वायरिंग, स्विच, इन्वर्टर'},
      {'trade': 'plumber', 'fallbackHi': 'प्लंबर मिस्त्री', 'sub': 'नल, पाइप, पानी टंकी रिपेयर'},
      {'trade': 'appliance', 'fallbackHi': 'एसी & फ्रिज रिपेयर', 'sub': 'एसी सर्विस, फ्रिज कूलिंग'},
      {'trade': 'carpenter', 'fallbackHi': 'बढ़ई / कारपेंटर', 'sub': 'दरवाजा, खिड़की, फर्नीचर'},
      {'trade': 'painter', 'fallbackHi': 'पेंटर & पुट्टी', 'sub': 'घर की रंगाई, वॉल पुट्टी'},
      {'trade': 'cleaning', 'fallbackHi': 'घर की डीप सफाई', 'sub': 'बाथरूम, किचन, सोफा सफाई'},
    ];

    for (final item in popularKeys) {
      final cat = _findCategoryForTrade(item['trade']!, categories);
      trending.add(
        SearchSuggestionItem(
          title: cat?.titleHindi ?? item['fallbackHi']!,
          subtitle: item['sub']!,
          categoryId: cat?.id,
          categoryName: cat?.titleHindi,
          tradeType: item['trade'],
          searchQuery: cat?.titleHindi ?? item['fallbackHi']!,
          isTrending: true,
        ),
      );
    }
    return trending;
  }

  /// Built-in Domain Knowledge dictionary for trade categories in Hindi / Hinglish / English
  static const Map<String, List<String>> _tradeKeywords = {
    'electrician': [
      'pankha', 'fan', 'light', 'bijli', 'current', 'switch', 'board', 'wiring', 'fuse',
      'inverter', 'motor', 'bulb', 'mcb', 'heater', 'cooler', 'short circuit', 'stabilizer',
      'पंखा', 'बिजली', 'लाइट', 'स्विच', 'बोर्ड', 'वायरिंग', 'फ्यूज', 'इनवर्टर', 'मोटर',
      'बल्ब', 'एमसीबी', 'हीटर', 'कूलर', 'करंट', 'शॉर्ट सर्किट', 'स्टेबलाइजर',
    ],
    'plumber': [
      'nal', 'tap', 'pani', 'water', 'pipe', 'leakage', 'tanki', 'tank', 'motor',
      'basin', 'commode', 'toilet', 'shower', 'drainage', 'geyser', 'nali', 'sewer',
      'नल', 'पानी', 'पाइप', 'लीक', 'लीकेज', 'टंकी', 'मोटर', 'बेसिन', 'कमोड',
      'टॉयलेट', 'शावर', 'ड्रेनेज', 'नाली', 'गीजर', 'सीवर',
    ],
    'appliance': [
      'ac', 'fridge', 'refrigerator', 'washing machine', 'gas', 'cooling', 'compressor', 'oven', 'tv',
      'एसी', 'फ्रिज', 'वाशिंग मशीन', 'गैस', 'कूलिंग', 'कंप्रेसर', 'ओवन', 'टीवी',
    ],
    'carpenter': [
      'lakdi', 'wood', 'darwaja', 'door', 'khidki', 'window', 'bed', 'sofa', 'almirah', 'furniture', 'tala', 'lock',
      'लकड़ी', 'दरवाजा', 'खिड़की', 'बेड', 'सोफा', 'अलमारी', 'फर्नीचर', 'ताला', 'बढ़ई',
    ],
    'painter': [
      'paint', 'putty', 'rang', 'wall', 'colour', 'color',
      'पेंट', 'पुट्टी', 'रंग', 'दीवार', 'कलर', 'पेंटर',
    ],
    'cleaning': [
      'safai', 'cleaning', 'jhadu', 'pocha', 'kachra', 'deep cleaning',
      'सफाई', 'झाड़ू', 'पोछा', 'क्लीनिंग', 'कचरा',
    ],
  };

  /// Direct match check against live category titles & sub-services
  static AISearchIntentEntity? _checkDirectCategoryMatch(
    String query,
    List<ServiceCategoryEntity> categories,
  ) {
    final qLower = query.toLowerCase();

    for (final cat in categories) {
      if (!cat.isActive) continue;

      final titleHi = cat.titleHindi.toLowerCase();
      final titleEn = cat.titleEnglish.toLowerCase();

      // Exact category title match
      if (qLower == titleHi || qLower == titleEn) {
        return AISearchIntentEntity(
          intentType: AISearchIntentType.serviceSearch,
          categoryId: cat.id,
          categoryTitleHindi: cat.titleHindi,
          categoryTitleEnglish: cat.titleEnglish,
          extractedProblem: query,
          confidence: 1.0,
          suggestedSubServices: cat.subServices,
        );
      }

      // Check sub-services exact match
      for (final sub in cat.subServices) {
        if (qLower == sub.toLowerCase()) {
          return AISearchIntentEntity(
            intentType: AISearchIntentType.serviceSearch,
            categoryId: cat.id,
            categoryTitleHindi: cat.titleHindi,
            categoryTitleEnglish: cat.titleEnglish,
            serviceTitle: sub,
            extractedProblem: sub,
            confidence: 0.95,
            suggestedSubServices: cat.subServices,
          );
        }
      }
    }

    return null;
  }


  /// Local dynamic semantic intent matcher over real Firestore categories & subservices
  static AISearchIntentEntity _matchLocallyAgainstRealCategories({
    required String query,
    required List<ServiceCategoryEntity> availableCategories,
    String? preferredArea,
  }) {
    final qLower = query.toLowerCase();

    // Hindi & English generic stop words that should not trigger category matches
    const stopWords = {
      'wala', 'wali', 'wale', 'banane', 'banao', 'chahiye', 'karna', 'karo', 'karwana',
      'hai', 'hain', 'ho', 'tha', 'thi', 'the', 'ko', 'ka', 'ki', 'ke', 'se', 'me', 'mein',
      'par', 'kuch', 'bhi', 'mera', 'meri', 'mere', 'apna', 'apni', 'kisko', 'kahan',
      'need', 'want', 'require', 'please', 'help', 'service', 'mistri', 'repair',
      'theek', 'thik', 'kar', 'kardo', 'jaldi', 'urgent', 'mujhe', 'mujhko', 'kaam',
      'kuchh', 'काम', 'कुछ', 'मदद', 'चाहिए', 'करवाना', 'है', 'मेरे', 'घर', 'ghar',
    };

    final tokens = RegExp(r'[\w\u0900-\u097F]+')
        .allMatches(qLower)
        .map((m) => m.group(0)!)
        .where((t) => t.length >= 2 && !stopWords.contains(t))
        .toList();

    // Ambiguity check: e.g. "मुझे कुछ काम करवाना है"
    final genericPhrases = [
      'kuch kaam',
      'kaam karwana hai',
      'help chahiye',
      'service chahiye',
      'कुछ काम',
      'काम करवाना है',
      'मदद चाहिए',
      'काम है',
      'kaam hai',
    ];
    final isGeneric = genericPhrases.any((p) => qLower.contains(p)) && tokens.isEmpty;
    if (isGeneric) {
      return const AISearchIntentEntity(
        intentType: AISearchIntentType.clarificationRequired,
        confidence: 0.30,
        clarificationMessage: 'आप किस तरह की service चाहते हैं? कृपया श्रेणी चुनें।',
      );
    }

    if (tokens.isEmpty) {
      return AISearchIntentEntity(
        intentType: AISearchIntentType.noMatch,
        confidence: 0.0,
        clarificationMessage: '“$query” से संबंधित सेवा अभी उपलब्ध नहीं है।',
      );
    }

    ServiceCategoryEntity? bestCategory;
    String? bestSubService;
    double maxScore = 0.0;
    List<String> matchedKeywords = [];

    for (final cat in availableCategories) {
      if (!cat.isActive) continue;

      double score = 0.0;
      final catTitleEn = cat.titleEnglish.toLowerCase();
      final catTitleHi = cat.titleHindi.toLowerCase();

      // Exact substring match in category title
      if (qLower.contains(catTitleHi) || qLower.contains(catTitleEn)) {
        score += 0.85;
        matchedKeywords.add(cat.titleHindi);
      }

      // Check trade domain knowledge dictionary
      for (final entry in _tradeKeywords.entries) {
        final isElectricianCat = entry.key == 'electrician' &&
            (catTitleEn.contains('electr') || catTitleEn.contains('bijli') || catTitleHi.contains('इलेक्ट्रीशियन') || catTitleHi.contains('बिजली'));
        final isPlumberCat = entry.key == 'plumber' &&
            (catTitleEn.contains('plumb') || catTitleEn.contains('plimb') || catTitleHi.contains('plimb') || catTitleHi.contains('प्लंबर') || catTitleHi.contains('नल') || catTitleEn.contains('pipe'));
        final isApplianceCat = entry.key == 'appliance' &&
            (catTitleEn.contains('appliance') || catTitleEn.contains('ac') || catTitleHi.contains('एसी') || catTitleHi.contains('फ्रिज'));
        final isCarpenterCat = entry.key == 'carpenter' &&
            (catTitleEn.contains('carpent') || catTitleHi.contains('बढ़ई') || catTitleEn.contains('wood'));
        final isPainterCat = entry.key == 'painter' &&
            (catTitleEn.contains('paint') || catTitleHi.contains('पेंट') || catTitleHi.contains('पुट्टी') || catTitleHi.contains('रंग'));
        final isCleaningCat = entry.key == 'cleaning' &&
            (catTitleEn.contains('clean') || catTitleHi.contains('सफाई'));
        final isMechanicCat = entry.key == 'mechanic' &&
            (catTitleEn.contains('mechanic') || catTitleEn.contains('bike') || catTitleEn.contains('car') || catTitleHi.contains('मैकेनिक') || catTitleHi.contains('बाइक') || catTitleHi.contains('कार'));

        if (catTitleEn.contains(entry.key) || catTitleHi.contains(entry.key) ||
            isElectricianCat || isPlumberCat || isApplianceCat || isCarpenterCat || isPainterCat || isCleaningCat || isMechanicCat) {
          for (final kw in entry.value) {
            final kwLower = kw.toLowerCase();
            if (tokens.contains(kwLower) || (kwLower.length >= 4 && qLower.contains(kwLower))) {
              score += 0.85;
              matchedKeywords.add(kw);
              bestSubService ??= kw;
              break;
            }
          }
        }
      }

      // Check sub-services
      for (final sub in cat.subServices) {
        final subLower = sub.toLowerCase();
        if (qLower.contains(subLower)) {
          score += 0.75;
          bestSubService = sub;
          matchedKeywords.add(sub);
        } else {
          for (final token in tokens) {
            if (token.length >= 3 && (subLower.contains(token) || _isFuzzyMatch(token, subLower))) {
              score += 0.55;
              bestSubService = sub;
              matchedKeywords.add(token);
            }
          }
        }
      }

      // Check common problems
      for (final prob in cat.commonProblems) {
        final probLower = prob.toLowerCase();
        if (qLower.contains(probLower)) {
          score += 0.70;
          matchedKeywords.add(prob);
        } else {
          for (final token in tokens) {
            if (token.length >= 3 && (probLower.contains(token) || _isFuzzyMatch(token, probLower))) {
              score += 0.50;
              matchedKeywords.add(token);
            }
          }
        }
      }

      // Token overlap with title (only for meaningful non-stopwords >= 3 chars)
      for (final token in tokens) {
        if (token.length >= 3) {
          if (catTitleHi.contains(token) || catTitleEn.contains(token) || _isFuzzyMatch(token, catTitleEn) || _isFuzzyMatch(token, catTitleHi)) {
            score += 0.45;
            matchedKeywords.add(token);
          }
        }
      }

      if (score > maxScore) {
        maxScore = score;
        bestCategory = cat;
      }
    }

    final confidence = (maxScore).clamp(0.0, 1.0);

    if (bestCategory != null && confidence >= suggestionThreshold) {
      final isDirect = confidence >= directMatchThreshold;
      return AISearchIntentEntity(
        intentType: isDirect ? AISearchIntentType.serviceSearch : AISearchIntentType.serviceSearch,
        categoryId: bestCategory.id,
        categoryTitleHindi: bestCategory.titleHindi,
        categoryTitleEnglish: bestCategory.titleEnglish,
        serviceTitle: bestSubService,
        extractedProblem: query,
        extractedArea: preferredArea,
        confidence: confidence,
        suggestedSubServices: bestCategory.subServices,
        clarificationMessage: !isDirect ? 'क्या आप ${bestCategory.titleHindi} सेवा ढूंढ रहे हैं?' : null,
      );
    }

    return AISearchIntentEntity(
      intentType: AISearchIntentType.noMatch,
      confidence: 0.0,
      clarificationMessage: '“$query” से संबंधित सेवा अभी जमुई में उपलब्ध नहीं है।',
    );
  }

  static bool categoriesContainTokens(List<String> tokens, List<ServiceCategoryEntity> categories) {
    for (final cat in categories) {
      for (final token in tokens) {
        if (cat.titleHindi.toLowerCase().contains(token) ||
            cat.titleEnglish.toLowerCase().contains(token) ||
            cat.subServices.any((s) => s.toLowerCase().contains(token))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Validation Layer: Ensures returned category exists in live Firestore active categories
  static AISearchIntentEntity? _validateIntentResult(
    AISearchIntentEntity result,
    List<ServiceCategoryEntity> availableCategories,
  ) {
    if (result.categoryId == null) return result;

    final exists = availableCategories.any((c) => c.id == result.categoryId && c.isActive);
    if (exists) {
      final matchedCat = availableCategories.firstWhere((c) => c.id == result.categoryId);
      return AISearchIntentEntity(
        intentType: result.intentType,
        categoryId: matchedCat.id,
        categoryTitleHindi: matchedCat.titleHindi,
        categoryTitleEnglish: matchedCat.titleEnglish,
        serviceId: result.serviceId,
        serviceTitle: result.serviceTitle,
        extractedProblem: result.extractedProblem,
        extractedArea: result.extractedArea,
        isUrgent: result.isUrgent,
        confidence: result.confidence,
        suggestedSubServices: matchedCat.subServices.isNotEmpty
            ? matchedCat.subServices
            : result.suggestedSubServices,
        clarificationMessage: result.clarificationMessage,
      );
    }

    // Invalid/hallucinated category ID returned -> reject
    return null;
  }
}
