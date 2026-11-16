import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user/core/config/app_config.dart';
import 'package:user/design_system/molecules/remote_image.dart';

void main() {
  const config = AppConfig(apiBaseUrl: 'http://pin.test:8080', useMockApi: false);
  const fallback = Text('placeholder');

  Widget host(String? path) {
    return RepositoryProvider.value(
      value: config,
      child: MaterialApp(
        home: SizedBox(width: 200, height: 100, child: RemoteImage(path: path, fallback: fallback)),
      ),
    );
  }

  group('RemoteImage.resolve', () {
    test('puts the server in front of the path it sends', () {
      expect(
        RemoteImage.resolve('http://pin.test:8080', '/images/events/e1?v=5'),
        'http://pin.test:8080/images/events/e1?v=5',
      );
    });

    test('does not double the slash, whether the server address ends with one or the path starts with one', () {
      expect(RemoteImage.resolve('http://pin.test/', '/images/e'), 'http://pin.test/images/e');
      expect(RemoteImage.resolve('http://pin.test', 'images/e'), 'http://pin.test/images/e');
      expect(RemoteImage.resolve('https://api.pin.example', '/images/e?v=1'), 'https://api.pin.example/images/e?v=1');
    });

    test('leaves a complete address as it is', () {
      expect(RemoteImage.resolve('http://pin.test', 'https://cdn.example/a.jpg'), 'https://cdn.example/a.jpg');
    });
  });

  group('RemoteImage', () {
    testWidgets('shows the placeholder when the event has no picture, and asks the server for nothing', (tester) async {
      await tester.pumpWidget(host(null));

      expect(find.text('placeholder'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('fetches the picture from the server it talks to', (tester) async {
      await tester.pumpWidget(host('/images/events/e1?v=5'));

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, 'http://pin.test:8080/images/events/e1?v=5');
      expect(image.fit, BoxFit.cover);
    });

    testWidgets('falls back to the placeholder when the picture cannot be loaded', (tester) async {
      // The test environment answers every network request with an error.
      await tester.pumpWidget(host('/images/events/gone?v=1'));
      await tester.pump();
      await tester.pump();

      expect(find.text('placeholder'), findsOneWidget);
    });
  });
}
