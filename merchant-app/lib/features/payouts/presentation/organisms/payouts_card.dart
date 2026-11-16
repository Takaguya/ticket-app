import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/key_value_row.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/payouts.dart';
import '../bloc/payouts_bloc.dart';

/// What Pin owes the business for tickets booked in the Pin app, and the
/// payouts Pin has made. Expects a [PayoutsBloc] above it.
class PayoutsCard extends StatelessWidget {
  const PayoutsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PayoutsBloc, PayoutsState>(
      builder: (context, state) {
        final overview = state.overview;
        return AppCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Payouts from Pin', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 4),
              if (overview != null) ..._overview(overview),
              if (overview == null && state.status == PayoutsStatus.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (state.status == PayoutsStatus.failure) ...[
                const SizedBox(height: 6),
                Text(state.message ?? 'Could not load your payouts.', style: AppTextStyles.bodySmall),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Try again',
                  variant: AppButtonVariant.tonal,
                  height: 44,
                  onPressed: () => context.read<PayoutsBloc>().add(const PayoutsRequested()),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _overview(PayoutsOverview overview) {
    final due = overview.due;
    // Refunds can be more than new sales: nothing is owed then, and the rest
    // comes off the next payout.
    final owed = due.netCents < 0 ? 0 : due.netCents;
    return [
      KeyValueRow(
        label: 'Owed to you',
        value: Money.format(owed),
        emphasized: true,
        showDivider: overview.paid.isNotEmpty,
      ),
      Text(_dueCaption(due), style: AppTextStyles.caption.copyWith(height: 1.4)),
      if (due.netCents < 0) ...[
        const SizedBox(height: 4),
        Text(
          'Refunds of ${Money.format(due.refundsCents)} are taken off your next payout.',
          style: AppTextStyles.caption.copyWith(height: 1.4),
        ),
      ],
      if (overview.paid.isNotEmpty) ...[
        const SizedBox(height: 10),
        const Text('Paid', style: AppTextStyles.bodyStrong),
        for (final (index, payout) in overview.paid.indexed)
          KeyValueRow(
            label: payout.amount.refundsCents > 0
                ? 'Paid ${DateFormat.full(payout.paidAt)} '
                      '(after ${Money.format(payout.amount.refundsCents)} refunds)'
                : 'Paid ${DateFormat.full(payout.paidAt)}',
            value: Money.format(payout.amount.netCents),
            showDivider: index < overview.paid.length - 1,
          ),
      ],
    ];
  }

  static String _dueCaption(PayoutAmount due) {
    final refunds = due.refundsCents;
    if (due.bookingCount == 0 && refunds == 0) {
      return 'Everything booked in the Pin app so far has been paid out.';
    }
    final count = due.bookingCount == 0
        ? 'No new bookings'
        : '${due.bookingCount} ${due.bookingCount == 1 ? 'booking' : 'bookings'}';
    final refundsText = refunds > 0 ? ' minus ${Money.format(refunds)} refunds' : '';
    final payout = due.netCents > 0 ? ' Pin pays this out to you.' : '';
    return '$count in the Pin app: ${Money.format(due.grossCents)} sales minus '
        '${Money.format(due.commissionCents)} commission$refundsText.$payout';
  }
}
