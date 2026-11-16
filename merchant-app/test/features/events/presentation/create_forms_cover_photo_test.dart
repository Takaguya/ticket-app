// The cover picture in the four "Create" forms (event, trip, screening, place): the owner picks it
// while filling the form in, and it is uploaded once the event is published. All four behave the
// same, so every scenario runs on each of them.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/error/failure.dart';
import 'package:merchant/core/media/photo_picker.dart';
import 'package:merchant/core/result/result.dart';
import 'package:merchant/features/events/domain/entities/event.dart';
import 'package:merchant/features/events/domain/repositories/events_repository.dart';
import 'package:merchant/features/events/domain/usecases/publish_bus_trip.dart';
import 'package:merchant/features/events/domain/usecases/publish_event.dart';
import 'package:merchant/features/events/domain/usecases/publish_place.dart';
import 'package:merchant/features/events/domain/usecases/publish_screening.dart';
import 'package:merchant/features/events/domain/usecases/set_event_image.dart';
import 'package:merchant/features/events/presentation/bloc/cover_photos.dart';
import 'package:merchant/features/events/presentation/bloc/create_event_bloc.dart';
import 'package:merchant/features/events/presentation/bloc/create_place_bloc.dart';
import 'package:merchant/features/events/presentation/bloc/create_screening_bloc.dart';
import 'package:merchant/features/events/presentation/bloc/create_trip_bloc.dart';

/// Answers the gallery or camera with what the test says (null: the person closed it; or it fails).
class _Picker implements PhotoPicker {
  Uint8List? photo = Uint8List.fromList([9, 8, 7]);
  Object? error;
  final List<PhotoSource> asked = [];

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    asked.add(source);
    if (error != null) throw error!;
    return photo;
  }
}

/// Remembers what was uploaded for which event, and answers with [answer].
class _Uploader implements SetEventImage {
  Result<String> answer = const Result.success('/images/events/new-id?v=1');
  final List<EventPhoto> uploads = [];

  @override
  Future<Result<String>> call(EventPhoto params) async {
    uploads.add(params);
    return answer;
  }
}

class _Published<D> {
  _Published(this.answer);

  Result<Event> answer;
  Future<Result<Event>> publish(D draft) async => answer;
}

class _PublishEvent extends _Published<EventDraft> implements PublishEvent {
  _PublishEvent(super.answer);

  @override
  Future<Result<Event>> call(EventDraft params) => publish(params);
}

class _PublishTrip extends _Published<TripDraft> implements PublishBusTrip {
  _PublishTrip(super.answer);

  @override
  Future<Result<Event>> call(TripDraft params) => publish(params);
}

class _PublishPlace extends _Published<PlaceDraft> implements PublishPlace {
  _PublishPlace(super.answer);

  @override
  Future<Result<Event>> call(PlaceDraft params) => publish(params);
}

class _PublishScreening extends _Published<ScreeningDraft> implements PublishScreening {
  _PublishScreening(super.answer);

  @override
  Future<Result<Event>> call(ScreeningDraft params) => publish(params);
}

/// One of the four forms, seen through what they all share.
class _Form {
  const _Form({
    required this.name,
    required this.published,
    required this.build,
    required this.request,
    required this.remove,
    required this.submit,
    required this.photoIn,
    required this.noticeIn,
    required this.isPublished,
  });

  final String name;

  /// What the form says when it is published and on sale.
  final String published;

  /// A form filled in completely, whose publishing answers with [Result] and which hands its
  /// pictures to [photos].
  final Bloc<Object, Object?> Function(CoverPhotos photos, _Publish publish) build;
  final void Function(Bloc<Object, Object?> bloc, PhotoSource source) request;
  final void Function(Bloc<Object, Object?> bloc) remove;
  final void Function(Bloc<Object, Object?> bloc) submit;
  final Uint8List? Function(Object? state) photoIn;
  final String? Function(Object? state) noticeIn;
  final bool Function(Object? state) isPublished;
}

/// What publishing answers, shared by all four forms' fakes.
class _Publish {
  _Publish(this.answer);

  Result<Event> answer;
}

Event _event(String name) => Event(
  id: 'new-id',
  name: name,
  startsAt: DateTime(2026, 12, 5, 19),
  venue: 'Somewhere',
  ticketTypes: const [TicketType(name: 'Standard', priceCents: 1000, quantity: 100)],
);

