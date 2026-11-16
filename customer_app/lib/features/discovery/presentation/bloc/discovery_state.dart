import 'package:equatable/equatable.dart';
import '../../domain/entities/service_category_entity.dart';
import '../../domain/entities/service_provider_entity.dart';

abstract class DiscoveryState extends Equatable {
  const DiscoveryState();

  @override
  List<Object?> get props => [];
}

class DiscoveryInitial extends DiscoveryState {}

class DiscoveryLoading extends DiscoveryState {}

class DiscoveryLoaded extends DiscoveryState {
  final List<ServiceCategoryEntity> categories;
  final List<ServiceProviderEntity> providers;
  final String selectedCategoryId;
  final String selectedArea;
  final String searchQuery;
  final double? customerLatitude;
  final double? customerLongitude;
  final String customerAreaName;
  final String customerVillage;
  final String customerBlock;
  final dynamic activeAiIntent;
  final bool isAiProcessing;
  final bool hasMoreProviders;
  final bool isLoadingMore;
  final dynamic lastDocumentCursor;
  final int generationToken;

  const DiscoveryLoaded({
    required this.categories,
    required this.providers,
    this.selectedCategoryId = 'all',
    this.selectedArea = 'सभी इलाके',
    this.searchQuery = '',
    this.customerLatitude,
    this.customerLongitude,
    this.customerAreaName = 'स्थान चुनें (GPS)',
    this.customerVillage = '',
    this.customerBlock = '',
    this.activeAiIntent,
    this.isAiProcessing = false,
    this.hasMoreProviders = true,
    this.isLoadingMore = false,
    this.lastDocumentCursor,
    this.generationToken = 0,
  });

  DiscoveryLoaded copyWith({
    List<ServiceCategoryEntity>? categories,
    List<ServiceProviderEntity>? providers,
    String? selectedCategoryId,
    String? selectedArea,
    String? searchQuery,
    double? customerLatitude,
    double? customerLongitude,
    String? customerAreaName,
    String? customerVillage,
    String? customerBlock,
    dynamic activeAiIntent,
    bool? isAiProcessing,
    bool? hasMoreProviders,
    bool? isLoadingMore,
    dynamic lastDocumentCursor,
    int? generationToken,
    bool clearActiveAiIntent = false,
    bool clearCursor = false,
  }) {
    return DiscoveryLoaded(
      categories: categories ?? this.categories,
      providers: providers ?? this.providers,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedArea: selectedArea ?? this.selectedArea,
      searchQuery: searchQuery ?? this.searchQuery,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      customerAreaName: customerAreaName ?? this.customerAreaName,
      customerVillage: customerVillage ?? this.customerVillage,
      customerBlock: customerBlock ?? this.customerBlock,
      activeAiIntent: clearActiveAiIntent ? null : (activeAiIntent ?? this.activeAiIntent),
      isAiProcessing: isAiProcessing ?? this.isAiProcessing,
      hasMoreProviders: hasMoreProviders ?? this.hasMoreProviders,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocumentCursor: clearCursor ? null : (lastDocumentCursor ?? this.lastDocumentCursor),
      generationToken: generationToken ?? this.generationToken,
    );
  }

  @override
  List<Object?> get props => [
        categories,
        providers,
        selectedCategoryId,
        selectedArea,
        searchQuery,
        customerLatitude,
        customerLongitude,
        customerAreaName,
        customerVillage,
        customerBlock,
        activeAiIntent,
        isAiProcessing,
        hasMoreProviders,
        isLoadingMore,
        lastDocumentCursor,
        generationToken,
      ];
}

class DiscoveryError extends DiscoveryState {
  final String message;
  const DiscoveryError(this.message);

  @override
  List<Object?> get props => [message];
}
