import '../entities/admin_provider_kyc_entity.dart';

abstract class AdminProviderRepository {
  Future<List<AdminProviderKycEntity>> fetchKycRequests();
  Future<void> approveKyc(String providerId);
  Future<void> rejectKyc(String providerId, String reason);
}
