abstract class WebHostBridge {
  static bool get isHostAvailable => false;

  static void notify(String message) {
    // No-op on mobile / desktop platforms
  }

  static Future<Map<String, dynamic>?> requestNativeLocation({
    Duration timeout = const Duration(seconds: 28),
  }) async => null;
}
