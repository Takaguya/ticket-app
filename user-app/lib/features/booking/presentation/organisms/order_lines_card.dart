import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/atoms/icon_tile.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/booking_request.dart';
import '../../domain/entities/order_line.dart';
import '../booking_text.dart';

/// The order line by line, then the subtotal, any promo discount and the
/// total. "Edit" goes back to change it.
class OrderLinesCard extends StatelessWidget {
  const OrderLinesCard({
    super.key,
    required this.request,
    this.discountCents = 0,
    this.promoCode,
    this.onEdit,
  });

  final BookingRequest request;
  final int discountCents;

  /// The code that gave [discountCents].
  final String? promoCode;

  /// Shows "Edit" when set.
  final VoidCallback? onEdit;

  String get _heading => switch (request) {
    BusRequest() => 'FARE',
    CinemaRequest(:final snacks) when snacks.values.any((n) => n > 0) => 'TICKETS & SNACKS',
    _ => 'TICKETS',
  };

  @override
  Widget build(BuildContext context) {
    final subtotal = request.subtotalCents;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(child: Text(_heading, style: AppTextStyles.fieldLabel)),
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('Edit', style: AppTextStyles.link),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (final line in request.lines)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: _LineRow(line: line)),
          const SizedBox(height: 4),
          _Amount(label: 'Subtotal · ${request.ticketCountText}', amount: Money.format(subtotal)),
          if (discountCents > 0)
            _Amount(
              label: 'Promo $promoCode',
              amount: Money.format(-discountCents),
              colour: AppColors.success,
            ),
          const Divider(height: 18, color: AppColors.divider),
          _Amount(label: 'Total', amount: Money.format(subtotal - discountCents), strong: true),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconTile(
            icon: line.isTicket ? Icons.confirmation_number_outlined : Icons.fastfood_outlined,
            background: AppColors.warningSoft,
            foreground: AppColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: AppTextStyles.bodyStrong),
                Text(
                  '${line.quantity} × ${Money.formatPrice(line.unitPriceCents)}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Text(Money.formatPrice(line.totalCents), style: AppTextStyles.price),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.amount, this.strong = false, this.colour});

  final String label;
  final String amount;
  final bool strong;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? AppTextStyles.sectionTitle.copyWith(fontSize: 17)
        : AppTextStyles.bodySmall.copyWith(fontSize: 14, color: colour);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(amount, style: style),
        ],
      ),
    );
  }
}
