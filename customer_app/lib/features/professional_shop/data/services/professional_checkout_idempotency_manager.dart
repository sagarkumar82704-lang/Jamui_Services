import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/professional_order_entity.dart';

/// Stored record representing an in-flight or unresolved checkout attempt.
class CheckoutAttemptRecord {
  final String idempotencyKey;
  final String shopId;
  final String customerId;
  final String payloadFingerprint;
  final DateTime createdAt;
  final Map<String, dynamic> orderPayload;
  final bool isPending;

  const CheckoutAttemptRecord({
    required this.idempotencyKey,
    required this.shopId,
    required this.customerId,
    required this.payloadFingerprint,
    required this.createdAt,
    required this.orderPayload,
    this.isPending = true,
  });

  Map<String, dynamic> toJson() => {
        'idempotencyKey': idempotencyKey,
        'shopId': shopId,
        'customerId': customerId,
        'payloadFingerprint': payloadFingerprint,
        'createdAt': createdAt.toIso8601String(),
        'orderPayload': orderPayload,
        'isPending': isPending,
      };

  factory CheckoutAttemptRecord.fromJson(Map<String, dynamic> json) =>
      CheckoutAttemptRecord(
        idempotencyKey: json['idempotencyKey'] as String,
        shopId: json['shopId'] as String,
        customerId: json['customerId'] as String,
        payloadFingerprint: json['payloadFingerprint'] as String,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        orderPayload:
            Map<String, dynamic>.from(json['orderPayload'] as Map? ?? {}),
        isPending: json['isPending'] as bool? ?? true,
      );
}

enum ReconciliationResultStatus {
  confirmedPlaced,
  definitivelyNotFound,
  networkError,
}

class ReconciliationResult {
  final ReconciliationResultStatus status;
  final ProfessionalOrderEntity? order;
  final String? errorMessage;

  const ReconciliationResult({
    required this.status,
    this.order,
    this.errorMessage,
  });

  bool get isConfirmedPlaced => status == ReconciliationResultStatus.confirmedPlaced;
  bool get isDefinitivelyNotFound => status == ReconciliationResultStatus.definitivelyNotFound;
  bool get isNetworkError => status == ReconciliationResultStatus.networkError;
}

/// Robust, persistent idempotency manager for Professional Marketplace checkout.
/// Guarantees that network retries, widget rebuilds, and app restarts reuse the
/// exact same attempt identifier without silently creating duplicate orders.
class ProfessionalCheckoutIdempotencyManager {
  static const String prefPrefix = 'pro_unresolved_checkout_';

  final SharedPreferences? _prefs;

  ProfessionalCheckoutIdempotencyManager([this._prefs]);

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  static String storageKey(String customerId, String shopId) =>
      '$prefPrefix${customerId.trim()}_${shopId.trim()}';

  /// Computes a canonical SHA-256 fingerprint strictly matching backend
  /// `functions/index.js` `payloadFingerprint` calculation.
  static String computeFingerprint({
    required String shopId,
    required String deliveryMethod,
    required List<ProfessionalOrderItem> items,
    Map<String, dynamic>? deliveryAddress,
  }) {
    final sortedItemsForHash = items.map((it) {
      final vId = (it.variantId != null && it.variantId!.trim().isNotEmpty)
          ? it.variantId!.trim()
          : null;
      return {
        'productId': it.productId.trim(),
        'variantId': vId,
        'quantity': it.quantity,
      };
    }).toList()
      ..sort((a, b) {
        final keyA =
            (a['productId'] as String) + ((a['variantId'] as String?) ?? '');
        final keyB =
            (b['productId'] as String) + ((b['variantId'] as String?) ?? '');
        return keyA.compareTo(keyB);
      });

    Map<String, dynamic>? normalizedAddress;
    if (deliveryMethod == 'delivery' && deliveryAddress != null) {
      final num rawLat = (deliveryAddress['latitude'] as num?) ?? 0;
      final num rawLng = (deliveryAddress['longitude'] as num?) ?? 0;
      final latVal = (rawLat % 1 == 0) ? rawLat.toInt() : rawLat;
      final lngVal = (rawLng % 1 == 0) ? rawLng.toInt() : rawLng;

      normalizedAddress = {
        'address': (deliveryAddress['address'] as String?)?.trim() ?? '',
        'area': (deliveryAddress['area'] as String?)?.trim() ?? '',
        'contactPhone': (deliveryAddress['contactPhone'] as String?)?.trim() ?? '',
        'customerName': (deliveryAddress['customerName'] as String?)?.trim() ?? '',
        'latitude': latVal,
        'longitude': lngVal,
      };
    }

    final canonicalPayload = {
      'shopId': shopId.trim(),
      'deliveryMethod': deliveryMethod,
      'items': sortedItemsForHash,
      'deliveryAddress': normalizedAddress,
    };

    final canonicalJson = jsonEncode(canonicalPayload);
    return sha256.convert(utf8.encode(canonicalJson)).toString();
  }

