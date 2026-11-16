import '../../domain/entities/business_status.dart';
import '../../domain/entities/business_type.dart';
import '../../domain/entities/merchant_user.dart';
import '../../domain/entities/staff_role.dart';

/// [MerchantUser] as the API sends it:
///
/// ```json
/// {
///   "id": "u_1", "name": "Vannak Sok", "phone": "+85512345678", "role": "owner",
///   "business": {"id": "b_1", "name": "Khmer Runners Club", "type": "events", "status": "active"}
/// }
/// ```
///
/// `status` is `pending` until Pin approves the business. Sessions saved by an
/// older version of the app have no status; they count as active until the
/// next refresh from the server.
class MerchantUserModel {
  const MerchantUserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.businessId,
    required this.businessName,
    required this.businessType,
    this.businessStatus = BusinessStatus.active,
  });

  factory MerchantUserModel.fromJson(Map<String, dynamic> json) {
    final business = json['business'] as Map<String, dynamic>;
    return MerchantUserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: StaffRole.values.byName(json['role'] as String),
      businessId: business['id'] as String,
      businessName: business['name'] as String,
      businessType: BusinessType.values.byName(business['type'] as String),
      businessStatus: BusinessStatus.fromName(business['status'] as String?),
    );
  }

  factory MerchantUserModel.fromEntity(MerchantUser user) {
    return MerchantUserModel(
      id: user.id,
      name: user.name,
      phone: user.phone,
      role: user.role,
      businessId: user.businessId,
      businessName: user.businessName,
      businessType: user.businessType,
      businessStatus: user.businessStatus,
    );
  }

  final String id;
  final String name;
  final String phone;
  final StaffRole role;
  final String businessId;
  final String businessName;
  final BusinessType businessType;
  final BusinessStatus businessStatus;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role.name,
      'business': {
        'id': businessId,
        'name': businessName,
        'type': businessType.name,
        'status': businessStatus.name,
      },
    };
  }

  MerchantUser toEntity() {
    return MerchantUser(
      id: id,
      name: name,
      phone: phone,
      role: role,
      businessId: businessId,
      businessName: businessName,
      businessType: businessType,
      businessStatus: businessStatus,
    );
  }
}
