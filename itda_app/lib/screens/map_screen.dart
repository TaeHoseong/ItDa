import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';

import '../providers/map_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/directions_service.dart';

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
  List<NPolylineOverlay> _coursePolylines = [];  // 구간별 폴리라인
  int _currentRouteHash = 0;  // 경로 변경 감지용

  // 구간별 색상 (핑크 계열 그라데이션)
  static const List<Color> _segmentColors = [
    Color(0xFFFF6B9D),  // 핑크
    Color(0xFFE91E63),  // 진한 핑크
    Color(0xFFFF4081),  // 밝은 핑크
    Color(0xFFF50057),  // 레드 핑크
    Color(0xFFFF80AB),  // 연한 핑크
  ];

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

  /// 구간별 코스 경로 폴리라인 추가
  Future<void> _addCoursePolylines(
    NaverMapController controller,
    List<List<NLatLng>>? segments,
    List<NLatLng>? fallbackRoute,
  ) async {
    try {
      _coursePolylines.clear();

      if (segments != null && segments.isNotEmpty) {
        // 구간별로 다른 색상의 폴리라인 추가
        for (int i = 0; i < segments.length; i++) {
          final segment = segments[i];
          if (segment.isEmpty) continue;

          final color = _segmentColors[i % _segmentColors.length];
          final polyline = NPolylineOverlay(
            id: 'course_segment_$i',
            coords: segment,
            color: color,
            width: 5,
          );

          await controller.addOverlay(polyline);
          _coursePolylines.add(polyline);
        }
        debugPrint('🗺️ 구간별 폴리라인 추가 완료 (${segments.length}개 구간)');
      } else if (fallbackRoute != null && fallbackRoute.isNotEmpty) {
        // fallback: 단일 폴리라인
        final polyline = NPolylineOverlay(
          id: 'course_route',
          coords: fallbackRoute,
          color: const Color(0xFFFF6B9D),
          width: 5,
        );

        await controller.addOverlay(polyline);
        _coursePolylines.add(polyline);
        debugPrint('🗺️ 단일 폴리라인 추가 완료 (${fallbackRoute.length}개 지점)');
      }
    } catch (e) {
      debugPrint('❌ 폴리라인 추가 오류: $e');
    }
  }

  /// 코스 경로 폴리라인 제거
  Future<void> _removeCoursePolylines(NaverMapController controller) async {
    for (final polyline in _coursePolylines) {
      await controller.deleteOverlay(polyline.info);
    }
    _coursePolylines.clear();
    debugPrint('🗺️ 코스 경로 폴리라인 제거 완료');
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

      // 경로 좌표 변경 감지 (경로 타입 변경 시 폴리라인 다시 그리기)
      // 경로 길이 + 첫/마지막 좌표로 해시 계산
      final route = mapProvider.courseRoute;
      final newRouteHash = route == null || route.isEmpty
          ? 0
          : route.length.hashCode ^
            route.first.latitude.hashCode ^
            route.last.longitude.hashCode;

      final shouldRedrawOverlays =
          !_isSameMarkerList(_currentMarkerIds, newMarkerIds) ||
          (mapProvider.hasCourseRoute && _coursePolylines.isEmpty) ||
          (!mapProvider.hasCourseRoute && _coursePolylines.isNotEmpty) ||
          (_currentRouteHash != newRouteHash);  // 경로 변경 감지

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
          _coursePolylines.clear();

          // ✅ MapProvider.markers만 다시 그림
          if (mapProvider.markers.isNotEmpty) {
            await _addMarkersToMap(controller, mapProvider.markers);
          }

          // ✅ 선택된 코스가 있을 때만 폴리라인 그림 (구간별)
          if (mapProvider.hasCourseRoute) {
            await _addCoursePolylines(
              controller,
              mapProvider.courseSegments,
              mapProvider.courseRoute,
            );
          }

          _currentMarkerIds = newMarkerIds;
          _currentRouteHash = newRouteHash;
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

              if (mapProvider.hasCourseRoute) {
                await _addCoursePolylines(
                  controller,
                  mapProvider.courseSegments,
                  mapProvider.courseRoute,
                );
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

                // -------- 코스가 있을 때: 경로 타입 선택 + 정보 --------
                if (mapProvider.hasCourseRoute) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 경로 타입 토글
                          _RouteTypeButton(
                            icon: Icons.directions_walk,
                            label: '도보',
                            isSelected: mapProvider.routeType == RouteType.walking,
                            onTap: () => mapProvider.setRouteType(RouteType.walking),
                          ),
                          const SizedBox(width: 6),
                          _RouteTypeButton(
                            icon: Icons.directions_car,
                            label: '자동차',
                            isSelected: mapProvider.routeType == RouteType.driving,
                            onTap: () => mapProvider.setRouteType(RouteType.driving),
                          ),
                          const SizedBox(width: 6),
                          _RouteTypeButton(
                            icon: Icons.directions_transit,
                            label: '대중교통',
                            isSelected: mapProvider.routeType == RouteType.transit,
                            onTap: () => mapProvider.setRouteType(RouteType.transit),
                          ),
                          const Spacer(),
                          // 로딩 또는 경로 정보
                          if (mapProvider.isLoadingRoute)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF6B9D),
                              ),
                            )
                          else if (mapProvider.routeSummary != null) ...[
                            Icon(
                              Icons.route,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              mapProvider.routeSummary!.distanceText,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              mapProvider.routeSummary!.durationText,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          // X 버튼
                          GestureDetector(
                            onTap: () => mapProvider.clearCourseRoute(),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // -------- 기본 상단 아이콘/칩 --------
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24),
                    child: Row(
                      children: [
                        const _CircleChip(icon: Icons.star_border),
                        const SizedBox(width: 8),
                        const _CircleChip(icon: Icons.navigation),
                        const SizedBox(width: 8),
                        const _ScoreChip(scoreText: '10.1'),
                      ],
                    ),
                  ),
                ],
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

class _RouteTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteTypeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B9D) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
