import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/utils/money.dart';
import 'package:merchant/features/bookings/domain/entities/booking.dart';
import 'package:merchant/features/bookings/domain/entities/booking_filter.dart';
import 'package:merchant/features/bookings/domain/entities/bookings_csv.dart';
import 'package:merchant/features/bookings/domain/entities/sales_summary.dart';
import 'package:merchant/features/events/domain/entities/event.dart';

Booking booking(
  String id, {
  String name = 'Sokha Chan',
  String phone = '012 345 678',
  int quantity = 1,
  String type = '10K',
  int totalCents = 1800,
  SalesChannel channel = SalesChannel.online,
  BookingStatus status = BookingStatus.open,
  CheckIn? checkIn,
}) {
  return Booking(
    id: id,
    eventId: 'e0',
    buyerName: name,
    phone: phone,
    lines: [BookingLine(ticketType: type, quantity: quantity)],
    totalCents: totalCents,
    payment: channel == SalesChannel.door ? PaymentMethod.cash : PaymentMethod.card,
    channel: channel,
    status: status,
    checkIn: checkIn,
  );
}

void main() {
  final event = Event(
    id: 'e0',
    name: 'Phnom Penh Half Marathon 2026',
    startsAt: DateTime(2026, 11, 12, 5, 30),
    venue: 'Riverside',
    ticketTypes: const [
      TicketType(name: '5K', priceCents: 1200, quantity: 10),
      TicketType(name: '10K', priceCents: 1800, quantity: 10),
    ],
  );

  group('SalesSummary', () {
    final admittedAt = CheckIn(at: DateTime(2026, 11, 12, 5), staffName: 'Dara Keo');
    final summary = SalesSummary.of(
      event: event,
      bookings: [
        booking('TK00000001', quantity: 2, totalCents: 3600, status: BookingStatus.checkedIn, checkIn: admittedAt),
        booking('TK00000002', type: '5K', totalCents: 1200),
        booking('TK00000003', quantity: 3, totalCents: 5400, status: BookingStatus.cancelled),
        booking('TK00000004', totalCents: 1800, channel: SalesChannel.door),
      ],
    );

    test('cancelled bookings count for nothing', () {
      expect(summary.sold, 4);
      expect(summary.bookingCount, 3);
      expect(summary.revenueCents, 3600 + 1200 + 1800);
    });

    test('commission is 5% of online sales only; door sales have none', () {
      expect(summary.onlineCents, 4800);
      expect(summary.doorCents, 1800);
      expect(summary.commissionCents, 240);
      expect(summary.netCents, 6600 - 240);
    });

    test('left is capacity minus tickets sold', () {
      expect(summary.capacity, 20);
      expect(summary.left, 16);
      expect(summary.checkedIn, 2);
      expect(summary.stillToArrive, 2);
    });

    test('per ticket type counts', () {
      expect(summary.byTicketType, const [
        TicketTypeStats(name: '5K', sold: 1, checkedIn: 0),
        TicketTypeStats(name: '10K', sold: 3, checkedIn: 2),
      ]);
    });
  });

  group('BookingSearch', () {
    final list = [
      booking('TK48213377', name: 'Sokha Chan', phone: '012 345 678'),
      booking('TK11112222', name: 'Dara Keo', phone: '097 111 2222'),
    ];

    test('matches name, booking ID, or 3+ digits of the phone', () {
      expect(BookingSearch.search(list, 'dara').single.id, 'TK11112222');
      expect(BookingSearch.search(list, '48213').single.id, 'TK48213377');
      expect(BookingSearch.search(list, '345 6').single.id, 'TK48213377');
    });

    test('two phone digits are not enough to match a phone number', () {
      expect(BookingSearch.search(list, '34'), isEmpty);
    });

    test('an empty query keeps everything, sorted by name', () {
      expect(BookingSearch.search(list, '  ').map((b) => b.buyerName), ['Dara Keo', 'Sokha Chan']);
    });

    test('status filters', () {
      final cancelled = booking('TK3', status: BookingStatus.cancelled);
      expect(BookingFilter.all.accepts(cancelled), isTrue);
      expect(BookingFilter.cancelled.accepts(cancelled), isTrue);
      expect(BookingFilter.open.accepts(cancelled), isFalse);
    });
  });

  group('BookingsCsv', () {
    test('names the file after the event and filter and quotes every field', () {
      final file = BookingsCsv.build(
        event: event,
        bookings: [booking('TK48213377', name: 'Chan "Sokha"', totalCents: 1800)],
        filter: BookingFilter.open,
      );

      expect(file.name, 'phnom-penh-half-marathon-2026-bookings-not-checked-in.csv');
      final lines = file.content.split('\r\n');
      expect(lines.first, startsWith('﻿"Booking ID","Name"'));
      expect(lines[1], startsWith('"TK48213377","Chan ""Sokha""","012 345 678","1"'));
      expect(lines[1], contains('"18.00","0.90","17.10"'));
    });

    test('ends with the runner columns, in the server CSV order, empty without a runner', () {
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
      final withRunner = Booking(
        id: 'TK48213377',
        eventId: 'e0',
        buyerName: 'Sokha Chan',
        phone: '+85510222333',
        lines: const [BookingLine(ticketType: '10K', quantity: 1)],
        totalCents: 1800,
        payment: PaymentMethod.card,
        channel: SalesChannel.online,
        status: BookingStatus.open,
        runner: runner,
      );

      final lines = BookingsCsv.build(
        event: event,
        bookings: [withRunner, booking('TK48213378')],
      ).content.split('\r\n');

      expect(
        lines.first,
        endsWith(
          '"Checked in by","Runner","Runner phone","Runner email","Runner gender","Runner age",'
          '"Runner nationality","Emergency contact","Emergency phone","Visit date"',
        ),
      );
      expect(
        lines[1],
        endsWith('"","","Sokha Chan","+85510222333","","female","29","Cambodian","Dara Chan","+85510444555",""'),
      );
      expect(lines[2], endsWith('"","","","","","","","","","",""'));
    });

    test('a place booking carries the day its tickets are for', () {
      final visit = Booking(
        id: 'TK91000100',
        eventId: event.id,
        buyerName: 'Bopha Keo',
        phone: '+85549890835',
        lines: const [BookingLine(ticketType: 'Adult', quantity: 2)],
        totalCents: 2000,
        payment: PaymentMethod.card,
        channel: SalesChannel.online,
        status: BookingStatus.open,
        visitDate: DateTime(2026, 11, 8),
      );

      final lines = BookingsCsv.build(event: event, bookings: [visit]).content.split('\r\n');

      expect(lines[1], endsWith('"2026-11-08"'));
    });
  });

  group('Money', () {
    test('formats cents as dollars with grouping', () {
      expect(Money.format(0), r'$0.00');
      expect(Money.format(123456789), r'$1,234,567.89');
      expect(Money.format(-250), r'−$2.50');
    });

    test('parses what people type', () {
      expect(Money.parse('12'), 1200);
      expect(Money.parse('12.5'), 1250);
      expect(Money.parse(' 0.05 '), 5);
      expect(Money.parse('12.345'), isNull);
      expect(Money.parse('abc'), isNull);
    });
  });
}
