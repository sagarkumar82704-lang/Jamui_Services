import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/utils/auth_exception_handler.dart';
import '../models/customer_model.dart';

class FirebaseCustomerAuthRemoteDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';

  FirebaseCustomerAuthRemoteDataSource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  User? get currentFirebaseUser => _auth.currentUser;

  Future<CustomerModel?> getCurrentCustomerProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return getCustomerProfile(user.uid);
  }

  Future<CustomerModel?> getCustomerProfile(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final model = CustomerModel.fromMap(doc.data()!, doc.id);
        if (model.fullName.trim().isNotEmpty) {
          return model;
        }
      }

      // Fallback check by phone number: if app was uninstalled or user re-authenticates,
      // recover their existing registered name so they are NOT asked again
      final currentUser = _auth.currentUser;
      final phone = currentUser?.phoneNumber;
      if (phone != null && phone.trim().isNotEmpty) {
        final cleanPhone = phone.trim();
        final rawPhone = cleanPhone.startsWith('+91') ? cleanPhone.substring(3) : cleanPhone;

        final query = await _firestore
            .collection(_usersCollection)
            .where('phoneNumber', whereIn: [cleanPhone, rawPhone, '+91$rawPhone'])
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final foundDoc = query.docs.first;
          final model = CustomerModel.fromMap(foundDoc.data(), foundDoc.id);
          if (model.fullName.trim().isNotEmpty) {
            // Mirror to current uid doc so next lookup is instantaneous
            if (foundDoc.id != uid) {
              await saveCustomerProfile(CustomerModel(
                id: uid,
                phoneNumber: model.phoneNumber.isNotEmpty ? model.phoneNumber : cleanPhone,
                fullName: model.fullName,
                email: model.email,
                jamuiArea: model.jamuiArea,
                address: model.address,
                createdAt: model.createdAt,
              ));
            }
            return model;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getProviderProfile(String uid) async {
    try {
      final doc = await _firestore.collection('providers').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['id'] = doc.id;
        return data;
      }
    } catch (_) {}
    return null;
  }

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String errorMessage) onError,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    final clean = phoneNumber.trim();
    final formatted = clean.startsWith('+') ? clean : '+91$clean';

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formatted,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          onVerificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(AuthExceptionHandler.handleException(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(AuthExceptionHandler.handleException(e));
    }
  }

  Future<UserCredential> verifyOtpCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthExceptionHandler.handleException(e));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthExceptionHandler.handleException(e));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> saveCustomerProfile(CustomerModel customer) async {
    final map = customer.toMap();
    map['updatedAt'] = FieldValue.serverTimestamp();

    try {
      final user = _auth.currentUser;
      if (user != null && customer.fullName.isNotEmpty) {
        await user.updateDisplayName(customer.fullName);
      }
    } catch (_) {}

    await _firestore.collection(_usersCollection).doc(customer.id).set(
          map,
          SetOptions(merge: true),
        );
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthExceptionHandler.handleException(e));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String? jamuiArea,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      if (cred.user != null) {
        await cred.user!.updateDisplayName(fullName.trim());
        final cleanPhone = (phoneNumber ?? '').replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
        final formattedPhone = cleanPhone.startsWith('+91')
            ? cleanPhone
            : (cleanPhone.isNotEmpty ? '+91$cleanPhone' : '');
        final newCustomer = CustomerModel(
          id: cred.user!.uid,
          phoneNumber: formattedPhone,
          fullName: fullName.trim(),
          email: email.trim(),
          jamuiArea: (jamuiArea != null && jamuiArea.trim().isNotEmpty) ? jamuiArea.trim() : 'जमुई',
          address: address?.trim() ?? '',
          latitude: latitude,
          longitude: longitude,
          createdAt: DateTime.now(),
        );
        await saveCustomerProfile(newCustomer);

        // Send non-blocking email verification
        try {
          await cred.user!.sendEmailVerification();
        } catch (_) {}
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthExceptionHandler.handleException(e));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> linkEmailToCurrentAccount({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('सत्र समाप्त हो गया है। कृपया पुनः प्रयास करें।');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password.trim(),
      );
      await user.linkWithCredential(credential);
      // Synchronize email in Firestore
      await _firestore.collection(_usersCollection).doc(user.uid).set({
        'email': email.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthExceptionHandler.handleException(e));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<int> migrateOldCustomerData({
    required String phoneNumber,
    required String newUid,
  }) async {
    try {
      final clean = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (clean.isEmpty) return 0;
      final raw = clean.startsWith('+91') ? clean.substring(3) : clean;
      final formats = [clean, raw, '+91$raw'];

      final oldUsersSnap = await _firestore
          .collection(_usersCollection)
          .where('phoneNumber', whereIn: formats)
          .get();

      int migratedLeadsCount = 0;
      for (final doc in oldUsersSnap.docs) {
        if (doc.id == newUid) continue;

        final oldUid = doc.id;
        final oldData = doc.data();

        // 1. Copy old address/area to new profile if new profile is empty
        final newDocSnap = await _firestore.collection(_usersCollection).doc(newUid).get();
        final newData = newDocSnap.data() ?? {};

        final Map<String, dynamic> updateNew = {};
        final newAddr = (newData['address'] as String?) ?? (newData['formattedAddress'] as String?) ?? '';
        final oldAddr = (oldData['address'] as String?) ?? (oldData['formattedAddress'] as String?) ?? '';
        if (newAddr.isEmpty && oldAddr.isNotEmpty) {
          updateNew['address'] = oldAddr;
          updateNew['formattedAddress'] = oldAddr;
        }
        final newArea = (newData['jamuiArea'] as String?) ?? '';
        final oldArea = (oldData['jamuiArea'] as String?) ?? '';
        if ((newArea.isEmpty || newArea == 'जमुई') && oldArea.isNotEmpty) {
          updateNew['jamuiArea'] = oldArea;
        }
        if (updateNew.isNotEmpty) {
          await _firestore.collection(_usersCollection).doc(newUid).set(updateNew, SetOptions(merge: true));
        }

        // 2. Re-assign leads where customerId == oldUid to newUid
        final leadsSnap = await _firestore
            .collection('leads')
            .where('customerId', isEqualTo: oldUid)
            .get();

        for (final leadDoc in leadsSnap.docs) {
          await leadDoc.reference.update({
            'customerId': newUid,
            'migratedFromCustomerId': oldUid,
            'migratedAt': FieldValue.serverTimestamp(),
          });
          migratedLeadsCount++;
        }

        // 3. Flag old document as migrated
        await doc.reference.set({
          'isMigrated': true,
          'migratedToUid': newUid,
          'migratedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return migratedLeadsCount;
    } catch (_) {
      return 0;
    }
  }

  bool isCurrentAccountPhoneOnly() {
    final user = _auth.currentUser;
    if (user == null) return false;
    final hasPasswordProvider = user.providerData.any((p) => p.providerId == 'password');
    final hasEmail = user.email != null && user.email!.trim().isNotEmpty;
    return !hasPasswordProvider && !hasEmail;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthExceptionHandler.handleException(e));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

