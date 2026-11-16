// End-to-end flows through the real widgets, blocs, use cases, repositories
// and the in-memory mock backend, with in-memory storage and no camera.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant/app/app.dart';
import 'package:merchant/app/di/injector.dart';
import 'package:merchant/core/config/app_config.dart';
import 'package:merchant/core/services/file_sharer.dart';
import 'package:merchant/core/storage/key_value_store.dart';
import 'package:merchant/core/utils/ticker.dart';
import 'package:merchant/design_system/molecules/filter_pill.dart';
import 'package:merchant/design_system/organisms/app_tab_bar.dart';
import 'package:merchant/features/auth/data/datasources/auth_mock_data_source.dart';
import 'package:merchant/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:merchant/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:merchant/features/home/presentation/pages/home_shell_page.dart';
import 'package:merchant/mock_backend/mock_merchant_backend.dart';

/// A countdown that never ticks, so no timer outlives a test.
class _SilentTicker implements Ticker {
  const _SilentTicker();

  @override
  Stream<int> countdown({required int from}) => const Stream.empty();
}

/// Records shared files instead of opening the share sheet.
class _RecordingSharer implements FileSharer {
  final List<String> names = [];
  final List<String> contents = [];

  @override
  Future<void> shareTextFile({
    required String name,
    required String content,
    required String mimeType,
  }) async {
    names.add(name);
    contents.add(content);
  }
}

