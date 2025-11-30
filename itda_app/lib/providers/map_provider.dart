import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/date_course.dart';
import '../services/directions_service.dart';
import '../services/search_api_service.dart';

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
  bool _hasPendingMove = false; // 지도 탭 진입 시 이동 대기 플래그
  final List<MapMarker> _markers = [];

  // 데이트 코스 경로
  List<NLatLng>? _courseRoute;
  List<List<NLatLng>>? _courseSegments; // 구간별 경로
  List<CourseSlot>? _courseSlots;

  // 경로 타입 및 상태
  RouteType _routeType = RouteType.walking;
  bool _isLoadingRoute = false;
  RouteSummary? _routeSummary;

  // 🔹 가장 최근 경로 요청 id (비동기 응답 레이스 방지용)
  int _routeRequestId = 0;

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
  }

  /// ScheduleProvider의 일정들로 마커 생성
  void syncMarkersWithSchedules(List<DateCourse> courses) {
    // 기존 마커 제거 (초기화용 마커 제외)
    _markers.removeWhere((m) => m.id != 'city_hall');

    for (final course in courses) {
      DateTime? courseDate;
      try {
        courseDate = DateTime.parse(course.date);
      } catch (_) {
        // 파싱 실패 시 null
      }
      final dateKey =
          courseDate?.millisecondsSinceEpoch.toString() ?? course.date;

      for (int i = 0; i < course.slots.length; i++) {
        final slot = course.slots[i];

        final lat = slot.latitude;
        final lng = slot.longitude;

        _markers.add(
          MapMarker(
            id: 'course_${dateKey}_slot_$i',
            position: NLatLng(lat, lng),
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
    _hasPendingMove = true; // 이동 대기 플래그 설정
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
    if (_courseSlots == null || _courseSlots!.isEmpty) {
      // 코스 자체가 없으면 초기화
      _courseRoute = null;
      _courseSegments = null;
      _routeSummary = null;
      notifyListeners();
      return;
    }

    if (_courseSlots!.length < 2) {
      // 슬롯이 1개 이하면 직선 경로만 사용 (summary 없음)
      _courseRoute = _courseSlots!
          .map((slot) => NLatLng(slot.latitude, slot.longitude))
          .toList();
      _courseSegments = null;
      _routeSummary = null;
      notifyListeners();
      return;
    }

    // 🔹 이 시점의 타입과 요청 id를 캡처
    final int requestId = ++_routeRequestId;
    final RouteType requestType = _routeType;

    _isLoadingRoute = true;
    notifyListeners();

    try {
      // 슬롯 좌표 리스트 생성
      final points = _courseSlots!
          .map((slot) => NLatLng(slot.latitude, slot.longitude))
          .toList();

      // Directions API 호출 (구간별)
      final segments = await DirectionsService.getMultiPointRoute(
        points,
        type: requestType,
      );

      // 🔹 최신 요청이 아니면 결과 무시
      if (requestId != _routeRequestId || requestType != _routeType) {
        if (kDebugMode) {
          print(
              '⚠️ 오래된 경로 응답 버림 (requestId=$requestId, latest=$_routeRequestId, type=$requestType, current=$_routeType)');
        }
        return;
      }

      if (segments.isNotEmpty) {
        // 구간별 경로 저장
        _courseSegments = segments.map((s) => s.path).toList();

        // 전체 경로 합치기 + 총 거리/시간 합산
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
          print(
              '🗺️ 경로 로드 완료(type=$requestType): ${_routeSummary!.distanceText}, ${_routeSummary!.durationText}');
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
      // 🔹 에러도 오래된 요청이면 무시
      if (requestId != _routeRequestId) {
        if (kDebugMode) {
          print('⚠️ 오래된 경로 요청 에러 무시 (requestId=$requestId): $e');
        }
        return;
      }

      if (kDebugMode) {
        print('❌ 경로 로드 오류: $e');
      }
      // 오류 시 직선 경로 fallback
      _courseRoute = _courseSlots!
          .map((slot) => NLatLng(slot.latitude, slot.longitude))
          .toList();
      _courseSegments = null;
      _routeSummary = null;
    } finally {
      // 🔹 최신 요청에 대해서만 로딩 플래그 내려줌
      if (requestId == _routeRequestId) {
        _isLoadingRoute = false;
        notifyListeners();
      }
    }
  }

  /// 데이트 코스 경로 초기화
  void clearCourseRoute() {
    _courseRoute = null;
    _courseSegments = null;
    _courseSlots = null;
    _routeSummary = null;
    _routeRequestId++; // 🔹 기존 진행 중인 요청들은 모두 "구버전"으로 취급
    _isLoadingRoute = false;
    _markers.removeWhere((m) => m.id.startsWith('course_'));
    notifyListeners();

    if (kDebugMode) {
      print('MapProvider: 코스 경로 초기화');
    }
  }

  // =====================
  // 장소 검색
  // =====================
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  List<dynamic> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  Future<void> searchPlaces(String query) async {
    if (query.isEmpty) return;

    _isSearching = true;
    notifyListeners();

    try {
      // SearchApiService는 나중에 import 추가 필요
      // 여기서는 동적으로 import하거나 상단에 추가해야 함.
      // 일단 메서드 내에서 해결하거나 상단 import를 추가하는 별도 edit 필요.
      // 편의상 이 파일 상단에 import 추가했다고 가정하고 진행.
      final results = await SearchApiService.searchPlaces(query);
      _searchResults = results;
    } catch (e) {
      debugPrint('장소 검색 실패: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /// 검색 결과 선택 시 마커 추가
  void addSearchMarker(Map<String, dynamic> item) {
    final lat = item['latitude'] as double?;
    final lng = item['longitude'] as double?;
    final rawTitle = item['title'] as String?;
    final title = rawTitle?.replaceAll(RegExp(r'<[^>]*>'), '') ?? '검색 결과';

    if (lat == null || lng == null) {
      debugPrint('MapProvider: 좌표 누락 - lat=$lat, lng=$lng, item=$item');
      return;
    }

    // 기존 검색 마커 제거 (id가 'search_'로 시작하는 것들)
    _markers.removeWhere((m) => m.id.startsWith('search_'));

    // 새 마커 추가
    _markers.add(
      MapMarker(
        id: 'search_${item['mapx']}', // unique id
        position: NLatLng(lat, lng),
        caption: title,
      ),
    );
    
    debugPrint('MapProvider: 검색 결과 마커 추가 - $title ($lat, $lng)');

    // 카메라 이동을 위해 타겟 업데이트 (UI에서 참조 가능)
    _cameraTarget = NLatLng(lat, lng);
    _zoom = 16.0; // 검색 결과는 상세하게 보여줌
    _hasPendingMove = true; // 지도 이동 트리거
    
    notifyListeners();
  }
}
