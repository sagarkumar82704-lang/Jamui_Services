import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/favourites/data/services/customer_favourites_service.dart';

void main() {
  group('Customer Favourites Service Tests', () {
    test('Test 1: buildDocId creates unique deterministic ID for customer-provider pair', () {
      final docId = CustomerFavouritesService.buildDocId('cust_123', 'prov_456');
      expect(docId, equals('cust_123_prov_456'));

      final docId2 = CustomerFavouritesService.buildDocId('cust_123', 'prov_789');
      expect(docId2, equals('cust_123_prov_789'));
    });

    test('Test 2: Empty customer or provider ID returns false safely without crashing', () async {
      final service = CustomerFavouritesService();
      final result1 = await service.toggleFavourite(
        customerId: '',
        providerId: 'prov_123',
        makeFavourite: true,
      );
      expect(result1, isFalse);

      final result2 = await service.toggleFavourite(
        customerId: 'cust_123',
        providerId: '',
        makeFavourite: true,
      );
      expect(result2, isFalse);

      final isFav = await service.isProviderFavourite('', '');
      expect(isFav, isFalse);
    });

    test('Test 3: Empty customer ID streams an empty set of favourite IDs', () async {
      final service = CustomerFavouritesService();
      final stream = service.getFavouriteIdsStream('');
      final firstEmission = await stream.first;
      expect(firstEmission, isEmpty);
    });
  });
}
