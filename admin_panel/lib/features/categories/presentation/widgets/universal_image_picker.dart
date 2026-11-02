import 'picked_image_data.dart';
import 'universal_image_picker_stub.dart'
    if (dart.library.html) 'universal_image_picker_web.dart' as picker_impl;

class UniversalImagePicker {
  static Future<PickedImageData?> pickImage() async {
    return await picker_impl.pickImageFromBrowser();
  }
}
