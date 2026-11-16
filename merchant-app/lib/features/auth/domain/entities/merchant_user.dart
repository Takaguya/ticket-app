import 'package:equatable/equatable.dart';

import 'business_status.dart';
import 'business_type.dart';
import 'staff_role.dart';

/// A person signed in to Pin Merchant, with the business they work for.
class MerchantUser extends Equatable {
  const MerchantUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.businessId,
    required this.businessName,
    required this.businessType,
    this.businessStatus = BusinessStatus.active,
  });

  final String id;
  final String name;

  /// E.164 form, e.g. `+85512345678`.
  final String phone;
  final StaffRole role;
  final String businessId;
  final String businessName;
  final BusinessType businessType;

  /// Whether Pin has approved the business, or suspended it.
  final BusinessStatus businessStatus;

  bool get isOwner => role == StaffRole.owner;

  /// Tickets can be sold only once Pin has approved the business, and not
  /// while it is suspended.
  bool get canSell => businessStatus == BusinessStatus.active;

  MerchantUser copyWith({BusinessStatus? businessStatus}) {
    return MerchantUser(
      id: id,
      name: name,
      phone: phone,
      role: role,
      businessId: businessId,
      businessName: businessName,
      businessType: businessType,
      businessStatus: businessStatus ?? this.businessStatus,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    role,
    businessId,
    businessName,
    businessType,
    businessStatus,
  ];
}
