import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_persona.dart';
import 'api_config.dart';

/// User API service for managing user data
class UserApiService {
  static const _storage = FlutterSecureStorage();
  static const _kAccessToken = 'access_token';

  /// Submit user survey (persona results)
  ///
  /// Sends 20-dimension persona vector to backend
  /// Requires authentication (uses stored access_token)
  ///
  /// Throws Exception if:
  /// - No access token found (user not logged in)
  /// - API request fails
  /// - Server returns error
  static Future<void> submitSurvey(uid, UserPersona persona) async {
    // Get stored access token
    final token = await _storage.read(key: _kAccessToken);

    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }
    
    final body_json = persona.toJson();
    
    // Make API request
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/users/survey'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body_json),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        '설문 저장 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    // Success - survey saved to database
  }

  /// 매칭 코드 생성: POST /match/generate-code
  /// 성공 시 서버에서 내려준 JSON(Map)을 그대로 반환
  static Future<Map<String, dynamic>> generateMatchCode() async {
    final token = await _storage.read(key: _kAccessToken);

    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/match/generate-code');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 201) {
      final detail = body?['detail']?.toString() ?? response.body;
      throw Exception('매칭 코드 생성 실패 (${response.statusCode}): $detail');
    }

    if (body == null) {
      throw Exception('매칭 코드 생성 실패: 빈 응답');
    }

    return body;
  }

  /// 매칭 코드로 커플 연결: POST /match/connect
  /// 성공 시 서버 JSON(Map) 그대로 반환
  static Future<Map<String, dynamic>> connectWithMatchCode(
      String matchCode) async {
    final token = await _storage.read(key: _kAccessToken);

    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/match/connect');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'match_code': matchCode}),
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 201) {
      final detail = body?['detail']?.toString() ?? response.body;
      throw Exception('커플 매칭 실패 (${response.statusCode}): $detail');
    }

    if (body == null) {
      throw Exception('커플 매칭 실패: 빈 응답');
    }

    return body;
  }

    /// 현재 로그인한 사용자 정보 조회: GET /users/me
  /// 성공 시 서버에서 내려준 JSON(Map)을 그대로 반환
  static Future<Map<String, dynamic>> fetchMe() async {
    // 1) 액세스 토큰 읽기
    final token = await _storage.read(key: _kAccessToken);

    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    // 2) /users/me 호출 (엔드포인트 이름은 백엔드에 맞게 조정)
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/me');

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    // 3) 응답 파싱
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    // 4) 에러 처리
    if (response.statusCode != 200) {
      final detail = body?['detail']?.toString() ?? response.body;
      throw Exception('내 정보 조회 실패 (${response.statusCode}): $detail');
    }

    if (body == null) {
      throw Exception('내 정보 조회 실패: 빈 응답');
    }

    // 5) 정상 응답 반환
    return body;
  }
}
