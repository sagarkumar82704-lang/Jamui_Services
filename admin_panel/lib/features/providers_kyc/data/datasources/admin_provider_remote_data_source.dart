import '../models/admin_provider_kyc_model.dart';

abstract class AdminProviderRemoteDataSource {
  Future<List<AdminProviderKycModel>> getKycRequests();
  Future<void> updateKycStatus(String providerId, String status, {String? reason});
}
