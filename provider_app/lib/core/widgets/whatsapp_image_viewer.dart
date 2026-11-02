import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../utils/app_image_utils.dart';

class WhatsAppImageViewerDialog extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;

  const WhatsAppImageViewerDialog({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
  });

  static Future<void> show(BuildContext context, {required String imageUrl, required String title, String? subtitle}) async {
    if (imageUrl.isEmpty) return;

    String resolvedUrl = imageUrl;
    // If it's a private document relative key in R2, fetch secure short-lived presigned GET URL
    if ((imageUrl.contains('/certificates/') || imageUrl.contains('/kyc/')) &&
        !imageUrl.startsWith('http://') &&
        !imageUrl.startsWith('https://') &&
        !imageUrl.startsWith('blob:') &&
        !imageUrl.startsWith('data:image')) {
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('getSecureDocumentViewUrl');
        final result = await callable.call(<String, dynamic>{'objectKey': imageUrl}).timeout(const Duration(seconds: 10));
        if (result.data != null && result.data['viewUrl'] != null) {
          resolvedUrl = result.data['viewUrl'] as String;
        }
      } catch (e) {
        debugPrint('Could not fetch presigned view URL for private document: $e');
      }
    }

    if (context.mounted) {
      showDialog(
        context: context,
        useSafeArea: false,
        builder: (ctx) => WhatsAppImageViewerDialog(
          imageUrl: resolvedUrl,
          title: title,
          subtitle: subtitle,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
          ],
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          clipBehavior: Clip.none,
          child: AppImageUtils.buildImage(
            imageUrl,
            fit: BoxFit.contain,
            errorWidget: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                SizedBox(height: 12),
                Text('इमेज फ़ाइल उपलब्ध नहीं (Image unavailable)', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
