// What the Pin admin panel decides reaches the app: whether the business is
// approved or suspended, whether an event is approved, and payouts.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/error/failure.dart';
import 'package:merchant/core/result/result.dart';
import 'package:merchant/core/storage/key_value_store.dart';
import 'package:merchant/core/usecase/usecase.dart';
import 'package:merchant/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:merchant/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:merchant/features/auth/data/models/auth_session_model.dart';
import 'package:merchant/features/auth/data/models/merchant_user_model.dart';
import 'package:merchant/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:merchant/features/auth/domain/entities/auth_session.dart';
import 'package:merchant/features/auth/domain/entities/business_status.dart';
import 'package:merchant/features/auth/domain/entities/business_type.dart';
import 'package:merchant/features/auth/domain/entities/merchant_user.dart';
import 'package:merchant/features/auth/domain/entities/otp_verification.dart';
import 'package:merchant/features/auth/domain/entities/staff_role.dart';
import 'package:merchant/features/bookings/data/repositories/mock_bookings_repository.dart';
import 'package:merchant/features/bookings/domain/entities/booking.dart';
import 'package:merchant/features/dashboard/presentation/organisms/business_status_banner.dart';
import 'package:merchant/features/events/data/models/event_json.dart';
import 'package:merchant/features/payouts/data/mock_payouts_repository.dart';
import 'package:merchant/features/payouts/data/payouts_api_data_source.dart';
import 'package:merchant/features/payouts/domain/entities/payouts.dart';
import 'package:merchant/features/payouts/domain/usecases/get_payouts.dart';
import 'package:merchant/features/payouts/presentation/bloc/payouts_bloc.dart';
import 'package:merchant/features/payouts/presentation/organisms/payouts_card.dart';
import 'package:merchant/mock_backend/mock_merchant_backend.dart';
import 'package:merchant/mock_backend/mock_request_context.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetPayouts extends Mock implements GetPayouts {}

const _owner = MerchantUserModel(
  id: 'u_1',
  name: 'Vannak Sok',
  phone: '+85512345678',
  role: StaffRole.owner,
  businessId: MockMerchantBackend.demoBusinessId,
  businessName: 'Khmer Runners Club',
  businessType: BusinessType.events,
  businessStatus: BusinessStatus.pending,
);

/// The server's `GET /me`: answers [user] once set.
class _FakeRemote implements AuthRemoteDataSource {
  MerchantUserModel? user;
  int calls = 0;

