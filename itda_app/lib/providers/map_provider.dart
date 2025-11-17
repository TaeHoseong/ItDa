import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import './schedule_provider.dart';
import '../models/date_course.dart';

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
  List<CourseSlot>? _courseSlots;

  bool get isInitialized => _initialized;
  NLatLng get cameraTarget => _cameraTarget;
  double get zoom => _zoom;
  bool get hasPendingMove => _hasPendingMove;
  List<MapMarker> get markers => List.unmodifiable(_markers);
  List<NLatLng>? get courseRoute => _courseRoute;
  List<CourseSlot>? get courseSlots => _courseSlots;
  bool get hasCourseRoute => _courseRoute != null && _courseRoute!.isNotEmpty;

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
  void syncMarkersWithSchedules(List<Schedule> schedules) {
    // 기존 마커 제거 (초기화용 마커 제외)
    _markers.removeWhere((m) => m.id != 'city_hall');

    // 장소 정보가 있는 일정만 마커 추가
    for (final schedule in schedules) {
      if (schedule.hasPlace) {
        _markers.add(
          MapMarker(
            id: 'schedule_${schedule.date.millisecondsSinceEpoch}_${schedule.time}',
            position: NLatLng(schedule.latitude!, schedule.longitude!),
            caption: schedule.placeName,
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

  /// 데이트 코스 경로 설정
  void setCourseRoute(DateCourse course) {
    _courseRoute = course.slots.map((slot) =>
      NLatLng(slot.latitude, slot.longitude)
    ).toList();
    _courseSlots = course.slots;

    // 코스 슬롯 마커 추가 (기존 마커와 구분)
    _markers.removeWhere((m) => m.id.startsWith('course_'));

    for (int i = 0; i < course.slots.length; i++) {
      final slot = course.slots[i];
      _markers.add(
        MapMarker(
          id: 'course_${i}',
          position: NLatLng(slot.latitude, slot.longitude),
          caption: '${i + 1}. ${slot.placeName}',
        ),
      );
    }

    // 첫 번째 슬롯으로 카메라 이동
    if (_courseRoute!.isNotEmpty) {
      _cameraTarget = _courseRoute!.first;
      _zoom = 13.0;
      _hasPendingMove = true;
    }

    notifyListeners();

    if (kDebugMode) {
      print('MapProvider: 코스 경로 설정 완료 (${_courseRoute!.length}개 지점)');
    }
  }

  /// 데이트 코스 경로 초기화
  void clearCourseRoute() {
    _courseRoute = null;
    _courseSlots = null;
    _markers.removeWhere((m) => m.id.startsWith('course_'));
    notifyListeners();

    if (kDebugMode) {
      print('MapProvider: 코스 경로 초기화');
    }
  }
}
