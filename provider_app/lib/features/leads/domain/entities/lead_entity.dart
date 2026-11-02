import 'package:equatable/equatable.dart';

enum LeadStatus {
  newLead,
  viewed,
  accepted,
  rejected,
  completed,
  cancelled;

  String get displayNameHindi {
    switch (this) {
      case LeadStatus.newLead:
        return 'नया इनक्वायरी';
      case LeadStatus.viewed:
        return 'देखा गया';
      case LeadStatus.accepted:
        return 'स्वीकृत (Accepted)';
      case LeadStatus.rejected:
        return 'अस्वीकृत (Rejected)';
      case LeadStatus.completed:
        return 'कार्य पूर्ण (Completed)';
      case LeadStatus.cancelled:
        return 'रद्द (Cancelled)';
    }
  }
}

class LeadEntity extends Equatable {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String providerId;
  final String categoryId;
  final String categoryTitle;
  final String serviceName;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final LeadStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // --- ML DATA FOUNDATION: Status transition timestamps ---
  // These fields are required for:
  //  • Provider response time calculation (createdAt → viewedAt → acceptedAt)
  //  • Acceptance rate: accepted / (accepted + rejected)
  //  • Completion rate: completed / accepted
  //  • Lead quality prediction model features
  final DateTime? viewedAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  // --- ML FEATURE: Customer area for geo-demand analysis ---
  final String customerArea;

  // --- ML FEATURE: Preferred scheduling data ---
  final String preferredDate;
  final String preferredTimeSlot;

  // --- ML FEATURE: Visiting charge snapshot at lead time ---
  final double visitingCharge;

  const LeadEntity({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.providerId,
    required this.categoryId,
    required this.categoryTitle,
    required this.serviceName,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.viewedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.completedAt,
    this.cancelledAt,
    this.customerArea = '',
    this.preferredDate = '',
    this.preferredTimeSlot = '',
    this.visitingCharge = 0.0,
  });

  // --- ML COMPUTED PROPERTIES ---

  /// Time from lead creation until the provider accepted it (in minutes).
  /// Returns null if the lead was never accepted.
  int? get responseTimeMinutes {
    if (acceptedAt == null) return null;
    return acceptedAt!.difference(createdAt).inMinutes;
  }

  /// Whether the provider description is detailed enough (ML quality signal).
  bool get hasDetailedDescription => description.trim().split(' ').length >= 5;

  /// Hour of day when lead was created (for time-of-day demand patterns).
  int get createdHour => createdAt.hour;

  /// Day of week when lead was created (0=Monday, 6=Sunday).
  int get createdWeekday => createdAt.weekday;

  LeadEntity copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? providerId,
    String? categoryId,
    String? categoryTitle,
    String? serviceName,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    LeadStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? viewedAt,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? customerArea,
    String? preferredDate,
    String? preferredTimeSlot,
    double? visitingCharge,
  }) {
    return LeadEntity(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      providerId: providerId ?? this.providerId,
      categoryId: categoryId ?? this.categoryId,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      serviceName: serviceName ?? this.serviceName,
      description: description ?? this.description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewedAt: viewedAt ?? this.viewedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      customerArea: customerArea ?? this.customerArea,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTimeSlot: preferredTimeSlot ?? this.preferredTimeSlot,
      visitingCharge: visitingCharge ?? this.visitingCharge,
    );
  }

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        customerPhone,
        providerId,
        categoryId,
        categoryTitle,
        serviceName,
        description,
        address,
        latitude,
        longitude,
        status,
        createdAt,
        updatedAt,
        viewedAt,
        acceptedAt,
        rejectedAt,
        completedAt,
        cancelledAt,
        customerArea,
        preferredDate,
        preferredTimeSlot,
        visitingCharge,
      ];
}
