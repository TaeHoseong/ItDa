import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class SearchApiService {
  /// 장소 검색: GET /search/places?query=...
  static Future<List<dynamic>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    final uri = Uri.parse('${ApiConfig.baseUrl}/search/places').replace(
      queryParameters: {'query': query},
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('검색 실패 (${response.statusCode}): ${response.body}');
    }

    final List<dynamic> body = jsonDecode(response.body);
    return body;
  }
}
