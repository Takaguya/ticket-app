import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/error/failure.dart';
import 'package:merchant/core/media/photo_picker.dart';
import 'package:merchant/core/result/result.dart';
import 'package:merchant/features/events/domain/usecases/remove_event_image.dart';
import 'package:merchant/features/events/domain/usecases/set_event_image.dart';
import 'package:merchant/features/events/presentation/bloc/event_picture_cubit.dart';
import 'package:merchant/features/events/presentation/organisms/event_picture_sheet.dart';
import 'package:mocktail/mocktail.dart';

class _MockSetEventImage extends Mock implements SetEventImage {}

class _MockRemoveEventImage extends Mock implements RemoveEventImage {}

/// Answers with what the test says the person chose (null: they closed the picker).
class _FakePicker implements PhotoPicker {
  Uint8List? photo = Uint8List.fromList([1, 2, 3]);
  Object? error;
  final List<PhotoSource> asked = [];

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    asked.add(source);
    if (error != null) throw error!;
    return photo;
  }
}

void main() {
  late _MockSetEventImage setImage;
  late _MockRemoveEventImage removeImage;
  late _FakePicker picker;

  const newUrl = 'http://pin.test/images/events/e0?v=2';
  const oldUrl = 'http://pin.test/images/events/e0?v=1';

  EventPictureCubit cubit({String? imageUrl}) => EventPictureCubit(
    eventId: 'e0',
    imageUrl: imageUrl,
    picker: picker,
    setImage: setImage,
    removeImage: removeImage,
  );

  setUpAll(() => registerFallbackValue(EventPhoto(eventId: '', photo: Uint8List(0))));

  setUp(() {
    setImage = _MockSetEventImage();
    removeImage = _MockRemoveEventImage();
    picker = _FakePicker();
  });

  group('EventPictureCubit', () {
    blocTest<EventPictureCubit, EventPictureState>(
      'a chosen photo is uploaded for the event and its new address is shown',
      build: () {
        when(() => setImage(any())).thenAnswer((_) async => const Result.success(newUrl));
        return cubit(imageUrl: oldUrl);
      },
      act: (cubit) => cubit.choose(PhotoSource.gallery),
      expect: () => [
        const EventPictureState(imageUrl: oldUrl, status: EventPictureStatus.working),
        const EventPictureState(imageUrl: newUrl),
      ],
      verify: (_) {
        expect(picker.asked, [PhotoSource.gallery]);
        final sent = verify(() => setImage(captureAny())).captured.single as EventPhoto;
        expect(sent.eventId, 'e0');
        expect(sent.photo, [1, 2, 3]);
      },
    );

    blocTest<EventPictureCubit, EventPictureState>(
      'closing the picker without choosing changes nothing and uploads nothing',
      build: () {
        picker.photo = null;
        return cubit(imageUrl: oldUrl);
      },
      act: (cubit) => cubit.choose(PhotoSource.camera),
      expect: () => const <EventPictureState>[],
      verify: (_) => verifyNever(() => setImage(any())),
    );

    blocTest<EventPictureCubit, EventPictureState>(
      'a camera that cannot be opened says so and keeps the picture',
      build: () {
        picker.error = StateError('camera_access_denied');
        return cubit(imageUrl: oldUrl);
      },
      act: (cubit) => cubit.choose(PhotoSource.camera),
      expect: () => [
        isA<EventPictureState>()
            .having((s) => s.imageUrl, 'picture kept', oldUrl)
            .having((s) => s.message, 'message', contains('camera')),
      ],
      verify: (_) => verifyNever(() => setImage(any())),
    );

    blocTest<EventPictureCubit, EventPictureState>(
      'a gallery that cannot be opened says so',
      build: () {
        picker.error = StateError('no gallery');
        return cubit();
      },
      act: (cubit) => cubit.choose(PhotoSource.gallery),
      expect: () => [
        isA<EventPictureState>().having((s) => s.message, 'message', contains('photos')),
      ],
    );

    blocTest<EventPictureCubit, EventPictureState>(
      'a photo the server refuses keeps the old picture and shows why, as written',
      build: () {
        when(() => setImage(any())).thenAnswer(
          (_) async => const Result.failure(RejectedFailure('That picture is too big. Keep it under 5 MB.')),
        );
        return cubit(imageUrl: oldUrl);
      },
      act: (cubit) => cubit.choose(PhotoSource.gallery),
      expect: () => [
        const EventPictureState(imageUrl: oldUrl, status: EventPictureStatus.working),
        const EventPictureState(imageUrl: oldUrl, message: 'That picture is too big. Keep it under 5 MB.'),
      ],
    );

    blocTest<EventPictureCubit, EventPictureState>(
      'no connection is reported, and the picture stays',
      build: () {
        when(() => setImage(any())).thenAnswer((_) async => const Result.failure(NetworkFailure()));
        return cubit();
      },
      act: (cubit) => cubit.choose(PhotoSource.gallery),
      expect: () => [
        const EventPictureState(imageUrl: null, status: EventPictureStatus.working),
        const EventPictureState(imageUrl: null, message: "Can't reach Pin right now. Check your connection and try again."),
      ],
    );

    blocTest<EventPictureCubit, EventPictureState>(
      'removing takes the picture off the event',
      build: () {
        when(() => removeImage(any())).thenAnswer((_) async => const Result.success(null));
        return cubit(imageUrl: oldUrl);
      },
      act: (cubit) => cubit.remove(),
      expect: () => [
        const EventPictureState(imageUrl: oldUrl, status: EventPictureStatus.working),
        const EventPictureState(imageUrl: null),
      ],
      verify: (_) => verify(() => removeImage('e0')).called(1),
    );

    blocTest<EventPictureCubit, EventPictureState>(
      'a removal that fails keeps the picture and says why',
      build: () {
        when(() => removeImage(any())).thenAnswer((_) async => const Result.failure(ServerFailure()));
        return cubit(imageUrl: oldUrl);
      },
      act: (cubit) => cubit.remove(),
      expect: () => [
        const EventPictureState(imageUrl: oldUrl, status: EventPictureStatus.working),
        const EventPictureState(imageUrl: oldUrl, message: 'Something went wrong. Please try again.'),
      ],
    );

    blocTest<EventPictureCubit, EventPictureState>(
      'removing an event that has no picture does nothing',
      build: cubit,
      act: (cubit) => cubit.remove(),
      expect: () => const <EventPictureState>[],
      verify: (_) => verifyNever(() => removeImage(any())),
    );
  });

  group('EventPictureSheet', () {
    Future<EventPictureCubit> open(WidgetTester tester, {String? imageUrl}) async {
      final created = cubit(imageUrl: imageUrl);
      addTearDown(created.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: created,
              child: const EventPictureSheet(eventName: 'Khmer Rock Night 2026'),
            ),
          ),
        ),
      );
      return created;
    }

    testWidgets('an event with no picture offers the gallery and the camera, and nothing to remove', (tester) async {
      await open(tester);

      expect(find.text('Event picture'), findsOneWidget);
      expect(find.text('Khmer Rock Night 2026'), findsOneWidget);
      expect(find.text('No picture yet'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Remove picture'), findsNothing);
      expect(find.textContaining('up to 5 MB'), findsOneWidget);
    });

    testWidgets('an event with a picture offers to change or remove it', (tester) async {
      await open(tester, imageUrl: oldUrl);

      expect(find.text('Choose another photo'), findsOneWidget);
      expect(find.text('Remove picture'), findsOneWidget);
    });

    testWidgets('choosing from the gallery uploads the photo and shows the picture it became', (tester) async {
      when(() => setImage(any())).thenAnswer((_) async => const Result.success(newUrl));
      await open(tester);

      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();

      expect(picker.asked, [PhotoSource.gallery]);
      verify(() => setImage(any())).called(1);
      // The picture is there now: the sheet offers to replace or remove it.
      expect(find.text('Choose another photo'), findsOneWidget);
      expect(find.text('Remove picture'), findsOneWidget);
    });

    testWidgets('a photo the server refuses shows the server message', (tester) async {
      when(() => setImage(any())).thenAnswer(
        (_) async => const Result.failure(RejectedFailure('That file is not a picture. Choose a JPEG or PNG image.')),
      );
      await open(tester);

      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      expect(picker.asked, [PhotoSource.camera]);
      expect(find.text('That file is not a picture. Choose a JPEG or PNG image.'), findsOneWidget);
      expect(find.text('No picture yet'), findsOneWidget);
      expect(find.text('Remove picture'), findsNothing);
    });

    testWidgets('removing the picture puts the "no picture yet" view back', (tester) async {
      when(() => removeImage(any())).thenAnswer((_) async => const Result.success(null));
      await open(tester, imageUrl: oldUrl);

      // The sheet scrolls on a small screen: bring the button into view first.
      await tester.ensureVisible(find.text('Remove picture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove picture'));
      await tester.pumpAndSettle();

      verify(() => removeImage('e0')).called(1);
      expect(find.text('No picture yet'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Remove picture'), findsNothing);
    });
  });
}
