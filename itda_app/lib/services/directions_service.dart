import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

import '../secrets.dart';

/// 경로 타입
enum RouteType {
  driving,  // 자동차
  walking,  // 도보
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
  final bool isTransitFallback; // 대중교통 미지원으로 도보 fallback 여부

  RouteResult({
    required this.path,
    required this.summary,
    this.isTransitFallback = false,
  });
}

/// Directions API 서비스 (Tmap API)
class DirectionsService {
  // Tmap API Base URLs
  static const String _tmapBaseUrl = 'https://apis.openapi.sk.com';

  /// 자동차 경로 조회 (Tmap API)
  static Future<RouteResult?> getDrivingRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    final url = Uri.parse('$_tmapBaseUrl/tmap/routes?version=1&format=json');

    try {
      if (kDebugMode) {
        print('🚗 Tmap 자동차 경로 API 요청:');
        print('   출발: ${start.latitude}, ${start.longitude}');
        print('   도착: ${end.latitude}, ${end.longitude}');
      }

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'appKey': TMAP_APP_KEY,
        },
        body: jsonEncode({
          'startX': start.longitude.toString(),
          'startY': start.latitude.toString(),
          'endX': end.longitude.toString(),
          'endY': end.latitude.toString(),
          'reqCoordType': 'WGS84GEO',
          'resCoordType': 'WGS84GEO',
          'searchOption': '0', // 추천 경로
        }),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Tmap 자동차 API 오류: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }

      return _parseTmapRouteResponse(response.body);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Tmap 자동차 API 예외: $e');
      }
      return null;
    }
  }

  /// 도보 경로 조회 (Tmap Pedestrian API)
  static Future<RouteResult?> getWalkingRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    final url =
        Uri.parse('$_tmapBaseUrl/tmap/routes/pedestrian?version=1&format=json');

    try {
      if (kDebugMode) {
        print('🚶 Tmap 도보 경로 API 요청:');
        print('   출발: ${start.latitude}, ${start.longitude}');
        print('   도착: ${end.latitude}, ${end.longitude}');
      }

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'appKey': TMAP_APP_KEY,
        },
        body: jsonEncode({
          'startX': start.longitude.toString(),
          'startY': start.latitude.toString(),
          'endX': end.longitude.toString(),
          'endY': end.latitude.toString(),
          'startName': '출발지',
          'endName': '도착지',
          'reqCoordType': 'WGS84GEO',
          'resCoordType': 'WGS84GEO',
          'searchOption': '0', // 추천 경로
        }),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Tmap 도보 API 오류: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }

      return _parseTmapRouteResponse(response.body);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Tmap 도보 API 예외: $e');
      }
      return null;
    }
  }

  /// 대중교통 경로 조회 (Tmap Transit API)
  /// 대중교통 경로가 없으면 도보 경로로 fallback
  static Future<RouteResult?> getTransitRoute(
    NLatLng start,
    NLatLng end,
  ) async {
    final url = Uri.parse('$_tmapBaseUrl/transit/routes');

    try {
      if (kDebugMode) {
        print('🚌 Tmap 대중교통 경로 API 요청:');
        print('   출발: ${start.latitude}, ${start.longitude}');
        print('   도착: ${end.latitude}, ${end.longitude}');
      }

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'appKey': TMAP_APP_KEY,
        },
        body: jsonEncode({
          'startX': start.longitude.toString(),
          'startY': start.latitude.toString(),
          'endX': end.longitude.toString(),
          'endY': end.latitude.toString(),
          'count': 1,
          'lang': 0,
          'format': 'json',
        }),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Tmap 대중교통 API 오류: ${response.statusCode}');
          print('⚠️ 도보 경로로 fallback');
        }
        return _getWalkingRouteAsFallback(start, end);
      }

      final result = _parseTmapTransitResponse(response.body);

      // 대중교통 경로가 없으면 도보 경로로 fallback
      if (result == null) {
        if (kDebugMode) {
          print('⚠️ 대중교통 경로 없음, 도보 경로로 fallback');
        }
        return _getWalkingRouteAsFallback(start, end);
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Tmap 대중교통 API 예외: $e');
        print('⚠️ 도보 경로로 fallback');
      }
      return _getWalkingRouteAsFallback(start, end);
    }
  }

  /// 대중교통 fallback용 도보 경로 (isTransitFallback = true)
  static Future<RouteResult?> _getWalkingRouteAsFallback(
    NLatLng start,
    NLatLng end,
  ) async {
    final result = await getWalkingRoute(start, end);
    if (result == null) return null;

    return RouteResult(
      path: result.path,
      summary: result.summary,
      isTransitFallback: true,
    );
  }

  /// Tmap 자동차/도보 경로 응답 파싱 (GeoJSON 형식)
  static RouteResult? _parseTmapRouteResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      final features = data['features'] as List<dynamic>?;

      if (features == null || features.isEmpty) {
        if (kDebugMode) {
          print('❌ Tmap 경로 응답에 features가 없음');
        }
        return null;
      }

      // 전체 거리/시간 추출 (첫 번째 Point feature의 properties에 포함)
      int totalDistance = 0;
      int totalTime = 0;
      final path = <NLatLng>[];

      for (final feature in features) {
        final geometry = feature['geometry'];
        final properties = feature['properties'];

        // 첫 번째 Point (출발지)에서 totalDistance, totalTime 추출
        if (geometry['type'] == 'Point' && properties['totalDistance'] != null) {
          totalDistance = properties['totalDistance'] as int;
          totalTime = properties['totalTime'] as int;
        }

        // LineString에서 경로 좌표 추출
        if (geometry['type'] == 'LineString') {
          final coordinates = geometry['coordinates'] as List<dynamic>;
          for (final coord in coordinates) {
            // [lng, lat] 형식
            final lng = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            path.add(NLatLng(lat, lng));
          }
        }
      }

      if (path.isEmpty) {
        if (kDebugMode) {
          print('❌ Tmap 경로에서 좌표를 추출하지 못함');
        }
        return null;
      }

      if (kDebugMode) {
        print('✅ Tmap 경로 로드 성공: ${path.length}개 좌표, ${totalDistance}m, ${totalTime}초');
      }

      return RouteResult(
        path: path,
        summary: RouteSummary(
          distance: totalDistance,
          duration: totalTime * 1000, // 초 → 밀리초
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Tmap 경로 파싱 오류: $e');
      }
      return null;
    }
  }

  /// Tmap 대중교통 경로 응답 파싱
  static RouteResult? _parseTmapTransitResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      final metaData = data['metaData'];

      if (metaData == null) {
        if (kDebugMode) {
          print('❌ Tmap 대중교통 응답에 metaData가 없음');
        }
        return null;
      }

      final plan = metaData['plan'];
      if (plan == null) {
        if (kDebugMode) {
          print('❌ Tmap 대중교통 응답에 plan이 없음');
        }
        return null;
      }

      final itineraries = plan['itineraries'] as List<dynamic>?;
      if (itineraries == null || itineraries.isEmpty) {
        if (kDebugMode) {
          print('❌ Tmap 대중교통 경로가 없음');
        }
        return null;
      }

      // 첫 번째 경로 사용
      final itinerary = itineraries[0];
      final totalTime = itinerary['totalTime'] as int; // 초 단위
      final totalDistance = itinerary['totalDistance'] as int? ?? 0; // 미터

      // legs에서 경로 좌표 추출
      final legs = itinerary['legs'] as List<dynamic>?;
      final path = <NLatLng>[];

      if (legs != null) {
        for (final leg in legs) {
          // 각 leg의 시작점 추가
          final start = leg['start'];
          if (start != null) {
            final lat = (start['lat'] as num).toDouble();
            final lon = (start['lon'] as num).toDouble();
            path.add(NLatLng(lat, lon));
          }

          // passShape가 있으면 상세 경로 추출
          final passShape = leg['passShape'];
          if (passShape != null) {
            final lineString = passShape['linestring'] as String?;
            if (lineString != null) {
              // "lon1 lat1, lon2 lat2, ..." 형식 파싱
              final points = lineString.split(',');
              for (final point in points) {
                final coords = point.trim().split(' ');
                if (coords.length >= 2) {
                  final lon = double.tryParse(coords[0]);
                  final lat = double.tryParse(coords[1]);
                  if (lon != null && lat != null) {
                    path.add(NLatLng(lat, lon));
                  }
                }
              }
            }
          }

          // 각 leg의 끝점 추가
          final end = leg['end'];
          if (end != null) {
            final lat = (end['lat'] as num).toDouble();
            final lon = (end['lon'] as num).toDouble();
            path.add(NLatLng(lat, lon));
          }
        }
      }

      // 경로가 없으면 출발/도착만이라도 추가
      if (path.isEmpty) {
        final startLat = (plan['startLat'] as num?)?.toDouble();
        final startLon = (plan['startLon'] as num?)?.toDouble();
        final endLat = (plan['endLat'] as num?)?.toDouble();
        final endLon = (plan['endLon'] as num?)?.toDouble();

        if (startLat != null && startLon != null) {
          path.add(NLatLng(startLat, startLon));
        }
        if (endLat != null && endLon != null) {
          path.add(NLatLng(endLat, endLon));
        }
      }

      if (path.isEmpty) {
        if (kDebugMode) {
          print('❌ Tmap 대중교통 경로에서 좌표를 추출하지 못함');
        }
        return null;
      }

      if (kDebugMode) {
        print('✅ Tmap 대중교통 경로 로드 성공: ${path.length}개 좌표, ${totalDistance}m, ${totalTime}초');
      }

      return RouteResult(
        path: path,
        summary: RouteSummary(
          distance: totalDistance,
          duration: totalTime * 1000, // 초 → 밀리초
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Tmap 대중교통 파싱 오류: $e');
      }
      return null;
    }
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
