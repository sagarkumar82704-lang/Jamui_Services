import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardStatsModel {
  final int totalCustomers;
  final int totalProviders;
  final int activeProviders;
  final int pendingProviders;
  final int totalLeads;
  final int totalBookings;
  final int activeSubscriptions;
  final double totalRevenue;

  const DashboardStatsModel({
    required this.totalCustomers,
    required this.totalProviders,
    required this.activeProviders,
    required this.pendingProviders,
    required this.totalLeads,
    required this.totalBookings,
    required this.activeSubscriptions,
    required this.totalRevenue,
  });
}

abstract class DashboardRemoteDataSource {
  Future<DashboardStatsModel> getRealDashboardStats();
}

class FirebaseDashboardRemoteDataSource implements DashboardRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirebaseDashboardRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<DashboardStatsModel> getRealDashboardStats() async {
    int customersCount = 0;
    int providersCount = 0;
    int activeProvidersCount = 0;
    int pendingProvidersCount = 0;
    int leadsCount = 0;
    int bookingsCount = 0;
    int subscriptionsCount = 0;
    double revenue = 0.0;

    try {
      final usersSnap = await _firestore.collection('users').count().get();
      customersCount = usersSnap.count ?? 0;
    } catch (_) {
      try {
        final custSnap = await _firestore.collection('customers').count().get();
        customersCount = custSnap.count ?? 0;
      } catch (_) {}
    }

    try {
      final provSnap = await _firestore.collection('providers').count().get();
      providersCount = provSnap.count ?? 0;

      try {
        final activeSnap = await _firestore.collection('providers').where('status', isEqualTo: 'active').count().get();
        final approvedSnap = await _firestore.collection('providers').where('status', isEqualTo: 'approved').count().get();
        activeProvidersCount = (activeSnap.count ?? 0) + (approvedSnap.count ?? 0);
      } catch (_) {}

      try {
        final pendingSnap = await _firestore.collection('providers').where('verificationStatus', isEqualTo: 'pending').count().get();
        pendingProvidersCount = pendingSnap.count ?? 0;
        if (pendingProvidersCount == 0) {
          final pendingReviewSnap = await _firestore.collection('providers').where('status', isEqualTo: 'pendingReview').count().get();
          pendingProvidersCount = pendingReviewSnap.count ?? 0;
        }
      } catch (_) {}
    } catch (_) {}

    try {
      final leadsSnap = await _firestore.collection('leads').count().get();
      leadsCount = leadsSnap.count ?? 0;
    } catch (_) {}

    try {
      final bookingsSnap = await _firestore.collection('bookings').count().get();
      bookingsCount = bookingsSnap.count ?? 0;
    } catch (_) {}

    try {
      final subSnap = await _firestore.collection('subscriptions').where('status', isEqualTo: 'active').count().get();
      subscriptionsCount = subSnap.count ?? 0;
    } catch (_) {}

    try {
      final paySnap = await _firestore.collection('payments').where('status', isEqualTo: 'success').get();
      for (var doc in paySnap.docs) {
        final data = doc.data();
        if (data.containsKey('amount')) {
          revenue += (data['amount'] as num).toDouble();
        }
      }
    } catch (_) {}

    return DashboardStatsModel(
      totalCustomers: customersCount,
      totalProviders: providersCount,
      activeProviders: activeProvidersCount,
      pendingProviders: pendingProvidersCount,
      totalLeads: leadsCount,
      totalBookings: bookingsCount,
      activeSubscriptions: subscriptionsCount,
      totalRevenue: revenue,
    );
  }
}
