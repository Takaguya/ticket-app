import '../core/utils/clock.dart';
import '../core/utils/date_format.dart';
import '../features/catalog/domain/entities/bus_departure.dart';
import '../features/catalog/domain/entities/event_kind.dart';
import '../features/catalog/domain/entities/listing.dart';
import '../features/catalog/domain/entities/showtime.dart';
import '../features/catalog/domain/entities/ticket_category.dart';
import '../features/catalog/domain/entities/ticket_tier.dart';

/// The Pin user app prototype's sample catalogue, served from memory until the
/// Pin API sells tickets to buyers.
///
/// Events are dated from the day the catalogue is made, so they always lie
/// ahead: Khmer Rock Night is a week away, the half marathon four weeks. Bus
/// departures and film showtimes are the same every day; those that have
/// already left or started today are not offered.
class MockCatalog {
  MockCatalog({this.clock = const Clock()}) {
    final today = DateFormat.dateOnly(clock.now());
    listings = List.unmodifiable([
      ..._events(today),
      ..._busRoutes,
      ..._films(today),
      ..._admissions,
    ]);
  }

  final Clock clock;

  /// Every listing: events soonest first, then bus routes, films and places.
  late final List<Listing> listings;

  static const theatres = [
    Theatre(id: 'aeon1', name: 'Legend Cinema · Aeon Mall 1', area: 'Sen Sok · 3.2 km'),
    Theatre(id: 'exch', name: 'Legend Cinema · Exchange Square', area: 'Daun Penh · 1.4 km'),
    Theatre(id: 'major', name: 'Major Cineplex · Aeon Mall 2', area: 'Sen Sok · 6.8 km'),
  ];

  /// Theatre ID, start (hour, minute), hall, price in cents. The same every day.
  static const _shows = [
    ('aeon1', (10, 30), 'Hall 2', 450),
    ('aeon1', (13, 15), 'Hall 1', 450),
    ('aeon1', (16, 0), 'IMAX', 700),
    ('aeon1', (21, 30), 'IMAX', 700),
    ('exch', (12, 0), 'Hall 1', 450),
    ('exch', (18, 45), 'Hall 3', 550),
    ('exch', (20, 30), 'Hall 1', 550),
    ('major', (11, 0), 'Hall 4', 400),
    ('major', (15, 30), 'Hall 2', 400),
    ('major', (19, 0), '4DX', 800),
  ];

  static final int _cheapestShow = _shows.map((show) => show.$4).reduce((a, b) => a < b ? a : b);

  /// Where buses leave from in each city: the station and its street.
  static const _stations = {
    'Phnom Penh': ('Giant Ibis / Virak Buntham Terminal', 'St 106, Riverside, Phnom Penh'),
    'Siem Reap': ('Siem Reap Bus Terminal', 'National Rd 6, Siem Reap'),
    'Sihanoukville': ('Sihanoukville Bus Station', 'Ekareach St, Sihanoukville'),
    'Kampot': ('Kampot Bus Station', 'St 730, Kampot'),
    'Battambang': ('Battambang Bus Terminal', 'St 3, Battambang'),
  };

  /// The bus operators, in the order they leave each day.
  static const _operators = [
    _Operator('Giant Ibis', 'GI', 0xFF1E8A72, 'Luxury coach · 2+2', (7, 45), Duration.zero, 300,
        ['Wi-Fi', 'A/C', 'Snack'], 11),
    _Operator('Virak Buntham', 'VB', 0xFFE5484D, 'VIP van · 2+1', (9, 30), Duration(minutes: -30), 0,
        ['A/C', 'Water'], 4),
    _Operator('Larryta Express', 'LR', 0xFF1258AC, 'Hotel bus · 2+2', (13, 0), Duration.zero, 200,
        ['Wi-Fi', 'USB', 'A/C'], 18),
    _Operator('Mekong Express', 'ME', 0xFFC99400, 'Night sleeper · 1+1', (22, 30), Duration(minutes: 30),
        600, ['Bed', 'Blanket', 'Wi-Fi'], 7),
  ];

  List<Listing> inCategory(TicketCategory? category) {
    return category == null ? listings : listings.where((l) => l.category == category).toList();
  }

