import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/admin_provider_repository.dart';
import 'admin_kyc_event.dart';
import 'admin_kyc_state.dart';

class AdminKycBloc extends Bloc<AdminKycEvent, AdminKycState> {
  final AdminProviderRepository providerRepository;

  AdminKycBloc({required this.providerRepository}) : super(AdminKycInitial()) {
    on<LoadKycRequestsEvent>(_onLoadRequests);
    on<ApproveKycEvent>(_onApproveKyc);
    on<RejectKycEvent>(_onRejectKyc);
  }

  Future<void> _onLoadRequests(
    LoadKycRequestsEvent event,
    Emitter<AdminKycState> emit,
  ) async {
    emit(AdminKycLoading());
    try {
      final list = await providerRepository.fetchKycRequests();
      emit(AdminKycLoaded(list));
    } catch (e) {
      emit(AdminKycError(e.toString()));
    }
  }

  Future<void> _onApproveKyc(
    ApproveKycEvent event,
    Emitter<AdminKycState> emit,
  ) async {
    try {
      await providerRepository.approveKyc(event.providerId);
      final list = await providerRepository.fetchKycRequests();
      emit(AdminKycLoaded(list));
      emit(const AdminKycActionSuccess('प्रोवाइडर KYC सफलतापूर्वक स्वीकृत (Approved) किया गया!'));
    } catch (e) {
      emit(AdminKycError(e.toString()));
    }
  }

  Future<void> _onRejectKyc(
    RejectKycEvent event,
    Emitter<AdminKycState> emit,
  ) async {
    try {
      await providerRepository.rejectKyc(event.providerId, event.reason);
      final list = await providerRepository.fetchKycRequests();
      emit(AdminKycLoaded(list));
      emit(const AdminKycActionSuccess('प्रोवाइडर KYC अस्वीकृत (Rejected) किया गया।'));
    } catch (e) {
      emit(AdminKycError(e.toString()));
    }
  }
}
