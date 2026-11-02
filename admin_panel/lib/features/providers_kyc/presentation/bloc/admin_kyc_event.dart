import 'package:equatable/equatable.dart';

abstract class AdminKycEvent extends Equatable {
  const AdminKycEvent();

  @override
  List<Object?> get props => [];
}

class LoadKycRequestsEvent extends AdminKycEvent {
  const LoadKycRequestsEvent();
}

class ApproveKycEvent extends AdminKycEvent {
  final String providerId;
  const ApproveKycEvent(this.providerId);

  @override
  List<Object?> get props => [providerId];
}

class RejectKycEvent extends AdminKycEvent {
  final String providerId;
  final String reason;
  const RejectKycEvent({required this.providerId, required this.reason});

  @override
  List<Object?> get props => [providerId, reason];
}
