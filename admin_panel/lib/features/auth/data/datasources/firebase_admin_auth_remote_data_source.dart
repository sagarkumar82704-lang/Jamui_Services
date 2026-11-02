import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_user_model.dart';
import '../../domain/entities/admin_user_entity.dart';
import 'admin_auth_remote_data_source.dart';

class FirebaseAdminAuthRemoteDataSource implements AdminAuthRemoteDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _adminUsersCollection = 'admin_users';
  static const String _auditLogsCollection = 'audit_logs';

  AdminUserModel? _currentSession;

  FirebaseAdminAuthRemoteDataSource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<AdminUserModel?> checkCurrentSession() async {
    if (_currentSession != null) return _currentSession;

    try {
      // Ensure persistent web session is restored from IndexedDB on page reload
      User? user = _auth.currentUser;
      if (user == null) {
        user = await _auth.authStateChanges().first.timeout(
          const Duration(seconds: 4),
          onTimeout: () => null,
        );
      }

      if (user != null) {
        DocumentSnapshot<Map<String, dynamic>>? doc;
        try {
          doc = await _firestore
              .collection(_adminUsersCollection)
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 6));
        } catch (_) {}

        if ((doc == null || !doc.exists || doc.data() == null) &&
            user.email != null) {
          try {
            final emailQuery = await _firestore
                .collection(_adminUsersCollection)
                .where('email', isEqualTo: user.email!.trim())
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 6));
            if (emailQuery.docs.isNotEmpty) {
              doc = emailQuery.docs.first;
            }
          } catch (_) {}
        }

        if (doc != null && doc.exists && doc.data() != null) {
          final adminModel = AdminUserModel.fromMap(doc.data()!, user.uid);
          if (adminModel.status != 'blocked' &&
              adminModel.status != 'inactive') {
            _currentSession = adminModel;
            return _currentSession;
          }
        } else if (user.email != null && user.email!.trim().toLowerCase() == 'admin@jamuiservice.com') {
          final masterAdmin = AdminUserModel(
            uid: user.uid,
            email: user.email!.trim(),
            name: 'Jamui Master Admin',
            role: AdminRole.superAdmin,
            status: 'active',
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
          );
          try {
            await _firestore.collection(_adminUsersCollection).doc(user.uid).set({
              'email': user.email!.trim(),
              'name': 'Jamui Master Admin',
              'role': 'super_admin',
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
              'lastLogin': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}
          _currentSession = masterAdmin;
          return _currentSession;
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<AdminUserModel> signIn(String email, String password) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw Exception('कृपया ईमेल और पासवर्ड दोनों दर्ज करें।');
    }

    try {
      // Set persistence with timeout (non-blocking for private/restricted browser storage)
      try {
        await _auth.setPersistence(Persistence.LOCAL).timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      } catch (_) {}

      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('लॉगिन करने में सर्वर से उत्तर नहीं मिला। कृपया इंटरनेट कनेक्शन जांचें।');
        },
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('ऑथेंटिकेशन विफल रहा।');
      }

      // Check role authorization in Firestore `admin_users` collection
      DocumentSnapshot<Map<String, dynamic>>? doc;
      try {
        doc = await _firestore
            .collection(_adminUsersCollection)
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 6));
      } catch (_) {}

      // Fallback: check by email if doc(user.uid) was not directly set
      if (doc == null || !doc.exists || doc.data() == null) {
        try {
          final emailQuery = await _firestore
              .collection(_adminUsersCollection)
              .where('email', isEqualTo: cleanEmail)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 6));
          if (emailQuery.docs.isNotEmpty) {
            final emailDoc = emailQuery.docs.first;
            final existingData = emailDoc.data();
            // Automatically bind to user.uid so future lookups are instantaneous
            await _firestore
                .collection(_adminUsersCollection)
                .doc(user.uid)
                .set({
                  ...existingData,
                  'uid': user.uid,
                  'lastLogin': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            if (emailDoc.id != user.uid) {
              try {
                await _firestore
                    .collection(_adminUsersCollection)
                    .doc(emailDoc.id)
                    .delete();
              } catch (_) {}
            }
            doc = await _firestore
                .collection(_adminUsersCollection)
                .doc(user.uid)
                .get()
                .timeout(const Duration(seconds: 6));
          }
        } catch (_) {}
      }

      AdminUserModel adminModel;

      if (doc != null && doc.exists && doc.data() != null) {
        adminModel = AdminUserModel.fromMap(doc.data()!, user.uid);

        if (adminModel.status == 'blocked' || adminModel.status == 'inactive') {
          await _auth.signOut();
          throw Exception(
            'आपका एडमिन खाता निष्कासित (Blocked/Inactive) कर दिया गया है।',
          );
        }
      } else {
        final bool isDesignatedMasterAdmin = cleanEmail.toLowerCase() == 'admin@jamuiservice.com';

        // Check if ANY admins exist in system
        bool systemHasAdmins = true;
        try {
          final countSnap = await _firestore
              .collection(_adminUsersCollection)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));
          systemHasAdmins = countSnap.docs.isNotEmpty;
        } catch (_) {
          // If query is denied by security rules, system already has admins and caller is not authorized
          systemHasAdmins = true;
        }

        if (systemHasAdmins && !isDesignatedMasterAdmin) {
          // System already has admins; this user is not authorized
          await _auth.signOut();
          throw Exception(
            'अनधिकृत प्रवेश: आपका ईमेल ($cleanEmail) एडमिन के रूप में अधिकृत नहीं है।',
          );
        }

        // Bootstrap First-time Master Admin or Designated Root Master Admin
        adminModel = AdminUserModel(
          uid: user.uid,
          email: user.email ?? cleanEmail,
          name: isDesignatedMasterAdmin ? 'Jamui Master Admin' : 'Master Admin',
          role: AdminRole.superAdmin,
          status: 'active',
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        );

        try {
          await _firestore.collection(_adminUsersCollection).doc(user.uid).set({
            'email': user.email ?? cleanEmail,
            'name': isDesignatedMasterAdmin ? 'Jamui Master Admin' : 'Master Admin',
            'role': 'super_admin',
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      // Update last login timestamp
      try {
        await _firestore.collection(_adminUsersCollection).doc(user.uid).update(
          {'lastLogin': FieldValue.serverTimestamp()},
        );
      } catch (_) {}

      _currentSession = adminModel;
      await _logAudit(
        user.uid,
        user.email ?? cleanEmail,
        'ADMIN_LOGIN_SUCCESS',
      );
      return adminModel;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw Exception('अमान्य ईमेल या पासवर्ड। कृपया पुनः प्रयास करें।');
      } else if (e.code == 'too-many-requests') {
        throw Exception(
          'बहुत सारे असफल प्रयास। कृपया कुछ मिनट बाद पुनः प्रयास करें।',
        );
      } else {
        throw Exception(e.message ?? 'लॉगिन विफल रहा।');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  @override
  Future<AdminUserModel> registerAdmin({
    required String name,
    required String email,
    required String password,
    String role = 'super_admin',
  }) async {
    final cleanEmail = email.trim();
    final cleanName = name.trim();
    if (cleanEmail.isEmpty || password.isEmpty || cleanName.isEmpty) {
      throw Exception('कृपया नाम, ईमेल और पासवर्ड सभी विवरण भरें।');
    }
    if (password.length < 6) {
      throw Exception('पासवर्ड कम से कम 6 अक्षरों का होना चाहिए।');
    }

    try {
      await _auth.setPersistence(Persistence.LOCAL);

      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('एडमिन रजिस्ट्रेशन विफल रहा।');
      }

      final adminRole = AdminUserModel.parseRole(role);
      final adminModel = AdminUserModel(
        uid: user.uid,
        email: user.email ?? cleanEmail,
        name: cleanName,
        role: adminRole,
        status: 'active',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      await _firestore.collection(_adminUsersCollection).doc(user.uid).set({
        'email': user.email ?? cleanEmail,
        'name': cleanName,
        'role': role,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _currentSession = adminModel;
      await _logAudit(
        user.uid,
        user.email ?? cleanEmail,
        'ADMIN_REGISTER_SUCCESS',
      );
      return adminModel;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('यह ईमेल पहले से पंजीकृत है। कृपया साइन-इन करें।');
      } else if (e.code == 'weak-password') {
        throw Exception(
          'पासवर्ड कमजोर है। कम से कम 6 अक्षरों का पासवर्ड रखें।',
        );
      } else if (e.code == 'invalid-email') {
        throw Exception('अमान्य ईमेल प्रारूप।');
      } else {
        throw Exception(e.message ?? 'रजिस्ट्रेशन विफल रहा।');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (_currentSession != null) {
        await _logAudit(
          _currentSession!.uid,
          _currentSession!.email,
          'ADMIN_LOGOUT',
        );
      }
      await _auth.signOut();
    } catch (_) {}
    _currentSession = null;
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw Exception('पासवर्ड रीसेट लिंक भेजने में समस्या आई।');
    }
  }

  Future<void> _logAudit(String uid, String email, String action) async {
    try {
      await _firestore.collection(_auditLogsCollection).add({
        'adminId': uid,
        'adminEmail': email,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
