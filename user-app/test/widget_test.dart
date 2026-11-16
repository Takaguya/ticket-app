// End-to-end flows through the real widgets, blocs, use cases, repositories
// and the in-memory mock backend, with in-memory storage, no network delay and
// the clock stopped at 08:00 on 15 Nov 2026.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:user/app/app.dart';
import 'package:user/app/di/injector.dart';
import 'package:user/core/storage/key_value_store.dart';
import 'package:user/core/utils/clock.dart';
import 'package:user/core/utils/ticker.dart';
import 'package:user/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:user/features/catalog/domain/entities/available_categories.dart';
import 'package:user/features/catalog/presentation/organisms/category_shortcuts.dart';

/// A countdown that never ticks, so no timer outlives a test.
class _SilentTicker implements Ticker {
  const _SilentTicker();

  @override
  Stream<int> countdown({required int from}) => const Stream.empty();
}

void main() {
  setUp(() async {
    await sl.reset();
    configureDependencies(
      store: InMemoryKeyValueStore(),
      clock: FixedClock(DateTime(2026, 11, 15, 8)),
      mockLatency: Duration.zero,
    );
    sl
      ..allowReassignment = true
      ..registerLazySingleton<Ticker>(() => const _SilentTicker());
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

    await tester.pumpWidget(PinApp(authBloc: sl<AuthBloc>()..add(const AuthStarted())));
    await tester.pumpAndSettle();
  }

  /// Types the number, asks for a code and types the demo code.
  Future<void> signIn(WidgetTester tester, String phone) async {
    await tester.enterText(find.byType(TextField), phone);
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
  }

  Future<void> openTickets(WidgetTester tester) async {
    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();
    expect(find.text('Events, buses, cinema & more'), findsOneWidget);
  }

  testWidgets('a returning person signs in with a code and lands on Home', (tester) async {
    await pumpApp(tester);
    expect(find.text('Welcome back'), findsOneWidget);

    await signIn(tester, '010 222 333');

    expect(find.text('Good morning, Sokha'), findsOneWidget);
    for (final tab in ['Home', 'Activity', 'Message', 'Profile']) {
      expect(find.text(tab), findsOneWidget);
    }
  });

  testWidgets('a new number registers with a few details', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await signIn(tester, '012 888 999');
    expect(find.text('Your details'), findsOneWidget);

    // Nothing filled in yet: the button says what is missing.
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Please enter your name'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Dara Pich');
    await tester.tap(find.text('Female'));
    await tester.tap(find.text('Choose a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Dara'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Dara Pich'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
  });

  testWidgets('an event: browse, choose tickets, a promo code, pay, see the ticket', (tester) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');
    await openTickets(tester);
    expect(find.text('Happening this month'), findsOneWidget);

    await tester.tap(find.text('Events').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khmer Rock Night 2026').first);
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Koh Pich Theatre'), findsOneWidget);
    expect(find.text('Sun 22 Nov 2026'), findsOneWidget);
    expect(find.text('General admission'), findsOneWidget);
    expect(find.text('•  Organiser: PP Live Events'), findsOneWidget);

    await tester.tap(find.text('Select tickets'));
    await tester.pumpAndSettle();
    expect(find.text('No tickets selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Add General admission'));
    await tester.tap(find.byTooltip('Add General admission'));
    await tester.tap(find.byTooltip('Add VIP'));
    await tester.pump();
    expect(find.text('3 tickets'), findsOneWidget);
    expect(find.text(r'$65.00'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Subtotal · 3 tickets'), findsOneWidget);

    // 10% off with D2D10, typed in lower case.
    await tester.tap(find.bySemanticsLabel('Add a promo code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'd2d10');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Promo D2D10'), findsOneWidget);
    expect(find.text(r'$58.50'), findsWidgets);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Tickets issued. Show the QR code at the entrance.'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('2× General admission, 1× VIP'), findsOneWidget);

    // Back from the new ticket: the Activity list, with the booking in it.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    // The new booking and the demo account's cancelled one, both for this event.
    expect(find.text('Khmer Rock Night 2026'), findsNWidgets(2));
    expect(find.text('Neak Ta: The Guardian'), findsOneWidget);
  });

  testWidgets('a film: a showtime, a seat, a snack, then pay', (tester) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');
    await openTickets(tester);

    await tester.tap(find.text('Cinema').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neak Ta: The Guardian').first);
    await tester.pumpAndSettle();

    expect(find.text('Select theatre & time'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    // Nothing chosen yet.
    await tester.tap(find.text('Select seats'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a day and a time first'), findsOneWidget);

    await tester.ensureVisible(find.text('10:30'));
    await tester.tap(find.text('10:30'));
    await tester.pumpAndSettle();
    expect(find.text('Sun 15 Nov · 10:30 · Hall 2'), findsOneWidget);

    await tester.tap(find.text('Select seats'));
    await tester.pumpAndSettle();
    expect(find.text('SCREEN'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Seat \w+, free$')).first);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Add snacks'), findsOneWidget);
    await tester.tap(find.byTooltip('Add Popcorn combo'));
    await tester.pump();
    // A $4.50 seat and a $6.50 popcorn combo.
    expect(find.text(r'$11.00'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('TICKETS & SNACKS'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('1× Popcorn combo'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('on a server that sells no snacks, a film goes from its seat straight to checkout', (tester) async {
    sl.registerSingleton<AvailableCategories>(AvailableCategories.pinApi);
    await pumpApp(tester);
    await signIn(tester, '010 222 333');
    await openTickets(tester);

    await tester.tap(find.text('Cinema').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neak Ta: The Guardian').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('10:30'));
    await tester.tap(find.text('10:30'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select seats'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Seat \w+, free$')).first);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // No snack step: this is checkout, with the seat only.
    expect(find.text('Add snacks'), findsNothing);
    expect(find.text('Confirm'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('bus tickets: only buses that have not left yet', (tester) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');
    await openTickets(tester);

    await tester.tap(find.text('Bus').first);
    await tester.pumpAndSettle();

    expect(find.text('Bus tickets'), findsOneWidget);
    expect(find.text('Phnom Penh'), findsWidgets);
    expect(find.text('Siem Reap'), findsWidgets);
    // At 08:00 the 07:45 Giant Ibis has gone.
    expect(find.text('3 DEPARTURES · TODAY, 15 NOV'), findsOneWidget);
    expect(find.text('Giant Ibis'), findsNothing);
    expect(find.text('Virak Buntham'), findsOneWidget);

    await tester.tap(find.byTooltip('Swap from and to'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('From Siem Reap'), findsOneWidget);
  });

  testWidgets('search finds a bus route and opens it', (tester) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');
    await openTickets(tester);

    await tester.tap(find.text('Search events, routes, movies'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'kampot');
    await tester.pumpAndSettle();

    expect(find.text('Phnom Penh → Kampot'), findsOneWidget);
    await tester.tap(find.text('Phnom Penh → Kampot'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('To Kampot'), findsOneWidget);
  });

  testWidgets('signing out asks first, then returns to sign-in', (tester) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Sokha Chan'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a bus: a seat on the map, then pay', (tester) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');
    await openTickets(tester);
    await tester.tap(find.text('Bus').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Virak Buntham'));
    await tester.pumpAndSettle();
    expect(find.text('Choose seats'), findsOneWidget);
    expect(find.text('VIP seater · 2+1'), findsOneWidget);

    // Nothing chosen yet.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Choose at least one seat'), findsOneWidget);
    // Let the message go, so it does not cover a seat.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    final freeSeat = find.bySemanticsLabel(RegExp(r'^Seat \w+, free$')).first;
    await tester.ensureVisible(freeSeat);
    await tester.tap(freeSeat);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Get on at Giant Ibis / Virak Buntham Terminal'), findsOneWidget);
    // The fare is further down the page.
    await tester.scrollUntilVisible(find.text('FARE'), 200);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('DEPARTS'), findsOneWidget);
    expect(find.text('Virak Buntham'), findsOneWidget);
  });

  testWidgets("a race asks for the runner's details", (tester) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');
    await openTickets(tester);
    await tester.tap(find.text('Events').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phnom Penh Half Marathon 2026').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select tickets'));
    await tester.pumpAndSettle();
    expect(find.text('Run category'), findsOneWidget);

    // One runner per booking: the entry moves to the distance tapped last.
    await tester.tap(find.byTooltip('Add 10K'));
    await tester.tap(find.byTooltip('Add 21K Half marathon'));
    await tester.pump();
    expect(find.text('1 ticket'), findsOneWidget);
    expect(find.text(r'$25.00'), findsNWidgets(2));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Runner details'), findsOneWidget);
    // Filled from the account; the age comes from the date of birth.
    expect(find.text('Sokha Chan'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the nationality'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), 'Cambodian');
    await tester.ensureVisible(find.text('M'));
    await tester.tap(find.text('M'));
    await tester.ensureVisible(fields.at(5));
    await tester.enterText(fields.at(5), 'Vanna Chan');
    await tester.ensureVisible(fields.at(6));
    await tester.enterText(fields.at(6), '012 345 678');
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('RUNNER'), findsOneWidget);
    expect(find.text('Female · 30 · Cambodian · T-shirt M'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('T-SHIRT'), findsOneWidget);
    expect(find.text('1× 21K Half marathon'), findsOneWidget);
  });

  testWidgets('a booking step opened without its details goes to Tickets', (tester) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');

    // As after the app is restored: the location is back, `extra` is not.
    for (final step in ['/book/tickets', '/book/runner', '/book/seats', '/book/snacks', '/book/checkout']) {
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(step);
      await tester.pumpAndSettle();
      expect(find.text('Events, buses, cinema & more'), findsOneWidget, reason: step);
    }
  });

  testWidgets('a ticket opened by its ID alone is loaded, or said to be missing', (tester) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');

    void go(String location) => GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);

    go('/activity/TK00000000');
    await tester.pumpAndSettle();
    expect(find.text("Can't show this ticket"), findsOneWidget);
    expect(find.text("This booking can't be found."), findsOneWidget);

    go('/activity');
    await tester.pumpAndSettle();
    go('/activity/TK48213377');
    await tester.pumpAndSettle();
    expect(find.text('Your tickets'), findsOneWidget);
    expect(find.text('Hall 3 · F5, F6'), findsOneWidget);
    expect(find.text('TK48213377'), findsOneWidget);
  });

  testWidgets('Activity lists the bookings and opens their tickets', (tester) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

    // The demo account's cinema booking in two days.
    expect(find.text('Neak Ta: The Guardian'), findsOneWidget);
    expect(find.text('TK48213377 · 2 tickets'), findsOneWidget);
    // And the rock night its organiser cancelled yesterday.
    expect(find.text('Khmer Rock Night 2026'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phnom Penh → Kampot'));
    await tester.pumpAndSettle();
    expect(find.text('Ended'), findsOneWidget);
    expect(find.text('5A, 5B'), findsOneWidget);
    expect(find.text('TK30571942'), findsOneWidget);
  });

  testWidgets('a cancelled ticket shows who cancelled it, why and the refund, and no QR code', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, '010 222 333');
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Khmer Rock Night 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Your tickets'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Cancelled by PP Live Events on 14 Nov 2026'), findsOneWidget);
    expect(find.text('The event changed or was called off'), findsOneWidget);
    expect(find.text(r'Refunded $30.00 to ABA Pay'), findsOneWidget);
    expect(find.text('TK55012468'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('on a server that sells only events, Bus, Cinema and Admission are "Soon" and their pages go to Tickets', (
    tester,
  ) async {
    // What the injector registered before the Pin API sold bus trips.
    sl.registerSingleton<AvailableCategories>(AvailableCategories.eventsOnly);
    await pumpApp(tester);
    await signIn(tester, '010 222 333');
    await openTickets(tester);

    Finder inShortcuts(String text) =>
        find.descendant(of: find.byType(CategoryShortcuts), matching: find.text(text));
    expect(inShortcuts('Soon'), findsNWidgets(3));

    await tester.tap(inShortcuts('Bus'));
    await tester.pumpAndSettle();
    expect(find.text('Bus is coming soon.'), findsOneWidget);
    expect(find.text('Events, buses, cinema & more'), findsOneWidget);

    // An old link to a category that is not on sale opens the Tickets page instead.
    void go(String location) => GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    for (final location in ['/tickets/bus', '/tickets/cinema', '/tickets/admission']) {
      go(location);
      await tester.pumpAndSettle();
      expect(find.text('Events, buses, cinema & more'), findsOneWidget, reason: location);
    }

    // Events are on sale and open as before.
    go('/tickets/events');
    await tester.pumpAndSettle();
    expect(find.text('Events, buses, cinema & more'), findsNothing);
    expect(find.text('Khmer Rock Night 2026'), findsWidgets);
  });
}
