// course_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import '../models/date_course.dart'; // DateCourse / CourseSlot 정의 위치

class CourseApiService {
  static const _storage = FlutterSecureStorage();
  static const _kAccessToken = 'access_token';

  static Future<String?> _token() => _storage.read(key: _kAccessToken);

  /// 코스 생성
  static Future<DateCourse> createCourse(DateCourse course) async {
    final token = await _token();
    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/courses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(course.toJson()),
    );

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(
        '코스 생성 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    return DateCourse.fromJson(jsonDecode(response.body));
  }

  /// 현재 유저의 모든 코스 조회
  static Future<List<DateCourse>> getAllCourses() async {
    final token = await _token();
    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/courses'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        '코스 조회 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    final List<dynamic> list = jsonDecode(response.body);
    return list
        .map((e) => DateCourse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 특정 코스 조회
  static Future<DateCourse> getCourse(int courseId) async {
    final token = await _token();
    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/courses/$courseId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 404) {
      throw Exception('코스를 찾을 수 없습니다.');
    } else if (response.statusCode == 403) {
      throw Exception('권한이 없습니다.');
    } else if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        '코스 조회 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    return DateCourse.fromJson(jsonDecode(response.body));
  }

  /// 코스 수정 (전체 덮어쓰기 방식)
  static Future<DateCourse> updateCourse(DateCourse course) async {
    if (course.id == null) {
      throw Exception('코스 ID가 없습니다.');
    }

    final token = await _token();
    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/courses/${course.id}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(course.toJson()),
    );

    if (response.statusCode == 404) {
      throw Exception('코스를 찾을 수 없습니다.');
    } else if (response.statusCode == 403) {
      throw Exception('권한이 없습니다.');
    } else if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        '코스 수정 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    return DateCourse.fromJson(jsonDecode(response.body));
  }

  /// 코스 삭제
  static Future<void> deleteCourse(int courseId) async {
    final token = await _token();
    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/courses/$courseId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 404) {
      throw Exception('코스를 찾을 수 없습니다.');
    } else if (response.statusCode == 403) {
      throw Exception('권한이 없습니다.');
    } else if (response.statusCode != 204) {
      final body =
          response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(
        '코스 삭제 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }
  }
}
