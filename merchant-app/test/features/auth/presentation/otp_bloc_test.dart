import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/error/failure.dart';
import 'package:merchant/core/result/result.dart';
import 'package:merchant/core/utils/ticker.dart';
import 'package:merchant/features/auth/domain/entities/otp_verification.dart';
import 'package:merchant/features/auth/domain/usecases/request_otp.dart';
import 'package:merchant/features/auth/domain/usecases/verify_otp.dart';
import 'package:merchant/features/auth/presentation/bloc/otp/otp_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockVerifyOtp extends Mock implements VerifyOtp {}

class _MockRequestOtp extends Mock implements RequestOtp {}

/// A countdown the test advances by hand.
class _ManualTicker implements Ticker {
  final StreamController<int> seconds = StreamController<int>.broadcast();

  @override
  Stream<int> countdown({required int from}) => seconds.stream;
}

void main() {
  const phone = '+85512345678';
  const registration = OtpRegistrationRequired(registrationToken: 'reg_1', phone: phone);
  const start = OtpState(phone: phone, purpose: OtpPurpose.login);

  late _MockVerifyOtp verifyOtp;
  late _MockRequestOtp requestOtp;
  late _ManualTicker ticker;

  setUpAll(() {
    registerFallbackValue(
      const VerifyOtpParams(phone: '', code: '', purpose: OtpPurpose.login),
    );
    registerFallbackValue(const RequestOtpParams(phone: '', purpose: OtpPurpose.login));
  });

  setUp(() {
    verifyOtp = _MockVerifyOtp();
    requestOtp = _MockRequestOtp();
    ticker = _ManualTicker();
  });

  tearDown(() => ticker.seconds.close());

  OtpBloc build() {
    return OtpBloc(
      verifyOtp: verifyOtp,
      requestOtp: requestOtp,
      ticker: ticker,
      phone: phone,
      purpose: OtpPurpose.login,
    );
  }

  blocTest<OtpBloc, OtpState>(
    'counts down from 30 seconds once started',
    build: build,
    act: (bloc) async {
      bloc.add(const OtpStarted());
      await Future<void>.delayed(Duration.zero);
      ticker.seconds
        ..add(29)
        ..add(28);
    },
    expect: () => [
      start.copyWith(secondsLeft: 30),
      start.copyWith(secondsLeft: 29),
      start.copyWith(secondsLeft: 28),
    ],
  );

  blocTest<OtpBloc, OtpState>(
    'keeps only digits and does not verify an incomplete code',
    build: build,
    act: (bloc) => bloc.add(const OtpCodeChanged('12a3')),
    expect: () => [start.copyWith(code: '123')],
    verify: (_) => verifyNever(() => verifyOtp(any())),
  );

  blocTest<OtpBloc, OtpState>(
    'verifies by itself as soon as the sixth digit is typed',
    setUp: () {
      when(() => verifyOtp(any())).thenAnswer((_) async => const Result.success(registration));
    },
    build: build,
    act: (bloc) => bloc.add(const OtpCodeChanged('123456')),
    expect: () => [
      start.copyWith(code: '123456'),
      start.copyWith(code: '123456', status: OtpStatus.verifying),
      start.copyWith(code: '123456', status: OtpStatus.verified, verification: registration),
    ],
    verify: (_) {
      verify(
        () => verifyOtp(
          const VerifyOtpParams(phone: phone, code: '123456', purpose: OtpPurpose.login),
        ),
      ).called(1);
    },
  );

  blocTest<OtpBloc, OtpState>(
    'clears a wrong code and shows why',
    setUp: () {
      when(
        () => verifyOtp(any()),
      ).thenAnswer((_) async => const Result.failure(InvalidCodeFailure()));
    },
    build: build,
    act: (bloc) => bloc.add(const OtpCodeChanged('000000')),
    skip: 2,
    expect: () => [
      start.copyWith(errorMessage: () => const InvalidCodeFailure().message),
    ],
  );

  blocTest<OtpBloc, OtpState>(
    'keeps the digits when verifying failed because of the connection',
    setUp: () {
      when(
        () => verifyOtp(any()),
      ).thenAnswer((_) async => const Result.failure(NetworkFailure('Offline')));
    },
    build: build,
    act: (bloc) => bloc.add(const OtpCodeChanged('123456')),
    skip: 2,
    expect: () => [
      start.copyWith(code: '123456', errorMessage: () => 'Offline'),
    ],
  );

  blocTest<OtpBloc, OtpState>(
    'asks for all 6 digits when Verify is tapped early',
    build: build,
    seed: () => start.copyWith(code: '12'),
    act: (bloc) => bloc.add(const OtpSubmitted()),
    expect: () => [
      start.copyWith(code: '12', errorMessage: () => 'Enter all 6 digits'),
    ],
    verify: (_) => verifyNever(() => verifyOtp(any())),
  );

  blocTest<OtpBloc, OtpState>(
    'does not resend while the countdown is running',
    build: build,
    seed: () => start.copyWith(secondsLeft: 12),
    act: (bloc) => bloc.add(const OtpResendRequested()),
    expect: () => const <OtpState>[],
    verify: (_) => verifyNever(() => requestOtp(any())),
  );

  blocTest<OtpBloc, OtpState>(
    'resends when the countdown is over, restarts it and tells the person',
    setUp: () {
      when(() => requestOtp(any())).thenAnswer((_) async => const Result.success(null));
    },
    build: build,
    seed: () => start.copyWith(code: '12', errorMessage: () => 'Old error'),
    act: (bloc) => bloc.add(const OtpResendRequested()),
    expect: () => [
      start.copyWith(code: '12', errorMessage: () => 'Old error', status: OtpStatus.resending),
      start,
      start.copyWith(secondsLeft: 30),
      start.copyWith(secondsLeft: 30, notice: () => 'A new code is on its way'),
      start.copyWith(secondsLeft: 30),
    ],
    verify: (_) {
      verify(
        () => requestOtp(const RequestOtpParams(phone: phone, purpose: OtpPurpose.login)),
      ).called(1);
    },
  );
}
