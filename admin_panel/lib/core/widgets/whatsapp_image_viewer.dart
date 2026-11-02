import 'package:flutter/material.dart';
import '../utils/admin_image_utils.dart';

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

  static void show(BuildContext context, {required String imageUrl, required String title, String? subtitle}) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => WhatsAppImageViewerDialog(
        imageUrl: imageUrl,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
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
          child: AdminImageUtils.buildImage(
            imageUrl,
            fit: BoxFit.contain,
            placeholder: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 64),
                SizedBox(height: 12),
                Text('इमेज लोड करने में असमर्थ (Image Load Error)', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

