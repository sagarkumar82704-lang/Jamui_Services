import 'dart:async';
// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'package:apna_jamui_customer/features/auth/domain/entities/customer_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/auth_exception_handler.dart';
import '../../domain/repositories/customer_auth_repository.dart';
import 'customer_auth_event.dart';
import 'customer_auth_state.dart';

class CustomerAuthBloc extends Bloc<CustomerAuthEvent, CustomerAuthState> {
  final CustomerAuthRepository authRepository;
  final FirebaseAuth? _firebaseAuth;
  static const String _cachedCustomerProfileKey = 'cached_customer_profile_v2';

  CustomerAuthBloc({
    required this.authRepository,
    FirebaseAuth? firebaseAuth,
  })  : _firebaseAuth = firebaseAuth,
        super(const CustomerAuthInitialState()) {
    on<CheckCustomerAuthStatusEvent>(_onCheckStatus);
    on<CheckCustomerProfilesAfterAuthEvent>(_onCheckProfilesAfterAuth);
    on<SignInWithEmailEvent>(_onSignInWithEmail);
    on<RegisterWithEmailEvent>(_onRegisterWithEmail);
    on<SendPasswordResetEvent>(_onSendPasswordReset);
    on<SaveCustomerProfileEvent>(_onSaveProfile);
    on<CustomerSignOutEvent>(_onSignOut);
  }

  User? get _currentUser {
    try {
      return _firebaseAuth?.currentUser ?? FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheCustomerProfile(CustomerEntity customer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'id': customer.id,
        'phoneNumber': customer.phoneNumber,
        'fullName': customer.fullName,
        'email': customer.email,
        'jamuiArea': customer.jamuiArea,
        'address': customer.address,
        'latitude': customer.latitude,
        'longitude': customer.longitude,
        'createdAt': customer.createdAt.toIso8601String(),
        'updatedAt': customer.updatedAt?.toIso8601String(),
      };
      await prefs.setString(_cachedCustomerProfileKey, jsonEncode(map));
      await prefs.setString('customer_active_uid', customer.id);
      await prefs.setString('customer_active_role', 'customer');
    } catch (_) {}
  }

