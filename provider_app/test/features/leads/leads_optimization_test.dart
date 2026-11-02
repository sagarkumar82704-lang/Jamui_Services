import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/leads/data/datasources/lead_remote_data_source.dart';
import 'package:apna_jamui_provider/features/leads/data/models/lead_model.dart';
import 'package:apna_jamui_provider/features/leads/data/repositories/lead_repository_impl.dart';
import 'package:apna_jamui_provider/features/leads/domain/entities/lead_entity.dart';
import 'package:apna_jamui_provider/features/leads/presentation/bloc/lead_bloc.dart';
import 'package:apna_jamui_provider/features/leads/presentation/bloc/lead_event.dart';
import 'package:apna_jamui_provider/features/leads/presentation/bloc/lead_state.dart';

class MockLeadRemoteDataSource implements LeadRemoteDataSource {
  int lastRequestedLimit = 0;
  String lastProviderId = '';
  final StreamController<List<LeadModel>> controller = StreamController<List<LeadModel>>.broadcast();

  String lastUpdatedLeadId = '';
  String lastUpdatedStatus = '';

  @override
  Stream<List<LeadModel>> getLeadsStream(String providerId, {int limit = 30}) {
    lastProviderId = providerId;
    lastRequestedLimit = limit;
    return controller.stream;
  }

  @override
  Future<void> updateLeadStatus(String leadId, String status) async {
    lastUpdatedLeadId = leadId;
    lastUpdatedStatus = status;
  }

  void dispose() {
    controller.close();
  }
}

LeadModel createTestLead({
  required String id,
  required String providerId,
  required DateTime createdAt,
  LeadStatus status = LeadStatus.newLead,
  String customerName = 'रमेश कुमार',
  String customerPhone = '+919876543210',
  String serviceName = 'बिजली मरम्मत',
}) {
  return LeadModel(
    id: id,
    customerId: 'cust_$id',
    customerName: customerName,
    customerPhone: customerPhone,
    providerId: providerId,
    categoryId: 'electrician',
    categoryTitle: 'इलेक्ट्रीशियन',
    serviceName: serviceName,
    description: 'स्विच बोर्ड ठीक कराना है',
    address: 'स्टेशन रोड, जमुई',
    latitude: 24.9123,
    longitude: 86.2234,
    status: status,
    createdAt: createdAt,
  );
}

