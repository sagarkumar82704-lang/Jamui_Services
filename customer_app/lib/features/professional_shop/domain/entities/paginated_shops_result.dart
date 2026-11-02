import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'professional_shop_entity.dart';

/// Encapsulates paginated vendor listings with Firestore cursor state.
class PaginatedProfessionalShopsResult extends Equatable {
  final List<ProfessionalShopEntity> shops;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;
  final int totalLoaded;
  final bool isFromCache;

  const PaginatedProfessionalShopsResult({
    required this.shops,
    this.lastDoc,
    required this.hasMore,
    this.totalLoaded = 0,
    this.isFromCache = false,
  });

  @override
  List<Object?> get props => [shops, lastDoc, hasMore, totalLoaded, isFromCache];
}

