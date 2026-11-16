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

