import 'package:flutter/material.dart';
import '../../features/discovery/domain/entities/service_provider_entity.dart';
import 'app_network_or_base64_image.dart';

class ProviderAvatarWidget extends StatelessWidget {
  final ServiceProviderEntity provider;
  final double size;
  final bool isCircular;
  final bool showVerifiedBadge;

  const ProviderAvatarWidget({
    super.key,
    required this.provider,
    this.size = 48,
    this.isCircular = true,
    this.showVerifiedBadge = true,
  });

  /// Curated set of 48 distinct male-person style emojis representing
  /// technicians, craftsmen, mechanics, electricians, professionals, and service workers
  /// across diverse skin tones and styles.
  static const List<String> malePersonEmojis = [
    '👨🏻‍🔧', '👨🏼‍🔧', '👨🏽‍🔧', '👨🏾‍🔧', '👨🏿‍🔧',
    '👷🏻‍♂️', '👷🏼‍♂️', '👷🏽‍♂️', '👷🏾‍♂️', '👷🏿‍♂️',
    '👨🏻‍💻', '👨🏼‍💻', '👨🏽‍💻', '👨🏾‍💻', '👨🏿‍💻',
    '👨🏻‍🎨', '👨🏼‍🎨', '👨🏽‍🎨', '👨🏾‍🎨', '👨🏿‍🎨',
    '👨🏻‍💼', '👨🏼‍💼', '👨🏽‍💼', '👨🏾‍💼', '👨🏿‍💼',
    '👨🏻‍🏭', '👨🏼‍🏭', '👨🏽‍🏭', '👨🏾‍🏭', '👨🏿‍🏭',
    '👨🏻‍🍳', '👨🏼‍🍳', '👨🏽‍🍳', '👨🏾‍🍳', '👨🏿‍🍳',
    '👨🏻‍🌾', '👨🏼‍🌾', '👨🏽‍🌾', '👨🏾‍🌾', '👨🏿‍🌾',
    '🧔🏻‍♂️', '🧔🏼‍♂️', '🧔🏽‍♂️', '🧔🏾‍♂️', '🧔🏿‍♂️',
    '🧑🏻‍🔧', '🧑🏼‍🔧', '🧑🏽‍🔧',
  ];

  static const List<Color> avatarBgColors = [
    Color(0xFFFEF3C7), // Warm Amber
    Color(0xFFE0F2FE), // Soft Sky
    Color(0xFFDCFCE7), // Mint Green
    Color(0xFFFCE7F3), // Soft Rose
    Color(0xFFF3E8FF), // Soft Purple
    Color(0xFFE0E7FF), // Soft Indigo
    Color(0xFFCCFBF1), // Soft Teal
    Color(0xFFFFEDD5), // Soft Orange
  ];

  static const List<Color> avatarBorderColors = [
    Color(0xFFFDE68A),
    Color(0xFFBAE6FD),
    Color(0xFFBBF7D0),
    Color(0xFFFBCFE8),
    Color(0xFFE9D5FF),
    Color(0xFFC7D2FE),
    Color(0xFF99F6E4),
    Color(0xFFFED7AA),
  ];

  /// Standard 32-bit FNV-1a non-cryptographic hash for uniform dispersion.
  static int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Returns a stable, deterministic male-person emoji assigned to the provider.
  /// Uses a combined hash of provider ID and category ID to ensure providers
  /// in the same category also receive distinct emojis.
  static String getEmojiForProvider(String providerId, {String categoryId = ''}) {
    if (providerId.isEmpty && categoryId.isEmpty) {
      return malePersonEmojis.first;
    }
    final idHash = _fnv1a(providerId);
    final catHash = _fnv1a(categoryId);
    final combined = (idHash ^ (catHash * 31)).abs();
    final index = combined % malePersonEmojis.length;
    return malePersonEmojis[index];
  }

  static Color getBgColorForProvider(String providerId) {
    if (providerId.isEmpty) return avatarBgColors.first;
    final hash = _fnv1a(providerId).abs();
    return avatarBgColors[hash % avatarBgColors.length];
  }

  static Color getBorderColorForProvider(String providerId) {
    if (providerId.isEmpty) return avatarBorderColors.first;
    final hash = _fnv1a(providerId).abs();
    return avatarBorderColors[hash % avatarBorderColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasRealPhoto = provider.profileImageUrl.trim().isNotEmpty;
    final borderRadius = isCircular ? BorderRadius.circular(size / 2) : BorderRadius.circular(size * 0.28);

    if (hasRealPhoto) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: SizedBox(
              width: size,
              height: size,
              child: AppNetworkOrBase64Image(
                imageUrl: provider.profileImageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => _buildEmojiFallback(borderRadius),
              ),
            ),
          ),
          if (showVerifiedBadge && provider.isVerified) _buildVerifiedBadge(),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _buildEmojiFallback(borderRadius),
        if (showVerifiedBadge && provider.isVerified) _buildVerifiedBadge(),
      ],
    );
  }

  Widget _buildEmojiFallback(BorderRadius borderRadius) {
    final emoji = getEmojiForProvider(provider.id, categoryId: provider.categoryId);
    final bgColor = getBgColorForProvider(provider.id);
    final borderColor = getBorderColorForProvider(provider.id);
    final fontSize = size * 0.52;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    final badgeSize = (size * 0.28).clamp(11.0, 16.0);
    final iconSize = badgeSize * 0.75;

    return Positioned(
      right: -1,
      bottom: -1,
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Container(
          width: badgeSize,
          height: badgeSize,
          decoration: const BoxDecoration(
            color: Color(0xFF16A34A),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: iconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
