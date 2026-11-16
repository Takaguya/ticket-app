import '../../../auth/domain/entities/gender.dart';
import '../../../catalog/data/models/bus_json.dart';
import '../../../catalog/data/models/cinema_json.dart';
import '../../../catalog/data/models/event_json.dart';
import '../../../catalog/data/models/place_json.dart';
import '../../../catalog/domain/entities/ticket_tier.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/booking_cancellation.dart';
import '../../domain/entities/booking_request.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/runner_details.dart';

/// The buyer endpoints' JSON, to and from the app's entities. Money is whole
/// US cents; times are local, without an offset.
abstract final class BookingJson {
  /// A booking as `GET /buyer/bookings` sends it:
  /// `{id, status, holderName, payment, promoCode, discountCents, subtotalCents,
  /// totalCents, bookedAt, lines, seats, event, runner, cancellation}`.
  ///
  /// The server's `open`, `checkedIn` and `cancelled` become the app's
  /// confirmed, used and cancelled. The booking's request is built from the
  /// embedded event, the lines (ticket types by name) and the runner. A bus
  /// trip (`event.kind` is `bus`) is a [BusRequest] with the booking's `seats`,
  /// a screening (`cinema`) a [CinemaRequest] with them, and a place (`admission`)
  /// an [AdmissionRequest] for the booking's `visitDate`.
  static Booking booking(Map<String, dynamic> json) {
    final eventData = json['event'] as Map<String, dynamic>;
    final runnerData = json['runner'] as Map<String, dynamic>?;
    final cancellation = json['cancellation'] as Map<String, dynamic>?;
    return Booking(
      id: json['id'] as String,
      request: switch (eventData['kind']) {
        'bus' => _busRequest(eventData, json),
        'cinema' => _cinemaRequest(eventData, json),
        'admission' => _admissionRequest(eventData, json),
        _ => _eventRequest(eventData, json, runnerData),
      },
      holderName: json['holderName'] as String,
      paidWith: _payment(json['payment'] as String),
      promoCode: json['promoCode'] as String?,
      discountCents: (json['discountCents'] as num).toInt(),
      totalCents: (json['totalCents'] as num).toInt(),
      bookedAt: DateTime.parse(json['bookedAt'] as String),
      status: _status(json['status'] as String),
      cancellation: cancellation == null ? null : _cancellation(cancellation),
    );
  }

