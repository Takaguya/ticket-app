import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../design_system/atoms/app_button.dart';
import '../../../../design_system/atoms/app_card.dart';
import '../../../../design_system/molecules/app_text_field.dart';
import '../../../../design_system/molecules/app_toast.dart';
import '../../../../design_system/molecules/chip_selector.dart';
import '../../../../design_system/molecules/list_row.dart';
import '../../../../design_system/molecules/quantity_stepper.dart';
import '../../../../design_system/molecules/screen_header.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_dimens.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/presentation/bloc/check_in/check_in_bloc.dart';
import '../bloc/door_sale_bloc.dart';

/// Selling at the entrance, in three steps on one route: pick tickets, take
/// payment, then optionally admit. Expects [DoorSaleBloc] and [CheckInBloc]
/// above it.
class DoorSalePage extends StatelessWidget {
  const DoorSalePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DoorSaleBloc, DoorSaleState>(
      listenWhen: (previous, current) => previous.notice != current.notice,
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) AppToast.show(context, notice);
      },
      builder: (context, state) {
        final bloc = context.read<DoorSaleBloc>();
        return PopScope(
          // Back from payment returns to the ticket picker, not out of the sale.
          canPop: state.step != DoorSaleStep.payment,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) bloc.add(const DoorSaleCheckoutCancelled());
          },
          child: Scaffold(
            backgroundColor: state.step == DoorSaleStep.selecting
                ? AppColors.background
                : AppColors.surface,
            body: switch (state.step) {
              DoorSaleStep.selecting => _SelectTickets(state: state),
              DoorSaleStep.payment => _TakePayment(state: state),
              DoorSaleStep.completed => _SaleDone(sale: state.sale!),
            },
          ),
        );
      },
    );
  }
}

class _SelectTickets extends StatelessWidget {
  const _SelectTickets({required this.state});

  final DoorSaleState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DoorSaleBloc>();

    return Column(
      children: [
        ScreenHeader(
          title: 'Sell at the door',
          onBack: () => context.pop(),
          // A place's limits are per ticket type per day: there is no total left to count down.
          trailing: Text(
            state.event.isPlace ? "Today's limits apply" : '${state.ticketsLeft} left',
            style: AppTextStyles.bodySmall,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 14, AppSpacing.page, 20),
            children: [
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (final (index, type) in state.event.ticketTypes.indexed)
                      ListRow(
                        minHeight: 68,
                        showDivider: index < state.event.ticketTypes.length - 1,
                        title: type.name,
                        subtitle: type.priceCents == 0 ? 'Free' : Money.format(type.priceCents),
                        trailing: QuantityStepper(
                          quantity: state.quantities[type.name] ?? 0,
                          onDecrement: () => bloc.add(DoorSaleQuantityDecreased(type.name)),
                          onIncrement: () => bloc.add(DoorSaleQuantityIncreased(type.name)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: "Buyer's phone",
                      hintText: '012 345 678',
                      initialValue: state.phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9 +]')),
                        LengthLimitingTextInputFormatter(16),
                      ],
                      onChanged: (phone) => bloc.add(DoorSalePhoneChanged(phone)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The QR e-ticket is sent to this number by SMS.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Payment',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ChipSelector<PaymentMethod>(
                      options: const [PaymentMethod.cash, PaymentMethod.abaKhqr],
                      selected: state.payment,
                      labelOf: (method) => method == PaymentMethod.cash ? 'Cash' : 'KHQR',
                      onChanged: (method) => bloc.add(DoorSalePaymentChanged(method)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _TotalBar(
          state: state,
          action: AppButton(
            label: 'Take payment',
            active: state.canCheckout,
            onPressed: () => bloc.add(const DoorSaleCheckoutRequested()),
          ),
        ),
      ],
    );
  }
}

class _TakePayment extends StatelessWidget {
  const _TakePayment({required this.state});

  final DoorSaleState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DoorSaleBloc>();
    final khqr = state.payment == PaymentMethod.abaKhqr;

    return Column(
      children: [
        ScreenHeader(
          title: khqr ? 'Pay by KHQR' : 'Collect cash',
          onBack: () => bloc.add(const DoorSaleCheckoutCancelled()),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                children: [
                  Text(ticketsLabel(state.count), style: AppTextStyles.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    Money.format(state.totalCents),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (khqr)
                    const _KhqrPending()
                  else
                    const Text(
                      'Collect the cash from the buyer, then confirm below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: AppColors.textBody),
                    ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 18),
            child: AppButton(
              label: khqr ? 'Payment received' : 'Cash received',
              height: 54,
              loading: state.submitting,
              onPressed: () => bloc.add(const DoorSalePaymentConfirmed()),
            ),
          ),
        ),
      ],
    );
  }
}

/// Stands in for the KHQR code. A real KHQR needs the business's Bakong
/// merchant account, which is not connected yet, so no pattern that looks
/// payable is shown.
class _KhqrPending extends StatelessWidget {
  const _KhqrPending();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x2400315E), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: const Column(
        children: [
          ColoredBox(
            color: AppColors.error,
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: Center(
                child: Text(
                  'KHQR',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.qr_code_2_rounded, size: 72, color: AppColors.border),
                SizedBox(height: 10),
                Text(
                  'KHQR is not connected yet. Check the payment in your bank app before '
                  'confirming.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleDone extends StatelessWidget {
  const _SaleDone({required this.sale});

  final Booking sale;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckInBloc, CheckInState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CheckInStatus.failure) {
          AppToast.show(context, state.errorMessage ?? 'Something went wrong');
        }
        if (state.status == CheckInStatus.decided) {
          AppToast.show(context, '${ticketsLabel(sale.ticketCount)} checked in');
          context.pop();
        }
      },
      builder: (context, checkIn) {
        return SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: const BoxDecoration(
                            color: AppColors.successSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 42,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text('E-ticket sent by SMS', style: AppTextStyles.headline),
                        const SizedBox(height: 8),
                        Text(
                          'The buyer at ${PhoneNumber.display(sale.phone)} shows the QR at the entrance, or you can '
                          'admit them now.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: AppColors.textBody),
                        ),
                        const SizedBox(height: 22),
                        AppCard(
                          color: AppColors.background,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(sale.id, style: AppTextStyles.sectionTitle),
                                  ),
                                  Text(
                                    Money.format(sale.totalCents),
                                    style: AppTextStyles.sectionTitle,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${sale.summary} · ${sale.payment.label}',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Admit ${ticketsLabel(sale.ticketCount)} now',
                      height: 54,
                      loading: checkIn.status == CheckInStatus.checking,
                      onPressed: () => context.read<CheckInBloc>().add(
                        CheckInRequested(eventId: sale.eventId, code: sale.id),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'Done',
                      variant: AppButtonVariant.text,
                      height: 48,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.state, required this.action});

  final DoorSaleState state;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 14),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.count == 0 ? 'No tickets' : ticketsLabel(state.count),
                    style: AppTextStyles.caption,
                  ),
                  Text(Money.format(state.totalCents), style: AppTextStyles.title),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(child: action),
            ],
          ),
        ),
      ),
    );
  }
}
