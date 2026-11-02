import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// [ProviderFilterCriteria] holds all active filter states for the Provider List.
class ProviderFilterCriteria {
  final String status; // 'all', 'all_with_deleted', 'pending_approval', 'approved_active', 'rejected', 'suspended_blocked', 'inactive', 'deleted'
  final String categoryId; // 'all' or specific category doc id / title
  final String? categoryTitle;
  final String searchQuery;
  final String jamuiArea; // 'all' or specific area
  final double? radiusKm; // null or 5, 10, 25, 50 km from Jamui center
  final String dateFilter; // 'all', 'today', 'last_7_days', 'last_30_days', 'custom'
  final DateTimeRange? customDateRange;
  final String subscriptionFilter; // 'all', 'active', 'expired', 'trial', 'no_subscription', 'pending_approval'

  const ProviderFilterCriteria({
    this.status = 'all',
    this.categoryId = 'all',
    this.categoryTitle,
    this.searchQuery = '',
    this.jamuiArea = 'all',
    this.radiusKm,
    this.dateFilter = 'all',
    this.customDateRange,
    this.subscriptionFilter = 'all',
  });

  bool get hasActiveFilters {
    return status != 'all' ||
        categoryId != 'all' ||
        searchQuery.trim().isNotEmpty ||
        jamuiArea != 'all' ||
        radiusKm != null ||
        dateFilter != 'all' ||
        subscriptionFilter != 'all';
  }

  int get activeFiltersCount {
    int count = 0;
    if (status != 'all') count++;
    if (categoryId != 'all') count++;
    if (searchQuery.trim().isNotEmpty) count++;
    if (jamuiArea != 'all') count++;
    if (radiusKm != null) count++;
    if (dateFilter != 'all') count++;
    if (subscriptionFilter != 'all') count++;
    return count;
  }

  ProviderFilterCriteria copyWith({
    String? status,
    String? categoryId,
    String? categoryTitle,
    String? searchQuery,
    String? jamuiArea,
    double? radiusKm,
    bool clearRadius = false,
    String? dateFilter,
    DateTimeRange? customDateRange,
    bool clearCustomDateRange = false,
    String? subscriptionFilter,
  }) {
    return ProviderFilterCriteria(
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      searchQuery: searchQuery ?? this.searchQuery,
      jamuiArea: jamuiArea ?? this.jamuiArea,
      radiusKm: clearRadius ? null : (radiusKm ?? this.radiusKm),
      dateFilter: dateFilter ?? this.dateFilter,
      customDateRange: clearCustomDateRange ? null : (customDateRange ?? this.customDateRange),
      subscriptionFilter: subscriptionFilter ?? this.subscriptionFilter,
    );
  }

  static const ProviderFilterCriteria initial = ProviderFilterCriteria();
}

/// [ProviderFilterEvaluator] provides clean, pure filtering logic on provider data records.
class ProviderFilterEvaluator {
  // Jamui Town District HQ coordinates (Bihar, India)
  static const double jamuiCenterLat = 24.9197;
  static const double jamuiCenterLng = 86.2238;

