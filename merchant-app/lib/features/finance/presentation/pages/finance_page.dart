import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/key_value_row.dart';
import '../../../../design_system/molecules/message_view.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../bookings/domain/entities/sales_summary.dart';
import '../../../dashboard/presentation/bloc/business/business_bloc.dart';
import '../../../payouts/presentation/bloc/payouts_bloc.dart';
import '../../../payouts/presentation/organisms/payouts_card.dart';

/// Owner's money: earnings for today's event (online sales, Pin's commission,
/// door sales and what the business receives) and the payouts from Pin for
/// tickets booked in the Pin app. Expects a [BusinessBloc] and a [PayoutsBloc]
/// above it.
class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BusinessBloc, BusinessState>(
      builder: (context, state) {
        final snapshot = state.snapshot;
        final live = snapshot?.liveEvent;

        return Column(
          children: [
            ScreenHeader(
              title: 'Finance',
              subtitle: live == null ? null : '${live.name} · Today',
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final payouts = context.read<PayoutsBloc>()..add(const PayoutsRequested());
                  await payouts.stream.firstWhere((s) => s.status != PayoutsStatus.loading);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    14,
                    AppSpacing.page,
                    AppSpacing.lg,
                  ),
                  children: [
                    switch (state.status) {
                      BusinessStatus.loading => const SizedBox(
                        height: 120,
                        child: MessageView.loading(),
                      ),
                      BusinessStatus.failure => const _Note(
                        title: 'Could not load your sales',
                        message: 'Check your connection and open the app again.',
                      ),
                      BusinessStatus.ready when snapshot != null && live != null => EarningsCard(
                        summary: snapshot.summaryOf(live),
                      ),
                      BusinessStatus.ready => const _Note(
                        title: 'No event today',
                        message: "Today's earnings appear here on the day of an event.",
                      ),
                    },
                    const SizedBox(height: 14),
                    const PayoutsCard(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: 4),
          Text(message, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

/// The earnings breakdown. Door sales carry no commission.
class EarningsCard extends StatelessWidget {
  const EarningsCard({super.key, required this.summary});

  final SalesSummary summary;

  @override
  Widget build(BuildContext context) {
    final rate = _percent(summary.commissionRate);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Earnings', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 4),
          KeyValueRow(label: 'Booked in the Pin app', value: Money.format(summary.onlineCents)),
          KeyValueRow(
            label: 'Pin commission ($rate)',
            value: '−${Money.format(summary.commissionCents)}',
          ),
          KeyValueRow(label: 'Sold at the door', value: Money.format(summary.doorCents)),
          KeyValueRow(
            label: 'You receive',
            value: Money.format(summary.netCents),
            emphasized: true,
            showDivider: false,
          ),
          Text(
            'Pin keeps $rate of every ticket booked in the Pin app. Door sales have no '
            'commission.',
            style: AppTextStyles.caption.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// `5%` or `7.5%`
String _percent(double rate) {
  return '${rate == rate.roundToDouble() ? rate.round() : rate}%';
}
