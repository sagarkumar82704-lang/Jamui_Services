import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/service_category_entity.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_event.dart';
import '../bloc/discovery_state.dart';
import '../pages/customer_search_page.dart';
import 'voice_search_bottom_sheet.dart';

class AISmartSearchBar extends StatelessWidget {
  final String hintText;

  const AISmartSearchBar({
    super.key,
    this.hintText = 'सेवा या कारीगर खोजें...',
  });

  void _openDedicatedSearchPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DiscoveryBloc>(),
          child: const CustomerSearchPage(),
        ),
      ),
    );
  }

  void _clearActiveSearch(BuildContext context) {
    context.read<DiscoveryBloc>().add(const SearchProvidersEvent(''));
    context.read<DiscoveryBloc>().add(const SelectCategoryFilterEvent('all'));
  }

  void _openVoiceSearch(BuildContext context, List<ServiceCategoryEntity> categories) {
    VoiceSearchBottomSheet.show(
      context,
      availableCategories: categories,
      onSearchSelected: (spokenText, intent) {
        final query = spokenText.trim();
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscoveryBloc, DiscoveryState>(
      builder: (context, state) {
        final categories = state is DiscoveryLoaded ? state.categories : <ServiceCategoryEntity>[];
        final activeQuery = state is DiscoveryLoaded && state.searchQuery.isNotEmpty ? state.searchQuery : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Box Shell (Flipkart / Amazon Style Launchpad)
            InkWell(
              onTap: () => _openDedicatedSearchPage(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: activeQuery != null
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Search Icon / Sparkle
                    const Padding(
                      padding: EdgeInsets.only(left: 14, right: 8),
                      child: Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),

                    // Placeholder / Active query display
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          activeQuery != null
                              ? 'सर्च जारी है: "$activeQuery"'
                              : hintText,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: activeQuery != null ? AppColors.primary : Colors.grey.shade400,
                            fontWeight: activeQuery != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // Clear button if active query is set
                    if (activeQuery != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                        tooltip: 'हटाएं (Clear)',
                        onPressed: () => _clearActiveSearch(context),
                      ),

                    // Voice Search Microphone Button
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 22),
                        tooltip: 'बोलकर खोजें (Voice Search)',
                        onPressed: () => _openVoiceSearch(context, categories),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Active Search Chip Banner (When search query is active on Home)
            if (activeQuery != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_alt_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'खोजा गया: "$activeQuery"',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _clearActiveSearch(context),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
