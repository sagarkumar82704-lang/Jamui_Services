import 'package:equatable/equatable.dart';
import '../../domain/entities/lead_entity.dart';

abstract class LeadState extends Equatable {
  const LeadState();

  @override
  List<Object?> get props => [];
}

class LeadInitial extends LeadState {}

class LeadLoading extends LeadState {}

class LeadsLoaded extends LeadState {
  final List<LeadEntity> leads;
  final bool hasReachedMax;

  const LeadsLoaded(this.leads, {this.hasReachedMax = false});

  @override
  List<Object?> get props => [leads, hasReachedMax];
}

class LeadError extends LeadState {
  final String message;

  const LeadError(this.message);

  @override
  List<Object?> get props => [message];
}
