import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/team.dart';
import '../models/team_json.dart';

/// The staff endpoints of the Pin API. Owner only. Throws `ApiException` or
/// `NetworkException`.
class StaffApiDataSource {
  const StaffApiDataSource(this._dio);

  final Dio _dio;

  /// `GET /merchant/staff`
  Future<Team> fetchTeam() {
    return apiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/merchant/staff');
      return TeamJson.team(response.data!);
    });
  }

  /// `DELETE /merchant/staff/{id}`. The owner cannot be removed.
  Future<void> removeMember(String memberId) {
    return apiCall(() => _dio.delete<void>('/merchant/staff/$memberId'));
  }

  /// `POST /merchant/staff/join-code`: the new code.
  Future<String> regenerateJoinCode() {
    return apiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>('/merchant/staff/join-code');
      return response.data!['joinCode'] as String;
    });
  }
}
