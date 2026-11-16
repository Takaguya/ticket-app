// The booking detail page on its own: who sees "Cancel booking", what a
// cancelled booking says about the money, and the race runner's details.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/features/bookings/domain/entities/booking.dart';
import 'package:merchant/features/bookings/domain/usecases/cancel_booking.dart';
import 'package:merchant/features/bookings/domain/usecases/check_in_booking.dart';
import 'package:merchant/features/bookings/presentation/bloc/cancel_booking/cancel_booking_bloc.dart';
import 'package:merchant/features/bookings/presentation/bloc/check_in/check_in_bloc.dart';
import 'package:merchant/features/bookings/presentation/pages/booking_detail_page.dart';
import 'package:merchant/features/dashboard/domain/entities/business_snapshot.dart';
import 'package:merchant/features/dashboard/domain/usecases/watch_business_snapshot.dart';
import 'package:merchant/features/dashboard/presentation/bloc/business/business_bloc.dart';
import 'package:merchant/features/events/domain/entities/event.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchSnapshot extends Mock implements WatchBusinessSnapshot {}

class _MockCheckIn extends Mock implements CheckInBooking {}

class _MockCancelBooking extends Mock implements CancelBooking {}

final _now = DateTime(2026, 11, 12, 9, 30);

Event _event(String id, DateTime startsAt) {
  return Event(
    id: id,
    name: 'Phnom Penh Half Marathon 2026',
    startsAt: startsAt,
    venue: 'Riverside',
    ticketTypes: const [TicketType(name: '10K', priceCents: 1800, quantity: 100)],
  );
}

final _today = _event('e0', DateTime(2026, 11, 12, 5, 30));
final _upcoming = _event('e1', DateTime(2026, 11, 20, 6));
final _past = _event('e2', DateTime(2026, 10, 22, 18, 30));

Booking _booking({
  String eventId = 'e0',
  BookingStatus status = BookingStatus.open,
  SalesChannel channel = SalesChannel.online,
  CheckIn? checkIn,
  Cancellation? cancellation,
  String? promoCode,
  Runner? runner,
}) {
  return Booking(
    id: 'TK88900882',
    eventId: eventId,
    buyerName: 'Bopha Keo',
    phone: '+85549890835',
    lines: const [BookingLine(ticketType: '10K', quantity: 4)],
    totalCents: 7200,
    payment: channel == SalesChannel.door ? PaymentMethod.cash : PaymentMethod.card,
    channel: channel,
    status: status,
    checkIn: checkIn,
    cancellation: cancellation,
    promoCode: promoCode,
    runner: runner,
  );
}

