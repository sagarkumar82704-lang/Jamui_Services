import 'package:equatable/equatable.dart';
import '../../domain/entities/lead_entity.dart';

abstract class LeadEvent extends Equatable {
  const LeadEvent();

  @override
  List<Object?> get props => [];
}

class SubscribeLeadsEvent extends LeadEvent {
  final String providerId;
  final int limit;
  const SubscribeLeadsEvent(this.providerId, {this.limit = 30});

  @override
  List<Object?> get props => [providerId, limit];
}

class LoadMoreLeadsEvent extends LeadEvent {
  final int step;
  const LoadMoreLeadsEvent({this.step = 30});

  @override
  List<Object?> get props => [step];
}

class UpdateLeadStatusEvent extends LeadEvent {
  final String leadId;
  final LeadStatus newStatus;

  const UpdateLeadStatusEvent({required this.leadId, required this.newStatus});

  @override
  List<Object?> get props => [leadId, newStatus];
}

class LeadsUpdatedEvent extends LeadEvent {
  final List<LeadEntity> leads;
  const LeadsUpdatedEvent(this.leads);

  @override
  List<Object?> get props => [leads];
}
