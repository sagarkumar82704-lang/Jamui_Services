import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class DataColumnItem {
  final String label;
  final bool isNumeric;

  const DataColumnItem({required this.label, this.isNumeric = false});
}

class DataTableView extends StatefulWidget {
  final List<DataColumnItem> columns;
  final List<DataRow> rows;
  final bool isLoading;
  final String title;
  final Widget? headerAction;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onNextPage;
  final VoidCallback? onPrevPage;
  final int currentPage;
  final bool hasNextPage;
  final Widget? filterWidget;
  final String? paginationInfo;
  final Widget? emptyWidget;
  final Widget? rowsPerPageSelector;
  final Widget? searchWidget;

  const DataTableView({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    required this.title,
    this.headerAction,
    this.onSearch,
    this.onNextPage,
    this.onPrevPage,
    this.currentPage = 1,
    this.hasNextPage = false,
    this.filterWidget,
    this.paginationInfo,
    this.emptyWidget,
    this.rowsPerPageSelector,
    this.searchWidget,
  });

  @override
  State<DataTableView> createState() => _DataTableViewState();
}

class _DataTableViewState extends State<DataTableView> {
  final _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.title, style: AppTextStyles.h3)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.searchWidget != null)
                      widget.searchWidget!
                    else if (widget.onSearch != null)
                      SizedBox(
                        width: 250,
                        height: 38,
                        child: TextField(
                          onChanged: widget.onSearch,
                          style: AppTextStyles.body,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: AppTextStyles.caption,
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                          ),
                        ),
                      ),
                    if (widget.headerAction != null) ...[
                      const SizedBox(width: 12),
                      widget.headerAction!,
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (widget.filterWidget != null) ...[
            const Divider(height: 1),
            widget.filterWidget!,
          ],
          const Divider(height: 1),

          // Table Content
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.rows.isEmpty
                ? (widget.emptyWidget ??
                      const Center(
                        child: Text(
                          "No Records Found",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ))
                : Scrollbar(
                    controller: _verticalScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 320,
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              AppColors.surfaceSubtle,
                            ),
                            headingTextStyle: AppTextStyles.bodyBold.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            dataTextStyle: AppTextStyles.body.copyWith(
                              fontSize: 13,
                            ),
                            horizontalMargin: 16,
                            columnSpacing: 24,
                            columns: widget.columns
                                .map(
                                  (c) => DataColumn(
                                    label: Text(c.label),
                                    numeric: c.isNumeric,
                                  ),
                                )
                                .toList(),
                            rows: widget.rows,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),

          // Pagination Footer
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.rowsPerPageSelector != null) ...[
                      widget.rowsPerPageSelector!,
                      const SizedBox(width: 16),
                    ],
                    Text(
                      widget.paginationInfo ?? 'Page ${widget.currentPage}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: widget.currentPage > 1 ? widget.onPrevPage : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: widget.hasNextPage ? widget.onNextPage : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
