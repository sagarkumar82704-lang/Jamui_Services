import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/provider_filter_criteria.dart';

/// [ProviderAdvancedFilterBar] renders an expandable, responsive, and professional
/// filtering control panel for the Provider Directory in the Admin Panel.
class ProviderAdvancedFilterBar extends StatefulWidget {
  final ProviderFilterCriteria criteria;
  final ValueChanged<ProviderFilterCriteria> onCriteriaChanged;
  final VoidCallback onClearAll;
  final List<Map<String, dynamic>> availableCategories;
  final List<String> availableAreas;
  final int totalCount;
  final int filteredCount;
  final VoidCallback? onRefresh;

  const ProviderAdvancedFilterBar({
    super.key,
    required this.criteria,
    required this.onCriteriaChanged,
    required this.onClearAll,
    required this.availableCategories,
    required this.availableAreas,
    required this.totalCount,
    required this.filteredCount,
    this.onRefresh,
  });

  @override
  State<ProviderAdvancedFilterBar> createState() => _ProviderAdvancedFilterBarState();
}

class _ProviderAdvancedFilterBarState extends State<ProviderAdvancedFilterBar> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final criteria = widget.criteria;
    final hasFilters = criteria.hasActiveFilters;

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Toggle & Stats Bar (Responsive Layout)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              // Left: Title + Active filter count + Expand/Collapse toggle
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExpanded ? Icons.tune_rounded : Icons.filter_list_rounded,
                        size: 20,
                        color: hasFilters ? Colors.indigo : Colors.blueGrey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'उन्नत फ़िल्टर (Advanced Filters)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: hasFilters ? Colors.indigo.shade900 : Colors.blueGrey.shade800,
                        ),
                      ),
                      if (hasFilters) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${criteria.activeFiltersCount} सक्रिय',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Colors.blueGrey,
                      ),
                    ],
                  ),
                ),
              ),

              // Right: Live Result Count & Clear / Refresh actions
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Text(
                          'प्रदाता: ${widget.filteredCount} / कुल ${widget.totalCount}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onRefresh != null)
                    IconButton(
                      tooltip: 'रीलोड करें (Refresh)',
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.blueGrey),
                      onPressed: widget.onRefresh,
                    ),
                  if (hasFilters)
                    OutlinedButton.icon(
                      onPressed: widget.onClearAll,
                      icon: const Icon(Icons.clear_all_rounded, size: 16, color: Colors.red),
                      label: const Text('फ़िल्टर साफ़ करें (Clear All)', style: TextStyle(color: Colors.red, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Collapsible Filter Inputs Grid
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. Status Filter
                _buildDropdownContainer(
                  label: 'स्टेटस (Status)',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: criteria.status,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('सभी प्रदाता (All Providers)')),
                        DropdownMenuItem(value: 'pending_approval', child: Text('⏳ अनुमोदन लंबित (Pending Approval)')),
                        DropdownMenuItem(value: 'approved_active', child: Text('🟢 स्वीकृत / एक्टिव (Approved / Active)')),
                        DropdownMenuItem(value: 'rejected', child: Text('🔴 अस्वीकृत (Rejected)')),
                        DropdownMenuItem(value: 'suspended_blocked', child: Text('⛔ निलंबित / ब्लॉक (Suspended / Blocked)')),
                        DropdownMenuItem(value: 'inactive', child: Text('🟠 केवल निष्क्रिय (Inactive)')),
                        DropdownMenuItem(value: 'deleted', child: Text('🗑️ हटाए गए प्रदाता (Deleted)')),
                        DropdownMenuItem(value: 'all_with_deleted', child: Text('📋 संपूर्ण सूची (With Deleted)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          widget.onCriteriaChanged(criteria.copyWith(status: val));
                        }
                      },
                    ),
                  ),
                ),

                // 2. Category Filter (Real categories from Firestore categories collection)
                _buildDropdownContainer(
                  label: 'श्रेणी (Category)',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _isValidCategoryValue(criteria.categoryId) ? criteria.categoryId : 'all',
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w600),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('📂 सभी श्रेणियां (All Categories)')),
                        ...widget.availableCategories.map((c) {
                          final id = c['id'].toString();
                          final titleHindi = (c['titleHindi'] ?? c['name'] ?? '').toString();
                          final titleEng = (c['titleEnglish'] ?? c['slug'] ?? '').toString();
                          final bool isInactive = c['isDeleted'] == true || c['status'] == 'inactive' || c['isActive'] == false;

                          String label = titleHindi.isNotEmpty
                              ? (titleEng.isNotEmpty ? '$titleHindi ($titleEng)' : titleHindi)
                              : (titleEng.isNotEmpty ? titleEng : id);

                          if (isInactive) {
                            label = '$label [निष्क्रिय]';
                          }

                          return DropdownMenuItem(
                            value: id,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isInactive ? Colors.grey.shade600 : Colors.black87,
                                fontStyle: isInactive ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          String? catTitle;
                          if (val != 'all') {
                            final match = widget.availableCategories.cast<Map<String, dynamic>?>().firstWhere(
                                  (c) => c?['id'].toString() == val,
                                  orElse: () => null,
                                );
                            if (match != null) {
                              catTitle = (match['titleHindi'] ?? match['titleEnglish'] ?? match['name'])?.toString();
                            }
                          }
                          widget.onCriteriaChanged(criteria.copyWith(
                            categoryId: val,
                            categoryTitle: catTitle,
                          ));
                        }
                      },
                    ),
                  ),
                ),

                // 3. Location / Jamui Area Filter
                _buildDropdownContainer(
                  label: 'स्थान / क्षेत्र (Location)',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _isValidAreaValue(criteria.jamuiArea) ? criteria.jamuiArea : 'all',
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w600),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('📍 सभी क्षेत्र / ब्लॉक (All Areas)')),
                        ...widget.availableAreas.map((area) => DropdownMenuItem(
                              value: area,
                              child: Text(area),
                            )),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          widget.onCriteriaChanged(criteria.copyWith(jamuiArea: val));
                        }
                      },
                    ),
                  ),
                ),

                // 4. Coordinates / Radius Filter (Optional GPS Distance)
                _buildDropdownContainer(
                  label: 'GPS दायरा (Radius)',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<double?>(
                      value: criteria.radiusKm,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('🌐 कोई दूरी सीमा नहीं (Any Radius)')),
                        DropdownMenuItem(value: 5.0, child: Text('🎯 5 KM के अंदर (Within 5 KM)')),
                        DropdownMenuItem(value: 10.0, child: Text('🎯 10 KM के अंदर (Within 10 KM)')),
                        DropdownMenuItem(value: 25.0, child: Text('🎯 25 KM के अंदर (Within 25 KM)')),
                        DropdownMenuItem(value: 50.0, child: Text('🎯 50 KM के अंदर (Within 50 KM)')),
                      ],
                      onChanged: (val) {
                        widget.onCriteriaChanged(criteria.copyWith(
                          radiusKm: val,
                          clearRadius: val == null,
                        ));
                      },
                    ),
                  ),
                ),

                // 5. Date Filter (Registration createdAt)
                _buildDropdownContainer(
                  label: 'पंजीकरण दिनांक (Registered Date)',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: criteria.dateFilter,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w600),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('📅 सभी समय (All Time)')),
                        const DropdownMenuItem(value: 'today', child: Text('📅 आज (Today)')),
                        const DropdownMenuItem(value: 'last_7_days', child: Text('📅 पिछले 7 दिन (Last 7 Days)')),
                        const DropdownMenuItem(value: 'last_30_days', child: Text('📅 पिछले 30 दिन (Last 30 Days)')),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text(
                            criteria.customDateRange != null
                                ? '📅 ${DateFormat('dd MMM').format(criteria.customDateRange!.start)} - ${DateFormat('dd MMM').format(criteria.customDateRange!.end)}'
                                : '📅 कस्टम सीमा... (Custom Range)',
                          ),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val == null) return;
                        if (val == 'custom') {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                            initialDateRange: criteria.customDateRange ??
                                DateTimeRange(
                                  start: DateTime.now().subtract(const Duration(days: 14)),
                                  end: DateTime.now(),
                                ),
                          );
                          if (picked != null) {
                            widget.onCriteriaChanged(criteria.copyWith(
                              dateFilter: 'custom',
                              customDateRange: picked,
                            ));
                          }
                        } else {
                          widget.onCriteriaChanged(criteria.copyWith(
                            dateFilter: val,
                            clearCustomDateRange: true,
                          ));
                        }
                      },
                    ),
                  ),
                ),

                // 6. Subscription Filter
                _buildDropdownContainer(
                  label: 'सब्सक्रिप्शन (Subscription)',
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: criteria.subscriptionFilter,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: const TextStyle(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('💳 सभी सब्सक्रिप्शन (All)')),
                        DropdownMenuItem(value: 'premium', child: Text('⭐ केवल प्रीमियम (Premium Eligible)')),
                        DropdownMenuItem(value: 'active', child: Text('🟢 एक्टिव सब्सक्रिप्शन (Active)')),
                        DropdownMenuItem(value: 'expired', child: Text('🔴 समाप्त सब्सक्रिप्शन (Expired)')),
                        DropdownMenuItem(value: 'trial', child: Text('🆓 फ़्री ट्रायल (Trial)')),
                        DropdownMenuItem(value: 'no_subscription', child: Text('⚪ कोई सब्सक्रिप्शन नहीं (None)')),
                        DropdownMenuItem(value: 'pending_approval', child: Text('⏳ पेमेंट अप्रूवल लंबित')),
                        DropdownMenuItem(value: 'paid', child: Text('💵 केवल पेड (Paid Razorpay)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          widget.onCriteriaChanged(criteria.copyWith(subscriptionFilter: val));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),

            // Active Filter Chips with Quick Remove
            if (hasFilters) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('सक्रिय फ़िल्टर:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  if (criteria.status != 'all')
                    _buildActiveChip(
                      label: 'स्टेटस: ${_getStatusLabel(criteria.status)}',
                      onDeleted: () => widget.onCriteriaChanged(criteria.copyWith(status: 'all')),
                    ),
                  if (criteria.categoryId != 'all')
                    _buildActiveChip(
                      label: 'श्रेणी: ${_getCategoryLabel(criteria.categoryId)}',
                      onDeleted: () => widget.onCriteriaChanged(criteria.copyWith(categoryId: 'all', categoryTitle: '')),
                    ),
                  if (criteria.jamuiArea != 'all')
                    _buildActiveChip(
                      label: 'स्थान: ${criteria.jamuiArea}',
                      onDeleted: () => widget.onCriteriaChanged(criteria.copyWith(jamuiArea: 'all')),
                    ),
                  if (criteria.radiusKm != null)
                    _buildActiveChip(
                      label: 'GPS दायरा: ${criteria.radiusKm!.toInt()} KM',
                      onDeleted: () => widget.onCriteriaChanged(criteria.copyWith(clearRadius: true)),
                    ),
                  if (criteria.dateFilter != 'all')
                    _buildActiveChip(
                      label: 'दिनांक: ${_getDateLabel(criteria)}',
                      onDeleted: () => widget.onCriteriaChanged(criteria.copyWith(dateFilter: 'all', clearCustomDateRange: true)),
                    ),
                  if (criteria.subscriptionFilter != 'all')
                    _buildActiveChip(
                      label: 'सब्सक्रिप्शन: ${_getSubscriptionLabel(criteria.subscriptionFilter)}',
                      onDeleted: () => widget.onCriteriaChanged(criteria.copyWith(subscriptionFilter: 'all')),
                    ),
                  if (criteria.searchQuery.trim().isNotEmpty)
                    _buildActiveChip(
                      label: 'सर्च: "${criteria.searchQuery.trim()}"',
                      onDeleted: () => widget.onCriteriaChanged(criteria.copyWith(searchQuery: '')),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.clear_all, size: 14, color: Colors.red),
                    label: const Text('सभी हटाएं', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.red.shade50,
                    side: BorderSide(color: Colors.red.shade200),
                    onPressed: widget.onClearAll,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownContainer({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }

  Widget _buildActiveChip({required String label, required VoidCallback onDeleted}) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.indigo)),
      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.indigo),
      onDeleted: onDeleted,
      backgroundColor: Colors.indigo.shade50,
      side: BorderSide(color: Colors.indigo.shade200),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  bool _isValidCategoryValue(String catId) {
    if (catId == 'all') return true;
    return widget.availableCategories.any((c) => c['id'].toString() == catId);
  }

  bool _isValidAreaValue(String area) {
    if (area == 'all') return true;
    return widget.availableAreas.contains(area);
  }

  String _getStatusLabel(String val) {
    switch (val) {
      case 'pending_approval':
        return 'अनुमोदन लंबित';
      case 'approved_active':
        return 'स्वीकृत व एक्टिव';
      case 'rejected':
        return 'अस्वीकृत';
      case 'suspended_blocked':
        return 'निलंबित/ब्लॉक';
      case 'inactive':
        return 'निष्क्रिय';
      case 'deleted':
        return 'हटाए गए';
      case 'all_with_deleted':
        return 'सभी + हटाए गए';
      default:
        return val;
    }
  }

  String _getCategoryLabel(String catId) {
    final match = widget.availableCategories.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['id'].toString() == catId,
          orElse: () => null,
        );
    if (match != null) {
      return (match['titleHindi'] ?? match['titleEnglish'] ?? match['name'] ?? catId).toString();
    }
    return catId;
  }

  String _getDateLabel(ProviderFilterCriteria criteria) {
    switch (criteria.dateFilter) {
      case 'today':
        return 'आज';
      case 'last_7_days':
        return 'पिछले 7 दिन';
      case 'last_30_days':
        return 'पिछले 30 दिन';
      case 'custom':
        if (criteria.customDateRange != null) {
          final s = DateFormat('dd MMM').format(criteria.customDateRange!.start);
          final e = DateFormat('dd MMM').format(criteria.customDateRange!.end);
          return '$s - $e';
        }
        return 'कस्टम सीमा';
      default:
        return criteria.dateFilter;
    }
  }

  String _getSubscriptionLabel(String val) {
    switch (val) {
      case 'active':
        return 'एक्टिव';
      case 'premium':
        return '⭐ प्रीमियम';
      case 'expired':
        return 'समाप्त';
      case 'trial':
        return 'ट्रायल';
      case 'no_subscription':
        return 'कोई नहीं';
      case 'pending_approval':
        return 'अप्रूवल लंबित';
      case 'paid':
        return 'पेड';
      default:
        return val;
    }
  }
}
