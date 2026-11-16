import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/result/result.dart';
import '../../../../mock_backend/mock_merchant_backend.dart';
import '../../../../mock_backend/mock_request_context.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/events_repository.dart';

/// [EventsRepository] answered by the in-memory mock backend. Replaced by an
/// API-backed implementation once the server exists.
class MockEventsRepository implements EventsRepository {
  const MockEventsRepository({required this._backend, required this._context});

  final MockMerchantBackend _backend;
  final MockRequestContext _context;

  @override
  Stream<List<Event>> watchEvents() async* {
    final user = await _context.user();
    if (user == null) return;
    yield* _backend.watchEvents(user.businessId);
  }

  @override
  Future<Result<Event>> publishEvent(EventDraft draft) {
    return guard(() async {
      final owner = await _context.requireOwner();
      return _backend.publishEvent(owner.businessId, draft);
    });
  }

  @override
  Future<Result<Event>> publishBusTrip(TripDraft draft) {
    return guard(() async {
      final owner = await _context.requireOwner();
      return _backend.publishBusTrip(owner.businessId, draft);
    });
  }

  @override
  Future<Result<Event>> publishPlace(PlaceDraft draft) {
    return guard(() async {
      final owner = await _context.requireOwner();
      return _backend.publishPlace(owner.businessId, draft);
    });
  }

  @override
  Future<Result<Event>> publishScreening(ScreeningDraft draft) {
    return guard(() async {
      final owner = await _context.requireOwner();
      return _backend.publishScreening(owner.businessId, draft);
    });
  }

  // The in-memory backend keeps no pictures: they live on the Pin server.
  static const _needsServer = RejectedFailure('Pictures can only be added when the app is connected to Pin.');

  @override
  Future<Result<String>> setEventImage(String eventId, Uint8List photo) async {
    return const Result.failure(_needsServer);
  }

  @override
  Future<Result<void>> removeEventImage(String eventId) async {
    return const Result.failure(_needsServer);
  }
}
