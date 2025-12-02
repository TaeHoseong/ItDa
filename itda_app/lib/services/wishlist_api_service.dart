import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';
import '../models/wishlist.dart';

/// 찜목록 API 서비스
class WishlistApiService {
  static const _storage = FlutterSecureStorage();

  static Future<String?> _getToken() async {
    return await _storage.read(key: 'access_token');
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 찜목록 조회
  static Future<List<Wishlist>> getWishlists() async {
    final token = await _getToken();
    if (token == null) throw Exception('로그인이 필요합니다');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/wishlist'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      debugPrint('찜목록 조회 실패: ${response.body}');
      throw Exception('찜목록 조회 실패');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Wishlist.fromJson(json)).toList();
  }

  /// 찜 추가
  static Future<Wishlist> addWishlist({
    required String placeName,
    required double latitude,
    required double longitude,
    String? address,
    String? category,
    String? memo,
    String? link,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('로그인이 필요합니다');

    final body = {
      'place_name': placeName,
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      if (category != null) 'category': category,
      if (memo != null) 'memo': memo,
      if (link != null) 'link': link,
    };

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/wishlist'),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      final message = error['detail'] ?? error['error']?['message'] ?? '찜 추가 실패';
      debugPrint('찜 추가 실패: $message');
      throw Exception(message);
    }

    return Wishlist.fromJson(jsonDecode(response.body));
  }

  /// 찜 삭제
  static Future<void> deleteWishlist(String id) async {
    final token = await _getToken();
    if (token == null) throw Exception('로그인이 필요합니다');

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/wishlist/$id'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      debugPrint('찜 삭제 실패: ${response.body}');
      throw Exception('찜 삭제 실패');
    }
  }

  /// 찜 여부 확인
  static Future<Wishlist?> checkWishlist({
    required double latitude,
    required double longitude,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('로그인이 필요합니다');

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/wishlist/check'),
      headers: _headers(token),
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('찜 여부 확인 실패: ${response.body}');
      return null;
    }

    final data = jsonDecode(response.body);
    if (data['is_wishlisted'] == true && data['wishlist'] != null) {
      return Wishlist.fromJson(data['wishlist']);
    }
    return null;
  }
}
