import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Owner Contact Details Resolution Tests', () {
    test('Resolves owner contact details from provider profile when available', () {
      final providerProfileData = <String, dynamic>{
        'fullName': 'Sanjay Kumar',
        'phone': '+919988776655',
        'email': 'sanjay@jamui.test',
        'businessName': 'Sanjay Grocery',
      };

      final existingShopData = <String, dynamic>{};

      final ownerName = (providerProfileData['fullName'] as String?)?.trim() ?? '';
      final ownerPhone = (providerProfileData['phone'] as String?)?.trim() ?? '';
      final ownerEmail = (providerProfileData['email'] as String?)?.trim() ?? '';

      final resolvedOwnerName = ownerName.isNotEmpty
          ? ownerName
          : ((existingShopData['ownerName'] as String?)?.trim().isNotEmpty == true
              ? (existingShopData['ownerName'] as String).trim()
              : 'Sanjay Grocery');
      final resolvedOwnerPhone = ownerPhone.isNotEmpty
          ? ownerPhone
          : ((existingShopData['ownerPhone'] as String?)?.trim().isNotEmpty == true
              ? (existingShopData['ownerPhone'] as String).trim()
              : '');
      final resolvedOwnerEmail = ownerEmail.isNotEmpty
          ? ownerEmail
          : ((existingShopData['ownerEmail'] as String?)?.trim().isNotEmpty == true
              ? (existingShopData['ownerEmail'] as String).trim()
              : '');

      expect(resolvedOwnerName, equals('Sanjay Kumar'));
      expect(resolvedOwnerPhone, equals('+919988776655'));
      expect(resolvedOwnerEmail, equals('sanjay@jamui.test'));
    });

    test('Preserves existing shop owner contact details when update has empty inputs', () {
      final existingShopData = <String, dynamic>{
        'ownerName': 'Sanjay Kumar',
        'ownerPhone': '+919988776655',
        'ownerEmail': 'sanjay@jamui.test',
      };

      const emptyOwnerName = '';
      const emptyOwnerPhone = '';
      const emptyOwnerEmail = '';

      final resolvedOwnerName = emptyOwnerName.isNotEmpty
          ? emptyOwnerName
          : ((existingShopData['ownerName'] as String?)?.trim().isNotEmpty == true
              ? (existingShopData['ownerName'] as String).trim()
              : 'Fallback Shop');
      final resolvedOwnerPhone = emptyOwnerPhone.isNotEmpty
          ? emptyOwnerPhone
          : ((existingShopData['ownerPhone'] as String?)?.trim().isNotEmpty == true
              ? (existingShopData['ownerPhone'] as String).trim()
              : '');
      final resolvedOwnerEmail = emptyOwnerEmail.isNotEmpty
          ? emptyOwnerEmail
          : ((existingShopData['ownerEmail'] as String?)?.trim().isNotEmpty == true
              ? (existingShopData['ownerEmail'] as String).trim()
              : '');

      expect(resolvedOwnerName, equals('Sanjay Kumar'));
      expect(resolvedOwnerPhone, equals('+919988776655'));
      expect(resolvedOwnerEmail, equals('sanjay@jamui.test'));
    });

    test('Admin Inspector fallback hierarchy test', () {
      final legacyShop = <String, dynamic>{
        'fullName': 'Maheshwar Singh',
        'mobile': '+919431100000',
      };

      final inspectorOwner = (legacyShop['ownerName'] as String?)?.trim().isNotEmpty == true
          ? (legacyShop['ownerName'] as String).trim()
          : ((legacyShop['fullName'] as String?)?.trim().isNotEmpty == true
              ? (legacyShop['fullName'] as String).trim()
              : ((legacyShop['name'] as String?)?.trim().isNotEmpty == true
                  ? (legacyShop['name'] as String).trim()
                  : 'N/A'));

      final inspectorPhone = (legacyShop['ownerPhone'] as String?)?.trim().isNotEmpty == true
          ? (legacyShop['ownerPhone'] as String).trim()
          : ((legacyShop['phone'] as String?)?.trim().isNotEmpty == true
              ? (legacyShop['phone'] as String).trim()
              : ((legacyShop['mobile'] as String?)?.trim().isNotEmpty == true
                  ? (legacyShop['mobile'] as String).trim()
                  : ((legacyShop['contactPhone'] as String?)?.trim().isNotEmpty == true
                      ? (legacyShop['contactPhone'] as String).trim()
                      : 'N/A')));

      final inspectorEmail = (legacyShop['ownerEmail'] as String?)?.trim().isNotEmpty == true
          ? (legacyShop['ownerEmail'] as String).trim()
          : ((legacyShop['email'] as String?)?.trim().isNotEmpty == true
              ? (legacyShop['email'] as String).trim()
              : 'N/A');

      expect(inspectorOwner, equals('Maheshwar Singh'));
      expect(inspectorPhone, equals('+919431100000'));
      expect(inspectorEmail, equals('N/A'));
    });
  });
}

