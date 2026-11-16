import '../../../../core/result/result.dart';
import '../entities/payouts.dart';

/// What Pin owes the owner's business for online bookings, and has paid.
abstract interface class PayoutsRepository {
  Future<Result<PayoutsOverview>> fetchPayouts();
}
