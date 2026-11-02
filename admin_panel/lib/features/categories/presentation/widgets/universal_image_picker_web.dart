// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'picked_image_data.dart';

Future<PickedImageData?> pickImageFromBrowser() async {
  final completer = Completer<PickedImageData?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = 'image/jpeg,image/png,image/webp,image/jpg';
  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.listen((e) {
      final dataUrl = reader.result as String?;
      if (dataUrl == null || dataUrl.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final img = html.ImageElement();
      img.src = dataUrl;
      img.onLoad.listen((_) {
        try {
          int width = img.naturalWidth;
          int height = img.naturalHeight;
          if (width <= 0) width = img.width ?? 400;
          if (height <= 0) height = img.height ?? 400;
          
          const int maxDimension = 600;
          if (width > maxDimension || height > maxDimension) {
            if (width > height) {
              height = (height * maxDimension / width).round();
              width = maxDimension;
            } else {
              width = (width * maxDimension / height).round();
              height = maxDimension;
            }
          }

          final canvas = html.CanvasElement(width: width, height: height);
          final ctx = canvas.context2D;
          ctx.drawImageScaled(img, 0, 0, width, height);

          final compressedDataUrl = canvas.toDataUrl('image/jpeg', 0.85);
          final base64String = compressedDataUrl.split(',').last;
          final byteChars = html.window.atob(base64String);
          final bytes = Uint8List(byteChars.length);
          for (int i = 0; i < byteChars.length; i++) {
            bytes[i] = byteChars.codeUnitAt(i);
          }

          if (!completer.isCompleted) {
            completer.complete(PickedImageData(
              bytes: bytes,
              fileName: file.name,
              mimeType: 'image/jpeg',
            ));
          }
        } catch (_) {
          // Fallback to reading array buffer directly if canvas operations fail
          _readRawArrayBuffer(file, completer);
        }
      });

      img.onError.listen((_) {
        _readRawArrayBuffer(file, completer);
      });
    });
  });

  return completer.future;
}

void _readRawArrayBuffer(html.File file, Completer<PickedImageData?> completer) {
  if (completer.isCompleted) return;
  final rawReader = html.FileReader();
  rawReader.readAsArrayBuffer(file);
  rawReader.onLoadEnd.listen((_) {
    final res = rawReader.result;
    if (res is Uint8List && !completer.isCompleted) {
      completer.complete(PickedImageData(
        bytes: res,
        fileName: file.name,
        mimeType: file.type.isNotEmpty ? file.type : 'image/jpeg',
      ));
    } else if (res is List<int> && !completer.isCompleted) {
      completer.complete(PickedImageData(
        bytes: Uint8List.fromList(res),
        fileName: file.name,
        mimeType: file.type.isNotEmpty ? file.type : 'image/jpeg',
      ));
    } else if (!completer.isCompleted) {
      completer.complete(null);
    }
  });
}

