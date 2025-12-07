import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

/// 개인 장소 API 서비스
///
/// 코스에 추가하거나 찜할 때 호출하여 개인 장소로 저장합니다.
/// - 정식 DB에 이미 있는 장소는 저장되지 않음 (null 반환)
/// - 이미 추가한 장소는 기존 데이터 반환
/// - 카테고리 기반 기본 features 자동 할당
class UserPlaceApiService {
  static const _storage = FlutterSecureStorage();

  static Future<String?> _getToken() async {
    return await _storage.read(key: 'access_token');
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 개인 장소 추가
  ///
  /// [addedFrom]: 'course' 또는 'wishlist'
  ///
  /// 반환값:
  /// - 성공 시: 저장된 장소 정보 (Map)
  /// - 정식 DB에 이미 있는 경우: null
  /// - 에러 시: Exception throw
  static Future<Map<String, dynamic>?> addUserPlace({
    required String name,
    required double latitude,
    required double longitude,
    required String addedFrom,
    String? address,
    String? category,
    Map<String, dynamic>? naverData,
  }) async {
    final token = await _getToken();
    if (token == null) {
      debugPrint('[UserPlace] 토큰 없음 - 로그인 필요');
      return null; // 로그인 안 된 상태면 조용히 실패
    }

    final body = {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'added_from': addedFrom,
      if (address != null) 'address': address,
      if (category != null) 'category': category,
      if (naverData != null) 'naver_data': naverData,
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/user-places'),
        headers: _headers(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null) {
          debugPrint('[UserPlace] 정식 DB에 이미 있는 장소: $name');
          return null;
        }
        debugPrint('[UserPlace] 저장 완료: $name');
        return data as Map<String, dynamic>;
      } else {
        debugPrint('[UserPlace] 저장 실패 (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[UserPlace] 저장 중 오류: $e');
      return null;
    }
  }

  /// 내 개인 장소 목록 조회
  static Future<List<Map<String, dynamic>>> getMyPlaces({
    bool? hasFeatures,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('로그인이 필요합니다');

    String url = '${ApiConfig.baseUrl}/user-places';
    if (hasFeatures != null) {
      url += '?has_features=$hasFeatures';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      debugPrint('[UserPlace] 목록 조회 실패: ${response.body}');
      throw Exception('개인 장소 목록 조회 실패');
    }

    final data = jsonDecode(response.body);
    return (data['places'] as List).cast<Map<String, dynamic>>();
  }

  /// 개인 장소 삭제
  static Future<bool> deleteUserPlace(String userPlaceId) async {
    final token = await _getToken();
    if (token == null) throw Exception('로그인이 필요합니다');

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/user-places/$userPlaceId'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      debugPrint('[UserPlace] 삭제 완료: $userPlaceId');
      return true;
    } else if (response.statusCode == 404) {
      debugPrint('[UserPlace] 장소를 찾을 수 없음: $userPlaceId');
      return false;
    } else {
      debugPrint('[UserPlace] 삭제 실패: ${response.body}');
      throw Exception('개인 장소 삭제 실패');
    }
  }
}
