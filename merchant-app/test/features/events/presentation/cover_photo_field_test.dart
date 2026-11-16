import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/media/photo_picker.dart';
import 'package:merchant/features/events/presentation/organisms/cover_photo_field.dart';

/// A real 1 x 1 PNG, so the preview can be decoded.
final _pixel = Uint8List.fromList(
  base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='),
);

void main() {
  Widget host({Uint8List? photo, bool enabled = true, void Function(PhotoSource)? onChoose, VoidCallback? onRemove}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CoverPhotoField(
            what: 'screening',
            photo: photo,
            enabled: enabled,
            onChoose: onChoose ?? (_) {},
            onRemove: onRemove ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('with no photo it says so, offers the gallery and the camera, and nothing to remove', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Cover picture · optional'), findsOneWidget);
    expect(find.textContaining('screening’s card and ticket'), findsOneWidget);
    expect(find.text('No picture yet'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Remove picture'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('with a photo it shows the preview and offers to change or remove it', (tester) async {
    await tester.pumpWidget(host(photo: _pixel));

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('No picture yet'), findsNothing);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Remove picture'), findsOneWidget);
  });

  /// A screen tall enough for the whole card, so every button can be tapped.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('the buttons report what the owner chose', (tester) async {
    tall(tester);
    final chosen = <PhotoSource>[];
    var removed = 0;
    await tester.pumpWidget(host(photo: _pixel, onChoose: chosen.add, onRemove: () => removed++));

    await tester.tap(find.text('Change'));
    await tester.tap(find.text('Camera'));
    await tester.tap(find.text('Remove picture'));

    expect(chosen, [PhotoSource.gallery, PhotoSource.camera]);
    expect(removed, 1);
  });

  testWidgets('while the form is being published the buttons do nothing', (tester) async {
    tall(tester);
    final chosen = <PhotoSource>[];
    var removed = 0;
    await tester.pumpWidget(host(photo: _pixel, enabled: false, onChoose: chosen.add, onRemove: () => removed++));

    await tester.tap(find.text('Change'));
    await tester.tap(find.text('Camera'));
    await tester.tap(find.text('Remove picture'));

    expect(chosen, isEmpty);
    expect(removed, 0);
  });
}
