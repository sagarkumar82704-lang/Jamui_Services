import '../entities/customer_entity.dart';

abstract class CustomerAuthRepository {
  Future<CustomerEntity?> getCurrentCustomer();
  Future<CustomerEntity?> getCustomerProfile(String uid);
  Future<Map<String, dynamic>?> getProviderProfile(String uid);

  Future<CustomerEntity?> signInWithEmail({
    required String email,
    required String password,
  });

  Future<CustomerEntity?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String? jamuiArea,
    String? address,
    double? latitude,
    double? longitude,
  });

  Future<void> sendPasswordResetEmail(String email);
  Future<void> saveCustomerProfile(CustomerEntity customer);
  Future<void> signOut();
}