  /// Evaluates whether a given provider document matches all criteria.
  static bool matches(
    Map<String, dynamic> provider,
    ProviderFilterCriteria criteria, {
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();

    // 1. Status Filter
    if (!matchesStatus(provider, criteria.status)) return false;

    // 2. Category Filter
    if (!matchesCategory(provider, criteria.categoryId, categoryTitle: criteria.categoryTitle)) return false;

    // 3. Search Filter (Name, Phone, Email, Business, ID)
    if (!matchesSearch(provider, criteria.searchQuery)) return false;

    // 4. Location Filter (Jamui Area & Radius)
    if (!matchesLocation(provider, area: criteria.jamuiArea, radiusKm: criteria.radiusKm)) return false;

    // 5. Date Filter (Registration createdAt)
    if (!matchesDate(provider, criteria.dateFilter, customRange: criteria.customDateRange, referenceNow: now)) return false;

    // 6. Subscription Filter
    if (!matchesSubscription(provider, criteria.subscriptionFilter, referenceNow: now)) return false;

    return true;
  }

  /// 1. Status filter matching
  static bool matchesStatus(Map<String, dynamic> p, String filter) {
    final status = (p['status'] ?? '').toString().toLowerCase().trim();
    final vStatus = (p['verificationStatus'] ?? '').toString().toLowerCase().trim();
    final kycStatus = (p['kycStatus'] ?? '').toString().toLowerCase().trim();
    final isVerified = p['isVerified'] == true;
    final isActive = p['isActive'] != false;
    final isDeleted = p['isDeleted'] == true;

    final isRejected = status == 'rejected' || vStatus == 'rejected' || kycStatus == 'rejected';
    final isSuspendedOrBlocked = status == 'suspended' || status == 'blocked';

    final isApprovedOrActive = (status == 'approved' || status == 'active' || kycStatus == 'approved' || isVerified) &&
        !isRejected &&
        !isSuspendedOrBlocked;

    final isPending = !isApprovedOrActive && !isRejected && !isSuspendedOrBlocked && !isDeleted;

    switch (filter) {
      case 'all':
        return !isDeleted;
      case 'all_with_deleted':
        return true;
      case 'pending_approval':
        return isPending;
      case 'approved_active':
        return isApprovedOrActive && isActive && !isDeleted;
      case 'rejected':
        return isRejected;
      case 'suspended_blocked':
        return isSuspendedOrBlocked;
      case 'inactive':
        return !isActive && !isDeleted;
      case 'deleted':
        return isDeleted;
      default:
        return !isDeleted;
    }
  }

  /// 2. Category filter matching
  static bool matchesCategory(Map<String, dynamic> p, String categoryId, {String? categoryTitle}) {
    if (categoryId == 'all' || categoryId.trim().isEmpty) return true;

    final primaryCatId = (p['primaryCategoryId'] ?? p['categoryId'] ?? p['category'] ?? '').toString().trim();
    final selectedCatIds = (p['selectedCategoryIds'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .toList() ??
        const <String>[];
    final primaryCatTitle = (p['primaryCategoryTitle'] ?? p['categoryTitle'] ?? p['categoryName'] ?? '').toString().toLowerCase().trim();

    if (primaryCatId == categoryId) return true;
    if (selectedCatIds.contains(categoryId)) return true;

    if (categoryTitle != null && categoryTitle.trim().isNotEmpty) {
      final targetTitle = categoryTitle.toLowerCase().trim();
      if (primaryCatTitle == targetTitle) return true;
      if (selectedCatIds.any((id) => id.toLowerCase() == targetTitle)) return true;
    }

    return false;
  }

  /// 3. Search filter matching (Name, Mobile, Email, Business, ID)
  static bool matchesSearch(Map<String, dynamic> p, String query) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();

    // Provider Name
    final name = (p['fullName'] ?? p['ownerName'] ?? p['name'] ?? '').toString().toLowerCase();
    if (name.contains(q)) return true;

    // Business / Shop Name
    final business = (p['businessName'] ?? p['shopName'] ?? '').toString().toLowerCase();
    if (business.contains(q)) return true;

    // Provider ID
    final id = (p['id'] ?? '').toString().toLowerCase();
    if (id.contains(q)) return true;

    // Email
    final email = (p['email'] ?? '').toString().toLowerCase();
    if (email.contains(q)) return true;

    // Phone (normalized + raw)
    final rawPhone = (p['phoneNumber'] ?? p['phone'] ?? '').toString();
    if (rawPhone.toLowerCase().contains(q)) return true;

    final normalizedQ = normalizePhone(q);
    if (normalizedQ.isNotEmpty && normalizedQ.length >= 3) {
      final normalizedPhone = normalizePhone(rawPhone);
      if (normalizedPhone.contains(normalizedQ)) return true;
    }

    return false;
  }

  /// Normalizes phone number by removing country code, spaces, dashes, parentheses.
  static String normalizePhone(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// 4. Location filter matching
  static bool matchesLocation(
    Map<String, dynamic> p, {
    required String area,
    double? radiusKm,
    double centerLat = jamuiCenterLat,
    double centerLng = jamuiCenterLng,
  }) {
    // Area match
    if (area != 'all' && area.trim().isNotEmpty) {
      final providerArea = (p['jamuiArea'] ?? p['area'] ?? '').toString().toLowerCase();
      final fullAddress = (p['fullAddress'] ?? '').toString().toLowerCase();
      final targetArea = area.toLowerCase().trim();

      final matchesArea = providerArea.contains(targetArea) || fullAddress.contains(targetArea);
      if (!matchesArea) return false;
    }

    // Radius match if specified
    if (radiusKm != null && radiusKm > 0) {
      final lat = (p['latitude'] as num?)?.toDouble();
      final lng = (p['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null || (lat == 0 && lng == 0)) {
        return false;
      }
      final distance = calculateDistanceKm(centerLat, centerLng, lat, lng);
      if (distance > radiusKm) return false;
    }

    return true;
  }

  /// Haversine distance in Kilometers
  static double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  /// 5. Date filter matching (Registration Date createdAt)
  static bool matchesDate(
    Map<String, dynamic> p,
    String dateFilter, {
    DateTimeRange? customRange,
    DateTime? referenceNow,
  }) {
    if (dateFilter == 'all') return true;
    final now = referenceNow ?? DateTime.now();
    final createdAt = parseDateTime(p['createdAt'] ?? p['appliedAt']);
    if (createdAt == null) return false;

    switch (dateFilter) {
      case 'today':
        final startOfToday = DateTime(now.year, now.month, now.day);
        return createdAt.isAfter(startOfToday) || createdAt.isAtSameMomentAs(startOfToday);
      case 'last_7_days':
        final start = now.subtract(const Duration(days: 7));
        return createdAt.isAfter(start);
      case 'last_30_days':
        final start = now.subtract(const Duration(days: 30));
        return createdAt.isAfter(start);
      case 'custom':
        if (customRange == null) return true;
        final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
        final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
        return createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
            createdAt.isBefore(end.add(const Duration(seconds: 1)));
      default:
        return true;
    }
  }

  /// 6. Subscription filter matching
  static bool matchesSubscription(
    Map<String, dynamic> p,
    String filter, {
    DateTime? referenceNow,
  }) {
    if (filter == 'all') return true;
    final now = referenceNow ?? DateTime.now();

    final isSubActive = p['isSubscriptionActive'] == true;
    final isPaid = p['paymentVerified'] == true;
    final plan = (p['subscriptionPlan'] ?? 'free_trial').toString().toUpperCase();
    final approvalStatus = (p['subscriptionApprovalStatus'] ?? p['paymentApprovalStatus'] ?? '').toString().toLowerCase();
    final isPendingApproval = approvalStatus == 'pending_approval' || p['isPendingApproval'] == true;

    final expiry = parseDateTime(p['subscriptionExpiry']);
    final isExpired = (expiry != null && expiry.isBefore(now)) || (!isSubActive && isPaid);
    final isTrial = plan.contains('TRIAL') || (!isPaid && !isSubActive && plan == 'FREE_TRIAL');

    switch (filter) {
      case 'active':
        return isSubActive && (expiry == null || expiry.isAfter(now));
      case 'premium':
        final isPremium = (p['isPremiumEligible'] == true || (p['planLimits'] != null && p['planLimits']['isPremiumCategoryEligible'] == true));
        return isSubActive && isPremium && (expiry == null || expiry.isAfter(now));
      case 'expired':
        return isExpired;
      case 'trial':
        return isTrial;
      case 'no_subscription':
        return !isSubActive && !isPaid && !isTrial && !isPendingApproval;
      case 'pending_approval':
        return isPendingApproval;
      case 'paid':
        return isPaid;
      case 'unpaid':
        return !isPaid;
      default:
        return true;
    }
  }

  /// Robust date parsing supporting Timestamp, DateTime, int (epoch ms), and String
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.tryParse(value.toString());
  }
}
