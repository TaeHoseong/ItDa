import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';

import '../providers/map_provider.dart';
import '../providers/schedule_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _mapController;
  List<String> _currentMarkerIds = [];
  bool _isSyncing = false;
  NLatLng? _lastCameraTarget; // 마지막 카메라 위치 추적
  bool _isProgrammaticMove = false; // 프로그래밍 방식의 이동 여부

  @override
  void initState() {
    super.initState();
    // ScheduleProvider의 변경사항을 listen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scheduleProvider = context.read<ScheduleProvider>();
      scheduleProvider.addListener(_onScheduleChanged);
    });
  }

  @override
  void dispose() {
    final scheduleProvider = context.read<ScheduleProvider>();
    scheduleProvider.removeListener(_onScheduleChanged);
    super.dispose();
  }

  /// ScheduleProvider 변경 시 호출
  void _onScheduleChanged() {
    final mapProvider = context.read<MapProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    _syncMarkersIfNeeded(mapProvider, scheduleProvider);
  }

  /// 마커를 지도에 추가
  Future<void> _addMarkersToMap(
      NaverMapController controller, List<MapMarker> markers) async {
    for (final m in markers) {
      final marker = NMarker(
        id: m.id,
        position: m.position,
        caption:
            m.caption != null ? NOverlayCaption(text: m.caption!) : null,
      );

      // 마커 클릭 이벤트 핸들러
      marker.setOnTapListener((overlay) {
        _onMarkerTap(m);
      });

      await controller.addOverlay(marker);
    }
  }

  /// 마커 클릭 시 호출
  void _onMarkerTap(MapMarker marker) {
    // 마커 클릭 처리 로직
    debugPrint('마커 클릭: ${marker.id}');
  }

  /// 카메라 이동 처리
  void _moveCameraIfNeeded(MapProvider mapProvider) {
    final controller = _mapController;
    if (controller == null) return;

    final newTarget = mapProvider.cameraTarget;

    // 카메라 위치가 변경되었는지 확인
    if (_lastCameraTarget == null ||
        _lastCameraTarget!.latitude != newTarget.latitude ||
        _lastCameraTarget!.longitude != newTarget.longitude) {
      _lastCameraTarget = newTarget;

      // 프로그래밍 방식의 이동임을 표시
      _isProgrammaticMove = true;

      // 실제로 지도 카메라 이동
      final cameraUpdate = NCameraUpdate.fromCameraPosition(
        NCameraPosition(
          target: newTarget,
          zoom: mapProvider.zoom,
        ),
      );
      controller.updateCamera(cameraUpdate);

      debugPrint('🗺️ 카메라 이동: ${newTarget.latitude}, ${newTarget.longitude}');
    }
  }

  /// 일정 변경 시 마커 동기화
  void _syncMarkersIfNeeded(
      MapProvider mapProvider, ScheduleProvider scheduleProvider) {
    final controller = _mapController;
    if (controller == null || _isSyncing) return;

    // Provider의 마커 동기화
    final eventsWithPlace = scheduleProvider.getEventsWithPlace();
    debugPrint('일정 개수 (장소 포함): ${eventsWithPlace.length}');
    for (final event in eventsWithPlace) {
      debugPrint('  - ${event.placeName}: lat=${event.latitude}, lng=${event.longitude}');
    }

    mapProvider.syncMarkersWithSchedules(eventsWithPlace);

    final newMarkerIds = mapProvider.markers.map((m) => m.id).toList();

    // 마커 목록이 변경된 경우에만 지도 업데이트
    if (!_isSameMarkerList(_currentMarkerIds, newMarkerIds)) {
      _isSyncing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // 기존 마커 제거
        await controller.clearOverlays();

        // 새 마커 추가
        await _addMarkersToMap(controller, mapProvider.markers);

        _currentMarkerIds = newMarkerIds;
        _isSyncing = false;
      });
    }
  }

  /// 마커 목록 비교
  bool _isSameMarkerList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final size = MediaQuery.of(context).size;
    final mapProvider = context.read<MapProvider>();

    // MapProvider 카메라 변경 확인 (매 build마다 체크)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveCameraIfNeeded(mapProvider);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // ================= NAVER MAP (배경) =================
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: mapProvider.cameraTarget,
                zoom: mapProvider.zoom,
              ),
            ),
            onMapReady: (controller) async {
              _mapController = controller;

              // Provider 초기화 (딱 1회만 동작)
              mapProvider.ensureInitialized();

              // Provider에 저장된 마커들을 지도에 추가
              await _addMarkersToMap(controller, mapProvider.markers);
              _currentMarkerIds = mapProvider.markers.map((m) => m.id).toList();
            },

            // 📌 flutter_naver_map 공식 방식: 카메라 이벤트는 위젯 콜백으로 받는다.
            onCameraIdle: () {
              final c = _mapController;
              if (c == null) return;

              // 프로그래밍 방식의 이동이면 플래그만 리셋하고 리턴
              if (_isProgrammaticMove) {
                _isProgrammaticMove = false;
                return;
              }

              // 사용자가 직접 이동한 경우만 Provider 상태 업데이트
              final pos = c.nowCameraPosition;
              mapProvider.updateCamera(pos);
            },
          ),

          // ================= 오버레이 UI =================
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: padding.top + 16),

                // -------- 상단 검색바 + 모드 버튼 --------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // 검색바
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '장소, 주소 검색',
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      Color.fromRGBO(60, 60, 67, 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 다크/라이트 전환 아이콘 (추후 Provider에 연결 가능)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.wb_sunny_outlined,
                          color: Colors.black87,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // -------- 상단 아이콘/칩 (즐겨찾기, 현위치, 점수) --------
                const Padding(
                  padding: EdgeInsets.only(left: 24),
                  child: Row(
                    children: [
                      _CircleChip(icon: Icons.star_border),
                      SizedBox(width: 8),
                      _CircleChip(icon: Icons.navigation),
                      SizedBox(width: 8),
                      _ScoreChip(scoreText: '10.1'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= 재사용 위젯들 =================

class _CircleChip extends StatelessWidget {
  final IconData icon;
  const _CircleChip({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(34, 10, 0, 0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 18,
        color: Colors.grey.shade700,
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String scoreText;
  const _ScoreChip({required this.scoreText});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(34, 10, 0, 0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.send_rounded,
            size: 16,
            color: Color.fromRGBO(34, 10, 0, 1),
          ),
          const SizedBox(width: 4),
          Text(
            scoreText,
            style: const TextStyle(
              fontSize: 15,
              color: Color.fromRGBO(34, 10, 0, 1),
            ),
          ),
        ],
      ),
    );
  }
}