  Listing? byId(String id) {
    for (final listing in listings) {
      if (listing.id == id) return listing;
    }
    return null;
  }

  List<Listing> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return listings.where((listing) => _searchText(listing).contains(needle)).toList();
  }

  /// Buses either way along a route, on [date]'s day, that have not left yet.
  List<BusDeparture> departures({
    required String origin,
    required String destination,
    required DateTime date,
  }) {
    final route = listings.whereType<BusRoute>().where(
      (r) =>
          (r.origin == origin && r.destination == destination) ||
          (r.origin == destination && r.destination == origin),
    );
    if (route.isEmpty) return const [];

    final now = clock.now();
    final day = DateFormat.dateOnly(date);
    final (boardingPoint, boardingAddress) = _stations[origin] ?? ('$origin bus station', origin);
    final departures = <BusDeparture>[];
    for (final (index, company) in _operators.take(route.first.operatorCount).indexed) {
      final departsAt = DateTime(day.year, day.month, day.day, company.departs.$1, company.departs.$2);
      if (!departsAt.isAfter(now)) continue;
      departures.add(
        BusDeparture(
          id: '${route.first.id}-${company.code}-${day.year}${day.month}${day.day}',
          routeId: route.first.id,
          operatorName: company.name,
          operatorCode: company.code,
          operatorColor: company.color,
          coachType: company.coachType,
          origin: origin,
          destination: destination,
          departsAt: departsAt,
          duration: route.first.typicalDuration + company.durationOffset,
          priceCents: route.first.fromPriceCents + company.premiumCents,
          amenities: company.amenities,
          // A different number of seats left each day, the same all day.
          seatsLeft: 1 + (company.seats + day.day * (index + 3)) % 24,
          boardingPoint: boardingPoint,
          boardingAddress: boardingAddress,
        ),
      );
    }
    return departures;
  }

  /// Every theatre's screenings of the film on [date]'s day that have not
  /// started yet. Theatres with none left are left out.
  List<TheatreShowtimes> showtimes({required String filmId, required DateTime date}) {
    if (byId(filmId) is! FilmListing) return const [];
    final now = clock.now();
    final day = DateFormat.dateOnly(date);
    return [
      for (final theatre in theatres)
        TheatreShowtimes(
          theatre: theatre,
          showtimes: [
            for (final (theatreId, (hour, minute), hall, price) in _shows)
              if (theatreId == theatre.id)
                Showtime(
                  id: '$filmId-$theatreId-${day.year}${day.month}${day.day}-$hour$minute',
                  startsAt: DateTime(day.year, day.month, day.day, hour, minute),
                  hall: hall,
                  priceCents: price,
                ),
          ].where((show) => show.startsAt.isAfter(now)).toList(),
        ),
    ].where((theatre) => theatre.showtimes.isNotEmpty).toList();
  }

  static String _searchText(Listing listing) {
    final place = switch (listing) {
      EventListing(:final venue, :final venueDetail) => '$venue $venueDetail',
      AdmissionListing(:final venue, :final venueDetail) => '$venue $venueDetail',
      FilmListing(:final genre) => genre,
      BusRoute() => '',
    };
    return '${listing.name} $place'.toLowerCase();
  }

  static List<EventListing> _events(DateTime today) {
    DateTime on(int daysAhead, int hour, int minute) =>
        DateTime(today.year, today.month, today.day + daysAhead, hour, minute);
    return [
      EventListing(
        id: 'ev1',
        name: 'Khmer Rock Night 2026',
        startsAt: on(7, 19, 0),
        venue: 'Koh Pich Theatre',
        venueDetail: 'Diamond Island, Phnom Penh',
        about: 'Five Cambodian rock bands on one stage for a single night. Doors open 18:00, '
            'show starts 19:00. All ages, standing floor for GA.',
        organiser: 'PP Live Events',
        policy: 'Refundable up to 48h before the show',
        tiers: const [
          TicketTier(name: 'General admission', description: 'Standing floor', priceCents: 1500),
          TicketTier(name: 'VIP', description: 'Seated balcony · free drink', priceCents: 3500),
          TicketTier(name: 'Front row', description: 'Meet & greet included', priceCents: 6000),
        ],
        kind: EventKind.concert,
      ),
      EventListing(
        id: 'ev4',
        name: 'Laugh PP: Stand-up Comedy Night',
        startsAt: on(13, 20, 0),
        venue: 'Factory Phnom Penh',
        venueDetail: '#1159 National Rd 2, Phnom Penh',
        about: 'Six comedians, Khmer and English sets, 90 minutes. 18+ only.',
        organiser: 'Laugh PP',
        policy: 'Refundable up to 24h before',
        tiers: const [
          TicketTier(name: 'Standard seat', description: 'Free seating', priceCents: 800),
          TicketTier(name: 'Table for 2', description: 'Front tables · 2 drinks', priceCents: 3000),
        ],
        kind: EventKind.show,
      ),
      EventListing(
        id: 'ev2',
        name: 'Phnom Penh Half Marathon 2026',
        startsAt: on(28, 5, 30),
        venue: 'Riverside, Sisowath Quay',
        venueDetail: 'Start & finish at the Royal Palace',
        about: 'The annual riverside race. Race kit pickup two days before at Aeon Mall. Timing '
            'chip, finisher medal and T-shirt included with every distance.',
        organiser: 'Khmer Runners Club',
        policy: 'Non-refundable · transferable until a week before',
        tiers: const [
          TicketTier(name: '5K Fun run', description: 'Start 06:30', priceCents: 1200),
          TicketTier(name: '10K', description: 'Start 06:00', priceCents: 1800),
          TicketTier(name: '21K Half marathon', description: 'Start 05:30', priceCents: 2500),
        ],
        kind: EventKind.marathon,
      ),
      EventListing(
        id: 'ev3',
        name: 'Angkor Sunset Music Fest',
        startsAt: on(62, 17, 0),
        venue: 'Angkor Eye Field',
        venueDetail: 'Charles de Gaulle Rd, Siem Reap',
        about: 'Open-air festival with 12 acts across two stages, food village and night market. '
            'Gates open 16:00.',
        organiser: 'Siem Reap Arts Collective',
        policy: 'Refundable up to 7 days before',
        tiers: const [
          TicketTier(name: 'Day pass', description: 'All stages', priceCents: 2000),
          TicketTier(name: 'VIP pass', description: 'Lounge, viewing deck, fast lane', priceCents: 5500),
        ],
        kind: EventKind.concert,
      ),
    ];
  }

  static const _busRoutes = [
    BusRoute(
      id: 'bs1',
      origin: 'Phnom Penh',
      destination: 'Siem Reap',
      typicalDuration: Duration(hours: 6),
      operatorCount: 4,
      fromPriceCents: 1200,
    ),
    BusRoute(
      id: 'bs2',
      origin: 'Phnom Penh',
      destination: 'Sihanoukville',
      typicalDuration: Duration(hours: 4, minutes: 30),
      operatorCount: 3,
      fromPriceCents: 1000,
    ),
    BusRoute(
      id: 'bs3',
      origin: 'Phnom Penh',
      destination: 'Kampot',
      typicalDuration: Duration(hours: 3, minutes: 30),
      operatorCount: 3,
      fromPriceCents: 800,
    ),
    BusRoute(
      id: 'bs4',
      origin: 'Phnom Penh',
      destination: 'Battambang',
      typicalDuration: Duration(hours: 5, minutes: 30),
      operatorCount: 2,
      fromPriceCents: 1100,
    ),
  ];

  static List<FilmListing> _films(DateTime today) {
    DateTime released(int daysAgo) => DateTime(today.year, today.month, today.day - daysAgo);
    const policy = 'Non-refundable once seats are issued';
    return [
      FilmListing(
        id: 'cn1',
        name: 'Neak Ta: The Guardian',
        rating: 'PG-13',
        genre: 'Khmer',
        runtime: const Duration(hours: 1, minutes: 52),
        releasedOn: released(58),
        about: 'A young archaeologist awakens an ancient guardian spirit beneath Phnom Kulen. '
            'Khmer with English subtitles.',
        policy: policy,
        fromPriceCents: _cheapestShow,
      ),
      FilmListing(
        id: 'cn2',
        name: 'Skyline Run',
        rating: 'PG-13',
        genre: 'Action',
        runtime: const Duration(hours: 2, minutes: 8),
        releasedOn: released(51),
        about: 'A courier on a stolen motorbike has 90 minutes to cross a locked-down city.',
        policy: policy,
        fromPriceCents: _cheapestShow,
      ),
      FilmListing(
        id: 'cn3',
        name: 'Paper Moons',
        rating: 'G',
        genre: 'Animation',
        runtime: const Duration(hours: 1, minutes: 34),
        releasedOn: released(65),
        about: 'Two paper lanterns drift across Southeast Asia in search of the festival that made them.',
        policy: policy,
        fromPriceCents: _cheapestShow,
      ),
      FilmListing(
        id: 'cn4',
        name: 'Robot Rumble 3',
        rating: 'PG',
        genre: 'Family',
        runtime: const Duration(hours: 1, minutes: 46),
        releasedOn: released(44),
        about: 'The robots are back, and this time the arena is underwater.',
        policy: policy,
        fromPriceCents: _cheapestShow,
      ),
    ];
  }

  static const _admissions = [
    AdmissionListing(
      id: 'ad1',
      name: 'Angkor Archaeological Park – 1-day pass',
      venue: 'Angkor Ticket Office',
      venueDetail: 'Road 60, Siem Reap',
      about: 'Access to all temples in the Angkor park for one day, including Angkor Wat, Bayon '
          'and Ta Prohm. Valid from 5:00 to sunset on the chosen date.',
      organiser: 'Angkor Enterprise',
      policy: 'Non-refundable · date change allowed once',
      tiers: [
        TicketTier(name: 'Adult', description: '12 years and above', priceCents: 3700),
        TicketTier(name: 'Child', description: 'Under 12 · ID required', priceCents: 0),
      ],
    ),
    AdmissionListing(
      id: 'ad2',
      name: 'Garden City Water Park',
      venue: 'Garden City Water Park',
      venueDetail: 'Chroy Changvar, Phnom Penh',
      about: 'Full-day access to all slides, wave pool and lazy river. Lockers and towels '
          'available on site.',
      organiser: 'Garden City',
      policy: 'Refundable up to the day before',
      tiers: [
        TicketTier(name: 'Adult', description: 'Above 140cm', priceCents: 1200),
        TicketTier(name: 'Child', description: '90–140cm', priceCents: 800),
        TicketTier(name: 'Senior', description: '60+', priceCents: 600),
      ],
    ),
    AdmissionListing(
      id: 'ad3',
      name: 'Phnom Tamao Wildlife Rescue Centre',
      venue: 'Phnom Tamao',
      venueDetail: 'Takeo, 40km from Phnom Penh',
      about: "Cambodia's largest wildlife rescue centre, home to elephants, tigers, sun bears "
          'and gibbons. Open 08:00–17:00.',
      organiser: 'Wildlife Alliance',
      policy: 'Refundable up to the day before',
      tiers: [
        TicketTier(name: 'Adult', priceCents: 500),
        TicketTier(name: 'Child', description: 'Under 12', priceCents: 200),
      ],
    ),
    AdmissionListing(
      id: 'ad4',
      name: 'Kirirom Pine Resort – Day pass',
      venue: 'Kirirom National Park',
      venueDetail: 'Kampong Speu',
      about: 'Pine forest day pass with pool, zipline and mountain-bike trails. Shuttle from '
          'Phnom Penh available at extra cost.',
      organiser: 'vKirirom',
      policy: 'Refundable up to 48h before',
      tiers: [
        TicketTier(name: 'Adult', description: 'Pool + trails', priceCents: 1500),
        TicketTier(name: 'Child', description: 'Under 12', priceCents: 900),
        TicketTier(name: 'Zipline add-on', description: 'Per ride', priceCents: 1000),
      ],
    ),
  ];
}

/// A bus company and its daily departure.
class _Operator {
  const _Operator(
    this.name,
    this.code,
    this.color,
    this.coachType,
    this.departs,
    this.durationOffset,
    this.premiumCents,
    this.amenities,
    this.seats,
  );

  final String name;
  final String code;
  final int color;
  final String coachType;

  /// Hour and minute.
  final (int, int) departs;

  /// Added to the route's usual journey time.
  final Duration durationOffset;

  /// Added to the route's cheapest fare.
  final int premiumCents;
  final List<String> amenities;

  /// Seats left, before the day's variation.
  final int seats;
}
