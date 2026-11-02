import 'package:equatable/equatable.dart';

class CategoryDependencyCount extends Equatable {
  final int providerCount;
  final int serviceCount;
  final int leadCount;
  final int bookingCount;
  final int reviewCount;

  const CategoryDependencyCount({
    required this.providerCount,
    required this.serviceCount,
    required this.leadCount,
    required this.bookingCount,
    required this.reviewCount,
  });

  bool get hasDependencies =>
      (providerCount + serviceCount + leadCount + bookingCount + reviewCount) > 0;

  @override
  List<Object?> get props => [
        providerCount,
        serviceCount,
        leadCount,
        bookingCount,
        reviewCount,
      ];
}
