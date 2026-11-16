import 'package:equatable/equatable.dart';
import '../../domain/entities/customer_entity.dart';

abstract class CustomerAuthState extends Equatable {
  const CustomerAuthState();

  @override
  List<Object?> get props => [];
}

class CustomerAuthInitialState extends CustomerAuthState {
  const CustomerAuthInitialState();
}

class CustomerAuthLoadingState extends CustomerAuthState {
  final String? message;
  const CustomerAuthLoadingState({this.message});

  @override
  List<Object?> get props => [message];
}

class CustomerOtpSentState extends CustomerAuthState {
  final String verificationId;
  final int? resendToken;
  final String phoneNumber;
  final int timeoutSeconds;

  const CustomerOtpSentState({
    required this.verificationId,
    this.resendToken,
    required this.phoneNumber,
    this.timeoutSeconds = 60,
  });

  @override
  List<Object?> get props => [verificationId, resendToken, phoneNumber, timeoutSeconds];
}

class CustomerRoleSelectionRequiredState extends CustomerAuthState {
  final String userId;
  final CustomerEntity customer;
  final Map<String, dynamic> providerData;
  final bool isProviderApproved;
  final String providerStatus;
  final String? rejectionReason;

  const CustomerRoleSelectionRequiredState({
    required this.userId,
    required this.customer,
    required this.providerData,
    required this.isProviderApproved,
    required this.providerStatus,
    this.rejectionReason,
  });

  @override
  List<Object?> get props => [
        userId,
        customer,
        providerData,
        isProviderApproved,
        providerStatus,
        rejectionReason,
      ];
}

class CustomerProviderPendingApprovalState extends CustomerAuthState {
  final String providerId;
  final String status;
  final String? rejectionReason;

  const CustomerProviderPendingApprovalState({
    required this.providerId,
    required this.status,
    this.rejectionReason,
  });

  @override
  List<Object?> get props => [providerId, status, rejectionReason];
}

class CustomerProviderRejectedState extends CustomerAuthState {
  final String rejectionReason;

  const CustomerProviderRejectedState(this.rejectionReason);

  @override
  List<Object?> get props => [rejectionReason];
}

class CustomerProviderSuspendedState extends CustomerAuthState {
  final String reason;

  const CustomerProviderSuspendedState(this.reason);

  @override
  List<Object?> get props => [reason];
}

class CustomerProviderApprovedState extends CustomerAuthState {
  final Map<String, dynamic> providerData;

  const CustomerProviderApprovedState(this.providerData);

  @override
  List<Object?> get props => [providerData];
}

class CustomerProfileSetupRequiredState extends CustomerAuthState {
  final String userId;
  final String? email;
  final String phoneNumber;

  const CustomerProfileSetupRequiredState({
    required this.userId,
    this.email,
    this.phoneNumber = '',
  });

  @override
  List<Object?> get props => [userId, email, phoneNumber];
}

class CustomerAuthenticatedState extends CustomerAuthState {
  final CustomerEntity customer;
  const CustomerAuthenticatedState(this.customer);

  @override
  List<Object?> get props => [customer];
}

class CustomerUnauthenticatedState extends CustomerAuthState {
  const CustomerUnauthenticatedState();
}

class CustomerPasswordResetSentState extends CustomerAuthState {
  final String email;
  const CustomerPasswordResetSentState(this.email);

  @override
  List<Object?> get props => [email];
}


class CustomerAuthFailureState extends CustomerAuthState {
  final String errorMessage;
  const CustomerAuthFailureState(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