final _forms = <_Form>[
  _Form(
    name: 'event',
    published: 'Night Run is published and on sale',
    build: (photos, publish) =>
        CreateEventBloc(publishEvent: _PublishEvent(publish.answer), coverPhotos: photos)
          ..add(const CreateEventNameChanged('Night Run'))
          ..add(CreateEventDateChanged(DateTime(2026, 12, 1)))
          ..add(const CreateEventTimeChanged(hour: 18, minute: 30))
          ..add(const CreateEventVenueChanged('Riverside'))
          ..add(const CreateEventKindChanged(EventKind.concert))
          ..add(const CreateEventTicketTypeChanged(0, name: 'Standard', price: '10', quantity: '100')),
    request: (bloc, source) => (bloc as CreateEventBloc).add(CreateEventPhotoRequested(source)),
    remove: (bloc) => (bloc as CreateEventBloc).add(const CreateEventPhotoRemoved()),
    submit: (bloc) => (bloc as CreateEventBloc).add(const CreateEventSubmitted()),
    photoIn: (state) => (state as CreateEventState).photo,
    noticeIn: (state) => (state as CreateEventState).notice,
    isPublished: (state) => (state as CreateEventState).status == CreateEventStatus.published,
  ),
  _Form(
    name: 'trip',
    published: 'Phnom Penh to Siem Reap is published and on sale',
    build: (photos, publish) =>
        CreateTripBloc(publishBusTrip: _PublishTrip(publish.answer), coverPhotos: photos)
          ..add(const CreateTripOriginChanged('Phnom Penh'))
          ..add(const CreateTripDestinationChanged('Siem Reap'))
          ..add(CreateTripDateChanged(DateTime(2026, 12, 5)))
          ..add(const CreateTripTimeChanged(hour: 8, minute: 45))
          ..add(const CreateTripDurationChanged('6'))
          ..add(const CreateTripBoardingPointChanged('Giant Ibis Terminal')),
    request: (bloc, source) => (bloc as CreateTripBloc).add(CreateTripPhotoRequested(source)),
    remove: (bloc) => (bloc as CreateTripBloc).add(const CreateTripPhotoRemoved()),
    submit: (bloc) => (bloc as CreateTripBloc).add(const CreateTripSubmitted()),
    photoIn: (state) => (state as CreateTripState).photo,
    noticeIn: (state) => (state as CreateTripState).notice,
    isPublished: (state) => (state as CreateTripState).status == CreateTripStatus.published,
  ),
  _Form(
    name: 'screening',
    published: 'Skyline Run is published and on sale',
    build: (photos, publish) =>
        CreateScreeningBloc(publishScreening: _PublishScreening(publish.answer), coverPhotos: photos)
          ..add(const CreateScreeningFilmChanged('Skyline Run'))
          ..add(const CreateScreeningRuntimeChanged('128'))
          ..add(const CreateScreeningTheatreChanged('Legend Cinema, Aeon Mall'))
          ..add(const CreateScreeningHallChanged('Hall 2'))
          ..add(CreateScreeningDateChanged(DateTime(2026, 12, 5)))
          ..add(const CreateScreeningTimeChanged(hour: 19, minute: 30)),
    request: (bloc, source) => (bloc as CreateScreeningBloc).add(CreateScreeningPhotoRequested(source)),
    remove: (bloc) => (bloc as CreateScreeningBloc).add(const CreateScreeningPhotoRemoved()),
    submit: (bloc) => (bloc as CreateScreeningBloc).add(const CreateScreeningSubmitted()),
    photoIn: (state) => (state as CreateScreeningState).photo,
    noticeIn: (state) => (state as CreateScreeningState).notice,
    isPublished: (state) => (state as CreateScreeningState).status == CreateScreeningStatus.published,
  ),
  _Form(
    name: 'place',
    published: 'Garden City Water Park is published and on sale',
    build: (photos, publish) =>
        CreatePlaceBloc(publishPlace: _PublishPlace(publish.answer), coverPhotos: photos)
          ..add(const CreatePlaceNameChanged('Garden City Water Park'))
          ..add(const CreatePlaceVenueChanged('Garden City'))
          ..add(const CreatePlaceTicketChanged(0, name: 'Adult', price: '10', limit: '300')),
    request: (bloc, source) => (bloc as CreatePlaceBloc).add(CreatePlacePhotoRequested(source)),
    remove: (bloc) => (bloc as CreatePlaceBloc).add(const CreatePlacePhotoRemoved()),
    submit: (bloc) => (bloc as CreatePlaceBloc).add(const CreatePlaceSubmitted()),
    photoIn: (state) => (state as CreatePlaceState).photo,
    noticeIn: (state) => (state as CreatePlaceState).notice,
    isPublished: (state) => (state as CreatePlaceState).status == CreatePlaceStatus.published,
  ),
];

