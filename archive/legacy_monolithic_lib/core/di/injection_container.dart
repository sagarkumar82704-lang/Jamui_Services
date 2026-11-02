import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/firebase_auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// [InjectionContainer] (Service Locator / Dependency Injection)
/// यह पूरी एप्लिकेशन के लिए डिपेंडेंसी इन्वर्जन का मुख्य केंद्र है।
/// अगर कल Firebase से Custom API पर जाना हो, तो केवल यहीं `FirebaseAuthRemoteDataSource` को `ApiAuthRemoteDataSource` से बदलना होगा!
class InjectionContainer {
  InjectionContainer._();

  static final InjectionContainer instance = InjectionContainer._();

  // Core Services
  late final AuthService authService;
  late final FirestoreService firestoreService;

  // Auth Feature
  late final AuthRemoteDataSource authRemoteDataSource;
  late final AuthRepository authRepository;

  /// सभी सिंगलटन और रिपॉजिटरीज़ को इनिशियलाइज़ करें
  void init() {
    authService = AuthService();
    firestoreService = FirestoreService();

    // ⭐️ यहीं से डेटा सोर्स स्विच किया जा सकता है
    authRemoteDataSource = FirebaseAuthRemoteDataSource(
      authService: authService,
      firestoreService: firestoreService,
    );

    authRepository = AuthRepositoryImpl(remoteDataSource: authRemoteDataSource);
  }

  /// नया AuthBloc इंस्टेंस बनाएं
  AuthBloc createAuthBloc() {
    return AuthBloc(authRepository: authRepository);
  }
}
