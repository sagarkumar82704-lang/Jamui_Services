import 'package:cloud_firestore/cloud_firestore.dart';

/// [ProviderStatsService] — Reads and exposes the `provider_stats` collection.
///
/// The `provider_stats/{providerId}` document is a denormalized aggregation
/// computed incrementally by [FirebaseLeadRemoteDataSource._updateProviderStats]
/// every time a lead status changes.
///
/// This service is used by:
///   1. [MLProviderRankingService] — to compute acceptance/completion rate scores
///   2. Provider App Analytics Page — to show performance metrics
///   3. Admin Panel AI Insights — to identify underperforming providers
///
/// ## Document Schema (`provider_stats/{providerId}`)
/// ```
/// {
///   totalLeadsReceived: int,   // Incremented when lead is created (pending)
///   totalAccepted:      int,   // Incremented when status → accepted
///   totalRejected:      int,   // Incremented when status → rejected
///   totalCompleted:     int,   // Incremented when status → completed
///   totalCancelled:     int,   // Incremented when status → cancelled
///   lastLeadAt:         Timestamp,
///   statsUpdatedAt:     Timestamp,
///   // Computed by this service (not stored, derived on read)
///   acceptanceRate:     double,  // totalAccepted / totalLeadsReceived
///   completionRate:     double,  // totalCompleted / totalAccepted
///   avgResponseMinutes: double,  // Computed separately from leads (future)
/// }
/// ```
class ProviderStatsService {
  ProviderStatsService._();

  static const String _collection = 'provider_stats';
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Fetch stats for a single provider.
  /// Returns [ProviderStats.empty()] if no stats exist yet.
  static Future<ProviderStats> fetchStats(String providerId) async {
    try {
      final doc = await _fs
          .collection(_collection)
          .doc(providerId)
          .get()
          .timeout(const Duration(seconds: 4));

      if (doc.exists && doc.data() != null) {
        return ProviderStats.fromMap(doc.data()!, providerId);
      }
    } catch (_) {}
    return ProviderStats.empty(providerId);
  }

  /// Fetch stats for multiple providers in a single batched read.
  /// [providerIds] must contain at most 30 IDs (Firestore whereIn limit).
  static Future<Map<String, ProviderStats>> fetchStatsBatch(
      List<String> providerIds) async {
    final result = <String, ProviderStats>{};
    if (providerIds.isEmpty) return result;

    try {
      final chunks = _chunk(providerIds, 30);
      for (final chunk in chunks) {
        final snapshot = await _fs
            .collection(_collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get()
            .timeout(const Duration(seconds: 5));

        for (final doc in snapshot.docs) {
          result[doc.id] = ProviderStats.fromMap(doc.data(), doc.id);
        }
      }
    } catch (_) {}

    // Fill in empty stats for providers not yet in the collection
    for (final id in providerIds) {
      result.putIfAbsent(id, () => ProviderStats.empty(id));
    }

    return result;
  }

  /// Stream real-time stats for a single provider (for Provider Analytics page).
  static Stream<ProviderStats> statsStream(String providerId) {
    return _fs
        .collection(_collection)
        .doc(providerId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return ProviderStats.fromMap(doc.data()!, providerId);
      }
      return ProviderStats.empty(providerId);
    });
  }

  static List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}

/// Strongly-typed value object for provider statistics.
class ProviderStats {
  final String providerId;
  final int totalLeadsReceived;
  final int totalAccepted;
  final int totalRejected;
  final int totalCompleted;
  final int totalCancelled;
  final DateTime? lastLeadAt;
  final DateTime? statsUpdatedAt;

  const ProviderStats({
    required this.providerId,
    required this.totalLeadsReceived,
    required this.totalAccepted,
    required this.totalRejected,
    required this.totalCompleted,
    required this.totalCancelled,
    this.lastLeadAt,
    this.statsUpdatedAt,
  });

  /// Acceptance rate: percentage of leads the provider accepted.
  double get acceptanceRate {
    if (totalLeadsReceived == 0) return 0.0;
    return totalAccepted / totalLeadsReceived;
  }

  /// Completion rate: percentage of accepted leads the provider completed.
  double get completionRate {
    if (totalAccepted == 0) return 0.0;
    return totalCompleted / totalAccepted;
  }

  /// Overall performance score for admin display (0–100).
  int get performanceScore {
    final rate = (acceptanceRate * 0.5) + (completionRate * 0.5);
    return (rate * 100).round().clamp(0, 100);
  }

  /// Human-readable acceptance rate percentage.
  String get acceptanceRateDisplay =>
      '${(acceptanceRate * 100).toStringAsFixed(0)}%';

  /// Human-readable completion rate percentage.
  String get completionRateDisplay =>
      '${(completionRate * 100).toStringAsFixed(0)}%';

  factory ProviderStats.fromMap(Map<String, dynamic> map, String providerId) {
    return ProviderStats(
      providerId: providerId,
      totalLeadsReceived: (map['totalLeadsReceived'] as num?)?.toInt() ?? 0,
      totalAccepted: (map['totalAccepted'] as num?)?.toInt() ?? 0,
      totalRejected: (map['totalRejected'] as num?)?.toInt() ?? 0,
      totalCompleted: (map['totalCompleted'] as num?)?.toInt() ?? 0,
      totalCancelled: (map['totalCancelled'] as num?)?.toInt() ?? 0,
      lastLeadAt: _parseTs(map['lastLeadAt']),
      statsUpdatedAt: _parseTs(map['statsUpdatedAt']),
    );
  }

  factory ProviderStats.empty(String providerId) => ProviderStats(
        providerId: providerId,
        totalLeadsReceived: 0,
        totalAccepted: 0,
        totalRejected: 0,
        totalCompleted: 0,
        totalCancelled: 0,
      );

  static DateTime? _parseTs(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    return DateTime.tryParse(raw.toString());
  }

  Map<String, dynamic> toMap() => {
        'providerId': providerId,
        'totalLeadsReceived': totalLeadsReceived,
        'totalAccepted': totalAccepted,
        'totalRejected': totalRejected,
        'totalCompleted': totalCompleted,
        'totalCancelled': totalCancelled,
        'acceptanceRate': acceptanceRate,
        'completionRate': completionRate,
        'performanceScore': performanceScore,
        if (lastLeadAt != null) 'lastLeadAt': lastLeadAt!.toIso8601String(),
      };
}
