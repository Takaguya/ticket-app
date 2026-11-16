import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant/core/error/failure.dart';
import 'package:merchant/core/result/result.dart';
import 'package:merchant/features/auth/domain/entities/otp_verification.dart';
import 'package:merchant/features/auth/domain/usecases/request_otp.dart';
import 'package:merchant/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockRequestOtp extends Mock implements RequestOtp {}

void main() {
  const typedPhone = '012 345 678';
  const invalidMessage = 'Please enter a valid phone number';

  late _MockRequestOtp requestOtp;

  setUpAll(() {
    registerFallbackValue(const RequestOtpParams(phone: '', purpose: OtpPurpose.login));
  });

  setUp(() => requestOtp = _MockRequestOtp());

  LoginBloc build() => LoginBloc(requestOtp: requestOtp);

  test('starts in log-in mode with an empty phone number', () {
    expect(build().state, const LoginState());
  });

  blocTest<LoginBloc, LoginState>(
    'explains what is missing when the phone number is not valid, without asking for a code',
    build: build,
    act: (bloc) => bloc.add(const LoginSubmitted()),
    expect: () => const [
      LoginState(status: LoginStatus.failure, errorMessage: invalidMessage),
      LoginState(errorMessage: invalidMessage),
    ],
    verify: (_) => verifyNever(() => requestOtp(any())),
  );

  blocTest<LoginBloc, LoginState>(
    'asks for a code for the number in E.164 form, then reports it was sent',
    setUp: () {
      when(() => requestOtp(any())).thenAnswer((_) async => const Result.success(null));
    },
    build: build,
    act: (bloc) => bloc
      ..add(const LoginModeChanged(OtpPurpose.register))
      ..add(const LoginPhoneChanged(typedPhone))
      ..add(const LoginSubmitted()),
    expect: () => const [
      LoginState(mode: OtpPurpose.register),
      LoginState(mode: OtpPurpose.register, phone: typedPhone),
      LoginState(mode: OtpPurpose.register, phone: typedPhone, status: LoginStatus.submitting),
      LoginState(mode: OtpPurpose.register, phone: typedPhone, status: LoginStatus.codeSent),
    ],
    verify: (_) {
      verify(
        () => requestOtp(
          const RequestOtpParams(phone: '+85512345678', purpose: OtpPurpose.register),
        ),
      ).called(1);
    },
  );

  blocTest<LoginBloc, LoginState>(
    'reports the failure and returns to idle when the code cannot be sent',
    setUp: () {
      when(
        () => requestOtp(any()),
      ).thenAnswer((_) async => const Result.failure(NetworkFailure('Offline')));
    },
    build: build,
    seed: () => const LoginState(phone: typedPhone),
    act: (bloc) => bloc.add(const LoginSubmitted()),
    expect: () => const [
      LoginState(phone: typedPhone, status: LoginStatus.submitting),
      LoginState(phone: typedPhone, status: LoginStatus.failure, errorMessage: 'Offline'),
      LoginState(phone: typedPhone, errorMessage: 'Offline'),
    ],
  );
}
