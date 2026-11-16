import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Where a photo comes from.
enum PhotoSource { gallery, camera }

/// Lets the person choose a photo. A small interface of its own so screens do
/// not depend on the plugin, and tests can answer without a phone.
abstract interface class PhotoPicker {
  /// The chosen photo's bytes, or null when the person closed the picker
  /// without choosing. Throws if the phone cannot open the gallery or camera
  /// (for example when camera access is refused).
  Future<Uint8List?> pick(PhotoSource source);
}

/// [PhotoPicker] on the phone's gallery and camera.
class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Photos from a phone camera are 12 megapixels or more and several MB. The
  /// server keeps at most 1280 pixels, so scaling down here (and saving as a
  /// JPEG) makes the upload fast on a mobile connection and keeps it far below
  /// the 5 MB limit.
  static const _longestSide = 1600.0;
  static const _quality = 85;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: switch (source) {
        PhotoSource.gallery => ImageSource.gallery,
        PhotoSource.camera => ImageSource.camera,
      },
      maxWidth: _longestSide,
      maxHeight: _longestSide,
      imageQuality: _quality,
    );
    return file?.readAsBytes();
  }
}
