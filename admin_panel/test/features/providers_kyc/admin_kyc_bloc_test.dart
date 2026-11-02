import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_admin/features/providers_kyc/domain/entities/admin_provider_kyc_entity.dart';
import 'package:apna_jamui_admin/features/providers_kyc/domain/repositories/admin_provider_repository.dart';
import 'package:apna_jamui_admin/features/providers_kyc/presentation/bloc/admin_kyc_bloc.dart';
import 'package:apna_jamui_admin/features/providers_kyc/presentation/bloc/admin_kyc_event.dart';
import 'package:apna_jamui_admin/features/providers_kyc/presentation/bloc/admin_kyc_state.dart';

class MockAdminProviderRepository implements AdminProviderRepository {
  final List<AdminProviderKycEntity> _list = [];

  MockAdminProviderRepository(List<AdminProviderKycEntity> initial) {
    _list.addAll(initial);
  }

  @override
  Future<List<AdminProviderKycEntity>> fetchKycRequests() async {
    return List.from(_list);
  }

  @override
  Future<void> approveKyc(String providerId) async {
    final idx = _list.indexWhere((p) => p.id == providerId);
    if (idx != -1) {
      _list[idx] = _list[idx].copyWith(status: AdminKycStatus.approved);
    }
  }

  @override
  Future<void> rejectKyc(String providerId, String reason) async {
    final idx = _list.indexWhere((p) => p.id == providerId);
    if (idx != -1) {
      _list[idx] = _list[idx].copyWith(status: AdminKycStatus.rejected, rejectionReason: reason);
    }
  }
}

void main() {
  group('AdminKycBloc Unit Tests', () {
    late MockAdminProviderRepository mockRepo;
    late AdminKycBloc bloc;

    final dummyRequests = [
      AdminProviderKycEntity(
        id: 'prov_1',
        fullName: 'मुकेश कुमार झा',
        businessName: 'झा AC रिपेयर',
        phoneNumber: '+919431288412',
        categoryTitle: 'AC व फ्रिज रिपेयर',
        jamuiArea: 'स्टेशन रोड',
        visitingCharge: 200,
        experienceYears: 5,
        experienceCertificateStatus: 'pendingReview',
        status: AdminKycStatus.pendingReview,
        appliedAt: DateTime(2026, 1, 1),
      ),
    ];

    setUp(() {
      mockRepo = MockAdminProviderRepository(dummyRequests);
      bloc = AdminKycBloc(providerRepository: mockRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is AdminKycInitial', () {
      expect(bloc.state, equals(AdminKycInitial()));
    });

    test('LoadKycRequestsEvent emits [AdminKycLoading, AdminKycLoaded]', () async {
      final expectedStates = [
        AdminKycLoading(),
        AdminKycLoaded(dummyRequests),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(const LoadKycRequestsEvent());
    });

    test('ApproveKycEvent approves provider and emits success', () async {
      bloc.add(const ApproveKycEvent('prov_1'));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AdminKycState>((state) {
            return state is AdminKycLoaded &&
                state.approvedRequests.any((p) => p.id == 'prov_1');
          }),
        ),
      );
    });
  });
}
