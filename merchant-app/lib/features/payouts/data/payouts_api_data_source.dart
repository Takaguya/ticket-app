import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/entities/payouts.dart';

/// `GET /merchant/payouts` of the Pin API. Throws `ApiException` or
/// `NetworkException`.
class PayoutsApiDataSource {
  const PayoutsApiDataSource(this._dio);

  final Dio _dio;

  /// Owner only.
  Future<PayoutsOverview> fetchPayouts() {
    return apiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/merchant/payouts');
      return PayoutsJson.overview(response.data!);
    });
  }
}

/// Payouts as the API sends them:
///
/// ```json
/// {"due": {"grossCents": 412000, "commissionCents": 20600, "refundsCents": 0,
///          "netCents": 391400, "bookingCount": 174},
///  "paid": [{"id": "...", "paidAt": "2026-11-11T10:00:00", "grossCents": 158400,
///            "commissionCents": 7920, "refundsCents": 0, "netCents": 150480, "bookingCount": 85}]}
/// ```
///
/// `refundsCents` is missing from older servers and then counts as 0.
///
/// `paidAt` is local to Pin's time zone without an offset, read as a local
/// [DateTime] with the same fields.
abstract final class PayoutsJson {
  static PayoutsOverview overview(Map<String, dynamic> json) {
    return PayoutsOverview(
      due: amount(json['due'] as Map<String, dynamic>),
      paid: [
        for (final payout in json['paid'] as List<dynamic>)
          Payout(
            id: (payout as Map<String, dynamic>)['id'] as String,
            paidAt: DateTime.parse(payout['paidAt'] as String),
            amount: amount(payout),
          ),
      ],
    );
  }

  static PayoutAmount amount(Map<String, dynamic> json) {
    return PayoutAmount(
      grossCents: (json['grossCents'] as num).toInt(),
      commissionCents: (json['commissionCents'] as num).toInt(),
      refundsCents: (json['refundsCents'] as num?)?.toInt() ?? 0,
      netCents: (json['netCents'] as num).toInt(),
      bookingCount: (json['bookingCount'] as num).toInt(),
    );
  }
}
