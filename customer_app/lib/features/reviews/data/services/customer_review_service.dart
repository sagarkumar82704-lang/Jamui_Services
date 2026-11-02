import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/r2_upload_service.dart';
import '../../domain/entities/customer_review_entity.dart';

class CustomerReviewService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;
  final R2UploadService _r2Service;

  CustomerReviewService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
    R2UploadService? r2Service,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker(),
        _r2Service = r2Service ?? R2UploadService();

  /// Mask customer name for privacy (e.g., "Sagar Kumar" -> "Sagar K.", never expose phone/email)
  static String formatPrivacySafeName({
    String? displayName,
    String? email,
    String? phone,
  }) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      final parts = displayName.trim().split(RegExp(r'\s+'));
      if (parts.length > 1) {
        final first = parts.first;
        final lastInitial = parts.last[0].toUpperCase();
        return '$first $lastInitial.';
      }
      return displayName.trim();
    }

    if (email != null && email.contains('@')) {
      final local = email.split('@').first;
      if (local.length > 2) {
        return '${local.substring(0, 2)}***${local.substring(local.length - 1)}';
      }
      return 'सत्यापित ग्राहक';
    }

    return 'सत्यापित ग्राहक (जमुई)';
  }

  /// Pick an image from Camera or Gallery with compression (<5MB validation)
  Future<File?> pickReviewImage({required ImageSource source}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (picked == null) return null;

      final file = File(picked.path);
      final size = await file.length();
      if (size > 5 * 1024 * 1024) {
        throw Exception('फ़ोटो का आकार 5MB से कम होना चाहिए।');
      }

      return file;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload review photo directly to Cloudflare R2 with resilient Firebase Storage fallback.
  /// On successful R2 upload, returns the canonical relative object key (e.g. `reviews/...`).
  /// On failure, gracefully falls back to legacy Firebase Storage download URL.
  Future<String> uploadReviewPhoto({
    required String customerId,
    required String bookingId,
    required File file,
  }) async {
    // 1. Attempt R2 primary upload
    try {
      final r2Result = await _r2Service.uploadFile(
        file,
        folder: 'reviews',
        targetId: bookingId,
      );
      return r2Result.objectKey;
    } catch (r2Error) {
      debugPrint('⚠️ [CustomerReviewService] R2 upload failed, falling back to Firebase Storage: $r2Error');
    }

    // 2. Resilient fallback to Firebase Storage
    try {
      final fileName = 'rev_${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';
      final ref = _storage.ref().child('review_photos').child(customerId).child(bookingId).child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': customerId,
          'bookingId': bookingId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putFile(file, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('फ़ोटो अपलोड करने में त्रुटि: $e');
    }
  }

  /// Upload review photo bytes directly to Cloudflare R2 with resilient Firebase Storage fallback.
  Future<String> uploadReviewPhotoBytes({
    required String customerId,
    required String bookingId,
    required Uint8List bytes,
    String fileName = 'review.jpg',
    String mimeType = 'image/jpeg',
  }) async {
    // 1. Attempt R2 primary upload
    try {
      final r2Result = await _r2Service.uploadBytes(
        bytes: bytes,
        folder: 'reviews',
        fileName: fileName,
        mimeType: mimeType,
        targetId: bookingId,
      );
      return r2Result.objectKey;
    } catch (r2Error) {
      debugPrint('⚠️ [CustomerReviewService] R2 bytes upload failed, falling back to Firebase Storage: $r2Error');
    }

    // 2. Resilient fallback to Firebase Storage
    try {
      final name = 'rev_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = _storage.ref().child('review_photos').child(customerId).child(bookingId).child(name);

      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'uploadedBy': customerId,
          'bookingId': bookingId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('फ़ोटो अपलोड करने में त्रुटि: $e');
    }
  }

  /// Delete unreferenced review photo from Firebase Storage
  Future<void> deleteReviewPhoto(String photoUrl) async {
    try {
      if (photoUrl.isEmpty) return;
      if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
        final ref = _storage.refFromURL(photoUrl);
        await ref.delete();
      }
    } catch (_) {
      // Best-effort cleanup
    }
  }

  /// Fetch existing review for a specific booking and customer
  Future<CustomerReviewEntity?> getReviewForBooking({
    required String bookingId,
    required String customerId,
  }) async {
    try {
      // 1. Direct doc lookup by bookingId
      final docSnap = await _firestore.collection('reviews').doc(bookingId).get();
      if (docSnap.exists && docSnap.data()?['customerId'] == customerId) {
        return CustomerReviewEntity.fromFirestore(docSnap);
      }

      // 2. Fallback query by bookingId / leadId
      final querySnap = await _firestore
          .collection('reviews')
          .where('bookingId', isEqualTo: bookingId)
          .where('customerId', isEqualTo: customerId)
          .limit(1)
          .get();

      if (querySnap.docs.isNotEmpty) {
        return CustomerReviewEntity.fromFirestore(querySnap.docs.first);
      }
    } catch (_) {}
    return null;
  }

  /// Submit or Edit Review with atomic aggregate updates
  Future<CustomerReviewEntity> submitOrEditReview({
    required String bookingId,
    required String providerId,
    required String providerName,
    required int rating, // 1 to 5
    required String comment,
    required List<String> tags,
    required List<String> photoUrls,
    CustomerReviewEntity? existingReview,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('समीक्षा सबमिट करने के लिए कृपया पहले लॉगिन करें।');
    }

    final validRating = rating.clamp(1, 5);
    final isEditing = existingReview != null;
    final reviewDocId = existingReview?.id ?? bookingId;

    final customerDisplayName = formatPrivacySafeName(
      displayName: user.displayName,
      email: user.email,
      phone: user.phoneNumber,
    );

    final reviewRef = _firestore.collection('reviews').doc(reviewDocId);

    // 1. Prepare Review Document Payload
    final reviewData = {
      'bookingId': bookingId,
      'leadId': bookingId,
      'providerId': providerId,
      'providerName': providerName,
      'customerId': user.uid,
      'customerDisplayName': customerDisplayName,
      'rating': validRating,
      'comment': comment.trim(),
      'tags': tags,
      'photoUrls': photoUrls,
      'isEdited': isEditing,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!isEditing) {
      reviewData['createdAt'] = FieldValue.serverTimestamp();
    }

    // Save review document
    await reviewRef.set(reviewData, SetOptions(merge: true));

    // 2. Mark lead/booking as reviewed
    try {
      await _firestore.collection('leads').doc(bookingId).set({
        'hasReviewed': true,
        'reviewRating': validRating,
        'reviewId': reviewDocId,
        'reviewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    // 3. Atomically recalculate and update Provider Aggregates
    await recalculateAndSaveProviderAggregates(providerId);

    final updatedSnap = await reviewRef.get();
    return CustomerReviewEntity.fromFirestore(updatedSnap);
  }

  /// Recalculate Provider Aggregates (Mean Rating + 1..5 Star Distribution)
  Future<Map<String, dynamic>> recalculateAndSaveProviderAggregates(String providerId) async {
    try {
      final reviewsSnap = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .get();

      int totalCount = 0;
      double totalScore = 0.0;
      final Map<String, int> distribution = {
        '5': 0,
        '4': 0,
        '3': 0,
        '2': 0,
        '1': 0,
      };

      for (final doc in reviewsSnap.docs) {
        final data = doc.data();
        final rawRating = (data['rating'] as num?)?.toInt() ?? 5;
        final r = rawRating.clamp(1, 5);

        totalCount++;
        totalScore += r;
        distribution['$r'] = (distribution['$r'] ?? 0) + 1;
      }

      final double avgRating = totalCount > 0
          ? double.parse((totalScore / totalCount).toStringAsFixed(1))
          : 0.0;

      final updateMap = {
        'rating': avgRating,
        'ratingCount': totalCount,
        'ratingDistribution': distribution,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('providers').doc(providerId).set(
        updateMap,
        SetOptions(merge: true),
      );

      return updateMap;
    } catch (e) {
      return {'rating': 0.0, 'ratingCount': 0};
    }
  }
}
