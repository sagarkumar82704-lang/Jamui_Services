import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/bloc/admin_auth_bloc.dart';
import '../../../auth/presentation/bloc/admin_auth_state.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/category_bloc.dart';
import '../bloc/category_event.dart';
import '../bloc/category_state.dart';
import '../widgets/add_edit_category_modal.dart';
import '../widgets/category_customer_preview_dialog.dart';
import '../widgets/category_dependency_dialog.dart';
import '../widgets/premium_category_manager.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  int _activeTab = 0; // 0 = Standard Categories, 1 = Premium Categories
  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<CategoryBloc>().add(const LoadCategoriesEvent());
  }

  String _getAdminId() {
    final state = context.read<AdminAuthBloc>().state;
    if (state is AdminAuthenticated) {
      return state.adminUser.uid;
    }
    return 'master_admin_1';
  }

  void _openAddEditModal([CategoryEntity? category]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AddEditCategoryModal(
        category: category,
        onSave: (newCat) async {
          final adminId = _getAdminId();
          final bloc = context.read<CategoryBloc>();
          if (category == null || category.id.isEmpty) {
            bloc.add(CreateCategoryEvent(category: newCat, adminId: adminId));
          } else {
            bloc.add(UpdateCategoryEvent(category: newCat, adminId: adminId));
          }

          final nextState = await bloc.stream.firstWhere(
            (s) => s is CategoryOperationSuccessState || s is CategoryErrorState,
          ).timeout(
            const Duration(seconds: 8),
            onTimeout: () => const CategoryOperationSuccessState('Category update saved.'),
          );

          if (nextState is CategoryErrorState) {
            throw Exception(nextState.message);
          }
        },
      ),
    );
  }

  void _openCustomerPreview(CategoryEntity category) {
    showDialog(
      context: context,
      builder: (context) => CategoryCustomerPreviewDialog(category: category),
    );
  }

  void _onCheckDependencyAndDelete(CategoryEntity category) {
    context.read<CategoryBloc>().add(CheckCategoryDependenciesEvent(category));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CategoryBloc, CategoryState>(
      listener: (context, state) {
        if (state is CategoryOperationSuccessState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
          );
        } else if (state is CategoryErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.danger),
          );
        } else if (state is CategoryDependenciesCheckedState) {
          showDialog(
            context: context,
            builder: (context) => CategoryDependencyDialog(
              category: state.category,
              dependencyCount: state.dependencyCount,
              onDeactivate: () {
                context.read<CategoryBloc>().add(ToggleCategoryStatusEvent(
                      categoryId: state.category.id,
                      newStatus: CategoryStatus.inactive,
                      adminId: _getAdminId(),
                    ));
              },
              onArchive: () {
                context.read<CategoryBloc>().add(ArchiveCategoryEvent(
                      categoryId: state.category.id,
                      adminId: _getAdminId(),
                    ));
              },
              onDeletePermanently: () {
                context.read<CategoryBloc>().add(DeleteCategoryPermanentlyEvent(
                      categoryId: state.category.id,
                      adminId: _getAdminId(),
                    ));
              },
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is CategoryLoadingState;
        List<CategoryEntity> categories = [];
        if (state is CategoryLoadedState) {
          categories = state.categories;
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab Navigation
              Row(
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(
                        value: 0,
                        label: Text('सर्विस कैटेगरीज (Master Directory)'),
                        icon: Icon(Icons.category_outlined, size: 16),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        label: Text('होमपेज प्रीमियम कैटेगरीज (Premium Manager ⭐)'),
                        icon: Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      ),
                    ],
                    selected: {_activeTab},
                    onSelectionChanged: (val) {
                      if (val.isNotEmpty) setState(() => _activeTab = val.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_activeTab == 1)
                const Expanded(child: PremiumCategoryManager())
              else ...[
                // Filter Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active', 'active'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Inactive', 'inactive'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Archived', 'archived'),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openAddEditModal(),
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text('Create Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Categories Web Data Table / Empty State
              Expanded(
                child: (!isLoading && categories.isEmpty)
                    ? EmptyStateWidget(
                        title: "No Categories Found",
                        message: "There are currently no categories matching your filter in the database. Click 'Create Category' to set up services.",
                        icon: Icons.category_outlined,
                        onRefresh: () => context.read<CategoryBloc>().add(const LoadCategoriesEvent()),
                      )
                    : DataTableView(
                        title: 'Category Master Directory',
                        isLoading: isLoading,
                        onSearch: (q) {
                          setState(() => _searchQuery = q);
                          context.read<CategoryBloc>().add(LoadCategoriesEvent(
                                filterStatus: _selectedFilter,
                                searchQuery: q,
                              ));
                        },
                        columns: const [
                          DataColumnItem(label: 'CATEGORY'),
                          DataColumnItem(label: 'SLUG'),
                          DataColumnItem(label: 'SERVICES'),
                          DataColumnItem(label: 'PRICE & DURATION'),
                          DataColumnItem(label: 'FEATURED'),
                          DataColumnItem(label: 'ORDER'),
                          DataColumnItem(label: 'STATUS'),
                          DataColumnItem(label: 'ACTIONS'),
                        ],
                        rows: categories.map((cat) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySubtle,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: cat.imageUrl.isNotEmpty
                                          ? AppNetworkOrBase64Image(
                                              imageUrl: cat.imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 18, color: Colors.grey),
                                            )
                                          : const Icon(Icons.category_outlined, size: 18, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(cat.name, style: AppTextStyles.bodyBold),
                                        if (cat.titleHindi.isNotEmpty && cat.titleHindi != cat.name)
                                          Text(cat.titleHindi, style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(cat.slug, style: AppTextStyles.caption)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${cat.subServices.length} services',
                                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      cat.startingPrice != null && cat.startingPrice! > 0
                                          ? '₹${cat.startingPrice!.toStringAsFixed(0)} ${cat.priceUnit}'
                                          : (cat.pricingType == 'inspection' ? 'On Inspection' : 'Contact Provider'),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D6E57)),
                                    ),
                                    if (cat.estimatedDuration.isNotEmpty)
                                      Text(cat.estimatedDuration, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              DataCell(
                                cat.isFeatured
                                    ? const Icon(Icons.star, color: Colors.amber, size: 20)
                                    : const Text('-', style: TextStyle(color: Colors.grey)),
                              ),
                              DataCell(Text(cat.sortOrder.toString())),
                              DataCell(StatusBadge.fromStatus(cat.status.name)),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.blueGrey),
                                      onPressed: () => _openCustomerPreview(cat),
                                      tooltip: 'Preview Customer View',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                      onPressed: () => _openAddEditModal(cat),
                                      tooltip: 'Edit Category',
                                    ),
                                    if (cat.isActive)
                                      IconButton(
                                        icon: const Icon(Icons.pause_circle_outline, size: 18, color: AppColors.warning),
                                        onPressed: () {
                                          context.read<CategoryBloc>().add(ToggleCategoryStatusEvent(
                                                categoryId: cat.id,
                                                newStatus: CategoryStatus.inactive,
                                                adminId: _getAdminId(),
                                              ));
                                        },
                                        tooltip: 'Deactivate',
                                      )
                                    else if (cat.isInactive)
                                      IconButton(
                                        icon: const Icon(Icons.play_circle_outline, size: 18, color: AppColors.success),
                                        onPressed: () {
                                          context.read<CategoryBloc>().add(ToggleCategoryStatusEvent(
                                                categoryId: cat.id,
                                                newStatus: CategoryStatus.active,
                                                adminId: _getAdminId(),
                                              ));
                                        },
                                        tooltip: 'Re-activate',
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                      onPressed: () => _onCheckDependencyAndDelete(cat),
                                      tooltip: 'Safe Delete / Archive',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
              ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = value);
          context.read<CategoryBloc>().add(LoadCategoriesEvent(
                filterStatus: value,
                searchQuery: _searchQuery,
              ));
        }
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
