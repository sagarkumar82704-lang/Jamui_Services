import '../entities/lead_entity.dart';

abstract class LeadRepository {
  Stream<List<LeadEntity>> getLeadsStream(String providerId, {int limit = 30});
  Future<void> updateLeadStatus(String leadId, LeadStatus status);
}
