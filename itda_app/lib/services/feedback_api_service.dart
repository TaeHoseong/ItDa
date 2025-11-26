import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

/// 피드백 학습 API 서비스
/// 일기 별점 기반 커플 페르소나 업데이트
class FeedbackApiService {
  static const _storage = FlutterSecureStorage();

  /// 커플 페르소나 재계산 요청
  /// 일기 저장/수정/삭제 후 호출
  static Future<bool> recalculatePersona() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        debugPrint('[FeedbackAPI] No access token');
        return false;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/feedback/recalculate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[FeedbackAPI] Persona recalculated: ${data['message']}');
        debugPrint('[FeedbackAPI] Feedback count: ${data['feedback_count']}');
        return true;
      } else {
        debugPrint('[FeedbackAPI] Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[FeedbackAPI] Exception: $e');
      return false;
    }
  }

  /// 페르소나 차이 조회 (디버깅용)
  static Future<Map<String, dynamic>?> getPersonaDiff() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        return null;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/feedback/diff'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('[FeedbackAPI] Exception: $e');
      return null;
    }
  }
}
