part of 'register_business_bloc.dart';

enum RegisterBusinessStatus {
  editing,
  submitting,

  /// The account exists and the owner is signed in.
  success,

  /// Show [RegisterBusinessState.errorMessage].
  failure,
}

final class RegisterBusinessState extends Equatable {
  const RegisterBusinessState({
    this.businessName = '',
    this.contactName = '',
    this.type = BusinessType.events,
    this.status = RegisterBusinessStatus.editing,
    this.errorMessage,
  });

  static const _minNameLength = 2;

  final String businessName;
  final String contactName;
  final BusinessType type;
  final RegisterBusinessStatus status;
  final String? errorMessage;

  bool get isBusinessNameValid => businessName.trim().length >= _minNameLength;
  bool get isContactNameValid => contactName.trim().length >= _minNameLength;
  bool get isValid => isBusinessNameValid && isContactNameValid;
  bool get isSubmitting => status == RegisterBusinessStatus.submitting;

  RegisterBusinessState copyWith({
    String? businessName,
    String? contactName,
    BusinessType? type,
    RegisterBusinessStatus? status,
    String? errorMessage,
  }) {
    return RegisterBusinessState(
      businessName: businessName ?? this.businessName,
      contactName: contactName ?? this.contactName,
      type: type ?? this.type,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [businessName, contactName, type, status, errorMessage];
}
