import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user/core/utils/clock.dart';
import 'package:user/features/catalog/data/repositories/mock_catalog_repository.dart';
import 'package:user/features/catalog/domain/usecases/find_bus_departures.dart';
import 'package:user/features/catalog/domain/usecases/get_listings.dart';
import 'package:user/features/catalog/presentation/bloc/bus_search/bus_search_bloc.dart';
import 'package:user/mock_backend/mock_catalog.dart';

void main() {
  // Sunday 15 Nov 2026, 08:00: the 07:45 bus has left.
  final clock = FixedClock(DateTime(2026, 11, 15, 8));
  final repository = MockCatalogRepository(
    catalog: MockCatalog(clock: clock),
    latency: Duration.zero,
  );

  BusSearchBloc build({String? routeId}) => BusSearchBloc(
    getListings: GetListings(repository),
    findDepartures: FindBusDepartures(repository),
    clock: clock,
    initialRouteId: routeId,
  );

  blocTest<BusSearchBloc, BusSearchState>(
    'starts with the route that was tapped, today',
    build: () => build(routeId: 'bs3'),
    act: (bloc) => bloc.add(const BusSearchStarted()),
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      final state = bloc.state;
      expect(state.status, BusSearchStatus.ready);
      expect((state.origin, state.destination), ('Phnom Penh', 'Kampot'));
      expect(state.date, DateTime(2026, 11, 15));
      expect(state.departuresStatus, DeparturesStatus.loaded);
      // Three operators, one of them already gone.
      expect(state.departures.map((d) => d.operatorName), ['Virak Buntham', 'Larryta Express']);
      expect(state.stops, ['Battambang', 'Kampot', 'Phnom Penh', 'Siem Reap', 'Sihanoukville']);
    },
  );

  blocTest<BusSearchBloc, BusSearchState>(
    'choosing the place at the other end swaps the two',
    build: build,
    act: (bloc) async {
      bloc.add(const BusSearchStarted());
      await bloc.stream.firstWhere((s) => s.departuresStatus == DeparturesStatus.loaded);
      bloc.add(const BusDestinationChosen('Phnom Penh'));
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect((bloc.state.origin, bloc.state.destination), ('Siem Reap', 'Phnom Penh'));
      expect(bloc.state.departures.first.origin, 'Siem Reap');
    },
  );

  blocTest<BusSearchBloc, BusSearchState>(
    'another day searches again',
    build: build,
    act: (bloc) async {
      bloc.add(const BusSearchStarted());
      await bloc.stream.firstWhere((s) => s.departuresStatus == DeparturesStatus.loaded);
      bloc.add(BusDateChosen(DateTime(2026, 11, 16, 13, 45)));
    },
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.date, DateTime(2026, 11, 16));
      expect(bloc.state.departures, hasLength(4));
    },
  );
}
