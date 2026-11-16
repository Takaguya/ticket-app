import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/events_repository.dart';

/// Which event gets which photo.
class EventPhoto extends Equatable {
  const EventPhoto({required this.eventId, required this.photo});

  final String eventId;

  /// The picture as chosen (a JPEG or PNG up to 5 MB); the server resizes it.
  final Uint8List photo;

  @override
  List<Object?> get props => [eventId, photo];
}

/// Sets or replaces the cover image of an event, shown on the event's cards,
/// page and e-ticket in the Pin user app. Succeeds with the image's new address.
class SetEventImage implements UseCase<String, EventPhoto> {
  const SetEventImage(this._repository);

  final EventsRepository _repository;

  @override
  Future<Result<String>> call(EventPhoto params) => _repository.setEventImage(params.eventId, params.photo);
}
