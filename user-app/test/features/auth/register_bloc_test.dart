import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user/core/result/result.dart';
import 'package:user/features/auth/domain/entities/auth_session.dart';
import 'package:user/features/auth/domain/entities/gender.dart';
import 'package:user/features/auth/domain/entities/pin_user.dart';
import 'package:user/features/auth/domain/usecases/register_account.dart';
import 'package:user/features/auth/presentation/bloc/register/register_bloc.dart';

class _MockRegisterAccount extends Mock implements RegisterAccount {}

void main() {
  late _MockRegisterAccount registerAccount;
  final born = DateTime(1999, 3, 8);
  final session = AuthSession(
    accessToken: 'token',
    user: PinUser(
      id: 'u_9',
      name: 'Dara Pich',
      phone: '+85512888999',
      gender: Gender.female,
      dateOfBirth: born,
    ),
  );

  setUpAll(() {
    registerFallbackValue(
      RegisterAccountParams(registrationToken: '', name: '', gender: Gender.other, dateOfBirth: born),
    );
  });

  setUp(() => registerAccount = _MockRegisterAccount());

  RegisterBloc build() => RegisterBloc(registerAccount: registerAccount, registrationToken: 'reg_1');

  test('reports what is missing in the order of the form', () {
    expect(const RegisterState().firstProblem, 'Please enter your name');
    expect(const RegisterState(name: 'D').firstProblem, 'Please enter your name');
    expect(const RegisterState(name: 'Dara').firstProblem, 'Please choose a gender');
    expect(
      const RegisterState(name: 'Dara', gender: Gender.female).firstProblem,
      'Please enter your date of birth',
    );
    expect(
      RegisterState(name: 'Dara', gender: Gender.female, dateOfBirth: born, email: 'dara@').firstProblem,
      'Please enter a valid email',
    );
    // Email is optional.
    expect(RegisterState(name: 'Dara', gender: Gender.female, dateOfBirth: born).canSubmit, isTrue);
  });

  blocTest<RegisterBloc, RegisterState>(
    'does not send an incomplete form',
    build: build,
    act: (bloc) => bloc.add(const RegisterSubmitted()),
    expect: () => [
      const RegisterState(status: RegisterStatus.failure, errorMessage: 'Please enter your name'),
      const RegisterState(errorMessage: 'Please enter your name'),
    ],
    verify: (_) => verifyNever(() => registerAccount(any())),
  );

  blocTest<RegisterBloc, RegisterState>(
    'creates the account with the trimmed details, without an empty email',
    build: () {
      when(() => registerAccount(any())).thenAnswer((_) async => Result.success(session));
      return build();
    },
    act: (bloc) => bloc
      ..add(const RegisterNameChanged('  Dara Pich '))
      ..add(const RegisterGenderChanged(Gender.female))
      ..add(RegisterDateOfBirthChanged(born))
      ..add(const RegisterEmailChanged('  '))
      ..add(const RegisterSubmitted()),
    skip: 4,
    expect: () => [
      isA<RegisterState>().having((s) => s.status, 'status', RegisterStatus.submitting),
      isA<RegisterState>()
          .having((s) => s.status, 'status', RegisterStatus.registered)
          .having((s) => s.firstName, 'firstName', 'Dara'),
    ],
    verify: (_) => verify(
      () => registerAccount(
        RegisterAccountParams(
          registrationToken: 'reg_1',
          name: 'Dara Pich',
          gender: Gender.female,
          dateOfBirth: born,
        ),
      ),
    ).called(1),
  );
}
