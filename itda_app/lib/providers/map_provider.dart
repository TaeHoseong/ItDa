import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/date_course.dart';
import '../services/directions_service.dart';

class MapMarker {
  final String id;
  final NLatLng position;
  final String? caption;

  MapMarker({
    required this.id,
    required this.position,
    this.caption,
  });
}

class MapProvider extends ChangeNotifier {
  // 기본 카메라 위치 (서울시청)
  NLatLng _cameraTarget = const NLatLng(37.5666, 126.9790);
  double _zoom = 14.0;

  bool _initialized = false;
  bool _hasPendingMove = false;  // 지도 탭 진입 시 이동 대기 플래그
  final List<MapMarker> _markers = [];

  // 데이트 코스 경로
  List<NLatLng>? _courseRoute;
  List<List<NLatLng>>? _courseSegments;  // 구간별 경로
  List<CourseSlot>? _courseSlots;

  // 경로 타입 및 상태
  RouteType _routeType = RouteType.walking;
  bool _isLoadingRoute = false;
  RouteSummary? _routeSummary;

  bool get isInitialized => _initialized;
  NLatLng get cameraTarget => _cameraTarget;
  double get zoom => _zoom;
  bool get hasPendingMove => _hasPendingMove;
  List<MapMarker> get markers => List.unmodifiable(_markers);
  List<NLatLng>? get courseRoute => _courseRoute;
  List<List<NLatLng>>? get courseSegments => _courseSegments;
  List<CourseSlot>? get courseSlots => _courseSlots;
  bool get hasCourseRoute => _courseRoute != null && _courseRoute!.isNotEmpty;

  // 경로 관련 getter
  RouteType get routeType => _routeType;
  bool get isLoadingRoute => _isLoadingRoute;
  RouteSummary? get routeSummary => _routeSummary;

  /// 최초 1회 마커/상태 세팅
  void ensureInitialized() {
    if (_initialized) return;

    _markers.add(
      MapMarker(
        id: 'city_hall',
        position: _cameraTarget,
        caption: '서울시청',
      ),
    );

    _initialized = true;
    if (kDebugMode) {
      print('MapProvider: 초기화 완료 (서울시청 마커 추가)');
    }
  }

  /// 카메라 위치 저장 (재진입 시 복원 용도)
  void updateCamera(NCameraPosition position) {
    _cameraTarget = position.target;
    _zoom = position.zoom;
    // 여기서는 굳이 notifyListeners() 안해도 됨
    // (다음 빌드에서 initialCameraPosition에만 사용)
  }

  /// ScheduleProvider의 일정들로 마커 생성
  void syncMarkersWithSchedules(List<DateCourse> courses) {
    // 기존 마커 제거 (초기화용 마커 제외)
    _markers.removeWhere((m) => m.id != 'city_hall');

    for (final course in courses) {
      // DateCourse.date 는 String이므로, 가능하면 DateTime으로 파싱
      DateTime? courseDate;
      try {
        courseDate = DateTime.parse(course.date);
      } catch (_) {
        // 파싱 실패하면 그냥 null로 두고, 아래에서 문자열 사용
      }
      final dateKey = courseDate?.millisecondsSinceEpoch.toString() ?? course.date;

      // 코스 안의 슬롯들 중 위치가 있는 슬롯만 마커로 추가
      for (int i = 0; i < course.slots.length; i++) {
        final slot = course.slots[i];

        // lat/lng는 DateCourse가 아니라 CourseSlot에 있음
        final lat = slot.latitude;
        final lng = slot.longitude;

        // 혹시 0,0 같은 더미 좌표를 걸러내고 싶으면 여기서 체크
        // if (lat == 0 && lng == 0) continue;

        _markers.add(
          MapMarker(
            id: 'course_${dateKey}_slot_$i',
            position: NLatLng(lat, lng),
            // 이모지 + 장소 이름 같이 보여주면 가독성 좋음
            caption: '${slot.emoji} ${slot.placeName}',
          ),
        );
      }
    }

    notifyListeners();

    if (kDebugMode) {
      print('MapProvider: 마커 동기화 완료 (${_markers.length}개 마커)');
    }
  }


  /// 특정 장소로 카메라 이동 (지도 탭 진입 시 실제 이동)
  void moveToPlace(double latitude, double longitude, {double zoom = 15.0}) {
    _cameraTarget = NLatLng(latitude, longitude);
    _zoom = zoom;
    _hasPendingMove = true;  // 이동 대기 플래그 설정
    notifyListeners();

    if (kDebugMode) {
      print('MapProvider: 카메라 이동 예약 ($latitude, $longitude, zoom: $zoom)');
    }
  }

