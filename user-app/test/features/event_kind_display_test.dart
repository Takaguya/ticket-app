import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:user/core/result/result.dart';
import 'package:user/core/utils/clock.dart';
import 'package:user/features/booking/domain/entities/booking.dart';
import 'package:user/features/booking/domain/entities/booking_cancellation.dart';
import 'package:user/features/booking/domain/entities/booking_request.dart';
import 'package:user/features/booking/domain/entities/order.dart';
import 'package:user/features/booking/presentation/organisms/ticket_card.dart';
import 'package:user/features/catalog/domain/entities/event_kind.dart';
import 'package:user/features/catalog/domain/entities/listing.dart';
import 'package:user/features/catalog/domain/entities/ticket_tier.dart';
import 'package:user/features/catalog/domain/usecases/get_listing.dart';
import 'package:user/features/catalog/domain/usecases/get_showtimes.dart';
import 'package:user/features/catalog/presentation/bloc/listing_detail/listing_detail_bloc.dart';
import 'package:user/features/catalog/presentation/organisms/listing_poster_card.dart';
import 'package:user/features/catalog/presentation/pages/listing_detail_page.dart';

class _MockGetListing extends Mock implements GetListing {}

class _MockGetShowtimes extends Mock implements GetShowtimes {}

const _tier = TicketTier(name: 'Standard', priceCents: 1000);

/// An event as a merchant publishes it in Pin Merchant: no description and no
/// policy, which only the demo data fills in.
EventListing _merchantEvent(EventKind kind) => EventListing(
  id: 'ev9',
  name: 'Riverside Evening',
  startsAt: DateTime(2026, 11, 28, 19),
  venue: 'Riverside',
  venueDetail: '',
  about: '',
  organiser: 'Riverside Club',
  policy: '',
  tiers: const [_tier],
  kind: kind,
);

Booking _booking(EventKind kind, {BookingStatus status = BookingStatus.confirmed, BookingCancellation? cancellation}) {
  return Booking(
    id: 'TK12345678',
    request: EventRequest(event: _merchantEvent(kind), quantities: {_tier: 1}),
    holderName: 'Sokha Chan',
    paidWith: PaymentMethod.abaPay,
    totalCents: 1000,
    bookedAt: DateTime(2026, 11, 14, 9),
    status: status,
    cancellation: cancellation,
  );
}

Future<void> _pumpTicket(WidgetTester tester, Booking booking) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: TicketCard(booking: booking, isPast: false)),
      ),
    ),
  );
}

void main() {
  group('the ticket', () {
    testWidgets('a cancelled booking without details has no QR code and says the organiser cancelled it', (
      tester,
    ) async {
      await _pumpTicket(tester, _booking(EventKind.concert, status: BookingStatus.cancelled));

      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Cancelled by the organiser.'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('Scan at the entrance'), findsNothing);
      expect(find.text('TK12345678'), findsOneWidget);
    });

    testWidgets('a confirmed booking shows its QR code and the scan hint', (tester) async {
      await _pumpTicket(tester, _booking(EventKind.concert));

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('Scan at the entrance'), findsOneWidget);
      expect(find.text('Cancelled by the organiser.'), findsNothing);
    });

    testWidgets('shows the kind of event as its label and icon', (tester) async {
      await _pumpTicket(tester, _booking(EventKind.show));

      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Event'), findsNothing);
      expect(find.byIcon(Icons.theater_comedy_outlined), findsOneWidget);
    });
  });

  group('the event card', () {
    for (final (kind, label, icon) in [
      (EventKind.marathon, 'Marathon', Icons.directions_run_outlined),
      (EventKind.concert, 'Concert', Icons.music_note_outlined),
      (EventKind.show, 'Show', Icons.theater_comedy_outlined),
    ]) {
      testWidgets('a $label is labelled "$label" with its own icon', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  child: ListingPosterCard(
                    listing: _merchantEvent(kind),
                    subtitle: 'Sat 28 Nov',
                    onTap: () {},
                    showTag: true,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text(label), findsOneWidget);
        expect(find.text('Event'), findsNothing);
        expect(find.byIcon(icon), findsOneWidget);
      });
    }
  });

  group('the event page', () {
    Future<void> pumpPage(WidgetTester tester, EventListing event) async {
      final getListing = _MockGetListing();
      when(() => getListing('ev9')).thenAnswer((_) async => Result<Listing>.success(event));
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ListingDetailBloc(
              getListing: getListing,
              getShowtimes: _MockGetShowtimes(),
              clock: FixedClock(DateTime(2026, 11, 15, 8)),
              listingId: 'ev9',
            )..add(const ListingDetailStarted()),
            child: const ListingDetailPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('leaves out an empty About and an empty policy line', (tester) async {
      await pumpPage(tester, _merchantEvent(EventKind.concert));

      expect(find.text('Riverside Evening'), findsWidgets);
      expect(find.text('About'), findsNothing);
      expect(find.text('Good to know'), findsOneWidget);
      expect(find.text('•  E-ticket with QR code, no printing needed'), findsOneWidget);
      expect(find.text('•  Organiser: Riverside Club'), findsOneWidget);
      expect(find.text('•  '), findsNothing);
    });

    testWidgets('shows About and the policy when the organiser wrote them', (tester) async {
      final described = EventListing(
        id: 'ev9',
        name: 'Riverside Evening',
        startsAt: DateTime(2026, 11, 28, 19),
        venue: 'Riverside',
        venueDetail: '',
        about: 'Three bands by the river.',
        organiser: 'Riverside Club',
        policy: 'Refundable up to 48h before',
        tiers: const [_tier],
        kind: EventKind.concert,
      );
      await pumpPage(tester, described);

      expect(find.text('About'), findsOneWidget);
      expect(find.text('Three bands by the river.'), findsOneWidget);
      expect(find.text('•  Refundable up to 48h before'), findsOneWidget);
    });

    testWidgets('shows the kind of event as its label and icon', (tester) async {
      await pumpPage(tester, _merchantEvent(EventKind.marathon));

      expect(find.text('Marathon'), findsOneWidget);
      expect(find.text('Event'), findsNothing);
      expect(find.byIcon(Icons.directions_run_outlined), findsOneWidget);
    });
  });
}