  /// Retrieves any active unresolved checkout attempt for customer and shop.
  Future<CheckoutAttemptRecord?> getUnresolvedAttempt({
    required String customerId,
    required String shopId,
  }) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(storageKey(customerId, shopId));
      if (raw == null || raw.trim().isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CheckoutAttemptRecord.fromJson(map);
    } catch (e) {
      debugPrint('⚠️ [IdempotencyManager] Error reading unresolved attempt: $e');
      return null;
    }
  }

  /// Begins or reuses an existing attempt for this customer, shop, and payload.
  /// - If an unresolved attempt exists with identical payload fingerprint:
  ///   Reuses the existing idempotencyKey.
  /// - If no unresolved attempt exists:
  ///   Generates a fresh stable idempotencyKey and persists the attempt.
  /// - If an unresolved attempt exists with a different payload:
  ///   Returns [hasPayloadMismatch] = true so callers can reconcile before submitting.
  Future<({String idempotencyKey, bool isReused, bool hasPayloadMismatch})>
      getOrCreateAttempt({
    required String customerId,
    required String shopId,
    required String payloadFingerprint,
    required Map<String, dynamic> orderPayload,
    String? explicitKey,
  }) async {
    final existing = await getUnresolvedAttempt(
      customerId: customerId,
      shopId: shopId,
    );

    if (existing != null && existing.isPending) {
      if (existing.payloadFingerprint == payloadFingerprint) {
        // Safe retry of identical checkout attempt
        return (
          idempotencyKey: existing.idempotencyKey,
          isReused: true,
          hasPayloadMismatch: false,
        );
      } else {
        // Conflict: cart was modified while previous attempt is unresolved
        return (
          idempotencyKey: existing.idempotencyKey,
          isReused: false,
          hasPayloadMismatch: true,
        );
      }
    }

    final key = explicitKey ??
        'chk_${customerId.trim()}_${shopId.trim()}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

    final record = CheckoutAttemptRecord(
      idempotencyKey: key,
      shopId: shopId.trim(),
      customerId: customerId.trim(),
      payloadFingerprint: payloadFingerprint,
      createdAt: DateTime.now(),
      orderPayload: orderPayload,
      isPending: true,
    );

    try {
      final prefs = await _getPrefs();
      await prefs.setString(
        storageKey(customerId, shopId),
        jsonEncode(record.toJson()),
      );
    } catch (e) {
      debugPrint('⚠️ [IdempotencyManager] Error persisting attempt: $e');
    }

    return (
      idempotencyKey: key,
      isReused: false,
      hasPayloadMismatch: false,
    );
  }

  /// Safely clears the attempt after confirmed resolution (success or duplicate).
  Future<void> clearAttempt({
    required String customerId,
    required String shopId,
  }) async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(storageKey(customerId, shopId));
    } catch (e) {
      debugPrint('⚠️ [IdempotencyManager] Error clearing attempt: $e');
    }
  }

  /// Reconciles an unresolved attempt with Firestore to verify if an order
  /// was already authoritatively created.
  /// Strictly requires a live server response; an empty local cache is NEVER
  /// treated as proof that an order does not exist on the server.
  Future<ReconciliationResult> reconcileWithFirestore({
    required FirebaseFirestore firestore,
    required String customerId,
    required String shopId,
    required String idempotencyKey,
  }) async {
    try {
      final snap = await firestore
          .collection('diamond_orders')
          .where('customerId', isEqualTo: customerId.trim())
          .where('shopId', isEqualTo: shopId.trim())
          .where('idempotencyKey', isEqualTo: idempotencyKey.trim())
          .limit(1)
          .get(const GetOptions(source: Source.server));

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final order = ProfessionalOrderEntity.fromMap(doc.data(), doc.id);
        // Confirmed placed! Clear local attempt record.
        await clearAttempt(customerId: customerId, shopId: shopId);
        return ReconciliationResult(
          status: ReconciliationResultStatus.confirmedPlaced,
          order: order,
        );
      }

      // If the response came from local cache (e.g. offline fallback), it is UNCERTAIN.
      if (snap.metadata.isFromCache) {
        return const ReconciliationResult(
          status: ReconciliationResultStatus.networkError,
          errorMessage:
              'Reconciliation query returned from local cache. Authoritative server verification required.',
        );
      }

      return const ReconciliationResult(
        status: ReconciliationResultStatus.definitivelyNotFound,
      );
    } catch (e) {
      debugPrint('⚠️ [IdempotencyManager] Firestore reconciliation error: $e');
      return ReconciliationResult(
        status: ReconciliationResultStatus.networkError,
        errorMessage: e.toString(),
      );
    }
  }
}