  @override
  Future<MerchantUserModel?> currentUser() async {
    calls++;
    return user;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestOtp({required String phone, required OtpPurpose purpose}) =>
      throw UnimplementedError();

  @override
  Future<VerifyOtpResponseModel> verifyOtp({
    required String phone,
    required String code,
    required OtpPurpose purpose,
  }) => throw UnimplementedError();

  @override
  Future<AuthSessionModel> registerBusiness({
    required String registrationToken,
    required String businessName,
    required String contactName,
    required BusinessType type,
  }) => throw UnimplementedError();

  @override
  Future<AuthSessionModel> joinTeam({
    required String registrationToken,
    required String name,
    required String joinCode,
  }) => throw UnimplementedError();
}

void main() {
  group('business status', () {
    test('is read from the API, and an older saved session counts as active', () {
      final json = _owner.toJson();
      expect(MerchantUserModel.fromJson(json).businessStatus, BusinessStatus.pending);

      (json['business'] as Map<String, dynamic>).remove('status');
      final old = MerchantUserModel.fromJson(json).toEntity();
      expect(old.businessStatus, BusinessStatus.active);
      expect(old.canSell, isTrue);
      expect(old.copyWith(businessStatus: BusinessStatus.suspended).canSell, isFalse);
    });

    test('a change on the server is saved and announced', () async {
      final remote = _FakeRemote();
      final local = AuthLocalDataSource(InMemoryKeyValueStore());
      final repository = AuthRepositoryImpl(remote: remote, local: local);
      await local.saveSession(const AuthSessionModel(accessToken: 't0k', user: _owner));
      final announced = <AuthSession?>[];
      final subscription = repository.sessionChanges.listen(announced.add);

      // Nothing new: nothing announced.
      remote.user = _owner;
      await repository.refreshUser();
      await pumpEventQueue();
      expect(announced, isEmpty);

      // Pin approved the business.
      remote.user = MerchantUserModel.fromEntity(
        _owner.toEntity().copyWith(businessStatus: BusinessStatus.active),
      );
      final result = await repository.refreshUser();
      await pumpEventQueue();

      expect(result, isA<Success<void>>());
      expect(announced.single?.user.businessStatus, BusinessStatus.active);
      expect(announced.single?.accessToken, 't0k');
      expect((await local.readSession())?.user.businessStatus, BusinessStatus.active);
      await subscription.cancel();
    });

    test('nothing is asked while signed out', () async {
      final remote = _FakeRemote();
      final repository = AuthRepositoryImpl(
        remote: remote,
        local: AuthLocalDataSource(InMemoryKeyValueStore()),
      );

      await repository.refreshUser();

      expect(remote.calls, 0);
    });

    testWidgets('the banner says why nothing sells', (tester) async {
      Future<void> show(BusinessStatus status) {
        return tester.pumpWidget(
          MaterialApp(home: Scaffold(body: BusinessStatusBanner(status: status))),
        );
      }

      await show(BusinessStatus.pending);
      expect(find.text('Waiting for Pin’s approval'), findsOneWidget);

      await show(BusinessStatus.suspended);
      expect(find.text('Your business is suspended'), findsOneWidget);

      await show(BusinessStatus.active);
      expect(find.byType(Text), findsNothing);
    });
  });

  test('an event waiting for approval is read as such; older servers approve at once', () {
    final json = <String, dynamic>{
      'id': 'e1',
      'name': 'Kampot River Run 2026',
      'startsAt': '2026-11-20T06:00:00',
      'venue': 'Old Bridge, Kampot',
      'commissionRate': 5.0,
      'approved': false,
      'ticketTypes': [
        {'name': '5K', 'priceCents': 1000, 'quantity': 150},
      ],
    };
    expect(EventJson.event(json).approved, isFalse);

    json.remove('approved');
    expect(EventJson.event(json).approved, isTrue);
  });

  group('payouts', () {
    test('are read from the API', () {
      final overview = PayoutsJson.overview({
        'due': {'grossCents': 412000, 'commissionCents': 20600, 'netCents': 391400, 'bookingCount': 174},
        'paid': [
          {
            'id': 'p1',
            'paidAt': '2026-11-11T10:00:00',
            'grossCents': 158400,
            'commissionCents': 7920,
            'netCents': 150480,
            'bookingCount': 85,
          },
        ],
      });

      expect(
        overview.due,
        const PayoutAmount(grossCents: 412000, commissionCents: 20600, netCents: 391400, bookingCount: 174),
      );
      expect(overview.paid.single.id, 'p1');
      expect(overview.paid.single.paidAt, DateTime(2026, 11, 11, 10));
      expect(overview.paid.single.amount.netCents, 150480);
    });

    test('refunds taken back are read; an older server has none', () {
      final overview = PayoutsJson.overview({
        'due': {
          'grossCents': 1000,
          'commissionCents': 50,
          'refundsCents': 3800,
          'netCents': -2850,
          'bookingCount': 1,
        },
        'paid': [
          {
            'id': 'p1',
            'paidAt': '2026-11-11T10:00:00',
            'grossCents': 158400,
            'commissionCents': 7920,
            'netCents': 150480,
            'bookingCount': 85,
          },
        ],
      });

      expect(overview.due.refundsCents, 3800);
      expect(overview.due.netCents, -2850);
      expect(overview.paid.single.amount.refundsCents, 0);
    });

    Future<void> showCard(WidgetTester tester, PayoutsOverview overview) async {
      final getPayouts = _MockGetPayouts();
      when(() => getPayouts(const NoParams())).thenAnswer((_) async => Result.success(overview));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => PayoutsBloc(getPayouts: getPayouts)..add(const PayoutsRequested()),
              child: const PayoutsCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the card shows nothing owed while refunds are more than new sales', (tester) async {
      await showCard(
        tester,
        const PayoutsOverview(
          due: PayoutAmount(
            grossCents: 1000,
            commissionCents: 50,
            refundsCents: 3800,
            netCents: -2850,
            bookingCount: 1,
          ),
          paid: [],
        ),
      );

      expect(find.text('Owed to you'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget);
      expect(find.text(r'$-28.50'), findsNothing);
      expect(find.textContaining('−'), findsNothing);
      expect(find.text(r'Refunds of $38.00 are taken off your next payout.'), findsOneWidget);
      expect(find.textContaining('Pin pays this out to you'), findsNothing);
      expect(
        find.textContaining(r'$10.00 sales minus $0.50 commission minus $38.00 refunds'),
        findsOneWidget,
      );
    });

    testWidgets('the card shows refunds in the caption and on paid payouts', (tester) async {
      await showCard(
        tester,
        PayoutsOverview(
          due: const PayoutAmount(
            grossCents: 10000,
            commissionCents: 500,
            refundsCents: 1800,
            netCents: 7700,
            bookingCount: 3,
          ),
          paid: [
            Payout(
              id: 'p1',
              paidAt: DateTime(2026, 11, 11, 10),
              amount: const PayoutAmount(
                grossCents: 5000,
                commissionCents: 250,
                refundsCents: 900,
                netCents: 3850,
                bookingCount: 2,
              ),
            ),
          ],
        ),
      );

      expect(find.text(r'$77.00'), findsOneWidget);
      expect(
        find.textContaining(r'$100.00 sales minus $5.00 commission minus $18.00 refunds'),
        findsOneWidget,
      );
      expect(find.textContaining('are taken off your next payout'), findsNothing);
      expect(find.text(r'Paid 11 Nov 2026 (after $9.00 refunds)'), findsOneWidget);
      expect(find.text(r'$38.50'), findsOneWidget);
    });

    test('in the mock, every online booking is owed, minus commission', () async {
      final backend = MockMerchantBackend(latency: Duration.zero, clock: () => DateTime(2026, 11, 12, 9));
      final repository = MockPayoutsRepository(
        backend: backend,
        context: MockRequestContext(() async => _owner.toEntity()),
      );

      final result = await repository.fetchPayouts();

      final overview = (result as Success<PayoutsOverview>).value;
      expect(overview.due.bookingCount, greaterThan(0));
      expect(overview.due.netCents, overview.due.grossCents - overview.due.commissionCents);
      expect(overview.due.commissionCents, closeTo(overview.due.grossCents * 0.05, overview.due.bookingCount));
      expect(overview.paid, isEmpty);
    });

    test('in the mock, a scanner cannot cancel a booking', () async {
      final scanner = MerchantUser(
        id: 'u_2',
        name: 'Dara Keo',
        phone: '+85598765432',
        role: StaffRole.scanner,
        businessId: MockMerchantBackend.demoBusinessId,
        businessName: 'Khmer Runners Club',
        businessType: BusinessType.events,
      );
      final backend = MockMerchantBackend(latency: Duration.zero, clock: () => DateTime(2026, 11, 12, 9));
      final repository = MockBookingsRepository(backend: backend, context: MockRequestContext(() async => scanner));
      final open = (await backend.watchBookings(MockMerchantBackend.demoBusinessId).first)
          .firstWhere((b) => b.status == BookingStatus.open);

      final result = await repository.cancelBooking(bookingId: open.id, reason: CancelReason.other);

      expect(result, const Result<Booking>.failure(RejectedFailure('Only the owner can do this.')));
      final after = await backend.watchBookings(MockMerchantBackend.demoBusinessId).first;
      expect(after.firstWhere((b) => b.id == open.id).status, BookingStatus.open);
    });

    test('in the mock, scanners cannot see them', () async {
      final scanner = MerchantUser(
        id: 'u_2',
        name: 'Dara Keo',
        phone: '+85598765432',
        role: StaffRole.scanner,
        businessId: MockMerchantBackend.demoBusinessId,
        businessName: 'Khmer Runners Club',
        businessType: BusinessType.events,
      );
      final repository = MockPayoutsRepository(
        backend: MockMerchantBackend(latency: Duration.zero),
        context: MockRequestContext(() async => scanner),
      );

      expect(await repository.fetchPayouts(), isA<FailureResult<PayoutsOverview>>());
    });
  });
}
