import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/features/bookings/domain/entities/booking.dart';
import 'package:merchant/features/dashboard/domain/entities/business_snapshot.dart';
import 'package:merchant/features/dashboard/domain/usecases/watch_business_snapshot.dart';
import 'package:merchant/features/dashboard/presentation/bloc/business/business_bloc.dart';
import 'package:merchant/features/dashboard/presentation/organisms/new_booking_toaster.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchSnapshot extends Mock implements WatchBusinessSnapshot {}

Booking booking(String id, String name, {int tickets = 2, SalesChannel channel = SalesChannel.online}) {
  return Booking(
    id: id,
    eventId: 'e0',
    buyerName: name,
    phone: '+85549890835',
    lines: [BookingLine(ticketType: '10K', quantity: tickets)],
    totalCents: tickets * 1800,
    payment: channel == SalesChannel.door ? PaymentMethod.cash : PaymentMethod.abaKhqr,
    channel: channel,
    status: BookingStatus.open,
  );
}

BusinessSnapshot snapshot(List<Booking> bookings) {
  return BusinessSnapshot(events: const [], bookings: bookings, asOf: DateTime(2026, 11, 13, 8));
}

void main() {
  final bopha = booking('TK10000001', 'Bopha Keo');
  final dara = booking('TK10000002', 'Dara Chan', tickets: 1);
  final walkIn = booking('TK10000003', 'Walk-in guest', channel: SalesChannel.door);

  test('only online bookings that were not there before are new', () {
    final before = snapshot([bopha]);
    final after = snapshot([walkIn, dara, bopha]);

    expect(after.newOnlineBookingsSince(before), [dara]);
    expect(before.newOnlineBookingsSince(before), isEmpty);
  });

  test('the toast reads like the prototype', () {
    expect(
      NewBookingToaster.messageFor([bopha]),
      'New booking from the Pin app · Bopha Keo · 2 tickets',
    );
    expect(NewBookingToaster.messageFor([dara]), 'New booking from the Pin app · Dara Chan · 1 ticket');
    expect(NewBookingToaster.messageFor([bopha, dara]), '2 new bookings from the Pin app');
  });

  testWidgets('a booking made in the user app is announced, the bookings already there are not', (
    tester,
  ) async {
    final snapshots = StreamController<BusinessSnapshot>();
    final watch = _MockWatchSnapshot();
    when(() => watch()).thenAnswer((_) => snapshots.stream);

    // As in the app, the provider owns the bloc and closes it when the screen goes.
    // (Awaiting close() here would wait for the never-ending snapshot stream.)
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => BusinessBloc(watchSnapshot: watch)..add(const BusinessStarted()),
          child: const NewBookingToaster(child: Scaffold(body: SizedBox.expand())),
        ),
      ),
    );

    snapshots.add(snapshot([bopha]));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('New booking'), findsNothing);

    snapshots.add(snapshot([dara, bopha]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('New booking from the Pin app · Dara Chan · 1 ticket'), findsOneWidget);

    // Let the toast finish so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
  });
}
