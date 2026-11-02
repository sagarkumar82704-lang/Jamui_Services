import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_cropper_dialog.dart';

class PhotoSourcePicker {
  static Future<void> show(
    BuildContext context, {
    required Function(String imagePath) onImagePicked,
    void Function(String imagePath, Uint8List? imageBytes)? onImagePickedWithBytes,
    bool enableCrop = true,
    bool isCircle = true,
    String title = 'फोटो अपलोड स्रोत चुनें (Select Photo Source)',
  }) async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                  ),
                  title: const Text('कैमरा से फोटो खींचें (Camera 📷)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('मोबाइल कैमरा खोलकर तुरंत फोटो लें'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final XFile? photo = await picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 85,
                      );
                      if (photo != null && context.mounted) {
                        await _processPickedPhoto(
                          context: context,
                          photo: photo,
                          enableCrop: enableCrop,
                          isCircle: isCircle,
                          onImagePicked: onImagePicked,
                          onImagePickedWithBytes: onImagePickedWithBytes,
                        );
                      }
                    } catch (e) {
                      debugPrint('Camera picker error: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('कैमरा खोलने में समस्या: $e। गैलरी से फोटो चुन सकते हैं।'),
                            backgroundColor: Colors.orange.shade800,
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: 'गैलरी खोलें',
                              textColor: Colors.white,
                              onPressed: () {
                                _pickFromGallery(
                                  context: context,
                                  picker: picker,
                                  enableCrop: enableCrop,
                                  isCircle: isCircle,
                                  onImagePicked: onImagePicked,
                                  onImagePickedWithBytes: onImagePickedWithBytes,
                                );
                              },
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                  ),
                  title: const Text('गैलरी से फोटो चुनें (Gallery 🖼️)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('फोन की गैलरी से सहेजी गई फोटो चुनें'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromGallery(
                      context: context,
                      picker: picker,
                      enableCrop: enableCrop,
                      isCircle: isCircle,
                      onImagePicked: onImagePicked,
                      onImagePickedWithBytes: onImagePickedWithBytes,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _pickFromGallery({
    required BuildContext context,
    required ImagePicker picker,
    required bool enableCrop,
    required bool isCircle,
    required Function(String imagePath) onImagePicked,
    void Function(String imagePath, Uint8List? imageBytes)? onImagePickedWithBytes,
  }) async {
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (photo != null && context.mounted) {
        await _processPickedPhoto(
          context: context,
          photo: photo,
          enableCrop: enableCrop,
          isCircle: isCircle,
          onImagePicked: onImagePicked,
          onImagePickedWithBytes: onImagePickedWithBytes,
        );
      }
    } catch (e) {
      debugPrint('Gallery picker error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('गैलरी खोलने में समस्या: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static Future<void> _processPickedPhoto({
    required BuildContext context,
    required XFile photo,
    required bool enableCrop,
    required bool isCircle,
    required Function(String imagePath) onImagePicked,
    void Function(String imagePath, Uint8List? imageBytes)? onImagePickedWithBytes,
  }) async {
    final bytes = await photo.readAsBytes();
    if (!context.mounted) return;
    if (enableCrop) {
      final croppedPath = await ImageCropperDialog.show(
        context,
        imagePath: photo.path,
        initialBytes: bytes,
        isCircle: isCircle,
      );
      if (croppedPath != null) {
        Uint8List? croppedBytes;
        if (croppedPath.startsWith('data:image/')) {
          final comma = croppedPath.indexOf('base64,');
          if (comma != -1) {
            try {
              croppedBytes = base64Decode(croppedPath.substring(comma + 7).trim());
            } catch (_) {}
          }
        }
        if (onImagePickedWithBytes != null) {
          onImagePickedWithBytes(croppedPath, croppedBytes ?? bytes);
        }
        onImagePicked(croppedPath);
      }
    } else {
      if (onImagePickedWithBytes != null) {
        onImagePickedWithBytes(photo.path, bytes);
      }
      onImagePicked(photo.path);
    }
  }
}
