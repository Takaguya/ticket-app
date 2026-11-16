import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/entities/booking_request.dart';
import '../../domain/entities/runner_details.dart';
import '../bloc/checkout/checkout_bloc.dart';
import '../booking_navigation.dart';
import '../booking_text.dart';
import '../organisms/booking_summary_card.dart';
import '../organisms/bus_trip_card.dart';
import '../organisms/checkout_sheets.dart';
import '../organisms/order_lines_card.dart';

/// What is being bought and its price, how to pay and a promo code, then
/// "Confirm". Paying shows "Issuing tickets…", then the new ticket. Expects
/// a [CheckoutBloc] above it.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  Future<void> _choosePayment(BuildContext context, CheckoutState state) async {
    final bloc = context.read<CheckoutBloc>();
    final method = await showPaymentMethodSheet(context, selected: state.paymentMethod);
    if (method != null) bloc.add(CheckoutPaymentMethodChosen(method));
  }

  Future<void> _choosePromo(BuildContext context, CheckoutState state) async {
    final bloc = context.read<CheckoutBloc>();
    final code = await showPromoCodeSheet(
      context,
      offers: state.promotions,
      applied: state.promotion?.code,
    );
    if (code == null) return;
    bloc.add(code.isEmpty ? const CheckoutPromotionRemoved() : CheckoutPromoCodeEntered(code));
  }

  void _onStateChanged(BuildContext context, CheckoutState state) {
    final notice = state.notice;
    if (notice != null) AppToast.show(context, notice);
    final booking = state.booking;
    if (state.status == CheckoutStatus.paid && booking != null) context.showIssuedTicket(booking);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckoutBloc, CheckoutState>(
      listenWhen: (previous, current) =>
          (current.notice != null && previous.notice != current.notice) ||
          previous.status != current.status,
      listener: _onStateChanged,
      builder: (context, state) {
        final request = state.request;
        final paying = state.status != CheckoutStatus.ready;
        const gap = SizedBox(height: AppSpacing.sm);
        return PopScope(
          canPop: !paying,
          child: Stack(
            children: [
              Scaffold(
                body: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ColoredBox(
                        color: AppColors.surface,
                        child: ScreenHeader(title: 'Checkout', onBack: () => context.pop()),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.page),
                          children: [
                            BookingSummaryCard(request: request),
                            gap,
                            if (request case BusRequest(:final departure, :final seats)) ...[
                              BusTripCard(departure: departure, seats: seats),
                              gap,
                            ],
                            if (request case EventRequest(runner: final runner?)) ...[
                              _RunnerCard(runner: runner),
                              gap,
                            ],
                            OrderLinesCard(
                              request: request,
                              discountCents: state.discountCents,
                              promoCode: state.promotion?.code,
                              onEdit: () => context.pop(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: _PayBar(
                  state: state,
                  onPayment: () => _choosePayment(context, state),
                  onPromo: () => _choosePromo(context, state),
                  onConfirm: () => context.read<CheckoutBloc>().add(const CheckoutConfirmed()),
                ),
              ),
              if (paying) ...[
                const Positioned.fill(
                  child: ModalBarrier(dismissible: false, color: Color(0x8A000000)),
                ),
                Align(alignment: Alignment.bottomCenter, child: _IssuingPanel(state: state)),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A race: who runs.
class _RunnerCard extends StatelessWidget {
  const _RunnerCard({required this.runner});

  final RunnerDetails runner;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RUNNER', style: AppTextStyles.fieldLabel),
          const SizedBox(height: 6),
          Text(runner.name, style: AppTextStyles.bodyStrong.copyWith(fontSize: 15)),
          Text(
            '${runner.gender.label} · ${runner.age} · ${runner.nationality} · '
            'T-shirt ${runner.shirtSize.label}',
            style: AppTextStyles.bodySmall,
          ),
          Text(
            'Emergency contact: ${runner.emergencyName}, ${PhoneNumber.local(runner.emergencyPhone)}',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Pinned to the bottom: the total, how to pay, the promo code and
/// "Confirm".
class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.state,
    required this.onPayment,
    required this.onPromo,
    required this.onConfirm,
  });

  final CheckoutState state;
  final VoidCallback onPayment;
  final VoidCallback onPromo;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final promotion = state.promotion;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ColoredBox(
              color: AppColors.fill,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 8),
                child: Text(
                  'By placing your order you agree to the Pin Terms & Conditions.',
                  style: AppTextStyles.caption,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Total amount', style: AppTextStyles.sectionTitle)),
                      Text(Money.format(state.totalCents), style: AppTextStyles.title),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _Selector(
                          icon: paymentIcon(state.paymentMethod),
                          label: state.paymentMethod.label,
                          semanticLabel: 'Payment method: ${state.paymentMethod.label}',
                          onTap: onPayment,
                        ),
                      ),
                      const SizedBox(
                        height: 24,
                        child: VerticalDivider(width: 17, color: AppColors.divider),
                      ),
                      Expanded(
                        child: _Selector(
                          icon: Icons.percent_rounded,
                          label: promotion == null
                              ? 'Promotion'
                              : '${promotion.code} · ${Money.format(-state.discountCents)}',
                          semanticLabel: promotion == null
                              ? 'Add a promo code'
                              : 'Promo code ${promotion.code}',
                          onTap: onPromo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Confirm',
                    loading: state.status != CheckoutStatus.ready,
                    onPressed: onConfirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Selector extends StatelessWidget {
  const _Selector({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: SizedBox(
          height: AppSizes.tapTarget,
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong,
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// While paying: what is being issued, how it is paid and the total.
class _IssuingPanel extends StatelessWidget {
  const _IssuingPanel({required this.state});

  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    final request = state.request;
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primary,
              backgroundColor: AppColors.primarySoft,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Issuing tickets…', style: AppTextStyles.screenTitle),
                  const SizedBox(height: AppSpacing.sm),
                  Text(request.title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 16)),
                  Text(request.whenText, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 10),
                  for (final line in request.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.fill,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('×${line.quantity}', style: AppTextStyles.bodyStrong),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(line.name, style: AppTextStyles.bodySmall)),
                        ],
                      ),
                    ),
                  const Divider(height: 20, color: AppColors.divider),
                  Row(
                    children: [
                      const Text('Paid by  ', style: AppTextStyles.bodySmall),
                      Expanded(
                        child: Text(state.paymentMethod.label, style: AppTextStyles.bodyStrong),
                      ),
                      Text(Money.format(state.totalCents), style: AppTextStyles.price),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
