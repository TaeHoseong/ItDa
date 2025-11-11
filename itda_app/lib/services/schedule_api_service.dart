import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

/// Schedule API service for managing user schedules
///
/// Provides CRUD operations for schedules with JWT authentication
class ScheduleApiService {
  static const _storage = FlutterSecureStorage();
  static const _kAccessToken = 'access_token';

  /// Create a new schedule
  ///
  /// Required fields: title, date, time
  /// Optional fields: place_name, latitude, longitude, address
  ///
  /// Throws Exception if:
  /// - No access token found (user not logged in)
  /// - API request fails
  /// - Server returns error
  static Future<Map<String, dynamic>> createSchedule({
    required String title,
    required DateTime date,
    required String time,
    String? placeName,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final token = await _storage.read(key: _kAccessToken);

    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/schedules'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'date': date.toIso8601String(),
        'time': time,
        if (placeName != null) 'place_name': placeName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (address != null) 'address': address,
      }),
    );

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(
        '일정 생성 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    return jsonDecode(response.body);
  }

  /// Get all schedules for the current user
  ///
  /// Returns list of schedule objects
  ///
  /// Throws Exception if:
  /// - No access token found (user not logged in)
  /// - API request fails
  /// - Server returns error
  static Future<List<Map<String, dynamic>>> getAllSchedules() async {
    final token = await _storage.read(key: _kAccessToken);

    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/schedules'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        '일정 조회 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    final List<dynamic> schedules = jsonDecode(response.body);
    return schedules.cast<Map<String, dynamic>>();
  }

  /// Get a specific schedule by ID
  ///
  /// Throws Exception if:
  /// - No access token found (user not logged in)
  /// - API request fails
  /// - Server returns error (404 if schedule not found)
  /// - User doesn't have permission (403)
  static Future<Map<String, dynamic>> getSchedule(int scheduleId) async {
    final token = await _storage.read(key: _kAccessToken);

    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/schedules/$scheduleId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 404) {
      throw Exception('일정을 찾을 수 없습니다.');
    } else if (response.statusCode == 403) {
      throw Exception('권한이 없습니다.');
    } else if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        '일정 조회 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    return jsonDecode(response.body);
  }

  /// Update a schedule
  ///
  /// All fields are optional (partial update)
  ///
  /// Throws Exception if:
  /// - No access token found (user not logged in)
  /// - API request fails
  /// - Server returns error (404 if schedule not found, 403 if no permission)
  static Future<Map<String, dynamic>> updateSchedule({
    required int scheduleId,
    String? title,
    DateTime? date,
    String? time,
    String? placeName,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final token = await _storage.read(key: _kAccessToken);

    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final Map<String, dynamic> updateData = {};
    if (title != null) updateData['title'] = title;
    if (date != null) updateData['date'] = date.toIso8601String();
    if (time != null) updateData['time'] = time;
    if (placeName != null) updateData['place_name'] = placeName;
    if (latitude != null) updateData['latitude'] = latitude;
    if (longitude != null) updateData['longitude'] = longitude;
    if (address != null) updateData['address'] = address;

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/schedules/$scheduleId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updateData),
    );

    if (response.statusCode == 404) {
      throw Exception('일정을 찾을 수 없습니다.');
    } else if (response.statusCode == 403) {
      throw Exception('권한이 없습니다.');
    } else if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        '일정 수정 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    return jsonDecode(response.body);
  }

  /// Delete a schedule
  ///
  /// Throws Exception if:
  /// - No access token found (user not logged in)
  /// - API request fails
  /// - Server returns error (404 if schedule not found, 403 if no permission)
  static Future<void> deleteSchedule(int scheduleId) async {
    final token = await _storage.read(key: _kAccessToken);

    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/schedules/$scheduleId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 404) {
      throw Exception('일정을 찾을 수 없습니다.');
    } else if (response.statusCode == 403) {
      throw Exception('권한이 없습니다.');
    } else if (response.statusCode != 204) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(
        '일정 삭제 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    // Success - 204 No Content
  }
}