void main() {
  late _RecordingSharer sharer;

  setUp(() async {
    await sl.reset();
    configureDependencies(
      config: const AppConfig(apiBaseUrl: 'http://localhost', useMockApi: true),
    );
    sharer = _RecordingSharer();
    sl
      ..allowReassignment = true
      ..registerLazySingleton<KeyValueStore>(InMemoryKeyValueStore.new)
      ..registerLazySingleton(() => MockMerchantBackend(latency: Duration.zero))
      ..registerLazySingleton<AuthRemoteDataSource>(
        () => AuthMockDataSource(latency: Duration.zero, backend: sl()),
      )
      ..registerLazySingleton<Ticker>(() => const _SilentTicker())
      ..registerLazySingleton<FileSharer>(() => sharer);
  });

  tearDown(() async {
    await sl<AuthBloc>().close();
    await sl.reset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // A phone-sized screen: 360 x 780 logical pixels.
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MerchantApp(
        authBloc: sl<AuthBloc>()..add(const AuthStarted()),
        cameraBuilder: (_, _) => const SizedBox.expand(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Lets the toast finish so its timer does not outlive the test.
  Future<void> letToastsFinish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  Future<void> requestCode(WidgetTester tester, String phone) async {
    await tester.enterText(find.byType(TextField), phone);
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String phone) async {
    await pumpApp(tester);
    await requestCode(tester, phone);
    await enterCode(tester, AuthMockDataSource.demoCode);
    await letToastsFinish(tester);
  }

  /// The labels in the bottom tab bar.
  List<String> tabLabels(WidgetTester tester) {
    final bar = tester.widget<AppTabBar>(find.byType(AppTabBar));
    return [for (final item in bar.items) item.label];
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(AppTabBar), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  // ------------------------------------------------------------------ sign-in

  testWidgets('a signed-out person starts on the login screen', (tester) async {
    await pumpApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });

  testWidgets('an invalid phone number is explained and no code is sent', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), '12 34');
    await tester.tap(find.text('Send code'));
    await tester.pump();

    expect(find.text('Please enter a valid phone number'), findsOneWidget);
    expect(find.text('Enter the 6-digit code'), findsNothing);
    await letToastsFinish(tester);
  });

  testWidgets('a wrong code shows an error and stays on the code screen', (tester) async {
    await pumpApp(tester);

    await requestCode(tester, '12 345 678');
    await enterCode(tester, '000000');

    expect(find.text('That code is not right. Check the SMS and try again.'), findsOneWidget);
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
  });

  testWidgets('an owner lands on Today with all five tabs', (tester) async {
    await signIn(tester, '12 345 678');

    expect(tabLabels(tester), ['Today', 'Scan', 'Bookings', 'Finance', 'Staff']);
    expect(find.text('Khmer Runners Club'), findsOneWidget);
    expect(find.text('Vannak Sok'), findsOneWidget);
    expect(find.text('Phnom Penh Half Marathon 2026'), findsOneWidget);
    expect(find.text('Checked in'), findsOneWidget);
  });

  testWidgets("the owner sees the live event's kind on Today", (tester) async {
    await signIn(tester, '12 345 678');

    expect(find.textContaining('Marathon · Starts'), findsOneWidget);
  });

  testWidgets('a scanner lands on Scan and has only Scan and Bookings', (tester) async {
    await signIn(tester, '98 765 432');

    expect(tabLabels(tester), ['Scan', 'Bookings']);
    expect(find.text('Scan tickets'), findsOneWidget);
    expect(find.text('Point the camera at the ticket QR'), findsOneWidget);
  });

  testWidgets('a new number registers a business and lands in the app as owner', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await requestCode(tester, '77 000 111');
    await enterCode(tester, AuthMockDataSource.demoCode);

    expect(find.text('Welcome to Pin Merchant'), findsOneWidget);
    await tester.tap(find.text('Register a business'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us about your business'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Kampot Night Market');
    await tester.enterText(find.byType(TextField).at(1), 'Sophea Lim');
    await tester.tap(find.text('Cinema'));
    await tester.pump();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Kampot Night Market'), findsOneWidget);
    expect(find.text('Sophea Lim'), findsOneWidget);
    expect(find.text('No event today'), findsOneWidget);
    expect(tabLabels(tester), hasLength(5));
    await letToastsFinish(tester);
  });

  testWidgets('a bus company creates trips, not events, and the form says what is missing', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await requestCode(tester, '77 000 333');
    await enterCode(tester, AuthMockDataSource.demoCode);
    await tester.tap(find.text('Register a business'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Mekong Express');
    await tester.enterText(find.byType(TextField).at(1), 'Dara Chea');
    await tester.tap(find.text('Bus'));
    await tester.pump();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await letToastsFinish(tester);

    // Today speaks of trips, and its button opens the trip form.
    expect(find.text('Upcoming trips'), findsOneWidget);
    expect(find.text('Create event'), findsNothing);
    await tester.scrollUntilVisible(find.text('Create trip'), 200);
    await tester.tap(find.text('Create trip'));
    await tester.pumpAndSettle();

    expect(find.text('Seater · 2+2'), findsOneWidget);
    expect(find.text('VIP seater · 2+1'), findsOneWidget);
    expect(find.text('Sleeper · 1+1'), findsOneWidget);
    expect(find.text('40 seats. Passengers choose their seat in the Pin app.'), findsOneWidget);

    // A different coach changes the number of seats.
    await tester.tap(find.text('Sleeper · 1+1'));
    await tester.pump();
    expect(find.text('16 seats. Passengers choose their seat in the Pin app.'), findsOneWidget);

    // Publishing an empty form explains the first thing that is missing.
    await tester.tap(find.text('Publish trip'));
    await tester.pump();
    expect(find.text('Enter where the trip starts'), findsOneWidget);
    await letToastsFinish(tester);
  });

  testWidgets('a cinema creates screenings, not events, and the form says what is missing', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await requestCode(tester, '77 000 444');
    await enterCode(tester, AuthMockDataSource.demoCode);
    await tester.tap(find.text('Register a business'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Mekong Cinema');
    await tester.enterText(find.byType(TextField).at(1), 'Dara Chea');
    await tester.tap(find.text('Cinema'));
    await tester.pump();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await letToastsFinish(tester);

    // Today speaks of screenings, and its button opens the screening form.
    expect(find.text('Upcoming screenings'), findsOneWidget);
    expect(find.text('Create event'), findsNothing);
    await tester.scrollUntilVisible(find.text('Create screening'), 200);
    await tester.tap(find.text('Create screening'));
    await tester.pumpAndSettle();

    expect(find.text('Small'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Large'), findsOneWidget);
    expect(
      find.text('8 rows of 10, 80 seats. Viewers choose their seat in the Pin app.'),
      findsOneWidget,
    );

    // A different hall size changes the number of seats.
    await tester.ensureVisible(find.text('Large'));
    await tester.pump();
    await tester.tap(find.text('Large'));
    await tester.pump();
    expect(
      find.text('10 rows of 12, 120 seats. Viewers choose their seat in the Pin app.'),
      findsOneWidget,
    );

    // Publishing an empty form explains the first thing that is missing.
    await tester.tap(find.text('Publish screening'));
    await tester.pump();
    expect(find.text("Enter the film's title"), findsOneWidget);
    await letToastsFinish(tester);
  });

  testWidgets('an admission business creates places, not events, and the form says what is missing', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    await requestCode(tester, '77 000 555');
    await enterCode(tester, AuthMockDataSource.demoCode);
    await tester.tap(find.text('Register a business'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Garden City');
    await tester.enterText(find.byType(TextField).at(1), 'Visal Tep');
    await tester.tap(find.text('Admission'));
    await tester.pump();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await letToastsFinish(tester);

    // Today speaks of places, and its button opens the place form.
    expect(find.text('Upcoming places'), findsOneWidget);
    expect(find.text('Create event'), findsNothing);
    await tester.scrollUntilVisible(find.text('Create place'), 200);
    await tester.tap(find.text('Create place'));
    await tester.pumpAndSettle();

    // No date: a place is open every day. A ticket type has a price and a limit per day.
    expect(find.text('Date'), findsNothing);
    expect(find.text('The place is open every day. Visitors choose the day they come.'), findsOneWidget);
    expect(find.text('Max per day'), findsOneWidget);
    await tester.ensureVisible(find.text('Add ticket type'));
    await tester.pump();
    await tester.tap(find.text('Add ticket type'));
    await tester.pump();
    expect(find.text('Max per day'), findsNWidgets(2));

    // Publishing an empty form explains the first thing that is missing.
    await tester.tap(find.text('Publish place'));
    await tester.pump();
    expect(find.text('Enter the name of the place'), findsOneWidget);
    await letToastsFinish(tester);
  });

  testWidgets('a new number joins a team with the join code as a scanner', (tester) async {
    await pumpApp(tester);
    await requestCode(tester, '77 000 222');
    await enterCode(tester, AuthMockDataSource.demoCode);

    await tester.tap(find.text('Join a team with a code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Mony Chea');
    await tester.enterText(find.byType(TextField).at(1), '000 000');
    await tester.tap(find.text('Join team'));
    await tester.pumpAndSettle();
    expect(
      find.text('That join code is not right. Ask the owner for the current code.'),
      findsOneWidget,
    );
    await letToastsFinish(tester);

    await tester.enterText(find.byType(TextField).at(1), '482 913');
    await tester.tap(find.text('Join team'));
    await tester.pumpAndSettle();

    expect(tabLabels(tester), ['Scan', 'Bookings']);
    // Scanning for the business they joined.
    expect(find.textContaining('Phnom Penh Half Marathon 2026'), findsOneWidget);
    await letToastsFinish(tester);
  });

  testWidgets('anyone can sign out from the account sheet', (tester) async {
    await signIn(tester, '98 765 432');

    await tester.tap(find.bySemanticsLabel('Account'));
    await tester.pumpAndSettle();
    expect(find.text('You can scan tickets and see bookings.'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  // ----------------------------------------------------------------- routing

  GoRouter routerOf(WidgetTester tester) {
    return GoRouter.of(tester.element(find.byType(HomeShellPage)));
  }

  String currentPath(WidgetTester tester) {
    return routerOf(tester).routerDelegate.currentConfiguration.uri.path;
  }

  testWidgets('owners land on /today and scanners on /scan', (tester) async {
    await signIn(tester, '12 345 678');
    expect(currentPath(tester), '/today');

    await tapTab(tester, 'Finance');
    expect(currentPath(tester), '/finance');
  });

  testWidgets('a scanner sent to an owner-only URL lands on Scan instead', (tester) async {
    await signIn(tester, '98 765 432');
    expect(currentPath(tester), '/scan');

    for (final path in ['/today', '/finance', '/staff', '/door-sale', '/create-event']) {
      routerOf(tester).go(path);
      await tester.pumpAndSettle();
      expect(currentPath(tester), '/scan', reason: path);
    }
  });

  testWidgets('each tab keeps its state while another tab is showing', (tester) async {
    await signIn(tester, '12 345 678');
    await tapTab(tester, 'Bookings');
    await tester.enterText(find.byType(TextField), 'nobody by this name');
    await tester.pumpAndSettle();
    expect(find.text('No bookings match.'), findsOneWidget);

    await tapTab(tester, 'Today');
    await tapTab(tester, 'Bookings');

    expect(find.text('No bookings match.'), findsOneWidget);
    expect(currentPath(tester), '/bookings');
  });

  // ---------------------------------------------------------------- check-in

  testWidgets('scanning admits a valid ticket once, then reports it as used', (tester) async {
    await signIn(tester, '98 765 432');

    await tester.tap(find.text('Valid'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Admit'), findsOneWidget);
    expect(find.textContaining('checked in'), findsOneWidget);

    await tester.tap(find.text('Scan next'));
    await tester.pumpAndSettle();
    expect(find.text('Point the camera at the ticket QR'), findsOneWidget);

    await tester.tap(find.text('Already used'));
    await tester.pumpAndSettle();
    expect(find.text('Already checked in'), findsOneWidget);
    expect(find.text('Do not admit'), findsOneWidget);

    await tester.tap(find.text('Scan next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('Booking cancelled'), findsOneWidget);

    await tester.tap(find.text('Scan next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other event'));
    await tester.pumpAndSettle();
    expect(find.text('Ticket for another event'), findsOneWidget);
  });

  testWidgets('typing an unknown booking ID reports it was not found', (tester) async {
    await signIn(tester, '98 765 432');

    await tester.tap(find.text('Enter booking ID'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '11112222');
    await tester.pump();
    await tester.tap(find.text('Check ticket'));
    await tester.pumpAndSettle();

    expect(find.text('Booking not found'), findsOneWidget);
    expect(find.text('No booking with ID TK11112222 for this event.'), findsOneWidget);
  });

  // ---------------------------------------------------------------- bookings

  testWidgets('owners can download the bookings list but scanners cannot', (tester) async {
    await signIn(tester, '12 345 678');
    await tapTab(tester, 'Bookings');

    await tester.tap(find.text('Download list'));
    await tester.pumpAndSettle();

    expect(sharer.names, ['phnom-penh-half-marathon-2026-bookings.csv']);
    expect(sharer.contents.single, contains('"Booking ID","Name","Phone"'));

    await tester.tap(find.bySemanticsLabel('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    await requestCode(tester, '98 765 432');
    await enterCode(tester, AuthMockDataSource.demoCode);
    await letToastsFinish(tester);
    await tapTab(tester, 'Bookings');
    expect(find.text('Download list'), findsNothing);
  });

  testWidgets('searching bookings and opening one shows its details', (tester) async {
    await signIn(tester, '12 345 678');
    await tapTab(tester, 'Bookings');

    // Show only checked-in bookings (the pill may be scrolled out of view),
    // then open the first one.
    final checkedInPill = find.byWidgetPredicate(
      (widget) => widget is FilterPill && widget.label == 'Checked in',
      skipOffstage: false,
    );
    await tester.ensureVisible(checkedInPill);
    await tester.pumpAndSettle();
    await tester.tap(checkedInPill);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp(r'^TK\d{8} · ')).first);
    await tester.pumpAndSettle();

    expect(find.text('Event'), findsOneWidget);
    expect(find.textContaining('Checked in at'), findsOneWidget);
    expect(find.text('You receive'), findsOneWidget);
  });

  /// Opens the first booking that is not checked in yet, from the Bookings tab.
  Future<void> openAnOpenBooking(WidgetTester tester) async {
    await tapTab(tester, 'Bookings');
    final openPill = find.byWidgetPredicate(
      (widget) => widget is FilterPill && widget.label == 'Not checked in',
      skipOffstage: false,
    );
    await tester.ensureVisible(openPill);
    await tester.pumpAndSettle();
    await tester.tap(openPill);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(RegExp(r'^TK\d{8} · ')).first);
    await tester.pumpAndSettle();
    expect(find.text('Event'), findsOneWidget);
  }

  testWidgets('an owner cancels an open booking: reason, refund and who did it show', (tester) async {
    await signIn(tester, '12 345 678');
    await openAnOpenBooking(tester);

    await tester.scrollUntilVisible(find.text('Cancel booking'), 200);
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    expect(find.text('Why are you cancelling?'), findsOneWidget);
    expect(find.text('Pin refunds the buyer in full, to how they paid.'), findsOneWidget);

    // A reason has to be chosen first.
    await tester.tap(find.text('Cancel booking').last);
    await tester.pumpAndSettle();
    expect(find.text('Choose why you are cancelling.'), findsOneWidget);

    await tester.tap(find.text('Sold by mistake'));
    await tester.pump();
    await tester.tap(find.text('Cancel booking').last);
    await tester.pumpAndSettle();

    expect(find.text('Why are you cancelling?'), findsNothing);
    expect(find.text('Booking cancelled'), findsOneWidget);
    expect(find.textContaining('Cancelled by Vannak Sok'), findsOneWidget);
    expect(find.textContaining('Sold by mistake'), findsOneWidget);
    expect(find.textContaining('Pin refunded the buyer'), findsOneWidget);
    expect(find.text('Cancel booking', skipOffstage: false), findsNothing);
    await letToastsFinish(tester);
  });

  testWidgets('a scanner sees a booking but has no way to cancel it', (tester) async {
    await signIn(tester, '98 765 432');
    await openAnOpenBooking(tester);

    expect(find.text('Cancel booking', skipOffstage: false), findsNothing);
  });

  // --------------------------------------------------------------- door sale

  testWidgets('a door sale is recorded and the buyer can be admitted at once', (tester) async {
    await signIn(tester, '12 345 678');

    await tester.tap(find.text('Sell at the door'));
    await tester.pumpAndSettle();
    expect(find.text('Take payment'), findsOneWidget);

    await tester.tap(find.byTooltip('More').first);
    await tester.tap(find.byTooltip('More').first);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '012 777 888');
    await tester.pump();
    await tester.tap(find.text('Take payment'));
    await tester.pumpAndSettle();

    expect(find.text('Collect cash'), findsOneWidget);
    expect(find.text(r'$24.00'), findsOneWidget);
    await tester.tap(find.text('Cash received'));
    await tester.pumpAndSettle();

    expect(find.text('E-ticket sent by SMS'), findsOneWidget);
    await tester.tap(find.text('Admit 2 tickets now'));
    await tester.pumpAndSettle();

    expect(find.text('2 tickets checked in'), findsOneWidget);
    expect(find.text('Checked in'), findsOneWidget);
    await letToastsFinish(tester);
  });

  // ---------------------------------------------------------- finance, staff

  testWidgets('finance shows commission on online sales only', (tester) async {
    await signIn(tester, '12 345 678');
    await tapTab(tester, 'Finance');

    expect(find.text('Booked in the Pin app'), findsOneWidget);
    expect(find.text('Pin commission (5%)'), findsOneWidget);
    expect(find.text(r'$0.00'), findsOneWidget); // Nothing sold at the door yet.
    expect(find.text('You receive'), findsOneWidget);
  });

  testWidgets('the staff screen shows the join code and the team', (tester) async {
    await signIn(tester, '12 345 678');
    await tapTab(tester, 'Staff');

    expect(find.text('482 913'), findsOneWidget);
    expect(find.text('Vannak Sok (you)'), findsOneWidget);
    expect(find.text('Dara Keo'), findsOneWidget);

    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(find.text('Dara Keo'), findsNothing);
    expect(find.text('Dara Keo removed'), findsOneWidget);
    await letToastsFinish(tester);
  });
}
