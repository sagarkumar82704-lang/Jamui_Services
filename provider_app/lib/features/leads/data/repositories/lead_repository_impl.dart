import '../../domain/entities/lead_entity.dart';
import '../../domain/repositories/lead_repository.dart';
import '../datasources/lead_remote_data_source.dart';

class LeadRepositoryImpl implements LeadRepository {
  final LeadRemoteDataSource remoteDataSource;

  LeadRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<LeadEntity>> getLeadsStream(String providerId, {int limit = 30}) {
    return remoteDataSource.getLeadsStream(providerId, limit: limit);
  }

  @override
  Future<void> updateLeadStatus(String leadId, LeadStatus status) async {
    await remoteDataSource.updateLeadStatus(leadId, status.name);
  }
}