void main() {
  for (final form in _forms) {
    group('the ${form.name} form’s cover picture', () {
      late _Picker picker;
      late _Uploader uploader;
      late _Publish publish;
      late CoverPhotos photos;
      late Bloc<Object, Object?> bloc;
      final states = <Object?>[];
      late StreamSubscription<Object?> subscription;

      setUp(() {
        picker = _Picker();
        uploader = _Uploader();
        publish = _Publish(Result.success(_event('x')));
        photos = CoverPhotos(picker: picker, setImage: uploader);
        states.clear();
      });

      Bloc<Object, Object?> open() {
        bloc = form.build(photos, publish);
        subscription = bloc.stream.listen(states.add);
        return bloc;
      }

      tearDown(() async {
        await subscription.cancel();
        await bloc.close();
      });

      /// Waits for the form to reach a state that [test] accepts.
      Future<void> until(bool Function(Object? state) test) async {
        await bloc.stream.firstWhere(test).timeout(const Duration(seconds: 5));
      }

      test('a chosen photo stays on the form, and can be taken off again', () async {
        open();

        form.request(bloc, PhotoSource.gallery);
        await until((s) => form.photoIn(s) != null);
        expect(form.photoIn(bloc.state), [9, 8, 7]);
        expect(picker.asked, [PhotoSource.gallery]);

        form.remove(bloc);
        await until((s) => form.photoIn(s) == null);
        // Nothing was uploaded: the event does not exist yet.
        expect(uploader.uploads, isEmpty);
      });

      test('closing the gallery without choosing changes nothing', () async {
        picker.photo = null;
        open();
        // Let the form finish filling itself in, then watch only what the picker does.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        states.clear();

        form.request(bloc, PhotoSource.camera);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(states, isEmpty);
        expect(picker.asked, [PhotoSource.camera]);
      });

      test('a camera that cannot be opened is a notice, not a photo', () async {
        picker.error = StateError('camera_access_denied');
        open();

        form.request(bloc, PhotoSource.camera);
        await until((s) => form.noticeIn(s) != null);

        expect(form.noticeIn(states.firstWhere((s) => form.noticeIn(s) != null)), contains('camera'));
        expect(form.photoIn(bloc.state), isNull);
      });

      test('the photo goes up for the event that was published, and the notice is the usual one', () async {
        open();
        form.request(bloc, PhotoSource.gallery);
        await until((s) => form.photoIn(s) != null);

        form.submit(bloc);
        await until(form.isPublished);

        expect(uploader.uploads, hasLength(1));
        expect(uploader.uploads.single.eventId, 'new-id');
        expect(uploader.uploads.single.photo, [9, 8, 7]);
        expect(form.noticeIn(bloc.state), form.published);
      });

      test('without a photo nothing is uploaded', () async {
        open();

        form.submit(bloc);
        await until(form.isPublished);

        expect(uploader.uploads, isEmpty);
        expect(form.noticeIn(bloc.state), form.published);
      });

      test('a photo that cannot be uploaded never loses the event: it is published and the owner is told', () async {
        uploader.answer = const Result.failure(RejectedFailure('That picture is too big. Keep it under 5 MB.'));
        open();
        form.request(bloc, PhotoSource.gallery);
        await until((s) => form.photoIn(s) != null);

        form.submit(bloc);
        await until(form.isPublished);

        expect(uploader.uploads, hasLength(1));
        final notice = form.noticeIn(bloc.state)!;
        expect(notice, startsWith(form.published));
        expect(notice, contains('That picture is too big. Keep it under 5 MB.'));
        expect(notice, contains('Add it from the Today screen'));
      });

      test('an event Pin refuses is not published, uploads nothing and keeps the photo for the next try', () async {
        publish.answer = const Result.failure(RejectedFailure('Pin is still reviewing your business.'));
        open();
        form.request(bloc, PhotoSource.gallery);
        await until((s) => form.photoIn(s) != null);

        form.submit(bloc);
        await until((s) => form.noticeIn(s) == 'Pin is still reviewing your business.');

        expect(uploader.uploads, isEmpty);
        expect(form.photoIn(bloc.state), [9, 8, 7]);
        expect(form.isPublished(bloc.state), isFalse);
      });
    });
  }

  group('CoverPhotos.publishedNotice', () {
    test('is the plain message when the photo went up or there was none', () {
      expect(CoverPhotos.publishedNotice('Night Run is published and on sale', null), 'Night Run is published and on sale');
    });

    test('adds why the picture could not be added', () {
      expect(
        CoverPhotos.publishedNotice('Night Run is published and on sale', "Can't reach Pin right now."),
        'Night Run is published and on sale\nIts picture could not be added: Can\'t reach Pin right now. Add it from the Today screen.',
      );
    });
  });
}
