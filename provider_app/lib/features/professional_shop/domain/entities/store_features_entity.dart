import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Extensible Provider-Configurable Store Features & Policies Entity
/// Storage: `diamond_shops/{shopId}` (field: `storeFeatures`)
class StoreFeaturesEntity extends Equatable {
  final bool enableHomeDelivery;
  final bool enableStorePickup;
  final double minOrderAmount;
  final double deliveryCharge;
  final double? freeDeliveryThreshold;
  final int estimatedDeliveryMinutes;
  final double maxDeliveryRadiusKm;

  // Order Cancellation & Return Policies
  final bool allowCustomerCancellation;
  final int cancellationWindowMinutes;
  final bool isReturnable;
  final int returnWindowDays;
  final bool isExchangeable;
  final String policyNote;

  // Vacation / Store Notice
  final bool isVacationActive;
  final String vacationMessage;

  // Extensible Custom Registry (Arbitrary provider-defined feature toggles)
  final Map<String, dynamic> customSettings;

  const StoreFeaturesEntity({
    this.enableHomeDelivery = true,
    this.enableStorePickup = true,
    this.minOrderAmount = 0.0,
    this.deliveryCharge = 0.0,
    this.freeDeliveryThreshold,
    this.estimatedDeliveryMinutes = 30,
    this.maxDeliveryRadiusKm = 5.0,
    this.allowCustomerCancellation = true,
    this.cancellationWindowMinutes = 15,
    this.isReturnable = false,
    this.returnWindowDays = 0,
    this.isExchangeable = false,
    this.policyNote = '',
    this.isVacationActive = false,
    this.vacationMessage = '',
    this.customSettings = const {},
  });

  factory StoreFeaturesEntity.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const StoreFeaturesEntity();

    return StoreFeaturesEntity(
      enableHomeDelivery: (map['enableHomeDelivery'] as bool?) ?? true,
      enableStorePickup: (map['enableStorePickup'] as bool?) ?? true,
      minOrderAmount: (map['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryCharge: (map['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
      freeDeliveryThreshold: (map['freeDeliveryThreshold'] as num?)?.toDouble(),
      estimatedDeliveryMinutes: (map['estimatedDeliveryMinutes'] as num?)?.toInt() ?? 30,
      maxDeliveryRadiusKm: (map['maxDeliveryRadiusKm'] as num?)?.toDouble() ?? 5.0,
      allowCustomerCancellation: (map['allowCustomerCancellation'] as bool?) ?? true,
      cancellationWindowMinutes: (map['cancellationWindowMinutes'] as num?)?.toInt() ?? 15,
      isReturnable: (map['isReturnable'] as bool?) ?? false,
      returnWindowDays: (map['returnWindowDays'] as num?)?.toInt() ?? 0,
      isExchangeable: (map['isExchangeable'] as bool?) ?? false,
      policyNote: (map['policyNote'] ?? '').toString(),
      isVacationActive: (map['isVacationActive'] as bool?) ?? false,
      vacationMessage: (map['vacationMessage'] ?? '').toString(),
      customSettings: map['customSettings'] is Map
          ? Map<String, dynamic>.from(map['customSettings'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enableHomeDelivery': enableHomeDelivery,
      'enableStorePickup': enableStorePickup,
      'minOrderAmount': minOrderAmount,
      'deliveryCharge': deliveryCharge,
      if (freeDeliveryThreshold != null) 'freeDeliveryThreshold': freeDeliveryThreshold,
      'estimatedDeliveryMinutes': estimatedDeliveryMinutes,
      'maxDeliveryRadiusKm': maxDeliveryRadiusKm,
      'allowCustomerCancellation': allowCustomerCancellation,
      'cancellationWindowMinutes': cancellationWindowMinutes,
      'isReturnable': isReturnable,
      'returnWindowDays': returnWindowDays,
      'isExchangeable': isExchangeable,
      'policyNote': policyNote,
      'isVacationActive': isVacationActive,
      'vacationMessage': vacationMessage,
      'customSettings': customSettings,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  StoreFeaturesEntity copyWith({
    bool? enableHomeDelivery,
    bool? enableStorePickup,
    double? minOrderAmount,
    double? deliveryCharge,
    double? freeDeliveryThreshold,
    int? estimatedDeliveryMinutes,
    double? maxDeliveryRadiusKm,
    bool? allowCustomerCancellation,
    int? cancellationWindowMinutes,
    bool? isReturnable,
    int? returnWindowDays,
    bool? isExchangeable,
    String? policyNote,
    bool? isVacationActive,
    String? vacationMessage,
    Map<String, dynamic>? customSettings,
  }) {
    return StoreFeaturesEntity(
      enableHomeDelivery: enableHomeDelivery ?? this.enableHomeDelivery,
      enableStorePickup: enableStorePickup ?? this.enableStorePickup,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
      estimatedDeliveryMinutes: estimatedDeliveryMinutes ?? this.estimatedDeliveryMinutes,
      maxDeliveryRadiusKm: maxDeliveryRadiusKm ?? this.maxDeliveryRadiusKm,
      allowCustomerCancellation: allowCustomerCancellation ?? this.allowCustomerCancellation,
      cancellationWindowMinutes: cancellationWindowMinutes ?? this.cancellationWindowMinutes,
      isReturnable: isReturnable ?? this.isReturnable,
      returnWindowDays: returnWindowDays ?? this.returnWindowDays,
      isExchangeable: isExchangeable ?? this.isExchangeable,
      policyNote: policyNote ?? this.policyNote,
      isVacationActive: isVacationActive ?? this.isVacationActive,
      vacationMessage: vacationMessage ?? this.vacationMessage,
      customSettings: customSettings ?? this.customSettings,
    );
  }

  @override
  List<Object?> get props => [
        enableHomeDelivery,
        enableStorePickup,
        minOrderAmount,
        deliveryCharge,
        freeDeliveryThreshold,
        estimatedDeliveryMinutes,
        maxDeliveryRadiusKm,
        isReturnable,
        returnWindowDays,
        isExchangeable,
        isVacationActive,
        customSettings,
      ];
}

