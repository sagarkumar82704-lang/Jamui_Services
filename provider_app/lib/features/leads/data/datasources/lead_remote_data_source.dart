import '../models/lead_model.dart';

abstract class LeadRemoteDataSource {
  Stream<List<LeadModel>> getLeadsStream(String providerId, {int limit = 30});
  Future<void> updateLeadStatus(String leadId, String status);
}
