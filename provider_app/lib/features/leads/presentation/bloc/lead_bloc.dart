import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/lead_entity.dart';
import '../../domain/repositories/lead_repository.dart';
import 'lead_event.dart';
import 'lead_state.dart';

class LeadBloc extends Bloc<LeadEvent, LeadState> {
  final LeadRepository leadRepository;
  StreamSubscription<List<LeadEntity>>? _leadsSubscription;
  String? _currentProviderId;
  int _currentLimit = 30;

  LeadBloc({required this.leadRepository}) : super(LeadInitial()) {
    on<SubscribeLeadsEvent>(_onSubscribeLeads);
    on<LoadMoreLeadsEvent>(_onLoadMoreLeads);
    on<LeadsUpdatedEvent>(_onLeadsUpdated);
    on<UpdateLeadStatusEvent>(_onUpdateLeadStatus);
  }

  Future<void> _onSubscribeLeads(
    SubscribeLeadsEvent event,
    Emitter<LeadState> emit,
  ) async {
    _currentProviderId = event.providerId;
    _currentLimit = event.limit;
    emit(LeadLoading());
    await _leadsSubscription?.cancel();
    _leadsSubscription = leadRepository
        .getLeadsStream(event.providerId, limit: _currentLimit)
        .listen(
      (leads) {
        add(LeadsUpdatedEvent(leads));
      },
      onError: (error) {
        emit(LeadError('लीड्स लोड करने में त्रुटि: $error'));
      },
    );
  }

  Future<void> _onLoadMoreLeads(
    LoadMoreLeadsEvent event,
    Emitter<LeadState> emit,
  ) async {
    if (_currentProviderId == null) return;
    _currentLimit += event.step;
    await _leadsSubscription?.cancel();
    _leadsSubscription = leadRepository
        .getLeadsStream(_currentProviderId!, limit: _currentLimit)
        .listen(
      (leads) {
        add(LeadsUpdatedEvent(leads));
      },
      onError: (error) {
        emit(LeadError('लीड्स लोड करने में त्रुटि: $error'));
      },
    );
  }

  void _onLeadsUpdated(
    LeadsUpdatedEvent event,
    Emitter<LeadState> emit,
  ) {
    emit(LeadsLoaded(
      event.leads,
      hasReachedMax: event.leads.length < _currentLimit,
    ));
  }

  Future<void> _onUpdateLeadStatus(
    UpdateLeadStatusEvent event,
    Emitter<LeadState> emit,
  ) async {
    try {
      await leadRepository.updateLeadStatus(event.leadId, event.newStatus);
    } catch (e) {
      emit(LeadError('लीड स्थिति अपडेट करने में विफलता: $e'));
    }
  }

  @override
  Future<void> close() {
    _leadsSubscription?.cancel();
    return super.close();
  }
}
