import 'package:equatable/equatable.dart';
import '../../domain/entities/admin_provider_kyc_entity.dart';

abstract class AdminKycState extends Equatable {
  const AdminKycState();

  @override
  List<Object?> get props => [];
}

class AdminKycInitial extends AdminKycState {}

class AdminKycLoading extends AdminKycState {}

class AdminKycLoaded extends AdminKycState {
  final List<AdminProviderKycEntity> requests;

  const AdminKycLoaded(this.requests);

  List<AdminProviderKycEntity> get pendingRequests =>
      requests.where((r) => r.status == AdminKycStatus.pendingReview).toList();

  List<AdminProviderKycEntity> get approvedRequests =>
      requests.where((r) => r.status == AdminKycStatus.approved).toList();

  List<AdminProviderKycEntity> get rejectedRequests =>
      requests.where((r) => r.status == AdminKycStatus.rejected).toList();

  @override
  List<Object?> get props => [requests];
}

class AdminKycActionSuccess extends AdminKycState {
  final String message;

  const AdminKycActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AdminKycError extends AdminKycState {
  final String message;

  const AdminKycError(this.message);

  @override
  List<Object?> get props => [message];
}
