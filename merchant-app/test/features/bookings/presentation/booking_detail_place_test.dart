// The booking detail page for a place's ticket: a place is open every day, but
// each ticket is good on its visit day only, as the server decides.

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

final _now = DateTime(2026, 11, 20, 9, 30);

/// Published weeks ago: its date is only a placeholder.
final _place = Event(
  id: 'p1',
  name: 'Garden City Water Park',
  kind: EventKind.admission,
  startsAt: DateTime(2026, 11, 2),
  venue: 'Garden City',
  ticketTypes: const [TicketType(name: 'Adult', priceCents: 1000, quantity: 300)],
);

Booking _visit(DateTime day) {
  return Booking(
    id: 'TK91000100',
    eventId: 'p1',
    buyerName: 'Bopha Keo',
    phone: '+85549890835',
    lines: const [BookingLine(ticketType: 'Adult', quantity: 4)],
    totalCents: 4000,
    payment: PaymentMethod.card,
    channel: SalesChannel.online,
    status: BookingStatus.open,
    visitDate: day,
  );
}

void main() {
  Future<void> showPage(WidgetTester tester, Booking booking) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final watch = _MockWatchSnapshot();
    when(() => watch()).thenAnswer(
      (_) => Stream.value(
        BusinessSnapshot(events: [_place], bookings: [booking], asOf: _now),
      ).asBroadcastStream(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          key: UniqueKey(),
          providers: [
            BlocProvider(create: (_) => BusinessBloc(watchSnapshot: watch)..add(const BusinessStarted())),
            BlocProvider(create: (_) => CheckInBloc(checkIn: _MockCheckIn())),
            BlocProvider(
              create: (_) => CancelBookingBloc(cancelBooking: _MockCancelBooking(), bookingId: booking.id),
            ),
          ],
          child: BookingDetailPage(
            bookingId: booking.id,
            currentUserName: 'Vannak Sok',
            showMoney: true,
            canCancel: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
  }

  final checkInButton = find.text('Check in 4 tickets', skipOffstage: false);
  final cancelButton = find.text('Cancel booking', skipOffstage: false);

  testWidgets('a ticket for today can be checked in and cancelled', (tester) async {
    await showPage(tester, _visit(DateTime(2026, 11, 20)));

    expect(checkInButton, findsOneWidget);
    expect(cancelButton, findsOneWidget);
  });

  testWidgets('a ticket for a later day is not checked in today', (tester) async {
    await showPage(tester, _visit(DateTime(2026, 11, 22)));

    // The server answers 409 "Check-in opens on that day."
    expect(checkInButton, findsNothing);
    expect(find.textContaining('Not checked in yet'), findsNothing);
    expect(cancelButton, findsOneWidget);
  });

  testWidgets('a ticket whose visit day has passed is neither checked in nor cancelled', (tester) async {
    await showPage(tester, _visit(DateTime(2026, 11, 18)));

    // The server answers 409 to both: the ticket has expired.
    expect(checkInButton, findsNothing);
    expect(cancelButton, findsNothing);
    expect(find.textContaining('Not checked in yet'), findsNothing);
  });
}