void main() {
  Future<void> showPage(WidgetTester tester, Booking booking, {required bool owner}) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final watch = _MockWatchSnapshot();
    when(() => watch()).thenAnswer(
      (_) => Stream.value(
        BusinessSnapshot(events: [_today, _upcoming, _past], bookings: [booking], asOf: _now),
      ).asBroadcastStream(),
    );
    // Nothing is checked in or cancelled here: the use cases are never called.
    final checkIn = _MockCheckIn();
    final cancel = _MockCancelBooking();

    // The providers own the blocs, as in the app: awaiting close() on BusinessBloc
    // would wait for its snapshot stream. A new key gives every call new blocs.
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          key: UniqueKey(),
          providers: [
            BlocProvider(create: (_) => BusinessBloc(watchSnapshot: watch)..add(const BusinessStarted())),
            BlocProvider(create: (_) => CheckInBloc(checkIn: checkIn)),
            BlocProvider(create: (_) => CancelBookingBloc(cancelBooking: cancel, bookingId: booking.id)),
          ],
          child: BookingDetailPage(
            bookingId: booking.id,
            currentUserName: owner ? 'Vannak Sok' : 'Dara Keo',
            showMoney: owner,
            canCancel: owner,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls to the end of the page, so a button below the fold is built too.
  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
  }

  final cancelButton = find.text('Cancel booking', skipOffstage: false);

  group('"Cancel booking"', () {
    testWidgets('owners see it on an open booking of today or an upcoming event', (tester) async {
      await showPage(tester, _booking(), owner: true);
      await scrollToEnd(tester);
      expect(find.textContaining('Not checked in yet.'), findsOneWidget);
      expect(cancelButton, findsOneWidget);

      await showPage(tester, _booking(eventId: 'e1'), owner: true);
      await scrollToEnd(tester);
      expect(find.text('Check-in opens on the day of the event.'), findsOneWidget);
      expect(cancelButton, findsOneWidget);
    });

    testWidgets('scanners never see it', (tester) async {
      await showPage(tester, _booking(), owner: false);
      await scrollToEnd(tester);

      expect(find.text('Bopha Keo'), findsOneWidget);
      expect(cancelButton, findsNothing);
    });

    testWidgets('owners do not see it once the booking is checked in, cancelled or its event ended', (
      tester,
    ) async {
      // Each booking with the note that shows the page really is showing it.
      final cases = {
        _booking(status: BookingStatus.checkedIn, checkIn: CheckIn(at: _now, staffName: 'Dara Keo')):
            'Checked in at 09:30 by Dara Keo',
        _booking(status: BookingStatus.cancelled): 'Cancelled. Do not admit.',
        _booking(eventId: 'e2'): 'Did not check in. The event has ended.',
      };
      for (final MapEntry(key: booking, value: note) in cases.entries) {
        await showPage(tester, booking, owner: true);
        await scrollToEnd(tester);
        expect(find.text(note), findsOneWidget);
        expect(cancelButton, findsNothing, reason: note);
      }
    });

    testWidgets('the sheet tells the owner to pay a door sale back themselves', (tester) async {
      await showPage(tester, _booking(channel: SalesChannel.door), owner: true);
      await scrollToEnd(tester);
      await tester.tap(find.text('Cancel booking'));
      await tester.pumpAndSettle();

      expect(find.text('Why are you cancelling?'), findsOneWidget);
      for (final reason in CancelReason.values) {
        expect(find.text(reason.label), findsOneWidget);
      }
      expect(find.text(r'Give the buyer their $72.00 back yourself.'), findsOneWidget);
      expect(find.text('Pin refunds the buyer in full, to how they paid.'), findsNothing);
    });
  });

  group('a cancelled booking', () {
    testWidgets('online: who, when, why and what Pin refunded, which is less than the total with a promo', (
      tester,
    ) async {
      await showPage(
        tester,
        _booking(
          status: BookingStatus.cancelled,
          promoCode: 'D2D10',
          cancellation: Cancellation(
            at: DateTime(2026, 11, 12, 7, 15),
            staffName: 'Vannak Sok',
            reason: CancelReason.eventChanged,
            refundCents: 6480,
          ),
        ),
        owner: true,
      );

      expect(find.text('Promo D2D10 · paid by Pin'), findsOneWidget);
      await scrollToEnd(tester);
      expect(
        find.text(
          'Cancelled by Vannak Sok · 12 Nov 2026 07:15\n'
          'The event changed or was called off\n'
          r'Pin refunded the buyer $64.80',
        ),
        findsOneWidget,
      );
    });

    testWidgets('door sale: the owner gives the buyer their money back', (tester) async {
      await showPage(
        tester,
        _booking(
          status: BookingStatus.cancelled,
          channel: SalesChannel.door,
          cancellation: Cancellation(
            at: DateTime(2026, 11, 12, 7, 15),
            staffName: 'Vannak Sok',
            reason: CancelReason.soldByMistake,
            refundCents: 0,
          ),
        ),
        owner: false,
      );
      await scrollToEnd(tester);

      expect(find.textContaining(r'Give the buyer their $72.00 back'), findsOneWidget);
      expect(find.textContaining('Pin refunded'), findsNothing);
    });

    testWidgets('without details, as the older ones, says only not to admit', (tester) async {
      await showPage(tester, _booking(status: BookingStatus.cancelled), owner: true);
      await scrollToEnd(tester);

      expect(find.text('Cancelled. Do not admit.'), findsOneWidget);
      expect(find.textContaining('by the buyer'), findsNothing);
    });
  });

  testWidgets("the whole team sees a race runner's details", (tester) async {
    const runner = Runner(
      name: 'Sokha Chan',
      phone: '+85510222333',
      gender: 'female',
      age: 29,
      nationality: 'Cambodian',
      emergencyName: 'Dara Chan',
      emergencyPhone: '+85510444555',
      shirtSize: 'M',
    );
    await showPage(tester, _booking(runner: runner), owner: false);
    await scrollToEnd(tester);

    expect(find.text('Runner'), findsOneWidget);
    expect(find.text('Sokha Chan'), findsOneWidget);
    expect(find.text('+855 10 222 333'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('29'), findsOneWidget);
    expect(find.text('Cambodian'), findsOneWidget);
    expect(find.text('Dara Chan · +855 10 444 555'), findsOneWidget);
    expect(find.text('T-shirt size'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
  });
}
