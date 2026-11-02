import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ai_search_intent_service.dart';
import '../../domain/entities/ai_search_intent_entity.dart';
import '../../domain/entities/service_category_entity.dart';
import '../../domain/entities/service_provider_entity.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_event.dart';
import '../bloc/discovery_state.dart';
import '../../../../core/widgets/provider_category_badge.dart';
import '../widgets/favourite_button.dart';
import '../widgets/voice_search_bottom_sheet.dart';
import 'provider_details_page.dart';

class CustomerSearchPage extends StatefulWidget {
  final String? initialQuery;

  const CustomerSearchPage({super.key, this.initialQuery});

  @override
  State<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends State<CustomerSearchPage> {
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  Timer? _debounceTimer;
  Timer? _searchDebounceTimer;
  bool _isAiProcessing = false;
  AISearchIntentEntity? _liveAiIntent;
  List<SearchSuggestionItem> _suggestions = [];
  String? _activeSubmittedQuery;
  String _activeResultFilter = 'all'; // 'all', 'top_rated', 'verified'

  // Stored Recent Searches (populated only from real user searches)
  static final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _focusNode = FocusNode();

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _activeSubmittedQuery = widget.initialQuery;
    } else {
      // Auto focus search field when opening search page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query, List<ServiceCategoryEntity> categories) {
    final clean = query.trim();

    // 0ms instant local fuzzy suggestions
    final newSuggestions = AISearchIntentService.getLiveSuggestions(
      query: clean,
      availableCategories: categories,
      currentIntent: _liveAiIntent,
    );

    setState(() {
      _suggestions = newSuggestions;
      if (clean.isEmpty) {
        _activeSubmittedQuery = null;
        _liveAiIntent = null;
        _isAiProcessing = false;
      }
    });

    // 400ms debounce for Provider Search + Skip if query length is less than 2 characters
    _searchDebounceTimer?.cancel();
    if (clean.isEmpty) {
      // Reset search immediately when cleared
      context.read<DiscoveryBloc>().add(const SearchProvidersEvent(''));
    } else if (clean.length < 2) {
      // Under 2 characters: DO NOT execute unnecessary provider search query
      // (saves duplicate expensive Firestore reads on 1-character typing)
    } else {
      // 2 or more characters: apply 400ms debounce
      _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        context.read<DiscoveryBloc>().add(SearchProvidersEvent(clean));
      });
    }

    _debounceTimer?.cancel();
    if (clean.length >= 3) {
      _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
        if (!mounted) return;
        setState(() => _isAiProcessing = true);

        final intent = await AISearchIntentService.extractIntent(
          query: clean,
          availableCategories: categories,
        );

        if (mounted) {
          final updatedSuggestions = AISearchIntentService.getLiveSuggestions(
            query: clean,
            availableCategories: categories,
            currentIntent: intent,
          );

          setState(() {
            _liveAiIntent = intent;
            _suggestions = updatedSuggestions;
            _isAiProcessing = false;
          });

          if (intent.isDirectMatch && intent.categoryId != null) {
            context.read<DiscoveryBloc>().add(
                  ApplyAISearchIntentEvent(query: clean, intent: intent),
                );
          }
        }
      });
    }
  }

  Future<void> _submitSearch(String query, List<ServiceCategoryEntity> categories) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    if (clean.length < 2) return;

    _searchDebounceTimer?.cancel();
    _debounceTimer?.cancel();

    _addRecentSearch(clean);
    _focusNode.unfocus();

    setState(() {
      _activeSubmittedQuery = clean;
      _isAiProcessing = true;
    });

    final intent = await AISearchIntentService.extractIntent(
      query: clean,
      availableCategories: categories,
    );

    if (!mounted) return;

    setState(() {
      _liveAiIntent = intent;
      _isAiProcessing = false;
    });

    if (intent.categoryId != null && intent.intentType != AISearchIntentType.noMatch) {
      context.read<DiscoveryBloc>().add(
            ApplyAISearchIntentEvent(query: clean, intent: intent),
          );
    } else {
      context.read<DiscoveryBloc>().add(SearchProvidersEvent(clean));
    }
  }

  void _applySuggestion(SearchSuggestionItem item) {
    _searchDebounceTimer?.cancel();
    _debounceTimer?.cancel();
    _addRecentSearch(item.searchQuery);
    _searchController.text = item.searchQuery;
    _focusNode.unfocus();

    setState(() {
      _activeSubmittedQuery = item.searchQuery;
      _liveAiIntent = item.intent;
      _isAiProcessing = false;
    });

    if (item.categoryId != null) {
      context.read<DiscoveryBloc>().add(SelectCategoryFilterEvent(item.categoryId!));
      if (item.intent != null) {
        context.read<DiscoveryBloc>().add(
              ApplyAISearchIntentEvent(query: item.searchQuery, intent: item.intent!),
            );
      }
    } else if (item.searchQuery.trim().length >= 2) {
      context.read<DiscoveryBloc>().add(SearchProvidersEvent(item.searchQuery.trim()));
    }
  }

  void _addRecentSearch(String term) {
    if (!_recentSearches.contains(term)) {
      _recentSearches.insert(0, term);
      if (_recentSearches.length > 8) {
        _recentSearches.removeLast();
      }
    }
  }

  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _activeSubmittedQuery = null;
      _liveAiIntent = null;
      _suggestions.clear();
      _isAiProcessing = false;
    });
    context.read<DiscoveryBloc>().add(const SearchProvidersEvent(''));
    context.read<DiscoveryBloc>().add(const SelectCategoryFilterEvent('all'));
    _focusNode.requestFocus();
  }

  void _openVoiceSearch(BuildContext context, List<ServiceCategoryEntity> categories) {
    VoiceSearchBottomSheet.show(
      context,
      availableCategories: categories,
      onSearchSelected: (spokenText, intent) {
        final query = spokenText.trim();
        _searchController.text = query;
        _addRecentSearch(query);
        _focusNode.unfocus();

        setState(() {
          _activeSubmittedQuery = query;
          _liveAiIntent = intent;
        });

        if (intent != null && intent.categoryId != null) {
          context.read<DiscoveryBloc>().add(
                ApplyAISearchIntentEvent(query: query, intent: intent),
              );
        } else {
          context.read<DiscoveryBloc>().add(SearchProvidersEvent(query));
        }
      },
    );
  }

  IconData _getTradeIcon(String? tradeType, String title) {
    final t = (tradeType ?? title).toLowerCase();
    if (t.contains('electr') || t.contains('बिजली') || t.contains('पंखा')) {
      return Icons.bolt_rounded;
    } else if (t.contains('plumb') || t.contains('नल') || t.contains('पाइप') || t.contains('पानी')) {
      return Icons.plumbing_rounded;
    } else if (t.contains('ac') || t.contains('एसी') || t.contains('फ्रिज') || t.contains('appliance')) {
      return Icons.ac_unit_rounded;
    } else if (t.contains('carpent') || t.contains('बढ़ई') || t.contains('लकड़ी') || t.contains('फर्नीचर')) {
      return Icons.carpenter_rounded;
    } else if (t.contains('paint') || t.contains('पेंट') || t.contains('रंग')) {
      return Icons.format_paint_rounded;
    } else if (t.contains('clean') || t.contains('सफाई') || t.contains('झाड़ू')) {
      return Icons.cleaning_services_rounded;
    } else if (t.contains('ro') || t.contains('water') || t.contains('filter')) {
      return Icons.water_drop_rounded;
    }
    return Icons.search_rounded;
  }

  Color _getTradeColor(String? tradeType, String title) {
    final t = (tradeType ?? title).toLowerCase();
    if (t.contains('electr') || t.contains('बिजली') || t.contains('पंखा')) {
      return Colors.amber.shade700;
    } else if (t.contains('plumb') || t.contains('नल') || t.contains('पाइप') || t.contains('पानी')) {
      return Colors.blue.shade600;
    } else if (t.contains('ac') || t.contains('एसी') || t.contains('फ्रिज') || t.contains('appliance')) {
      return Colors.cyan.shade700;
    } else if (t.contains('carpent') || t.contains('बढ़ई') || t.contains('लकड़ी') || t.contains('फर्नीचर')) {
      return Colors.brown.shade600;
    } else if (t.contains('paint') || t.contains('पेंट') || t.contains('रंग')) {
      return Colors.purple.shade600;
    } else if (t.contains('clean') || t.contains('सफाई') || t.contains('झाड़ू')) {
      return Colors.teal.shade600;
    } else if (t.contains('ro') || t.contains('water') || t.contains('filter')) {
      return Colors.indigo.shade600;
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscoveryBloc, DiscoveryState>(
      builder: (context, state) {
        final categories = state is DiscoveryLoaded ? state.categories : <ServiceCategoryEntity>[];
        final rawProviders = state is DiscoveryLoaded ? state.providers : <ServiceProviderEntity>[];

        // Filter search results
        final filteredProviders = rawProviders.where((p) {
          if (_activeResultFilter == 'top_rated') return p.rating >= 4.0;
          if (_activeResultFilter == 'verified') return p.isVerified;
          return true;
        }).toList();

        // Maintain nearest-first order when location distance is available
        if (filteredProviders.any((p) => p.distanceKm != null)) {
          filteredProviders.sort((a, b) {
            final distA = a.distanceKm ?? double.infinity;
            final distB = b.distanceKm ?? double.infinity;
            final cmp = distA.compareTo(distB);
            if (cmp != 0) return cmp;
            return b.rating.compareTo(a.rating);
          });
        }

        final hasQuery = _searchController.text.trim().isNotEmpty;
        final hasActiveSearch = _activeSubmittedQuery != null && _activeSubmittedQuery!.isNotEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(74),
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 10,
                left: 12,
                right: 12,
              ),
              child: Row(
                children: [
                  // Back Button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Search Capsule Input Bar
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _focusNode.hasFocus ? AppColors.primary : Colors.grey.shade200,
                          width: _focusNode.hasFocus ? 1.6 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12, right: 8),
                            child: _isAiProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : Icon(
                                    _focusNode.hasFocus ? Icons.auto_awesome : Icons.search_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                          ),

                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              onChanged: (val) => _onQueryChanged(val, categories),
                              textInputAction: TextInputAction.search,
                              onSubmitted: (val) => _submitSearch(val, categories),
                              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'सेवा या कारीगर खोजें...',
                                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),

                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                              onPressed: _clearSearch,
                            ),

                          // Voice Search Button
                          IconButton(
                            icon: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 21),
                            tooltip: 'बोलकर खोजें',
                            onPressed: () => _openVoiceSearch(context, categories),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: _buildSearchBody(context, categories, filteredProviders, hasQuery, hasActiveSearch),
        );
      },
    );
  }

  Widget _buildSearchBody(
    BuildContext context,
    List<ServiceCategoryEntity> categories,
    List<ServiceProviderEntity> providers,
    bool hasQuery,
    bool hasActiveSearch,
  ) {
    // 1. If user is actively typing and suggestions exist (Amazon/Flipkart Live Dropdown View)
    if (_focusNode.hasFocus && hasQuery && _suggestions.isNotEmpty) {
      return _buildLiveSuggestionsView(context, _suggestions);
    }

    // 2. If user has submitted or selected a search -> Show Provider Results List
    if (hasActiveSearch || (hasQuery && !_focusNode.hasFocus)) {
      return _buildSearchResultsView(context, providers, categories);
    }

    // 3. Initial Empty State: Recent Searches + Trending in Jamui + Common Problems
    return _buildInitialExploreView(context, categories);
  }

  /// Initial Explore View (When nothing is typed yet)
  Widget _buildInitialExploreView(BuildContext context, List<ServiceCategoryEntity> categories) {
    final activeCategories = categories.where((c) => c.isActive).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Recent Searches (Only shown if user has actually searched something)
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 6),
                    Text(
                      'हाल ही में खोजी गई सेवाएं',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _recentSearches.clear());
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  child: const Text('साफ करें', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((term) {
                return InkWell(
                  onTap: () {
                    _searchController.text = term;
                    _submitSearch(term, categories);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 13, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          term,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // B. Real Active Categories from Firestore
          if (activeCategories.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.grid_view_rounded, size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'उपलब्ध सेवाएं व श्रेणियाँ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.3,
              ),
              itemCount: activeCategories.length,
              itemBuilder: (context, index) {
                final cat = activeCategories[index];
                final icon = _getTradeIcon(cat.titleEnglish, cat.titleHindi);
                final color = _getTradeColor(cat.titleEnglish, cat.titleHindi);

                return InkWell(
                  onTap: () {
                    _searchController.text = cat.titleHindi;
                    _focusNode.unfocus();
                    setState(() {
                      _activeSubmittedQuery = cat.titleHindi;
                      _liveAiIntent = AISearchIntentEntity(
                        intentType: AISearchIntentType.serviceSearch,
                        categoryId: cat.id,
                        categoryTitleHindi: cat.titleHindi,
                        categoryTitleEnglish: cat.titleEnglish,
                        confidence: 1.0,
                        suggestedSubServices: cat.subServices,
                      );
                    });
                    context.read<DiscoveryBloc>().add(
                          ApplyAISearchIntentEvent(
                            query: cat.titleHindi,
                            intent: AISearchIntentEntity(
                              intentType: AISearchIntentType.serviceSearch,
                              categoryId: cat.id,
                              categoryTitleHindi: cat.titleHindi,
                              categoryTitleEnglish: cat.titleEnglish,
                              confidence: 1.0,
                              suggestedSubServices: cat.subServices,
                            ),
                          ),
                        );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.titleHindi,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (cat.titleEnglish.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  cat.titleEnglish,
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.search_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'खोजने के लिए ऊपर टाइप करें या माइक दबाकर बोलें',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Live Suggestions Dropdown View (Flipkart / Amazon Style)
  Widget _buildLiveSuggestionsView(BuildContext context, List<SearchSuggestionItem> suggestions) {
    final typoItem = suggestions.where((s) => s.isTypoCorrection).firstOrNull;
    final otherSuggestions = suggestions.where((s) => !s.isTypoCorrection).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Typo Correction Banner
        if (typoItem != null) ...[
          InkWell(
            onTap: () => _applySuggestion(typoItem),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high_rounded, color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: 'क्या आप ढूंढ रहे हैं: ',
                        style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                        children: [
                          TextSpan(
                            text: typoItem.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Colors.amber.shade900,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          if (typoItem.tradeType != null)
                            TextSpan(
                              text: ' (${typoItem.tradeType})',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'चुनें',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Suggestions List Container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: otherSuggestions.map((item) {
              final icon = _getTradeIcon(item.tradeType, item.title);
              final color = _getTradeColor(item.tradeType, item.title);

              return InkWell(
                onTap: () => _applySuggestion(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 17),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle!,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.north_west_rounded, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Search Results View with Filter Chips & Provider Cards
  Widget _buildSearchResultsView(
    BuildContext context,
    List<ServiceProviderEntity> providers,
    List<ServiceCategoryEntity> categories,
  ) {
    return Column(
      children: [
        // Filter Header Strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${providers.length} कारीगर मिले',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Spacer(),
              _buildFilterChip('सभी', 'all'),
              const SizedBox(width: 6),
              _buildFilterChip('🌟 4.0+', 'top_rated'),
              const SizedBox(width: 6),
              _buildFilterChip('🛡️ सत्यापित', 'verified'),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 0.8),

        // Provider Cards List
        Expanded(
          child: providers.isEmpty
              ? _buildEmptyResultsState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    final p = providers[index];
                    return _buildProviderCard(context, p);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _activeResultFilter == value;
    return InkWell(
      onTap: () => setState(() => _activeResultFilter = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, ServiceProviderEntity provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<DiscoveryBloc>(),
                child: ProviderDetailsPage(provider: provider),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Zero-Network Category Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Text(
                        provider.fullName.isNotEmpty ? provider.fullName[0].toUpperCase() : 'P',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                provider.businessName.isNotEmpty ? provider.businessName : provider.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (provider.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: AppColors.primary, size: 16),
                            ],
                            const Spacer(),
                            FavouriteButton(
                              providerId: provider.id,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ProviderCategoryBadge(
                              categoryTitle: provider.resolvedCategoryTitle,
                              fontSize: 10,
                            ),
                            if (provider.experienceYears > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${provider.experienceYears} वर्ष अनुभव',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 3),
                            Text(
                              provider.rating > 0 ? provider.rating.toStringAsFixed(1) : 'नया',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                provider.jamuiArea.isNotEmpty ? provider.jamuiArea : 'जमुई',
                                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (provider.distanceKm != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 0.8),
                                ),
                                child: Text(
                                  provider.distanceKm! < 1.0
                                      ? '${(provider.distanceKm! * 1000).round()} m'
                                      : '${provider.distanceKm!.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 18, thickness: 0.6),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse('tel:${provider.phoneNumber}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      icon: const Icon(Icons.call, size: 15, color: AppColors.primary),
                      label: const Text('कॉल करें', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<DiscoveryBloc>(),
                              child: ProviderDetailsPage(provider: provider),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 15, color: Colors.white),
                      label: const Text('विवरण देखें', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyResultsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'कोई कारीगर नहीं मिला',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'कृपया अन्य कीवर्ड या श्रेणी से खोजें',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('सभी सेवाएं देखें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