  /// 대기 중인 카메라 이동 완료 처리
  void clearPendingMove() {
    _hasPendingMove = false;
    if (kDebugMode) {
      print('MapProvider: 카메라 이동 완료, 플래그 초기화');
    }
  }

  /// 경로 타입 변경
  void setRouteType(RouteType type) {
    if (_routeType == type) return;
    _routeType = type;
    notifyListeners();

    // 코스가 있으면 새 경로 타입으로 다시 로드
    if (_courseSlots != null && _courseSlots!.isNotEmpty) {
      _loadRouteForCurrentCourse();
    }
  }

  /// 데이트 코스 경로 설정
  Future<void> setCourseRoute(DateCourse course) async {
    _courseSlots = course.slots;

    // 코스 슬롯 마커 추가 (기존 마커와 구분)
    _markers.removeWhere((m) => m.id.startsWith('course_'));

    for (int i = 0; i < course.slots.length; i++) {
      final slot = course.slots[i];
      _markers.add(
        MapMarker(
          id: 'course_$i',
          position: NLatLng(slot.latitude, slot.longitude),
          caption: '${i + 1}. ${slot.placeName}',
        ),
      );
    }

    // 첫 번째 슬롯으로 카메라 이동
    final firstSlot = course.slots.first;
    _cameraTarget = NLatLng(firstSlot.latitude, firstSlot.longitude);
    _zoom = 13.0;
    _hasPendingMove = true;

    notifyListeners();

    // 실제 경로 로드
    await _loadRouteForCurrentCourse();

    if (kDebugMode) {
      print('MapProvider: 코스 경로 설정 완료 (${course.slots.length}개 지점)');
    }
  }

  /// 현재 코스에 대한 경로 로드
  Future<void> _loadRouteForCurrentCourse() async {
    if (_courseSlots == null || _courseSlots!.length < 2) {
      // 슬롯이 1개 이하면 직선 경로
      if (_courseSlots != null && _courseSlots!.isNotEmpty) {
        _courseRoute = _courseSlots!.map((slot) =>
          NLatLng(slot.latitude, slot.longitude)
        ).toList();
        _courseSegments = null;
        _routeSummary = null;
      }
      notifyListeners();
      return;
    }

    _isLoadingRoute = true;
    notifyListeners();

    try {
      // 슬롯 좌표 리스트 생성
      final points = _courseSlots!.map((slot) =>
        NLatLng(slot.latitude, slot.longitude)
      ).toList();

      // Directions API 호출 (구간별)
      final segments = await DirectionsService.getMultiPointRoute(
        points,
        type: _routeType,
      );

      if (segments.isNotEmpty) {
        // 구간별 경로 저장
        _courseSegments = segments.map((s) => s.path).toList();

        // 전체 경로 합치기 (기존 호환성)
        final combinedPath = <NLatLng>[];
        int totalDistance = 0;
        int totalDuration = 0;

        for (final segment in segments) {
          if (combinedPath.isNotEmpty && segment.path.isNotEmpty) {
            combinedPath.addAll(segment.path.skip(1));
          } else {
            combinedPath.addAll(segment.path);
          }
          totalDistance += segment.summary.distance;
          totalDuration += segment.summary.duration;
        }

        _courseRoute = combinedPath;
        _routeSummary = RouteSummary(
          distance: totalDistance,
          duration: totalDuration,
        );

        if (kDebugMode) {
          print('🗺️ 경로 로드 완료: ${_routeSummary!.distanceText}, ${_routeSummary!.durationText}');
        }
      } else {
        // API 실패 시 직선 경로 fallback
        _courseRoute = points;
        _courseSegments = null;
        _routeSummary = null;
        if (kDebugMode) {
          print('⚠️ 경로 API 실패, 직선 경로 사용');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 경로 로드 오류: $e');
      }
      // 오류 시 직선 경로
      _courseRoute = _courseSlots!.map((slot) =>
        NLatLng(slot.latitude, slot.longitude)
      ).toList();
      _courseSegments = null;
      _routeSummary = null;
    }

    _isLoadingRoute = false;
    notifyListeners();
  }

  /// 데이트 코스 경로 초기화
  void clearCourseRoute() {
    _courseRoute = null;
    _courseSegments = null;
    _courseSlots = null;
    _routeSummary = null;
    _markers.removeWhere((m) => m.id.startsWith('course_'));
    notifyListeners();

    if (kDebugMode) {
      print('MapProvider: 코스 경로 초기화');
    }
  }
}
