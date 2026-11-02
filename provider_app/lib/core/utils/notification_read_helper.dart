import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to manage per-provider read state for shared broadcast notifications
/// without mutating global Firestore documents.
class NotificationReadHelper {
  NotificationReadHelper._();

  static final Set<String> _readBroadcastIds = {};
  static String? _currentProviderId;

  /// Loads locally marked read broadcast notifications from SharedPreferences
  static Future<void> init(String providerId) async {
    if (_currentProviderId == providerId && _readBroadcastIds.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('read_broadcast_notifs_$providerId') ?? [];
      _readBroadcastIds.clear();
      _readBroadcastIds.addAll(list);
      _currentProviderId = providerId;
    } catch (e) {
      debugPrint('⚠️ [NotificationReadHelper] Error loading read broadcast IDs: $e');
    }
  }

  /// Determines whether a notification is read for the given provider.
  /// - Personal notification: reads Firestore document 'isRead' field.
  /// - Broadcast notification: checks local SharedPreferences set for this provider.
  static bool isNotificationRead({
    required String docId,
    required Map<String, dynamic> data,
    required String providerId,
  }) {
    final isPersonal = data['userId'] == providerId;
    if (isPersonal) {
      return (data['isRead'] as bool?) ?? false;
    }
    return _readBroadcastIds.contains(docId);
  }

  /// Marks a single broadcast notification as read for this provider locally
  static Future<void> markBroadcastRead(String docId, String providerId) async {
    _readBroadcastIds.add(docId);
    _currentProviderId = providerId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_broadcast_notifs_$providerId', _readBroadcastIds.toList());
    } catch (e) {
      debugPrint('⚠️ [NotificationReadHelper] Error saving read broadcast ID: $e');
    }
  }

  /// Marks multiple broadcast notifications as read for this provider locally
  static Future<void> markBroadcastsRead(Iterable<String> docIds, String providerId) async {
    _readBroadcastIds.addAll(docIds);
    _currentProviderId = providerId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_broadcast_notifs_$providerId', _readBroadcastIds.toList());
    } catch (e) {
      debugPrint('⚠️ [NotificationReadHelper] Error saving read broadcast IDs: $e');
    }
  }

  /// Exposes read broadcast IDs (primarily for testing and verification)
  static Set<String> get readBroadcastIds => Set.unmodifiable(_readBroadcastIds);

  /// Clears in-memory cache (useful during testing or logout)
  static void clearMemoryCache() {
    _readBroadcastIds.clear();
    _currentProviderId = null;
  }
}
