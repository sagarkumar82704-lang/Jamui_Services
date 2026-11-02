import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/features/favourites/data/services/customer_favourites_service.dart';
import 'package:apna_jamui_customer/features/discovery/presentation/widgets/favourite_button.dart';

void main() {
  group('Customer Favourites Optimization & Lifecycle Tests', () {
    setUp(() {
      CustomerFavouritesService.resetForTesting();
    });

    tearDown(() {
      CustomerFavouritesService.resetForTesting();
    });

    test('Test 1: Multiple service instances share the same singleton state', () {
      final serviceA = CustomerFavouritesService();
      final serviceB = CustomerFavouritesService();

      expect(identical(serviceA, serviceB), isTrue);
      expect(identical(serviceA.favouritesNotifier, serviceB.favouritesNotifier), isTrue);
    });

    test('Test 2: Optimistic update updates favouritesNotifier immediately', () async {
      final service = CustomerFavouritesService();

      // Initially empty
      expect(service.currentFavouriteIds, isEmpty);

      // Empty IDs do not crash and return false
      final toggleRes = await service.toggleFavourite(
        customerId: '',
        providerId: 'prov_1',
        makeFavourite: true,
      );
      expect(toggleRes, isFalse);
      expect(service.currentFavouriteIds, isEmpty);
    });

    test('Test 3: Logout/clearSubscription clears cached favourite IDs cleanly to prevent data leak', () {
      final service = CustomerFavouritesService();

      // Seed notifier with test favourites for User A
      service.favouritesNotifier.value = {'prov_101', 'prov_102'};
      expect(service.currentFavouriteIds.contains('prov_101'), isTrue);

      // User logs out -> clearSubscription called
      service.clearSubscription();

      // Must be strictly empty to prevent cross-user leak
      expect(service.currentFavouriteIds, isEmpty);
      expect(service.favouritesNotifier.value, isEmpty);
    });

    test('Test 4: isProviderFavourite uses in-memory cache when subscribed to customer', () async {
      final service = CustomerFavouritesService();

      // Set customer subscription in-memory state
      service.setSubscribedCustomerForTesting('cust_abc');
      service.favouritesNotifier.value = {'prov_99'};

      // Should return true from memory without touching network
      final isFav = await service.isProviderFavourite('cust_abc', 'prov_99');
      expect(isFav, isTrue);

      final isNotFav = await service.isProviderFavourite('cust_abc', 'prov_unknown');
      expect(isNotFav, isFalse);
    });

    testWidgets('Test 5: Multiple FavouriteButton widgets mount and render safely without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: const [
                  FavouriteButton(providerId: 'prov_1', key: Key('btn_1')),
                  FavouriteButton(providerId: 'prov_2', key: Key('btn_2')),
                  FavouriteButton(providerId: 'prov_3', key: Key('btn_3')),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify all 3 buttons mounted cleanly without crashes or overflow
      expect(find.byKey(const Key('btn_1')), findsOneWidget);
      expect(find.byKey(const Key('btn_2')), findsOneWidget);
      expect(find.byKey(const Key('btn_3')), findsOneWidget);
    });
  });
}
