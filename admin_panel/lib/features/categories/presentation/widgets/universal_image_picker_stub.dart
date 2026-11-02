import 'package:image_picker/image_picker.dart';
import 'picked_image_data.dart';

Future<PickedImageData?> pickImageFromBrowser() async {
  final picker = ImagePicker();
  final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return PickedImageData(
    bytes: bytes,
    fileName: file.name,
    mimeType: file.mimeType ?? 'image/jpeg',
  );
}
