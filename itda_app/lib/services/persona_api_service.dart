import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class PersonaApiService {
  final String sessionId;

  PersonaApiService({required this.sessionId});

  /// 챗봇에게 메시지 전송
  Future<Map<String, dynamic>> sendMessage(
    String message, {
    String? userId,
    double? userLat,
    double? userLng,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/persona/chat');

      final requestBody = <String, dynamic>{
        'message': message,
        'session_id': sessionId,
      };

      // user_id가 있으면 추가 (사용자별 맞춤 추천을 위함)
      if (userId != null) {
        requestBody['user_id'] = userId;
      }

      // GPS 위치가 있으면 추가 (위치 기반 추천을 위함)
      if (userLat != null && userLng != null) {
        requestBody['user_lat'] = userLat;
        requestBody['user_lng'] = userLng;
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestBody),
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data;
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  /// 세션 초기화
  Future<void> clearSession() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/persona/sessions/$sessionId');
      await http.delete(url).timeout(ApiConfig.timeout);
      print('🗑️ 세션 초기화 완료');
    } catch (e) {
      print('⚠️ 세션 초기화 실패: $e');
    }
  }
}