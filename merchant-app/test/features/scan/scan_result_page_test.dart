import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/features/bookings/domain/entities/booking.dart';
import 'package:merchant/features/bookings/domain/entities/check_in_result.dart';
import 'package:merchant/features/scan/presentation/pages/scan_result_page.dart';

Booking _cancelled({Cancellation? cancellation}) {
  return Booking(
    id: 'TK12345678',
    eventId: 'e0',
    buyerName: 'Sokha Chan',
    phone: '+85510222333',
    lines: const [BookingLine(ticketType: '10K', quantity: 1)],
    totalCents: 1800,
    payment: PaymentMethod.card,
    channel: SalesChannel.online,
    status: BookingStatus.cancelled,
    cancellation: cancellation,
  );
}

void main() {
  Future<void> show(WidgetTester tester, Booking booking) {
    return tester.pumpWidget(
      MaterialApp(
        home: ScanResultPage(result: CheckInCancelled(booking), currentUserName: 'Dara Keo'),
      ),
    );
  }

  testWidgets('a cancelled booking shows why it was cancelled when that is known', (tester) async {
    await show(
      tester,
      _cancelled(
        cancellation: Cancellation(
          at: DateTime(2026, 11, 12, 7, 15),
          staffName: 'Vannak Sok',
          reason: CancelReason.eventChanged,
          refundCents: 1800,
        ),
      ),
    );

    expect(find.text('Booking cancelled'), findsOneWidget);
    expect(find.textContaining('Reason: The event changed or was called off'), findsOneWidget);
  });

  testWidgets('a cancelled booking without details has no reason line', (tester) async {
    await show(tester, _cancelled());

    expect(find.text('Booking cancelled'), findsOneWidget);
    expect(find.textContaining('Reason:'), findsNothing);
  });
}
