import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/discovery/data/models/service_provider_model.dart';

/// [MLProviderRankingService] — Phase 1 Weighted Provider Ranking
///
/// Replaces the previous distance-only sort with a multi-factor weighted score.
/// This is a DETERMINISTIC scoring algorithm (no trained model yet).
/// Phase 2 will replace the weights with learned parameters from data.
///
/// ## Scoring Formula:
///   mlScore = w_rating     × ratingScore        (0–1)
///           + w_engagement × engagementScore     (0–1)
///           + w_distance   × distanceScore       (0–1)
///           + w_verify     × verifyBonus         (0 or 1)
///           + w_experience × experienceScore     (0–1)
///           + w_stats      × statsScore          (0–1)
///           + w_newbie     × newProviderBonus    (0 or boost)
///
/// ## Safety Rules:
///   • New providers (ratingCount < 3) get a cold-start bonus to prevent burial
///   • Premium subscription providers get a mild ranking boost (not free)
///   • Score is NEVER the sole factor — must pass eligibility filters first
///   • Admin can override rank via a pinned flag in Firestore
class MLProviderRankingService {
  MLProviderRankingService._();

  // --- Weight Configuration ---
  // Phase 1 weights are heuristic; Phase 2 will tune these from click/conversion data.
  static const double _wRating = 0.30; // Rating quality (most important)
  static const double _wDistance = 0.25; // Proximity to customer
  static const double _wEngagement = 0.15; // Profile views + calls + WhatsApp
  static const double _wVerify = 0.10; // KYC + certificate verified
  static const double _wExperience = 0.10; // Years of experience
  static const double _wStats = 0.10; // Acceptance + completion rate from provider_stats

  // Cold-start bonus: providers with < 3 ratings get boosted so they don't
  // permanently rank below established providers.
  static const double _coldStartBonus = 0.12;

  // Subscription boost: premium providers get a mild bump (not a hijack).
  static const double _premiumBoost = 0.05;
  static const double _proBoost = 0.02;

  // Cap on engagement normalization (beyond this, marginal return is low)
  static const double _maxEngagementSignals = 500.0;

  /// Main entry point: rank a list of eligible providers for a given customer.
  ///
  /// [providers] — pre-filtered list (approved + available + subscription active)
  /// [providerStatsMap] — optional map of providerId → stats from `provider_stats`
  ///   collection; if empty, stats component is skipped gracefully.
  static List<ServiceProviderModel> rankProviders(
    List<ServiceProviderModel> providers, {
    Map<String, Map<String, dynamic>> providerStatsMap = const {},
  }) {
    if (providers.isEmpty) return providers;

    // Compute statistics needed for normalization across the candidate set
    final maxEngagement = _computeMaxEngagement(providers);
    final maxExperience = providers
        .map((p) => p.experienceYears.toDouble())
        .fold(1.0, (a, b) => a > b ? a : b);

    // Score each provider
    final scored = providers.map((p) {
      final score = _computeScore(
        provider: p,
        maxEngagement: maxEngagement,
        maxExperience: maxExperience,
        stats: providerStatsMap[p.id],
      );
      return _ScoredProvider(provider: p, score: score);
    }).toList();

    // Sort descending by score
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((s) => s.provider).toList();
  }

  /// Compute the ML score for a single provider.
  static double _computeScore({
    required ServiceProviderModel provider,
    required double maxEngagement,
    required double maxExperience,
    Map<String, dynamic>? stats,
  }) {
    double score = 0.0;

    // 1. RATING SCORE (0–1)
    // Uses Bayesian-style weighting: new providers default toward 3.5/5 average
    // rather than their raw 5.0 default, preventing gaming.
    final ratingScore = _bayesianRatingScore(
      rating: provider.rating,
      count: provider.ratingCount,
    );
    score += _wRating * ratingScore;

    // 2. DISTANCE SCORE (0–1) — already calculated and present in distanceKm
    // If no GPS data, skip (don't punish providers unfairly).
    final distKm = provider.distanceKm;
    if (distKm != null && distKm >= 0) {
      final distanceScore = _distanceScore(distKm);
      score += _wDistance * distanceScore;
    } else {
      // No distance data: give neutral 0.5 so distance component doesn't hurt
      score += _wDistance * 0.5;
    }

    // 3. ENGAGEMENT SCORE (0–1)
    // Combines totalViews + totalCalls + totalWhatsAppClicks (weighted by intent strength)
    final engagementScore = _engagementScore(
      provider: provider,
      maxEngagement: maxEngagement,
    );
    score += _wEngagement * engagementScore;

    // 4. VERIFICATION BONUS (0 or 1)
    final verifyScore = _verificationScore(provider);
    score += _wVerify * verifyScore;

    // 5. EXPERIENCE SCORE (0–1)
    final experienceScore = maxExperience > 0
        ? (provider.experienceYears.toDouble() / maxExperience).clamp(0.0, 1.0)
        : 0.0;
    score += _wExperience * experienceScore;

    // 6. PROVIDER STATS SCORE (0–1) — from provider_stats collection
    if (stats != null) {
      final statsScore = _providerStatsScore(stats);
      score += _wStats * statsScore;
    } else {
      // No stats yet → neutral 0.5 (don't penalize new providers)
      score += _wStats * 0.5;
    }

    // 7. COLD-START BONUS for new providers (< 3 ratings)
    // Without this, new providers would always rank last despite being qualified.
    if (provider.ratingCount < 3) {
      score += _coldStartBonus;
    }

    // 8. SUBSCRIPTION BOOST (mild — signal of commitment, not pay-to-win)
    final plan = provider.subscriptionPlan.toLowerCase();
    if (plan.contains('premium')) {
      score += _premiumBoost;
    } else if (plan.contains('pro')) {
      score += _proBoost;
    }

    return score;
  }

