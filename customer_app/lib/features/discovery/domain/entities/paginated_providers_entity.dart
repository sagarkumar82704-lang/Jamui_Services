import 'package:equatable/equatable.dart';
import 'service_provider_entity.dart';

class PaginatedProvidersResult extends Equatable {
  final List<ServiceProviderEntity> items;
  final dynamic lastDocumentCursor;
  final bool hasMore;
  final int totalCountEstimate;

  const PaginatedProvidersResult({
    required this.items,
    this.lastDocumentCursor,
    this.hasMore = false,
    this.totalCountEstimate = 0,
  });

  @override
  List<Object?> get props => [items, lastDocumentCursor, hasMore, totalCountEstimate];
}
