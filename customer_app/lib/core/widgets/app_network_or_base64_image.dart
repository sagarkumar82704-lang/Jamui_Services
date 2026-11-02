import 'dart:convert';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/app_image_url_resolver.dart';

/// Centralized image widget supporting HTTP/HTTPS URLs with persistent disk caching
/// (via [CachedNetworkImage]), inline Base64 data URIs, local asset paths,
/// memory decoding optimization ([memCacheWidth]/[memCacheHeight]), and error/loading fallbacks.
class AppNetworkOrBase64Image extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, String)? placeholder;
  final int? memCacheWidth;
  final int? memCacheHeight;

  /// Default pixel density scaling factor for high-DPI displays.
  /// 2.5x balances crisp rendering on xxxhdpi devices while preventing excessive decoded memory.
  static const double defaultDensityMultiplier = 2.5;

  /// Maximum decoded dimension cap to prevent runaway bitmap allocations in memory.
  static const int maxDecodeDimension = 1920;

  const AppNetworkOrBase64Image({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
    this.placeholder,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  /// Computes safe decode bounds:
  /// - If caller explicitly sets [memCacheWidth] or [memCacheHeight], respects caller arguments.
  /// - If both [width] and [height] are finite and positive, targets ONLY the major dimension
  ///   leaving the other null, so Flutter's image codec scales proportionally preserving intrinsic aspect ratio.
  /// - If only one dimension is finite and positive (e.g. width is double.infinity), targets only that valid dimension.
  /// - If neither is valid or dimensions are unbounded, leaves both null to preserve full resolution.
  int? get _effectiveMemCacheWidth {
    if (memCacheWidth != null && memCacheWidth! > 0) return memCacheWidth;

    final hasValidWidth = width != null && width!.isFinite && width! > 0;
    final hasValidHeight = height != null && height!.isFinite && height! > 0;

    if (hasValidWidth && hasValidHeight) {
      if (width! >= height!) {
        return math.min((width! * defaultDensityMultiplier).round(), maxDecodeDimension);
      }
      return null;
    }

    if (hasValidWidth) {
      return math.min((width! * defaultDensityMultiplier).round(), maxDecodeDimension);
    }

    return null;
  }

  int? get _effectiveMemCacheHeight {
    if (memCacheHeight != null && memCacheHeight! > 0) return memCacheHeight;

    final hasValidWidth = width != null && width!.isFinite && width! > 0;
    final hasValidHeight = height != null && height!.isFinite && height! > 0;

    if (hasValidWidth && hasValidHeight) {
      if (height! > width!) {
        return math.min((height! * defaultDensityMultiplier).round(), maxDecodeDimension);
      }
      return null;
    }

    if (hasValidHeight) {
      return math.min((height! * defaultDensityMultiplier).round(), maxDecodeDimension);
    }

    return null;
  }

  double? get _sanitizedWidth {
    if (width == null || width!.isNaN || width! < 0) return null;
    return width;
  }

  double? get _sanitizedHeight {
    if (height == null || height!.isNaN || height! < 0) return null;
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = AppImageUrlResolver.resolve(imageUrl);

    // 1. Empty URL handling
    if (cleanUrl.isEmpty) {
      if (errorBuilder != null) {
        return errorBuilder!(context, 'Empty image URL', null);
      }
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    // 2. Base64 data URI handling (e.g. data:image/png;base64,...)
    if (cleanUrl.startsWith('data:image') && cleanUrl.contains(';base64,')) {
      try {
        final b64String = cleanUrl.split(';base64,').last;
        final bytes = base64Decode(b64String);
        return Image.memory(
          bytes,
          fit: fit,
          width: _sanitizedWidth,
          height: _sanitizedHeight,
          errorBuilder: errorBuilder,
        );
      } catch (e) {
        if (errorBuilder != null) return errorBuilder!(context, e, null);
        return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
      }
    }

    // 3. Local asset path fallback (e.g. assets/images/...)
    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        fit: fit,
        width: _sanitizedWidth,
        height: _sanitizedHeight,
        errorBuilder: errorBuilder,
      );
    }

    // 4. HTTP / HTTPS Network image with persistent disk caching
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: cleanUrl,
        fit: fit,
        width: _sanitizedWidth,
        height: _sanitizedHeight,
        memCacheWidth: _effectiveMemCacheWidth,
        memCacheHeight: _effectiveMemCacheHeight,
        fadeInDuration: const Duration(milliseconds: 250),
        fadeOutDuration: const Duration(milliseconds: 150),
        placeholder: (ctx, url) {
          if (placeholder != null) {
            return placeholder!(ctx, url);
          }
          return Container(
            width: _sanitizedWidth,
            height: _sanitizedHeight,
            color: Colors.black.withValues(alpha: 0.04),
          );
        },
        errorWidget: (ctx, url, error) {
          if (errorBuilder != null) {
            return errorBuilder!(ctx, error, null);
          }
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    }

    // 5. Unrecognized scheme fallback
    if (errorBuilder != null) {
      return errorBuilder!(context, 'Unsupported image URL format: $cleanUrl', null);
    }
    return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
  }
}