  /// Bayesian rating: pulls rating toward global mean (3.5) when count is low.
  /// Formula: (count × rating + C × globalMean) / (count + C)
  /// where C = confidence threshold (set to 5 reviews).
  static double _bayesianRatingScore({
    required double rating,
    required int count,
    double globalMean = 3.5,
    double confidenceC = 5.0,
    double maxRating = 5.0,
  }) {
    final adjustedRating =
        (count * rating + confidenceC * globalMean) / (count + confidenceC);
    return (adjustedRating / maxRating).clamp(0.0, 1.0);
  }

  /// Distance score: inverse exponential decay.
  /// 0 km → 1.0, 5 km → ~0.6, 10 km → ~0.4, 20+ km → ~0.1
  static double _distanceScore(double distKm) {
    if (distKm <= 0) return 1.0;
    return (1.0 / (1.0 + distKm * 0.15)).clamp(0.0, 1.0);
  }

  /// Engagement score using intent-weighted signals.
  /// Calls > WhatsApp > Views in terms of conversion intent strength.
  static double _engagementScore({
    required ServiceProviderModel provider,
    required double maxEngagement,
  }) {
    if (maxEngagement <= 0) return 0.0;
    final weighted = provider.totalCalls * 3.0 +
        provider.totalWhatsAppClicks * 2.0 +
        provider.totalViews * 1.0;
    return (weighted / maxEngagement).clamp(0.0, 1.0);
  }

  /// Verification score: checks KYC status + experience certificate.
  static double _verificationScore(ServiceProviderModel provider) {
    double v = 0.0;
    if (provider.isVerified || provider.kycStatus == 'approved') {
      v += 0.6;
    }
    if (provider.hasExperienceCertificate &&
        provider.experienceCertificateStatus == 'verified') {
      v += 0.4;
    }
    return v.clamp(0.0, 1.0);
  }

  /// Stats score based on acceptance + completion rates.
  /// These come from the `provider_stats` Firestore collection.
  static double _providerStatsScore(Map<String, dynamic> stats) {
    final total = (stats['totalLeadsReceived'] as num?)?.toInt() ?? 0;
    final accepted = (stats['totalAccepted'] as num?)?.toInt() ?? 0;
    final completed = (stats['totalCompleted'] as num?)?.toInt() ?? 0;

    if (total == 0) return 0.5; // No data → neutral

    final acceptanceRate = accepted / total;
    final completionRate = accepted > 0 ? completed / accepted : 0.0;

    // Weighted: acceptance matters more than completion for ranking
    return ((acceptanceRate * 0.6) + (completionRate * 0.4)).clamp(0.0, 1.0);
  }

  /// Maximum engagement signal across all providers in the candidate set.
  /// Used for normalization so scores are relative to current search results.
  static double _computeMaxEngagement(List<ServiceProviderModel> providers) {
    double max = 1.0;
    for (final p in providers) {
      final e = p.totalCalls * 3.0 +
          p.totalWhatsAppClicks * 2.0 +
          p.totalViews * 1.0;
      if (e > max) max = e;
    }
    return max.clamp(1.0, _maxEngagementSignals);
  }
}

/// Internal helper to carry score alongside the provider model.
class _ScoredProvider {
  final ServiceProviderModel provider;
  final double score;
  const _ScoredProvider({required this.provider, required this.score});
}

/// [MLSearchLogger] — Logs customer search queries for demand analysis.
///
/// Every search query (non-empty) is written to `analytics_events` collection.
/// This data feeds:
///   • Category demand trends
///   • Unmet service detection (queries with 0 results)
///   • Time-of-day search patterns
///   • Area-based demand hotspots
class MLSearchLogger {
  MLSearchLogger._();

  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Log a customer search query.
  ///
  /// Call this inside [fetchProviders] whenever [searchQuery] is non-empty.
  /// [resultCount] = 0 signals unmet demand — especially valuable for admin.
  static Future<void> logSearchQuery({
    required String query,
    required String categoryId,
    required String area,
    required int resultCount,
    String? customerId,
  }) async {
    if (query.trim().isEmpty) return;
    try {
      await _fs.collection('analytics_events').add({
        'eventType': 'search_query',
        'query': query.trim().toLowerCase(),
        'categoryId': categoryId,
        'area': area,
        'resultCount': resultCount,
        'customerId': customerId ?? 'anonymous',
        'timestamp': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Search logging failure must NEVER interrupt the search itself
    }
  }
}
