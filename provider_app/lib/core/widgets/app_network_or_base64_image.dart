import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/app_image_url_resolver.dart';

class AppNetworkOrBase64Image extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const AppNetworkOrBase64Image({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = AppImageUrlResolver.resolve(imageUrl);
    if (cleanUrl.isEmpty) {
      if (errorBuilder != null) return errorBuilder!(context, 'Empty image URL', null);
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    if (cleanUrl.startsWith('data:image') && cleanUrl.contains(';base64,')) {
      try {
        final b64String = cleanUrl.split(';base64,').last;
        final bytes = base64Decode(b64String);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: errorBuilder,
        );
      } catch (e) {
        if (errorBuilder != null) return errorBuilder!(context, e, null);
        return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
      }
    }

    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder,
      );
    }

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return Image.network(
        cleanUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder,
      );
    }

    if (errorBuilder != null) {
      return errorBuilder!(context, 'Unsupported image URL format: $cleanUrl', null);
    }
    return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
  }
}
