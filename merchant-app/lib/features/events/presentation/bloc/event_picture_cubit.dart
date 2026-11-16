import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/media/photo_picker.dart';
import '../../domain/entities/event.dart';
import '../../domain/usecases/remove_event_image.dart';
import '../../domain/usecases/set_event_image.dart';
import 'cover_photos.dart';

/// Makes the cubit for one event; the router provides it to the screens that open the picture sheet.
typedef EventPictureCubitFactory = EventPictureCubit Function(Event event);

enum EventPictureStatus { idle, working }

/// The picture of one event, as the "Event picture" sheet shows it.
class EventPictureState extends Equatable {
  const EventPictureState({required this.imageUrl, this.status = EventPictureStatus.idle, this.message});

  /// Where the picture is, or null when the event has none.
  final String? imageUrl;
  final EventPictureStatus status;

  /// Why the last try failed, written for the person; null when it did not.
  final String? message;

  bool get working => status == EventPictureStatus.working;

  @override
  List<Object?> get props => [imageUrl, status, message];
}

/// Chooses, uploads and removes the cover image of one event. The owner picks
/// a photo from the gallery or camera; the server checks it, shrinks it and
/// keeps it, and every screen that shows the event then shows the new picture.
class EventPictureCubit extends Cubit<EventPictureState> {
  EventPictureCubit({
    required this._eventId,
    required String? imageUrl,
    required this._picker,
    required this._setImage,
    required this._removeImage,
  }) : super(EventPictureState(imageUrl: imageUrl));

  final String _eventId;
  final PhotoPicker _picker;
  final SetEventImage _setImage;
  final RemoveEventImage _removeImage;

  /// Opens the gallery or camera and uploads what the person chooses. Does
  /// nothing if they close the picker without choosing.
  Future<void> choose(PhotoSource source) async {
    if (state.working) return;
    final Uint8List? photo;
    try {
      photo = await _picker.pick(source);
    } on Object {
      emit(EventPictureState(imageUrl: state.imageUrl, message: CoverPhotos.problemOpening(source)));
      return;
    }
    if (photo == null) return;

    emit(EventPictureState(imageUrl: state.imageUrl, status: EventPictureStatus.working));
    final result = await _setImage(EventPhoto(eventId: _eventId, photo: photo));
    emit(
      result.when(
        success: (url) => EventPictureState(imageUrl: url),
        failure: (failure) => EventPictureState(imageUrl: state.imageUrl, message: failure.message),
      ),
    );
  }

  /// Takes the picture off the event.
  Future<void> remove() async {
    if (state.working || state.imageUrl == null) return;
    emit(EventPictureState(imageUrl: state.imageUrl, status: EventPictureStatus.working));
    final result = await _removeImage(_eventId);
    emit(
      result.when(
        success: (_) => const EventPictureState(imageUrl: null),
        failure: (failure) => EventPictureState(imageUrl: state.imageUrl, message: failure.message),
      ),
    );
  }
}
