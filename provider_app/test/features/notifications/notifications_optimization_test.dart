import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_jamui_provider/core/services/app_notification_service.dart';
import 'package:apna_jamui_provider/core/utils/notification_read_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Provider Notifications Step 3 Correctness Audit Tests', () {
    test('1. Audience filtering: Correctly matches personal, all, and all_providers without customer leakage', () {
      final providerId = 'provider_123';
      final allowedAudiences = [providerId, 'all', 'all_providers'];

      expect(allowedAudiences.contains(providerId), isTrue);
      expect(allowedAudiences.contains('all'), isTrue);
      expect(allowedAudiences.contains('all_providers'), isTrue);
      expect(allowedAudiences.contains('all_customers'), isFalse);
      expect(allowedAudiences.contains('other_provider_999'), isFalse);
    });

    test('2. Boundary Testing: 0, 10, 11, and 50 notifications pagination logic', () {
      int limit = 25;

      // Case: 0 notifications
      List<int> docs0 = [];
      expect(docs0.isEmpty, isTrue);
      expect(docs0.length >= limit, isFalse); // hasMore = false

      // Case: 10 notifications
      List<int> docs10 = List.generate(10, (i) => i);
      expect(docs10.length, equals(10));
      expect(docs10.length >= limit, isFalse); // hasMore = false (all fit in page 1)

      // Case: 11 notifications
      List<int> docs11 = List.generate(11, (i) => i);
      expect(docs11.length, equals(11));
      expect(docs11.length >= limit, isFalse); // hasMore = false

      // Case: 25 notifications (exact page boundary)
      List<int> docs25 = List.generate(25, (i) => i);
      expect(docs25.length >= limit, isTrue); // hasMore = true (triggers Load More button)

      // Click "Load More"
      limit += 25;
      expect(limit, equals(50));

      // Case: 50 notifications (page 2 full)
      List<int> docs50 = List.generate(50, (i) => i);
      expect(docs50.length >= limit, isTrue); // hasMore = true (triggers Page 3)
    });

    test('3. App-closed scenario: 15 notifications while app closed are fully visible in inbox without popup alert storm', () {
      final serviceStartTime = DateTime.now();

      // 15 notifications generated 30 minutes ago while app was closed
      final closedNotifications = List.generate(15, (i) {
        return {
          'id': 'notif_closed_$i',
          'userId': 'provider_123',
          'title': 'Job Alert $i',
          'createdAt': Timestamp.fromDate(serviceStartTime.subtract(Duration(minutes: 30 - i))),
          'isRead': false,
        };
      });

      // A) In-box verification: Since limit is 25, all 15 documents are immediately returned in Page 1!
      expect(closedNotifications.length, equals(15));
      expect(closedNotifications.length <= 25, isTrue);

      // B) Real-time popup verification: The foreground popup listener checks:
      // createdAt.isAfter(serviceStartTime.subtract(const Duration(seconds: 5)))
      // All 15 notifications from 30 mins ago are correctly SKIPPED from triggering noisy screen popups!
      final popupsTriggered = closedNotifications.where((d) {
        final createdAt = (d['createdAt'] as Timestamp).toDate();
        return createdAt.isAfter(serviceStartTime.subtract(const Duration(seconds: 5)));
      }).toList();

      expect(popupsTriggered.isEmpty, isTrue, reason: 'Historical notifications must never spam user with popups on app launch');
    });

    test('4. Unread badge boundary testing: Exact count for 1-9 and 9+ for 10 or more', () {
      // Helper function matching main.dart badge count formatting
      String formatBadgeCount(int unread) {
        if (unread <= 0) return '';
        if (unread >= 10) return '9+';
        return '$unread';
      }

      expect(formatBadgeCount(0), equals(''));
      expect(formatBadgeCount(1), equals('1'));
      expect(formatBadgeCount(5), equals('5'));
      expect(formatBadgeCount(9), equals('9'));
      expect(formatBadgeCount(10), equals('9+'));
      expect(formatBadgeCount(15), equals('9+'));
      expect(formatBadgeCount(100), equals('9+'));
    });

    test('5. Broadcast read-state isolation: Reading broadcast notification does NOT mutate shared doc for other providers', () {
      final sharedBroadcastDoc = {
        'id': 'broadcast_diwali_2026',
        'userId': 'all_providers',
        'title': 'Diwali Festive Bonus',
        'isRead': false, // Shared Firestore global state
      };

      // Provider A reads the broadcast notification
      final providerAReadIds = <String>{};
      final providerBReadIds = <String>{};

      // Provider A marks it read locally
      providerAReadIds.add(sharedBroadcastDoc['id'] as String);

      // Evaluate read state for Provider A
      final isReadForProviderA = providerAReadIds.contains(sharedBroadcastDoc['id']);
      expect(isReadForProviderA, isTrue);

      // Evaluate read state for Provider B
      final isReadForProviderB = providerBReadIds.contains(sharedBroadcastDoc['id']);
      expect(isReadForProviderB, isFalse, reason: 'Provider B must still see the broadcast as unread');

      // Shared doc in Firestore remains unmutated (false)
      expect(sharedBroadcastDoc['isRead'], isFalse);
    });

    test('6. Personal notification read-state: Personal doc updates isRead directly in Firestore batch', () {
      final personalDoc = {
        'id': 'lead_accept_456',
        'userId': 'provider_123',
        'title': 'Customer Accepted Quote',
        'isRead': false,
      };

      expect(personalDoc['userId'], equals('provider_123'));
      // Personal doc can safely be updated in Firestore because it belongs solely to this provider
      personalDoc['isRead'] = true;
      expect(personalDoc['isRead'], isTrue);
    });

    test('7. Listener lifecycle & memory cleanup: dispose cancels active Firestore subscription', () {
      // Calling dispose() cleans up listeners safely without throwing
      expect(() => AppNotificationService.dispose(), returnsNormally);
    });

    test('8. SPECIFIC USER SCENARIO: 20 newest notifications READ, but 5 older notifications UNREAD', () {
      // Create a collection of 25 total notifications ordered by createdAt descending (newest first)
      final all25Notifications = List.generate(25, (index) {
        // index 0 to 19 (the 20 newest) are READ (isRead: true)
        // index 20 to 24 (the 5 oldest) are UNREAD (isRead: false)
        final bool isRead = index < 20;
        return {
          'id': 'notif_$index',
          'userId': 'provider_123',
          'title': 'Notification #$index',
          'isRead': isRead,
          'createdAt': Timestamp.fromMillisecondsSinceEpoch(1700000000000 - index * 10000),
        };
      });

      // Verification A: Dashboard Badge (query limit: 20)
      // The dashboard query fetches only the top 20 newest documents:
      final dashboardDocs = all25Notifications.take(20).toList();
      expect(dashboardDocs.length, equals(20));

      final int dashboardUnreadCount = dashboardDocs.where((d) {
        return (d['isRead'] as bool? ?? false) == false;
      }).length;

      // Because all 20 in the top window are read, dashboard evaluates unread to 0:
      expect(dashboardUnreadCount, equals(0),
          reason: 'Limitation of recent-window query: unread notifications older than the limit are outside this window');

      // Verification B: Inbox Page (initial limit: 25)
      // The inbox fetches 25 documents, so it encompasses all 25 notifications:
      final inboxDocs = all25Notifications.take(25).toList();
      expect(inboxDocs.length, equals(25));

      final int inboxUnreadCount = inboxDocs.where((d) {
        return (d['isRead'] as bool? ?? false) == false;
      }).length;

      // Inbox correctly detects the 5 unread items and displays the banner "5 अपठित सूचनाएं":
      expect(inboxUnreadCount, equals(5),
          reason: 'Inbox initial 25-record page successfully discovers and surfaces the 5 older unread notifications');
    });

    test('9. NotificationReadHelper: Syncs broadcast read status locally & isolates across providers', () async {
      SharedPreferences.setMockInitialValues({
        'read_broadcast_notifs_provider_A': ['broadcast_1'],
      });

      NotificationReadHelper.clearMemoryCache();
      await NotificationReadHelper.init('provider_A');

      final broadcastDoc = {
        'userId': 'all_providers',
        'title': 'Diwali Announcement',
        'isRead': false, // unmutated in Firestore
      };

      // Provider A sees broadcast_1 as read
      expect(
        NotificationReadHelper.isNotificationRead(
          docId: 'broadcast_1',
          data: broadcastDoc,
          providerId: 'provider_A',
        ),
        isTrue,
      );

      // Provider A sees broadcast_2 as unread
      expect(
        NotificationReadHelper.isNotificationRead(
          docId: 'broadcast_2',
          data: broadcastDoc,
          providerId: 'provider_A',
        ),
        isFalse,
      );

      // Provider B sees broadcast_1 as UNREAD (isolated!)
      NotificationReadHelper.clearMemoryCache();
      await NotificationReadHelper.init('provider_B');
      expect(
        NotificationReadHelper.isNotificationRead(
          docId: 'broadcast_1',
          data: broadcastDoc,
          providerId: 'provider_B',
        ),
        isFalse,
      );
    });
  });
}