  static Promotion promotion(Map<String, dynamic> json) {
    return Promotion(
      code: json['code'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      percentOff: (json['percentOff'] as num).toInt(),
      amountOffCents: (json['amountOffCents'] as num).toInt(),
      minimumSpendCents: (json['minimumSpendCents'] as num).toInt(),
    );
  }

  static RunnerDetails runner(Map<String, dynamic> json) {
    return RunnerDetails(
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      gender: Gender.values.byName(json['gender'] as String),
      age: (json['age'] as num).toInt(),
      nationality: json['nationality'] as String,
      emergencyName: json['emergencyName'] as String,
      emergencyPhone: json['emergencyPhone'] as String,
      shirtSize: ShirtSize.values.firstWhere((size) => size.label == json['shirtSize'] as String),
    );
  }

  static Map<String, dynamic> runnerJson(RunnerDetails runner) {
    return {
      'name': runner.name,
      'phone': runner.phone,
      'email': ?runner.email,
      'gender': runner.gender.name,
      'age': runner.age,
      'nationality': runner.nationality,
      'emergencyName': runner.emergencyName,
      'emergencyPhone': runner.emergencyPhone,
      'shirtSize': runner.shirtSize.label,
    };
  }

  /// `POST /buyer/bookings` body for an event order. The server prices it
  /// again; only what was chosen is sent.
  static Map<String, dynamic> order(Order order, EventRequest request) {
    final runner = request.runner;
    final code = order.promoCode;
    return {
      'eventId': request.event.id,
      'lines': [
        for (final line in request.lines) {'ticketType': line.name, 'quantity': line.quantity},
      ],
      'payment': switch (order.paymentMethod) {
        PaymentMethod.abaPay => 'abaKhqr',
        PaymentMethod.card => 'card',
      },
      'promoCode': ?code,
      if (runner != null) 'runner': runnerJson(runner),
      if (runner != null && order.saveRunner) 'saveRunner': true,
    };
  }

  /// `POST /buyer/bookings` body for a bus order: the trip and the seats
  /// chosen, instead of ticket types.
  static Map<String, dynamic> busOrder(Order order, BusRequest request) {
    final code = order.promoCode;
    return {
      'eventId': request.departure.id,
      'seats': [for (final seat in request.seats) seat.id],
      'payment': switch (order.paymentMethod) {
        PaymentMethod.abaPay => 'abaKhqr',
        PaymentMethod.card => 'card',
      },
      'promoCode': ?code,
    };
  }

  /// `POST /buyer/bookings` body for a cinema order: the screening and the seats
  /// chosen. Snacks are not sold by the server, so none are sent.
  static Map<String, dynamic> cinemaOrder(Order order, CinemaRequest request) {
    final code = order.promoCode;
    return {
      'eventId': request.showtime.id,
      'seats': [for (final seat in request.seats) seat.id],
      'payment': switch (order.paymentMethod) {
        PaymentMethod.abaPay => 'abaKhqr',
        PaymentMethod.card => 'card',
      },
      'promoCode': ?code,
    };
  }

  /// `POST /buyer/bookings` body for a place order: the tickets by type and the
  /// day of the visit (`2026-11-28`).
  static Map<String, dynamic> admissionOrder(Order order, AdmissionRequest request) {
    final code = order.promoCode;
    final day = request.day;
    String two(int n) => n.toString().padLeft(2, '0');
    return {
      'eventId': request.attraction.id,
      'lines': [
        for (final line in request.lines) {'ticketType': line.name, 'quantity': line.quantity},
      ],
      'payment': switch (order.paymentMethod) {
        PaymentMethod.abaPay => 'abaKhqr',
        PaymentMethod.card => 'card',
      },
      'visitDate': '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-${two(day.day)}',
      'promoCode': ?code,
    };
  }

  static AdmissionRequest _admissionRequest(Map<String, dynamic> eventData, Map<String, dynamic> json) {
    final place = PlaceJson.listing(eventData);
    return AdmissionRequest(
      attraction: place,
      // Only the date counts: `2026-11-28`.
      day: DateTime.parse(json['visitDate'] as String),
      quantities: _quantities(place.tiers, json['lines'] as List<dynamic>),
    );
  }

  static EventRequest _eventRequest(
    Map<String, dynamic> eventData,
    Map<String, dynamic> json,
    Map<String, dynamic>? runnerData,
  ) {
    final event = EventJson.listing(eventData);
    return EventRequest(
      event: event,
      quantities: _quantities(event.tiers, json['lines'] as List<dynamic>),
      runner: runnerData == null ? null : runner(runnerData),
    );
  }

  static BusRequest _busRequest(Map<String, dynamic> eventData, Map<String, dynamic> json) {
    return BusRequest(
      departure: BusJson.departureOfBooking(eventData),
      seats: [for (final id in json['seats'] as List<dynamic>? ?? const []) BusJson.bookedSeat(id as String)],
    );
  }

  static CinemaRequest _cinemaRequest(Map<String, dynamic> eventData, Map<String, dynamic> json) {
    return CinemaRequest(
      film: CinemaJson.filmOfBooking(eventData),
      theatre: CinemaJson.theatreOfBooking(eventData),
      showtime: CinemaJson.showtimeOfBooking(eventData),
      // Only the seats' names are known here, as on a bus.
      seats: [for (final id in json['seats'] as List<dynamic>? ?? const []) BusJson.bookedSeat(id as String)],
    );
  }

  static Map<TicketTier, int> _quantities(List<TicketTier> tiers, List<dynamic> lines) {
    // The server keeps an event's ticket types after publishing, so every
    // line names one of the event's tiers.
    final quantities = <TicketTier, int>{};
    for (final line in lines.cast<Map<String, dynamic>>()) {
      final name = line['ticketType'] as String;
      for (final tier in tiers) {
        if (tier.name == name) quantities[tier] = (line['quantity'] as num).toInt();
      }
    }
    return quantities;
  }

  static BookingStatus _status(String code) {
    return switch (code) {
      'checkedIn' => BookingStatus.used,
      'cancelled' => BookingStatus.cancelled,
      _ => BookingStatus.confirmed,
    };
  }

  static PaymentMethod _payment(String code) {
    return code == 'card' ? PaymentMethod.card : PaymentMethod.abaPay;
  }

  static BookingCancellation _cancellation(Map<String, dynamic> json) {
    return BookingCancellation(
      at: DateTime.parse(json['at'] as String),
      reason: CancellationReason.values.asNameMap()[json['reason'] as String] ?? CancellationReason.other,
      businessName: json['businessName'] as String,
      refundCents: (json['refundCents'] as num).toInt(),
    );
  }
}
