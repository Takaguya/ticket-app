import 'dart:typed_data';

import '../../../../core/media/photo_picker.dart';
import '../../domain/usecases/set_event_image.dart';

/// What came of asking the phone for a photo: exactly one of the three.
class CoverPick {
  const CoverPick.chosen(Uint8List this.photo) : problem = null;
  const CoverPick.closed() : photo = null, problem = null;
  const CoverPick.failed(String this.problem) : photo = null;

  /// The photo the person chose.
  final Uint8List? photo;

  /// Why the phone could not open the gallery or camera, written for the person.
  final String? problem;
}

/// The cover photo of an event as the "Create" forms handle it: the owner picks it
/// while filling in the form, and it is uploaded once the event is published (the
/// server needs the event to exist first). A photo that cannot be uploaded never
/// loses the event: it is published, and the owner is told how to add the picture later.
class CoverPhotos {
  const CoverPhotos({required this._picker, required this._setImage});

  final PhotoPicker _picker;
  final SetEventImage _setImage;

  /// What to say when the gallery or the camera cannot be opened.
  static String problemOpening(PhotoSource source) => switch (source) {
    PhotoSource.camera =>
      'Pin could not open the camera. Allow camera access in your phone settings, or choose from the gallery.',
    PhotoSource.gallery => 'Pin could not open your photos. Try again.',
  };

  /// Opens the gallery or camera. Never throws.
  Future<CoverPick> pick(PhotoSource source) async {
    try {
      final photo = await _picker.pick(source);
      return photo == null ? const CoverPick.closed() : CoverPick.chosen(photo);
    } on Object {
      return CoverPick.failed(problemOpening(source));
    }
  }

  /// Uploads [photo] as the cover image of the event that was just published. Null when it
  /// went well, or when there is no photo; otherwise why it did not, as the server wrote it.
  Future<String?> upload(String eventId, Uint8List? photo) async {
    if (photo == null) return null;
    final result = await _setImage(EventPhoto(eventId: eventId, photo: photo));
    return result.when(success: (_) => null, failure: (failure) => failure.message);
  }

  /// [published] (e.g. "Kampot Run is published and on sale"), with what happened to the
  /// photo added when it could not be uploaded.
  static String publishedNotice(String published, String? photoProblem) {
    if (photoProblem == null) return published;
    return '$published\nIts picture could not be added: $photoProblem Add it from the Today screen.';
  }
}