  Future<CustomerEntity?> _getCachedCustomerProfile(String expectedUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cachedCustomerProfileKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (map['id'] == expectedUid && (map['fullName'] as String?)?.trim().isNotEmpty == true) {
          return CustomerEntity(
            id: map['id'] as String,
            phoneNumber: (map['phoneNumber'] as String?) ?? '',
            fullName: map['fullName'] as String,
            email: map['email'] as String?,
            jamuiArea: (map['jamuiArea'] as String?) ?? 'जमुई',
            address: (map['address'] as String?) ?? '',
            latitude: (map['latitude'] as num?)?.toDouble(),
            longitude: (map['longitude'] as num?)?.toDouble(),
            createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
            updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _checkProfilesAndRoute(
    String uid,
    String? phoneNumber,
    Emitter<CustomerAuthState> emit,
  ) async {
    emit(const CustomerAuthLoadingState(message: 'खाता विवरण जाँचा जा रहा है...'));

    // 1. FAST-PATH: Load cached customer profile immediately (<20ms)
    final cachedCustomer = await _getCachedCustomerProfile(uid);
    if (cachedCustomer != null && cachedCustomer.fullName.trim().isNotEmpty) {
      emit(CustomerAuthenticatedState(cachedCustomer));

      // Asynchronously refresh in background without delaying startup
      unawaited(Future(() async {
        try {
          final remoteCustomer = await authRepository.getCustomerProfile(uid);
          if (remoteCustomer != null && remoteCustomer.fullName.trim().isNotEmpty) {
            await _cacheCustomerProfile(remoteCustomer);
          }
        } catch (_) {}
      }));
      return;
    }

    try {
      // 2. NETWORK PATH: Strictly load customer profile from users collection
      CustomerEntity? customer;
      bool isNetworkFailure = false;
      try {
        customer = await authRepository
            .getCustomerProfile(uid)
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        isNetworkFailure = true;
        debugPrint('⚠️ [CustomerAuthBloc] Profile network lookup error: $e');
      }

      if (customer != null && customer.fullName.trim().isNotEmpty) {
        // Prioritize verified phone number from FirebaseAuth session
        String verifiedPhone = phoneNumber ?? '';
        try {
          final currentUser = _currentUser;
          if (verifiedPhone.isEmpty && currentUser?.phoneNumber != null && currentUser!.phoneNumber!.isNotEmpty) {
            verifiedPhone = currentUser.phoneNumber!;
          }
        } catch (_) {}

        CustomerEntity effectiveCustomer = customer;
        if (verifiedPhone.isNotEmpty && customer.phoneNumber != verifiedPhone) {
          effectiveCustomer = customer.copyWith(phoneNumber: verifiedPhone);
          try {
            authRepository.saveCustomerProfile(effectiveCustomer);
          } catch (_) {}
        }

        await _cacheCustomerProfile(effectiveCustomer);
        emit(CustomerAuthenticatedState(effectiveCustomer));
        return;
      }

      // If network failure occurred (timeout, offline, socket exception):
      // Do NOT log out authenticated user! Keep user authenticated with safe customer entity.
      if (isNetworkFailure) {
        final currentUser = _currentUser;
        final phone = phoneNumber ?? currentUser?.phoneNumber ?? '';
        final fallbackCustomer = CustomerEntity(
          id: uid,
          phoneNumber: phone,
          fullName: 'ग्राहक',
          createdAt: DateTime.now(),
        );
        await _cacheCustomerProfile(fallbackCustomer);
        emit(CustomerAuthenticatedState(fallbackCustomer));
        return;
      }

      // Check if user is registered as a Provider in 'providers' collection
      if (!isNetworkFailure) {
        try {
          final providerData = await authRepository.getProviderProfile(uid);
          if (providerData != null) {
            await authRepository.signOut();
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_cachedCustomerProfileKey);
            await prefs.remove('customer_active_uid');
            await prefs.remove('customer_active_role');
            emit(const CustomerAuthFailureState(
              'यह खाता Jamui Services Provider Portal (कारीगर) के लिए पंजीकृत है। कृपया Provider App में लॉगिन करें या ग्राहक के रूप में नया खाता बनाएं।',
            ));
            return;
          }
        } catch (_) {}
      }

      // Legitimate clean fetch returned null: user does not have a customer profile in Firestore yet.
      // New Customer profile setup required.
      String userPhone = phoneNumber ?? '';
      try {
        final currentUser = _currentUser;
        if (userPhone.isEmpty) userPhone = currentUser?.phoneNumber ?? '';
      } catch (_) {}

      // Strictly pass email as null so provider registered email is NEVER used as fallback
      emit(CustomerProfileSetupRequiredState(
        userId: uid,
        email: null,
        phoneNumber: userPhone,
      ));
    } catch (e) {
      // If error occurs but user is authenticated in Firebase Auth, preserve authentication!
      final currentUser = _currentUser;
      if (currentUser != null) {
        final fallbackCustomer = CustomerEntity(
          id: uid,
          phoneNumber: phoneNumber ?? currentUser.phoneNumber ?? '',
          fullName: 'ग्राहक',
          createdAt: DateTime.now(),
        );
        emit(CustomerAuthenticatedState(fallbackCustomer));
      } else {
        emit(CustomerAuthFailureState('खाता जांच में समस्या हुई: $e'));
      }
    }
  }

  Future<void> _onCheckStatus(
    CheckCustomerAuthStatusEvent event,
    Emitter<CustomerAuthState> emit,
  ) async {
    emit(const CustomerAuthLoadingState(message: 'सेशन जाँच किया जा रहा है...'));
    try {
      // 1. Check current synchronous user
      User? currentFirebaseUser = _currentUser;

      // 2. If null on cold boot, give Firebase Auth opportunity to restore credentials from disk
      if (currentFirebaseUser == null) {
        try {
          final auth = _firebaseAuth ?? FirebaseAuth.instance;
          currentFirebaseUser = await auth
              .authStateChanges()
              .first
              .timeout(const Duration(milliseconds: 1200));
        } catch (_) {
          currentFirebaseUser = _currentUser;
        }
      }

      if (currentFirebaseUser == null) {
        emit(const CustomerUnauthenticatedState());
        return;
      }

      await _checkProfilesAndRoute(
        currentFirebaseUser.uid,
        currentFirebaseUser.phoneNumber,
        emit,
      );
    } catch (_) {
      emit(const CustomerUnauthenticatedState());
    }
  }

  Future<void> _onCheckProfilesAfterAuth(
    CheckCustomerProfilesAfterAuthEvent event,
    Emitter<CustomerAuthState> emit,
  ) async {
    await _checkProfilesAndRoute(event.uid, event.phoneNumber, emit);
  }

  Future<void> _onSaveProfile(
    SaveCustomerProfileEvent event,
    Emitter<CustomerAuthState> emit,
  ) async {
    emit(const CustomerAuthLoadingState(message: 'प्रोफ़ाइल सहेजा जा रहा है...'));
    try {
      await authRepository
          .saveCustomerProfile(event.customer)
          .timeout(const Duration(seconds: 8));
      await _cacheCustomerProfile(event.customer);
      emit(CustomerAuthenticatedState(event.customer));
    } catch (e) {
      emit(const CustomerAuthFailureState('प्रोफ़ाइल सहेजने में त्रुटि हुई। कृपया पुनः प्रयास करें।'));
    }
  }

  Future<void> _onSignInWithEmail(
    SignInWithEmailEvent event,
    Emitter<CustomerAuthState> emit,
  ) async {
    emit(const CustomerAuthLoadingState(message: 'लॉगिन किया जा रहा है...'));
    try {
      final customer = await authRepository.signInWithEmail(
        email: event.email,
        password: event.password,
      );

      final currentFirebaseUser = _currentUser;
      final uid = currentFirebaseUser?.uid ?? customer?.id ?? '';
      final phone = currentFirebaseUser?.phoneNumber ?? customer?.phoneNumber ?? '';

      if (uid.isNotEmpty) {
        await _checkProfilesAndRoute(uid, phone, emit);
      } else if (customer != null && customer.fullName.isNotEmpty) {
        await _cacheCustomerProfile(customer);
        emit(CustomerAuthenticatedState(customer));
      } else {
        emit(CustomerProfileSetupRequiredState(
          userId: uid,
          email: event.email,
          phoneNumber: phone,
        ));
      }
    } catch (e) {
      String cleanMessage = e.toString();
      if (cleanMessage.startsWith('Exception: ')) {
        cleanMessage = cleanMessage.substring(11);
      } else {
        cleanMessage = AuthExceptionHandler.handleException(e);
      }
      emit(CustomerAuthFailureState(cleanMessage));
    }
  }

  Future<void> _onRegisterWithEmail(
    RegisterWithEmailEvent event,
    Emitter<CustomerAuthState> emit,
  ) async {
    emit(const CustomerAuthLoadingState(message: 'खाता बनाया जा रहा है...'));
    try {
      final customer = await authRepository.registerWithEmail(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        phoneNumber: event.phoneNumber,
        jamuiArea: event.jamuiArea,
        address: event.address,
        latitude: event.latitude,
        longitude: event.longitude,
      );

      final currentFirebaseUser = _currentUser;
      final uid = currentFirebaseUser?.uid ?? customer?.id ?? '';

      if (uid.isNotEmpty) {
        final freshCustomer = await authRepository.getCustomerProfile(uid) ?? customer;
        if (freshCustomer != null) {
          await _cacheCustomerProfile(freshCustomer);
          emit(CustomerAuthenticatedState(freshCustomer));
          return;
        }
      }

      if (customer != null) {
        await _cacheCustomerProfile(customer);
        emit(CustomerAuthenticatedState(customer));
      } else {
        emit(CustomerProfileSetupRequiredState(
          userId: uid,
          email: event.email,
          phoneNumber: event.phoneNumber,
        ));
      }
    } catch (e) {
      String cleanMessage = e.toString();
      if (cleanMessage.startsWith('Exception: ')) {
        cleanMessage = cleanMessage.substring(11);
      } else {
        cleanMessage = AuthExceptionHandler.handleException(e);
      }
      emit(CustomerAuthFailureState(cleanMessage));
    }
  }

  Future<void> _onSendPasswordReset(
    SendPasswordResetEvent event,
    Emitter<CustomerAuthState> emit,
  ) async {
    emit(const CustomerAuthLoadingState(message: 'रीसेट लिंक भेजा जा रहा है...'));
    try {
      await authRepository.sendPasswordResetEmail(event.email);
      emit(CustomerPasswordResetSentState(event.email));
    } catch (e) {
      String cleanMessage = e.toString();
      if (cleanMessage.startsWith('Exception: ')) {
        cleanMessage = cleanMessage.substring(11);
      } else {
        cleanMessage = AuthExceptionHandler.handleException(e);
      }
      emit(CustomerAuthFailureState(cleanMessage));
    }
  }

  Future<void> _onSignOut(
    CustomerSignOutEvent event,
    Emitter<CustomerAuthState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedCustomerProfileKey);
      await prefs.remove('customer_active_uid');
      await prefs.remove('customer_active_role');
    } catch (_) {}
    await authRepository.signOut();
    emit(const CustomerUnauthenticatedState());
  }
}
