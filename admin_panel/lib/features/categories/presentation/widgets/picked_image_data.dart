import 'dart:typed_data';

class PickedImageData {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  PickedImageData({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}
