import '../../domain/entities/admin_provider_kyc_entity.dart';
import '../../domain/repositories/admin_provider_repository.dart';
import '../datasources/admin_provider_remote_data_source.dart';

class AdminProviderRepositoryImpl implements AdminProviderRepository {
  final AdminProviderRemoteDataSource remoteDataSource;

  AdminProviderRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<AdminProviderKycEntity>> fetchKycRequests() async {
    return await remoteDataSource.getKycRequests();
  }

  @override
  Future<void> approveKyc(String providerId) async {
    await remoteDataSource.updateKycStatus(providerId, 'approved');
  }

  @override
  Future<void> rejectKyc(String providerId, String reason) async {
    await remoteDataSource.updateKycStatus(providerId, 'rejected', reason: reason);
  }
}
