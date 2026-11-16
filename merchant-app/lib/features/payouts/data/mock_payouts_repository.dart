import '../../../core/error/guard.dart';
import '../../../core/result/result.dart';
import '../../../mock_backend/mock_merchant_backend.dart';
import '../../../mock_backend/mock_request_context.dart';
import '../../bookings/domain/entities/booking.dart';
import '../../bookings/domain/entities/sales_summary.dart';
import '../domain/entities/payouts.dart';
import '../domain/repositories/payouts_repository.dart';

/// [PayoutsRepository] answered by the in-memory mock backend. The mock has
/// no Pin admins, so nothing is ever paid out: every online booking is owed.
class MockPayoutsRepository implements PayoutsRepository {
  const MockPayoutsRepository({required this._backend, required this._context});

  final MockMerchantBackend _backend;
  final MockRequestContext _context;

  @override
  Future<Result<PayoutsOverview>> fetchPayouts() {
    return guard(() async {
      final owner = await _context.requireOwner();
      final events = await _backend.watchEvents(owner.businessId).first;
      final bookings = await _backend.watchBookings(owner.businessId).first;
      final rates = {for (final event in events) event.id: event.commissionRate};
      final owed = bookings
          .where((b) => b.channel == SalesChannel.online && b.countsAsSold && rates.containsKey(b.eventId))
          .toList();
      final gross = owed.fold(0, (sum, b) => sum + b.totalCents);
      final commission = owed.fold(
        0,
        (sum, b) => sum + SalesSummary.commissionOf(b, rates[b.eventId]!),
      );
      return PayoutsOverview(
        due: PayoutAmount(
          grossCents: gross,
          commissionCents: commission,
          netCents: gross - commission,
          bookingCount: owed.length,
        ),
        paid: const [],
      );
    });
  }
}