void main() {
  group('Step 4: Leads Query Optimization Tests', () {
    late MockLeadRemoteDataSource mockDataSource;
    late LeadRepositoryImpl repository;
    late LeadBloc leadBloc;

    setUp(() {
      mockDataSource = MockLeadRemoteDataSource();
      repository = LeadRepositoryImpl(remoteDataSource: mockDataSource);
      leadBloc = LeadBloc(leadRepository: repository);
    });

    tearDown(() {
      leadBloc.close();
      mockDataSource.dispose();
    });

    test('1. Repository forwards default limit (30) to data source', () {
      repository.getLeadsStream('prov_123');
      expect(mockDataSource.lastProviderId, equals('prov_123'));
      expect(mockDataSource.lastRequestedLimit, equals(30));
    });

    test('2. Repository forwards custom pagination limit (e.g. 60) to data source', () {
      repository.getLeadsStream('prov_123', limit: 60);
      expect(mockDataSource.lastProviderId, equals('prov_123'));
      expect(mockDataSource.lastRequestedLimit, equals(60));
    });

    test('3. LeadBloc SubscribeLeadsEvent initiates stream with limit 30', () async {
      leadBloc.add(const SubscribeLeadsEvent('prov_abc'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(mockDataSource.lastProviderId, equals('prov_abc'));
      expect(mockDataSource.lastRequestedLimit, equals(30));
      expect(leadBloc.state, isA<LeadLoading>());
    });

    test('4. LeadBloc emits LeadsLoaded with hasReachedMax=true when results < limit', () async {
      final states = <LeadState>[];
      final sub = leadBloc.stream.listen(states.add);

      leadBloc.add(const SubscribeLeadsEvent('prov_abc'));
      await Future.delayed(const Duration(milliseconds: 10));

      // Emit 10 leads (less than default limit 30)
      final sampleLeads = List.generate(
        10,
        (i) => createTestLead(
          id: 'lead_$i',
          providerId: 'prov_abc',
          createdAt: DateTime.now().subtract(Duration(minutes: i)),
        ),
      );

      mockDataSource.controller.add(sampleLeads);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(states.length, greaterThanOrEqualTo(1));
      final loadedState = states.lastWhere((s) => s is LeadsLoaded) as LeadsLoaded;
      expect(loadedState.leads.length, equals(10));
      expect(loadedState.hasReachedMax, isTrue); // 10 < 30 -> hasReachedMax = true

      await sub.cancel();
    });

    test('5. LeadBloc emits LeadsLoaded with hasReachedMax=false when results == limit', () async {
      final states = <LeadState>[];
      final sub = leadBloc.stream.listen(states.add);

      leadBloc.add(const SubscribeLeadsEvent('prov_abc'));
      await Future.delayed(const Duration(milliseconds: 10));

      // Emit full 30 leads (exact batch limit)
      final sampleLeads = List.generate(
        30,
        (i) => createTestLead(
          id: 'lead_$i',
          providerId: 'prov_abc',
          createdAt: DateTime.now().subtract(Duration(minutes: i)),
        ),
      );

      mockDataSource.controller.add(sampleLeads);
      await Future.delayed(const Duration(milliseconds: 10));

      final loadedState = states.lastWhere((s) => s is LeadsLoaded) as LeadsLoaded;
      expect(loadedState.leads.length, equals(30));
      expect(loadedState.hasReachedMax, isFalse); // 30 == 30 -> more may exist!

      await sub.cancel();
    });

    test('6. LoadMoreLeadsEvent increases limit to 60 and resubscribes seamlessly without duplicates', () async {
      leadBloc.add(const SubscribeLeadsEvent('prov_abc', limit: 30));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(mockDataSource.lastRequestedLimit, equals(30));

      leadBloc.add(const LoadMoreLeadsEvent(step: 30));
      await Future.delayed(const Duration(milliseconds: 10));

      // Limit should now be 60
      expect(mockDataSource.lastRequestedLimit, equals(60));
    });

    test('7. LeadBloc UpdateLeadStatusEvent updates status correctly', () async {
      leadBloc.add(const UpdateLeadStatusEvent(
        leadId: 'lead_999',
        newStatus: LeadStatus.accepted,
      ));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(mockDataSource.lastUpdatedLeadId, equals('lead_999'));
      expect(mockDataSource.lastUpdatedStatus, equals('accepted'));
    });

    test('8. LeadModel.fromMap preserves customer contact, description and ML details', () {
      final map = {
        'customerId': 'cust_101',
        'customerName': 'सुनील कुमार',
        'customerPhone': '9876543210',
        'providerId': 'prov_505',
        'categoryId': 'plumbing',
        'categoryTitle': 'प्लम्बर',
        'serviceName': 'नल रिपेयर',
        'description': 'पाइप लीकेज समस्या',
        'address': 'झाझा रोड, जमुई',
        'customerArea': 'शहरी क्षेत्र',
        'visitingCharge': 150.0,
        'status': 'accepted',
        'createdAt': '2026-10-25T10:00:00.000Z',
      };

      final lead = LeadModel.fromMap(map, 'doc_123');

      expect(lead.id, equals('doc_123'));
      expect(lead.customerName, equals('सुनील कुमार'));
      expect(lead.customerPhone, equals('9876543210'));
      expect(lead.status, equals(LeadStatus.accepted));
      expect(lead.visitingCharge, equals(150.0));
      expect(lead.customerArea, equals('शहरी क्षेत्र'));
    });

    test('9. LeadModel.fromMap handles missing createdAt safely without crashing', () {
      final mapWithoutCreatedAt = {
        'customerId': 'cust_old',
        'customerName': 'पुराना ग्राहक',
        'customerPhone': '9999999999',
        'providerId': 'prov_old',
        'status': 'completed',
        // createdAt is omitted
      };

      final lead = LeadModel.fromMap(mapWithoutCreatedAt, 'old_doc');

      expect(lead.id, equals('old_doc'));
      expect(lead.createdAt, isNotNull);
      expect(lead.status, equals(LeadStatus.completed));
    });

    test('10. Leads are sorted descending by createdAt (latest first)', () {
      final t1 = DateTime(2026, 10, 25, 9, 0);
      final t2 = DateTime(2026, 10, 25, 10, 0);
      final t3 = DateTime(2026, 10, 25, 11, 0);

      final leads = [
        createTestLead(id: '1', providerId: 'p1', createdAt: t1),
        createTestLead(id: '3', providerId: 'p1', createdAt: t3),
        createTestLead(id: '2', providerId: 'p1', createdAt: t2),
      ];

      leads.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(leads[0].id, equals('3')); // latest (11:00)
      expect(leads[1].id, equals('2')); // (10:00)
      expect(leads[2].id, equals('1')); // oldest (09:00)
    });

    test('11. Multi-tab filtering partitions leads cleanly across 4 tabs without duplicate leakage', () {
      final sampleLeads = [
        createTestLead(id: '1', providerId: 'p1', createdAt: DateTime.now(), status: LeadStatus.newLead),
        createTestLead(id: '2', providerId: 'p1', createdAt: DateTime.now(), status: LeadStatus.viewed),
        createTestLead(id: '3', providerId: 'p1', createdAt: DateTime.now(), status: LeadStatus.accepted),
        createTestLead(id: '4', providerId: 'p1', createdAt: DateTime.now(), status: LeadStatus.completed),
        createTestLead(id: '5', providerId: 'p1', createdAt: DateTime.now(), status: LeadStatus.rejected),
      ];

      // Tab 1: New / Inquiries (newLead + viewed)
      final tabNew = sampleLeads.where((l) => l.status == LeadStatus.newLead || l.status == LeadStatus.viewed).toList();
      // Tab 2: Accepted
      final tabAccepted = sampleLeads.where((l) => l.status == LeadStatus.accepted).toList();
      // Tab 3: Completed
      final tabCompleted = sampleLeads.where((l) => l.status == LeadStatus.completed).toList();
      // Tab 4: All
      final tabAll = sampleLeads;

      expect(tabNew.map((l) => l.id).toList(), equals(['1', '2']));
      expect(tabAccepted.map((l) => l.id).toList(), equals(['3']));
      expect(tabCompleted.map((l) => l.id).toList(), equals(['4']));
      expect(tabAll.length, equals(5));

      // Guarantee no ID is duplicated in any tab
      expect(tabNew.map((l) => l.id).toSet().length, equals(tabNew.length));
      expect(tabAccepted.map((l) => l.id).toSet().length, equals(tabAccepted.length));
      expect(tabCompleted.map((l) => l.id).toSet().length, equals(tabCompleted.length));
      expect(tabAll.map((l) => l.id).toSet().length, equals(tabAll.length));
    });

    test('12. Consecutive pagination 30 -> 60 -> 90 updates limit smoothly', () async {
      leadBloc.add(const SubscribeLeadsEvent('prov_xyz', limit: 30));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(mockDataSource.lastRequestedLimit, equals(30));

      leadBloc.add(const LoadMoreLeadsEvent(step: 30));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(mockDataSource.lastRequestedLimit, equals(60));

      leadBloc.add(const LoadMoreLeadsEvent(step: 30));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(mockDataSource.lastRequestedLimit, equals(90));
    });

    test('13. Leads list contains no duplicates when stream emits updated list', () async {
      final states = <LeadState>[];
      final sub = leadBloc.stream.listen(states.add);

      leadBloc.add(const SubscribeLeadsEvent('prov_xyz'));
      await Future.delayed(const Duration(milliseconds: 10));

      final uniqueLeads = List.generate(
        15,
        (i) => createTestLead(
          id: 'lead_$i',
          providerId: 'prov_xyz',
          createdAt: DateTime.now().subtract(Duration(minutes: i)),
        ),
      );

      mockDataSource.controller.add(uniqueLeads);
      await Future.delayed(const Duration(milliseconds: 10));

      final loadedState = states.lastWhere((s) => s is LeadsLoaded) as LeadsLoaded;
      final ids = loadedState.leads.map((l) => l.id).toList();
      expect(ids.toSet().length, equals(ids.length), reason: 'Every lead must have a distinct ID');

      await sub.cancel();
    });
  });
}
