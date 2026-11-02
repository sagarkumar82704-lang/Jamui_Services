import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../discovery/data/models/service_provider_model.dart';
import '../../../discovery/domain/entities/service_provider_entity.dart';

class CustomerFavouritesService {
  static CustomerFavouritesService _instance = CustomerFavouritesService._internal();

  factory CustomerFavouritesService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return CustomerFavouritesService._internal(firestore: firestore);
    }
    return _instance;
  }

  CustomerFavouritesService._internal({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static String buildDocId(String customerId, String providerId) => '${customerId}_$providerId';

  String? _subscribedCustomerId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSubscription;
  StreamSubscription<User?>? _authSubscription;
  final ValueNotifier<Set<String>> _favouritesNotifier = ValueNotifier<Set<String>>(<String>{});

  /// Expose value listenable for high-performance reactive UI updates without extra streams
  ValueNotifier<Set<String>> get favouritesNotifier => _favouritesNotifier;

  /// Current cached favourite IDs
  Set<String> get currentFavouriteIds => _favouritesNotifier.value;

  /// Ensure a single shared Firestore snapshot subscription is active for the given customer
  void ensureSubscribed(String customerId) {
    if (customerId.isEmpty) {
      clearSubscription();
      return;
    }
    if (_subscribedCustomerId == customerId && _firestoreSubscription != null) {
      return;
    }

    clearSubscription();
    _subscribedCustomerId = customerId;

    _firestoreSubscription = _firestore
        .collection('favourites')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .listen(
      (snapshot) {
        final ids = snapshot.docs
            .map((doc) => (doc.data()['providerId'] as String?) ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        _favouritesNotifier.value = ids;
      },
      onError: (e) {
        debugPrint('⚠️ [CustomerFavouritesService] Stream error: $e');
      },
    );
  }

  /// Automatically clear and sync subscription on user login / logout
  void initAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        clearSubscription();
      } else if (user.uid != _subscribedCustomerId) {
        ensureSubscribed(user.uid);
      }
    });
  }

  /// Clear the active subscription and reset in-memory cached favourites
  void clearSubscription() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _subscribedCustomerId = null;
    _favouritesNotifier.value = <String>{};
  }

  /// Reset singleton state (for unit and widget testing)
  @visibleForTesting
  static void resetForTesting({FirebaseFirestore? firestore}) {
    _instance.clearSubscription();
    _instance._authSubscription?.cancel();
    _instance._authSubscription = null;
    _instance = CustomerFavouritesService._internal(firestore: firestore);
  }

  /// Real-time stream of favourited provider IDs for the authenticated customer.
  /// Uses the single shared Firestore snapshot subscription to prevent N-listener storm.
  Stream<Set<String>> getFavouriteIdsStream(String customerId) {
    if (customerId.isEmpty) {
      return Stream.value(<String>{});
    }

    ensureSubscribed(customerId);

    late StreamController<Set<String>> controller;
    void listener() {
      if (!controller.isClosed) {
        controller.add(_favouritesNotifier.value);
      }
    }

    controller = StreamController<Set<String>>(
      onListen: () {
        controller.add(_favouritesNotifier.value);
        _favouritesNotifier.addListener(listener);
      },
      onCancel: () {
        _favouritesNotifier.removeListener(listener);
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Toggle favourite state for a customer-provider pair with optimistic update
  Future<bool> toggleFavourite({
    required String customerId,
    required String providerId,
    required bool makeFavourite,
  }) async {
    if (customerId.isEmpty || providerId.isEmpty) return false;

    // Optimistically update local notifier for instant UI feedback
    final current = Set<String>.from(_favouritesNotifier.value);
    if (makeFavourite) {
      current.add(providerId);
    } else {
      current.remove(providerId);
    }
    _favouritesNotifier.value = current;

    final docId = buildDocId(customerId, providerId);
    final docRef = _firestore.collection('favourites').doc(docId);

    try {
      if (makeFavourite) {
        await docRef.set({
          'customerId': customerId,
          'providerId': providerId,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      } else {
        await docRef.delete();
        return false;
      }
    } catch (e) {
      // Revert optimistic update on failure
      final reverted = Set<String>.from(_favouritesNotifier.value);
      if (makeFavourite) {
        reverted.remove(providerId);
      } else {
        reverted.add(providerId);
      }
      _favouritesNotifier.value = reverted;
      rethrow;
    }
  }

  /// Check if a single provider is favourited
  Future<bool> isProviderFavourite(String customerId, String providerId) async {
    if (customerId.isEmpty || providerId.isEmpty) return false;
    // Check in-memory cache first if active for this customer
    if (_subscribedCustomerId == customerId) {
      return _favouritesNotifier.value.contains(providerId);
    }
    final docId = buildDocId(customerId, providerId);
    try {
      final docSnap = await _firestore.collection('favourites').doc(docId).get();
      return docSnap.exists;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  void setSubscribedCustomerForTesting(String customerId) {
    _subscribedCustomerId = customerId;
  }

  /// Realtime stream of full Provider objects for customer's favourites screen
  Stream<List<ServiceProviderEntity>> getFavouriteProvidersStream(String customerId) {
    if (customerId.isEmpty) {
      return Stream.value(<ServiceProviderEntity>[]);
    }

    return _firestore
        .collection('favourites')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .asyncMap((favSnap) async {
      final providerIds = favSnap.docs
          .map((d) => (d.data()['providerId'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (providerIds.isEmpty) return <ServiceProviderEntity>[];

      // Fetch corresponding provider docs in batches (up to 30 per query)
      final List<ServiceProviderEntity> result = [];
      for (var i = 0; i < providerIds.length; i += 30) {
        final end = (i + 30 < providerIds.length) ? i + 30 : providerIds.length;
        final chunk = providerIds.sublist(i, end);

        final providersSnap = await _firestore
            .collection('providers')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in providersSnap.docs) {
          final data = doc.data();
          final provider = ServiceProviderModel.fromMap(data, doc.id);
          if (provider.isApprovedAndLive) {
            result.add(provider);
          }
        }
      }

      return result;
    });
  }
}
