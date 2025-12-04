import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../services/directions_service.dart' show RouteSummary;

/// 턴바이턴 안내 단계
class NavigationStep {
  final int index;
  final String description;      // "롯데마트 방면으로 좌회전"
  final int turnType;            // 12 (좌회전)
  final String turnTypeIcon;     // "turn_left"
  final int distanceMeters;      // 구간 거리 (미터)
  final int durationSeconds;     // 구간 시간 (초)
  final NLatLng location;        // 안내 지점 좌표
  final List<NLatLng>? polyline; // 이 구간의 상세 경로

  NavigationStep({
    required this.index,
    required this.description,
    required this.turnType,
    required this.turnTypeIcon,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
    this.polyline,
  });

  /// turnType 코드를 아이콘 이름으로 변환
  static String getTurnTypeIcon(int turnType) {
    switch (turnType) {
      case 11:
        return 'straight';
      case 12:
        return 'turn_left';
      case 13:
        return 'turn_right';
      case 14:
        return 'u_turn_left';
      case 16: // 8시 방향
      case 17: // 10시 방향
        return 'turn_slight_left';
      case 18: // 2시 방향
      case 19: // 4시 방향
        return 'turn_slight_right';
      case 125: // 육교
      case 126: // 지하보도
      case 127: // 계단
        return 'stairs';
      case 200: // 출발지
        return 'flag';
      case 201: // 도착지
        return 'location_on';
      case 211: // 횡단보도
        return 'directions_walk';
      case 212: // 좌측 횡단보도
        return 'directions_walk';
      case 213: // 우측 횡단보도
        return 'directions_walk';
      case 214: // 8시 횡단보도
        return 'directions_walk';
      case 215: // 10시 횡단보도
        return 'directions_walk';
      case 216: // 2시 횡단보도
        return 'directions_walk';
      case 217: // 4시 횡단보도
        return 'directions_walk';
      default:
        return 'straight';
    }
  }

  /// turnType 코드를 한국어 설명으로 변환
  static String getTurnTypeText(int turnType) {
    switch (turnType) {
      case 11:
        return '직진';
      case 12:
        return '좌회전';
      case 13:
        return '우회전';
      case 14:
        return '유턴';
      case 16:
        return '8시 방향';
      case 17:
        return '10시 방향';
      case 18:
        return '2시 방향';
      case 19:
        return '4시 방향';
      case 125:
        return '육교';
      case 126:
        return '지하보도';
      case 127:
        return '계단';
      case 200:
        return '출발';
      case 201:
        return '도착';
      case 211:
        return '횡단보도';
      case 212:
        return '좌측 횡단보도';
      case 213:
        return '우측 횡단보도';
      case 214:
        return '8시 횡단보도';
      case 215:
        return '10시 횡단보도';
      case 216:
        return '2시 횡단보도';
      case 217:
        return '4시 횡단보도';
      default:
        return '이동';
    }
  }
}

/// 상세 경로 결과 (턴바이턴 안내 포함)
class DetailedRouteResult {
  final List<NLatLng> path;
  final RouteSummary summary;
  final List<NavigationStep> steps;
  final NLatLng destination;

  DetailedRouteResult({
    required this.path,
    required this.summary,
    required this.steps,
    required this.destination,
  });
}
