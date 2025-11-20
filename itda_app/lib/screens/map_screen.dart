import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';

import '../providers/map_provider.dart';
import '../providers/navigation_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _mapController;
  List<String> _currentMarkerIds = [];
  bool _isSyncing = false;
  bool _isProgrammaticMove = false;
  NPolylineOverlay? _coursePolyline;

  // ========= 마커 관련 =========

  /// 마커를 지도에 추가
  Future<void> _addMarkersToMap(
    NaverMapController controller,
    List<MapMarker> markers,
  ) async {
    for (final m in markers) {
      final marker = NMarker(
        id: m.id,
        position: m.position,
        caption: m.caption != null ? NOverlayCaption(text: m.caption!) : null,
      );

      // 마커 클릭 이벤트
      marker.setOnTapListener((overlay) {
        _onMarkerTap(m);
      });

      await controller.addOverlay(marker);
    }
  }

  /// 마커 클릭 시 호출
  void _onMarkerTap(MapMarker marker) {
    debugPrint('마커 클릭: ${marker.id}');
    // TODO: 필요하면 여기서 bottom sheet 띄우기 등 처리
  }

  // ========= 코스 폴리라인 =========

  /// 코스 경로 폴리라인 추가
  Future<void> _addCoursePolyline(
    NaverMapController controller,
    List<NLatLng> route,
  ) async {
    try {
      final polyline = NPolylineOverlay(
        id: 'course_route',
        coords: route,
        color: const Color(0xFFFF6B9D),
        width: 5,
      );

      await controller.addOverlay(polyline);
      _coursePolyline = polyline;
      debugPrint('🗺️ 코스 경로 폴리라인 추가 완료 (${route.length}개 지점)');
    } catch (e) {
      debugPrint('❌ 폴리라인 추가 오류: $e');
    }
  }

  /// 코스 경로 폴리라인 제거
  Future<void> _removeCoursePolyline(NaverMapController controller) async {
    if (_coursePolyline != null) {
      await controller.deleteOverlay(_coursePolyline!.info);
      _coursePolyline = null;
      debugPrint('🗺️ 코스 경로 폴리라인 제거 완료');
    }
  }

  // ========= 카메라 이동 =========

  void _moveCameraToTarget(MapProvider mapProvider) {
    final controller = _mapController;
    if (controller == null) return;

    _isProgrammaticMove = true;

    final cameraUpdate = NCameraUpdate.fromCameraPosition(
      NCameraPosition(
        target: mapProvider.cameraTarget,
        zoom: mapProvider.zoom,
      ),
    );
    controller.updateCamera(cameraUpdate);

    mapProvider.clearPendingMove();
    debugPrint('🗺️ 지도 탭 진입 시 카메라 이동 완료');
  }

  // ========= 마커 리스트 비교 =========

  bool _isSameMarkerList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ========= build =========

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final mapProvider = context.watch<MapProvider>();
    final navigationProvider = context.watch<NavigationProvider>();

    // 🔁 지도 탭에 있을 때만 동기화/카메라 이동
    if (navigationProvider.currentIndex == 1 && _mapController != null) {
      // 1) 카메라 이동 예약 처리
      if (mapProvider.hasPendingMove) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveCameraToTarget(mapProvider);
        });
      }

      // 2) 선택된 코스 상태에 맞춰 마커/폴리라인 동기화
      final newMarkerIds = mapProvider.markers.map((m) => m.id).toList();

      final shouldRedrawOverlays =
          !_isSameMarkerList(_currentMarkerIds, newMarkerIds) ||
          (mapProvider.hasCourseRoute && _coursePolyline == null) ||
          (!mapProvider.hasCourseRoute && _coursePolyline != null);

      if (shouldRedrawOverlays && !_isSyncing) {
        _isSyncing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final controller = _mapController;
          if (controller == null) {
            _isSyncing = false;
            return;
          }

          // 기존 오버레이 모두 제거
          await controller.clearOverlays();
          _coursePolyline = null;

          // ✅ MapProvider.markers만 다시 그림
          if (mapProvider.markers.isNotEmpty) {
            await _addMarkersToMap(controller, mapProvider.markers);
          }

          // ✅ 선택된 코스가 있을 때만 폴리라인 그림
          if (mapProvider.hasCourseRoute && mapProvider.courseRoute != null) {
            await _addCoursePolyline(controller, mapProvider.courseRoute!);
          }

          _currentMarkerIds = newMarkerIds;
          _isSyncing = false;
        });
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // ================= NAVER MAP =================
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: mapProvider.cameraTarget,
                zoom: mapProvider.zoom,
              ),
            ),
            onMapReady: (controller) async {
              _mapController = controller;

              // Provider 초기화 (서울시청 마커 등)
              mapProvider.ensureInitialized();

              // 초기 진입 시 상태대로 마커/폴리라인 그리기
              if (mapProvider.markers.isNotEmpty) {
                await _addMarkersToMap(controller, mapProvider.markers);
                _currentMarkerIds =
                    mapProvider.markers.map((m) => m.id).toList();
              }

              if (mapProvider.hasCourseRoute &&
                  mapProvider.courseRoute != null) {
                await _addCoursePolyline(controller, mapProvider.courseRoute!);
              }
            },
            onCameraIdle: () {
              final c = _mapController;
              if (c == null) return;

              if (_isProgrammaticMove) {
                _isProgrammaticMove = false;
                return;
              }

              final pos = c.nowCameraPosition;
              mapProvider.updateCamera(pos);
            },
          ),

          // ================= 상단 UI 오버레이 =================
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: padding.top + 16),

                // -------- 검색바 + 모드 버튼 --------
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
                                  color: Color.fromRGBO(60, 60, 67, 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 라이트/다크 토글 아이콘 (현재는 모양만)
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

                // -------- 상단 아이콘/칩 + X 버튼 --------
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24),
                  child: Row(
                    children: [
                      const _CircleChip(icon: Icons.star_border),
                      const SizedBox(width: 8),
                      const _CircleChip(icon: Icons.navigation),
                      const SizedBox(width: 8),
                      const _ScoreChip(scoreText: '10.1'),
                      const Spacer(),
                      // ✅ 코스가 있을 때만 X 버튼 노출
                      if (mapProvider.hasCourseRoute)
                        _CircleChip(
                          icon: Icons.close,
                          onTap: () {
                            // 코스 숨기기
                            mapProvider.clearCourseRoute();
                            // 폴리라인은 mapProvider 변경 → MapScreen에서 싱크하면서 지움
                          },
                        ),
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
  final VoidCallback? onTap;

  const _CircleChip({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
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

    if (onTap == null) return child;

    return GestureDetector(
      onTap: onTap,
      child: child,
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
