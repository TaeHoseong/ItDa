import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

import '../secrets.dart';

/// 경로 타입
enum RouteType {
  driving,  // 자동차
  walking,  // 도보 (현재 driving과 동일)
  transit,  // 대중교통
}

/// 경로 요약 정보
class RouteSummary {
  final int distance;  // 미터
  final int duration;  // 밀리초

  RouteSummary({required this.distance, required this.duration});

  /// 거리를 읽기 좋은 형식으로 변환
  String get distanceText {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
    return '${distance}m';
  }

  /// 소요시간을 읽기 좋은 형식으로 변환
  String get durationText {
    final minutes = (duration / 60000).round();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '$hours시간 $mins분' : '$hours시간';
    }
    return '$minutes분';
  }
}

/// 경로 응답
class RouteResult {
  final List<NLatLng> path;
  final RouteSummary summary;

  RouteResult({required this.path, required this.summary});
}

/// Directions API 서비스 (Naver + Google Directions API)
class DirectionsService {
  static const String _naverBaseUrl = 'https://maps.apigw.ntruss.com';
  static const String _googleDirectionsUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  /// 자동차 경로 조회 (Naver API)
  static Future<RouteResult?> getDrivingRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    final url = Uri.parse('$_naverBaseUrl/map-direction/v1/driving').replace(
      queryParameters: {
        'start': '${start.longitude},${start.latitude}',
        'goal': '${end.longitude},${end.latitude}',
        'option': 'trafast',
      },
    );

    try {
      if (kDebugMode) {
        print('🔑 Directions API 요청:');
        print('   URL: $url');
        print('   KEY_ID: $NAVER_API_KEY_ID');
        print('   KEY: ${NAVER_API_KEY.substring(0, 5)}...${NAVER_API_KEY.substring(NAVER_API_KEY.length - 5)}');
      }

      final response = await http.get(
        url,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': NAVER_API_KEY_ID,
          'X-NCP-APIGW-API-KEY': NAVER_API_KEY,
        },
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Directions API 오류: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }

      final data = jsonDecode(response.body);

      if (data['code'] != 0) {
        if (kDebugMode) {
          print('❌ 경로를 찾을 수 없음: ${data['message']}');
        }
        return null;
      }

      final route = data['route']?['trafast']?[0];
      if (route == null) return null;

      final summary = route['summary'];
      final pathCoords = route['path'] as List<dynamic>;

      // [lng, lat] -> NLatLng 변환
      final path = pathCoords.map((coord) {
        return NLatLng(coord[1] as double, coord[0] as double);
      }).toList();

      return RouteResult(
        path: path,
        summary: RouteSummary(
          distance: summary['distance'] as int,
          duration: summary['duration'] as int,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Directions API 예외: $e');
      }
      return null;
    }
  }

  /// 도보 경로 조회 (Google API, 한국 미지원시 Naver fallback)
  static Future<RouteResult?> getWalkingRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    // Google 도보 경로 시도
    final googleResult = await _getGoogleRoute(start, end, 'walking');
    if (googleResult != null) {
      return googleResult;
    }

    // Google 미지원 시 Naver 자동차 경로 + 도보 시간 재계산
    if (kDebugMode) {
      print('⚠️ Google 도보 미지원, Naver fallback 사용');
    }
    final naverResult = await getDrivingRoute(start, end);
    if (naverResult == null) return null;

    // 도보 시간으로 재계산 (분당 67m 기준, 약 4km/h)
    final walkingDuration = (naverResult.summary.distance / 67 * 60000).round();

    return RouteResult(
      path: naverResult.path,
      summary: RouteSummary(
        distance: naverResult.summary.distance,
        duration: walkingDuration,
      ),
    );
  }

  /// 대중교통 경로 조회 (Google API)
  static Future<RouteResult?> getTransitRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    return _getGoogleRoute(start, end, 'transit');
  }

  /// Google Directions API 공통 메서드 (GET 방식 - Legacy)
  static Future<RouteResult?> _getGoogleRoute(
    NLatLng start,
    NLatLng end,
    String mode,
  ) async {
    final url = Uri.parse(_googleDirectionsUrl).replace(
      queryParameters: {
        'origin': '${start.latitude},${start.longitude}',
        'destination': '${end.latitude},${end.longitude}',
        'mode': mode,
        'key': GOOGLE_DIRECTIONS_API_KEY,
        'language': 'ko',
      },
    );

    try {
      if (kDebugMode) {
        print('🔑 Google Directions API 요청 ($mode):');
        print('   URL: $url');
      }

      final response = await http.get(url);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Google API 오류: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }

      final data = jsonDecode(response.body);

      if (data['status'] != 'OK') {
        if (kDebugMode) {
          print('❌ Google 경로를 찾을 수 없음: ${data['status']}');
          if (data['error_message'] != null) {
            print('   에러: ${data['error_message']}');
          }
        }
        return null;
      }

      final route = data['routes']?[0];
      if (route == null) return null;

      final leg = route['legs']?[0];
      if (leg == null) return null;

      // Polyline 디코딩하여 경로 좌표 추출
      final overviewPolyline = route['overview_polyline']?['points'] as String?;
      if (overviewPolyline == null) return null;

      final path = _decodePolyline(overviewPolyline);

      // 거리(미터)와 시간(밀리초) 추출
      final distance = leg['distance']?['value'] as int? ?? 0;
      final durationSeconds = leg['duration']?['value'] as int? ?? 0;
      final duration = durationSeconds * 1000; // 초 → 밀리초

      if (kDebugMode) {
        print('✅ Google 경로 로드 성공: ${path.length}개 좌표, ${distance}m, ${duration}ms');
      }

      return RouteResult(
        path: path,
        summary: RouteSummary(
          distance: distance,
          duration: duration,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Google API 예외: $e');
      }
      return null;
    }
  }

  /// Google Polyline 디코딩 (Encoded Polyline Algorithm)
  static List<NLatLng> _decodePolyline(String encoded) {
    final points = <NLatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Latitude
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Longitude
      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(NLatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// 다중 지점 경로 조회
  static Future<List<RouteResult>> getMultiPointRoute(
    List<NLatLng> points, {
    RouteType type = RouteType.driving,
  }) async {
    if (points.length < 2) return [];

    final results = <RouteResult>[];

    for (int i = 0; i < points.length - 1; i++) {
      RouteResult? result;

      switch (type) {
        case RouteType.walking:
          result = await getWalkingRoute(points[i], points[i + 1]);
        case RouteType.driving:
          result = await getDrivingRoute(points[i], points[i + 1]);
        case RouteType.transit:
          result = await getTransitRoute(points[i], points[i + 1]);
      }

      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  /// 다중 지점의 전체 경로를 하나로 합침
  static Future<RouteResult?> getCombinedRoute(
    List<NLatLng> points, {
    RouteType type = RouteType.driving,
  }) async {
    final segments = await getMultiPointRoute(points, type: type);
    if (segments.isEmpty) return null;

    // 모든 경로 좌표 합치기
    final combinedPath = <NLatLng>[];
    int totalDistance = 0;
    int totalDuration = 0;

    for (final segment in segments) {
      // 첫 세그먼트가 아니면 시작점 중복 제거
      if (combinedPath.isNotEmpty && segment.path.isNotEmpty) {
        combinedPath.addAll(segment.path.skip(1));
      } else {
        combinedPath.addAll(segment.path);
      }
      totalDistance += segment.summary.distance;
      totalDuration += segment.summary.duration;
    }

    return RouteResult(
      path: combinedPath,
      summary: RouteSummary(
        distance: totalDistance,
        duration: totalDuration,
      ),
    );
  }
}
