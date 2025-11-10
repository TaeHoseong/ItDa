import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_persona.dart';
import 'api_config.dart';

/// User API service for managing user data
class UserApiService {
  static const _storage = FlutterSecureStorage();
  static const _kAccessToken = 'access_token';

  /// Update user persona (survey results)
  ///
  /// Sends 20-dimension persona vector to backend
  /// Requires authentication (uses stored access_token)
  ///
  /// Throws Exception if:
  /// - No access token found (user not logged in)
  /// - API request fails
  /// - Server returns error
  static Future<void> updatePersona(UserPersona persona) async {
    // Get stored access token
    final token = await _storage.read(key: _kAccessToken);

    if (token == null) {
      throw Exception('로그인이 필요합니다. 토큰이 없습니다.');
    }

    // Make API request
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/users/persona'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(persona.toJson()),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        '페르소나 저장 실패 (${response.statusCode}): ${body['detail'] ?? response.body}',
      );
    }

    // Success - persona saved to database
  }
}
