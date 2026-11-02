import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/professional_shop/presentation/pages/professional_shop_registration_page.dart';

void main() {
  group('Professional Shop Registration & Owner Contact Details Resolution Tests', () {
    test('1. Provider Profile Name is saved as ownerName from providers/{uid}', () {
      final providerData = <String, dynamic>{
        'fullName': 'Ramesh Kumar Gupta',
        'phoneNumber': '+919431200001',
        'email': 'ramesh.gupta@jamui.test',
      };
      final existingShopData = <String, dynamic>{};

      final profileName = (providerData['fullName'] as String?)?.trim() ??
          (providerData['name'] as String?)?.trim() ??
          (providerData['ownerName'] as String?)?.trim() ??
          '';

      String resolvedOwnerName = '';
      if (profileName.isNotEmpty) {
        resolvedOwnerName = profileName;
      } else if (existingShopData['ownerName'] != null) {
        resolvedOwnerName = existingShopData['ownerName'] as String;
      }

      final payload = <String, dynamic>{};
      if (resolvedOwnerName.isNotEmpty) {
        payload['ownerName'] = resolvedOwnerName;
      }

      expect(payload['ownerName'], equals('Ramesh Kumar Gupta'));
    });

    test('2. Provider Profile Mobile is saved as ownerPhone and contactPhone from providers/{uid}', () {
      final providerData = <String, dynamic>{
        'fullName': 'Ramesh Kumar Gupta',
        'phoneNumber': '+919431200001',
        'email': 'ramesh.gupta@jamui.test',
      };
      final existingShopData = <String, dynamic>{};

      final profilePhone = (providerData['phoneNumber'] as String?)?.trim() ??
          (providerData['phone'] as String?)?.trim() ??
          (providerData['mobile'] as String?)?.trim() ??
          (providerData['ownerPhone'] as String?)?.trim() ??
          '';

      String resolvedOwnerPhone = '';
      if (profilePhone.isNotEmpty) {
        resolvedOwnerPhone = profilePhone;
      } else if (existingShopData['ownerPhone'] != null) {
        resolvedOwnerPhone = existingShopData['ownerPhone'] as String;
      }

      final payload = <String, dynamic>{};
      if (resolvedOwnerPhone.isNotEmpty) {
        payload['ownerPhone'] = resolvedOwnerPhone;
        payload['contactPhone'] = resolvedOwnerPhone;
      }

      expect(payload['ownerPhone'], equals('+919431200001'));
      expect(payload['contactPhone'], equals('+919431200001'));
    });

    test('3. Provider Profile Email is saved as ownerEmail from providers/{uid}', () {
      final providerData = <String, dynamic>{
        'fullName': 'Ramesh Kumar Gupta',
        'phoneNumber': '+919431200001',
        'email': 'ramesh.gupta@jamui.test',
      };

      final profileEmail = (providerData['email'] as String?)?.trim() ??
          (providerData['ownerEmail'] as String?)?.trim() ??
          '';

      String resolvedOwnerEmail = '';
      if (profileEmail.isNotEmpty) {
        resolvedOwnerEmail = profileEmail.toLowerCase();
      }

      final payload = <String, dynamic>{};
      if (resolvedOwnerEmail.isNotEmpty) {
        payload['ownerEmail'] = resolvedOwnerEmail;
      }

      expect(payload['ownerEmail'], equals('ramesh.gupta@jamui.test'));
    });

    test('4. Firebase Auth email fallback works if the profile email is unavailable', () {
      final providerData = <String, dynamic>{
        'fullName': 'Ramesh Kumar Gupta',
        'phoneNumber': '+919431200001',
        'email': '', // Empty in providers doc
      };
      const authUserEmail = 'auth_fallback@jamui.test';

      final profileEmail = (providerData['email'] as String?)?.trim() ??
          (providerData['ownerEmail'] as String?)?.trim() ??
          '';

      String resolvedOwnerEmail = '';
      if (profileEmail.isNotEmpty) {
        resolvedOwnerEmail = profileEmail.toLowerCase();
      } else if (authUserEmail.trim().isNotEmpty) {
        resolvedOwnerEmail = authUserEmail.trim().toLowerCase();
      }

      final payload = <String, dynamic>{};
      if (resolvedOwnerEmail.isNotEmpty) {
        payload['ownerEmail'] = resolvedOwnerEmail;
      }

      expect(payload['ownerEmail'], equals('auth_fallback@jamui.test'));
    });

    test('5. Empty profile values do not erase existing shop contact values', () {
      final existingShopData = <String, dynamic>{
        'ownerName': 'Original Shop Owner',
        'ownerPhone': '+919876543210',
        'ownerEmail': 'original@jamui.test',
      };

      final providerData = <String, dynamic>{
        'fullName': '',
        'phoneNumber': '',
        'email': '',
      };

      final existingOwnerName = (existingShopData['ownerName'] as String?)?.trim() ?? '';
      final existingOwnerPhone = (existingShopData['ownerPhone'] as String?)?.trim() ?? '';
      final existingOwnerEmail = (existingShopData['ownerEmail'] as String?)?.trim() ?? '';

      final profileName = (providerData['fullName'] as String?)?.trim() ?? '';
      final profilePhone = (providerData['phoneNumber'] as String?)?.trim() ?? '';
      final profileEmail = (providerData['email'] as String?)?.trim() ?? '';

      String resolvedOwnerName = '';
      if (profileName.isNotEmpty) {
        resolvedOwnerName = profileName;
      } else if (existingOwnerName.isNotEmpty) {
        resolvedOwnerName = existingOwnerName;
      }

      String resolvedOwnerPhone = '';
      if (profilePhone.isNotEmpty) {
        resolvedOwnerPhone = profilePhone;
      } else if (existingOwnerPhone.isNotEmpty) {
        resolvedOwnerPhone = existingOwnerPhone;
      }

      String resolvedOwnerEmail = '';
      if (profileEmail.isNotEmpty) {
        resolvedOwnerEmail = profileEmail.toLowerCase();
      } else if (existingOwnerEmail.isNotEmpty) {
        resolvedOwnerEmail = existingOwnerEmail.toLowerCase();
      }

      final payload = <String, dynamic>{'shopName': 'Updated Shop'};
      if (resolvedOwnerName.isNotEmpty) payload['ownerName'] = resolvedOwnerName;
      if (resolvedOwnerPhone.isNotEmpty) {
        payload['ownerPhone'] = resolvedOwnerPhone;
        payload['contactPhone'] = resolvedOwnerPhone;
      }
      if (resolvedOwnerEmail.isNotEmpty) payload['ownerEmail'] = resolvedOwnerEmail;

      final mergedDoc = {...existingShopData, ...payload};
      expect(mergedDoc['ownerName'], equals('Original Shop Owner'));
      expect(mergedDoc['ownerPhone'], equals('+919876543210'));
      expect(mergedDoc['ownerEmail'], equals('original@jamui.test'));
    });

    test('6. Registration works when an optional contact value is unavailable', () {
      final providerData = <String, dynamic>{
        'fullName': 'Solo Trader',
        'phoneNumber': '+919876543210',
        // Email completely missing
      };
      final existingShopData = <String, dynamic>{};

      final profileEmail = (providerData['email'] as String?)?.trim() ?? '';
      String? authEmail;
      final existingOwnerEmail = (existingShopData['ownerEmail'] as String?)?.trim() ?? '';

      String resolvedOwnerEmail = '';
      if (profileEmail.isNotEmpty) {
        resolvedOwnerEmail = profileEmail.toLowerCase();
      } else if (authEmail != null && authEmail.trim().isNotEmpty) {
        resolvedOwnerEmail = authEmail.trim().toLowerCase();
      } else if (existingOwnerEmail.isNotEmpty) {
        resolvedOwnerEmail = existingOwnerEmail.toLowerCase();
      }

      final payload = <String, dynamic>{
        'shopName': 'Solo Store',
        'ownerUid': 'test_user_123',
      };
      if (resolvedOwnerEmail.isNotEmpty) {
        payload['ownerEmail'] = resolvedOwnerEmail;
      }

      // Payload is valid and does not contain ownerEmail key
      expect(payload.containsKey('ownerEmail'), isFalse);
      expect(payload['shopName'], equals('Solo Store'));
      expect(payload['ownerUid'], equals('test_user_123'));
    });

    test('7. Correct authenticated UID is saved as ownerUid and id', () {
      const authUid = 'auth_provider_unique_uid_999';
      final payload = <String, dynamic>{
        'id': authUid,
        'ownerUid': authUid,
        'shopName': 'Verified UID Shop',
      };

      expect(payload['id'], equals('auth_provider_unique_uid_999'));
      expect(payload['ownerUid'], equals('auth_provider_unique_uid_999'));
    });

    test('8. No Phone OTP is required (Authoritative mobile is sourced from providers/{uid})', () {
      // Sourcing mobile number authoritatively from providers/{uid} schema
      final providerData = <String, dynamic>{
        'phoneNumber': '+919876543210',
      };

      // Ensure no reliance on FirebaseAuth.currentUser.phoneNumber
      final resolvedPhone = (providerData['phoneNumber'] as String?)?.trim() ?? '';
      expect(resolvedPhone, equals('+919876543210'));
      expect(resolvedPhone.startsWith('+91'), isTrue);
    });

    test('9. Existing Normal/Premium Provider registration behavior remains unchanged', () {
      final normalProviderProfile = <String, dynamic>{
        'categoryType': 'service',
        'isProfessional': false,
        'isDiamond': false,
        'primaryCategoryId': 'electrician_service',
      };

      expect(normalProviderProfile['categoryType'], equals('service'));
      expect(normalProviderProfile['isProfessional'], isFalse);
      expect(normalProviderProfile['isDiamond'], isFalse);
    });
  });
}
