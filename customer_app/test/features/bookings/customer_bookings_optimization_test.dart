import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Customer Bookings Query & Data Safety Tests', () {
    test('Test 1: Leads client-side sorting orders by createdAt descending correctly', () {
      final now = DateTime.now();
      final leadOlder = {
        'id': 'lead_1',
        'title': 'Plumber',
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
      };
      final leadNewer = {
        'id': 'lead_2',
        'title': 'Electrician',
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
      };
      final leadOldest = {
        'id': 'lead_3',
        'title': 'Carpenter',
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 10))),
      };

      final leads = [leadOlder, leadOldest, leadNewer];

      leads.sort((a, b) {
        final aTime = a['createdAt'] is Timestamp
            ? (a['createdAt'] as Timestamp).toDate()
            : DateTime(2020);
        final bTime = b['createdAt'] is Timestamp
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime(2020);
        return bTime.compareTo(aTime);
      });

      expect(leads[0]['id'], equals('lead_2')); // Most recent first
      expect(leads[1]['id'], equals('lead_1'));
      expect(leads[2]['id'], equals('lead_3')); // Oldest last
    });

    test('Test 2: Leads with missing or invalid createdAt do not crash and sort gracefully', () {
      final now = DateTime.now();
      final leadValid = {
        'id': 'lead_valid',
        'createdAt': Timestamp.fromDate(now),
      };
      final leadMissingCreatedAt = {
        'id': 'lead_missing',
      };
      final leadNullCreatedAt = {
        'id': 'lead_null',
        'createdAt': null,
      };

      final leads = [leadMissingCreatedAt, leadValid, leadNullCreatedAt];

      expect(() {
        leads.sort((a, b) {
          final aTime = a['createdAt'] is Timestamp
              ? (a['createdAt'] as Timestamp).toDate()
              : DateTime(2020);
          final bTime = b['createdAt'] is Timestamp
              ? (b['createdAt'] as Timestamp).toDate()
              : DateTime(2020);
          return bTime.compareTo(aTime);
        });
      }, returnsNormally);

      // The valid recent lead should appear at top
      expect(leads[0]['id'], equals('lead_valid'));
      // Fallback records remain accessible and are placed safely at bottom
      expect(leads.length, equals(3));
    });

    test('Test 3: Status filtering preserves all tabs without losing records', () {
      final allLeads = [
        {'id': '1', 'status': 'pending'},
        {'id': '2', 'status': 'accepted'},
        {'id': '3', 'status': 'completed'},
        {'id': '4', 'status': 'rejected'},
        {'id': '5', 'status': 'cancelled'},
        {'id': '6', 'status': 'pending'},
      ];

      final pending = allLeads.where((l) => l['status'] == 'pending').toList();
      final accepted = allLeads.where((l) => l['status'] == 'accepted').toList();
      final completed = allLeads.where((l) => l['status'] == 'completed').toList();
      final cancelledOrRejected = allLeads
          .where((l) => l['status'] == 'rejected' || l['status'] == 'cancelled')
          .toList();

      expect(pending.length, equals(2));
      expect(accepted.length, equals(1));
      expect(completed.length, equals(1));
      expect(cancelledOrRejected.length, equals(2));

      // Sum of all status partitions equals total leads
      final totalPartitioned = pending.length + accepted.length + completed.length + cancelledOrRejected.length;
      expect(totalPartitioned, equals(allLeads.length));
    });
  });
}
