import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scoped persistent product favorites service for Professional Seller shops.
/// Keeps favorites isolated per customer device with instant reactive UI updates.
class ShopFavoritesService {
  ShopFavoritesService._();
  static final ShopFavoritesService instance = ShopFavoritesService._();

  static const String _prefPrefix = 'pro_shop_fav_';

  // Per-shop notifiers: shopId -> ValueNotifier<Set<String>>
  final Map<String, ValueNotifier<Set<String>>> _notifiers = {};

  String _key(String shopId) => '$_prefPrefix$shopId';

  /// Returns reactive ValueNotifier for the given shop's favorites.
  ValueNotifier<Set<String>> getFavoritesNotifier(String shopId) {
    return _notifiers.putIfAbsent(shopId, () => ValueNotifier<Set<String>>({}));
  }

  /// Loads favorite product IDs for a specific shop
  Future<void> init(String shopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key(shopId)) ?? <String>[];
      getFavoritesNotifier(shopId).value = list.toSet();
    } catch (_) {}
  }

  /// Alias for init — loads favorites for the given shop
  Future<Set<String>> loadFavorites(String shopId) async {
    await init(shopId);
    return getFavoritesNotifier(shopId).value;
  }

  /// Checks if a product is favorited (requires shopId scope)
  bool isFavorite(String shopId, String productId) {
    return getFavoritesNotifier(shopId).value.contains(productId);
  }

  /// Toggles favorite status and persists
  Future<bool> toggleFavorite(String shopId, String productId) async {
    final notifier = getFavoritesNotifier(shopId);
    final current = Set<String>.from(notifier.value);
    final willBeFavorite = !current.contains(productId);

    if (willBeFavorite) {
      current.add(productId);
    } else {
      current.remove(productId);
    }

    notifier.value = current;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key(shopId), current.toList());
    } catch (_) {}

    return willBeFavorite;
  }
}
