import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';

import '../providers/map_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/course_provider.dart';
import '../services/directions_service.dart'; // 유지

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _BottomTab { place, route }

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _mapController;
  List<String> _currentMarkerIds = [];
  bool _isSyncing = false;
  bool _isProgrammaticMove = false;
  List<NPolylineOverlay> _coursePolylines = [];
  int _currentRouteHash = 0;

  _BottomTab _currentTab = _BottomTab.place;

  // 🔹 경로 타입별로 한 번 계산된 소요 시간/거리 캐시
  final Map<RouteType, String> _cachedDuration = {};
  final Map<RouteType, String> _cachedDistance = {};

  // 🔹 MapProvider 상태 변화 감지용 (로딩 상태 트래킹)
  bool _prevIsLoadingRoute = false;
  RouteSummary? _prevRouteSummary;

  static const List<Color> _segmentColors = [
    Color(0xFFFF6B9D),
    Color(0xFFE91E63),
    Color(0xFFFF4081),
    Color(0xFFF50057),
    Color(0xFFFF80AB),
  ];

  @override
  void initState() {
    super.initState();
    // MapProvider 리스너 등록
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapProvider = context.read<MapProvider>();
      mapProvider.addListener(_onMapProviderChanged);
      _prevIsLoadingRoute = mapProvider.isLoadingRoute;
      _prevRouteSummary = mapProvider.routeSummary;
    });
  }

  @override
  void dispose() {
    // 리스너 제거
    try {
      context.read<MapProvider>().removeListener(_onMapProviderChanged);
    } catch (_) {}
    super.dispose();
  }

  /// 🔹 MapProvider 변경 시 호출
  /// - "경로 로딩이 끝난 시점"에만 캐시를 갱신
  void _onMapProviderChanged() {
    if (!mounted) return;
    final mapProvider = context.read<MapProvider>();

    final bool isLoading = mapProvider.isLoadingRoute;
    final RouteSummary? summary = mapProvider.routeSummary;
    final RouteType type = mapProvider.routeType;

    // 이전에는 로딩 중이었는데, 지금은 로딩이 끝났고, summary가 새로 생겼을 때만 캐시 갱신
    final bool loadingJustFinished =
        _prevIsLoadingRoute && !isLoading && summary != null;

    final bool summaryChanged = summary != null &&
        (_prevRouteSummary == null ||
            summary.distance != _prevRouteSummary!.distance ||
            summary.duration != _prevRouteSummary!.duration);

    if (loadingJustFinished && summaryChanged) {
      setState(() {
        _cachedDuration[type] = summary.durationText;
        _cachedDistance[type] = summary.distanceText;
      });
    }

    _prevIsLoadingRoute = isLoading;
    _prevRouteSummary = summary;
  }

  // ================= 마커 및 폴리라인 함수 =================

  Future<void> _addMarkersToMap(
      NaverMapController controller, List<MapMarker> markers) async {
    for (final m in markers) {
      final marker = NMarker(
        id: m.id,
        position: m.position,
        caption: m.caption != null ? NOverlayCaption(text: m.caption!) : null,
      );

      marker.setOnTapListener((overlay) {
        debugPrint('마커 클릭: ${marker.info}');
      });

      await controller.addOverlay(marker);
    }
  }

  Future<void> _addCoursePolylines(
    NaverMapController controller,
    List<List<NLatLng>>? segments,
    List<NLatLng>? fallbackRoute,
  ) async {
    try {
      _coursePolylines.clear();

      if (segments != null && segments.isNotEmpty) {
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
      } else if (fallbackRoute != null && fallbackRoute.isNotEmpty) {
        final polyline = NPolylineOverlay(
          id: 'fallback_route',
          coords: fallbackRoute,
          color: const Color(0xFFFF6B9D),
          width: 5,
        );
        await controller.addOverlay(polyline);
        _coursePolylines.add(polyline);
      }
    } catch (e) {
      debugPrint('Polyline error: $e');
    }
  }

  void _moveCameraToTarget(MapProvider provider) {
    if (_mapController == null) return;

    _isProgrammaticMove = true;

    _mapController!.updateCamera(
      NCameraUpdate.fromCameraPosition(
        NCameraPosition(
          target: provider.cameraTarget,
          zoom: provider.zoom,
        ),
      ),
    );

    provider.clearPendingMove();
  }

  bool _isSameMarkerList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ================= build =================

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final mapProvider = context.watch<MapProvider>();
    final navigationProvider = context.watch<NavigationProvider>();
    final courseProvider = context.watch<CourseProvider>();

    // 날짜 상관 없이, 저장된 모든 코스
    final allCourses = courseProvider.allCourses;

    // 버튼 안에서 보여줄 시간/거리 라벨 (캐시 우선)
    String durationLabelFor(RouteType type) {
      final cached = _cachedDuration[type];
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      if (mapProvider.routeType == type) {
        if (mapProvider.isLoadingRoute) return '시간 계산 중';
        if (mapProvider.routeSummary != null) {
          return mapProvider.routeSummary!.durationText;
        }
      }
      return '-';
    }

    String distanceLabelFor(RouteType type) {
      final cached = _cachedDistance[type];
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      if (mapProvider.routeType == type) {
        if (mapProvider.isLoadingRoute) return '거리 계산 중';
        if (mapProvider.routeSummary != null) {
          return mapProvider.routeSummary!.distanceText;
        }
      }
      return '-';
    }

    // ===== 지도 오버레이 동기화 =====
    if (navigationProvider.currentIndex == 1 && _mapController != null) {
      if (mapProvider.hasPendingMove) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveCameraToTarget(mapProvider);
        });
      }

      final newMarkerIds = mapProvider.markers.map((m) => m.id).toList();
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
              (_currentRouteHash != newRouteHash);

      if (shouldRedrawOverlays && !_isSyncing) {
        _isSyncing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (_mapController == null) {
            _isSyncing = false;
            return;
          }

          await _mapController!.clearOverlays();
          _coursePolylines.clear();

          if (mapProvider.markers.isNotEmpty) {
            await _addMarkersToMap(_mapController!, mapProvider.markers);
          }

          if (mapProvider.hasCourseRoute) {
            await _addCoursePolylines(
              _mapController!,
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

    // ================= UI =================

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // ===== NAVER MAP =====
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: mapProvider.cameraTarget,
                zoom: mapProvider.zoom,
              ),
            ),
            onMapReady: (controller) async {
              _mapController = controller;
              mapProvider.ensureInitialized();

              if (mapProvider.markers.isNotEmpty) {
                await _addMarkersToMap(controller, mapProvider.markers);
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

              mapProvider.updateCamera(c.nowCameraPosition);
            },
          ),

          // ===== 상단 UI =====
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: padding.top + 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                          // 왼쪽: 3개의 경로 타입 버튼 (라벨 + "시간 · 거리")
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _RouteTypeButton(
                                    icon: Icons.directions_walk,
                                    label: '도보',
                                    timeText: durationLabelFor(
                                      RouteType.walking,
                                    ),
                                    distanceText: distanceLabelFor(
                                      RouteType.walking,
                                    ),
                                    isSelected:
                                        mapProvider.routeType ==
                                            RouteType.walking,
                                    onTap: () => mapProvider
                                        .setRouteType(RouteType.walking),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _RouteTypeButton(
                                    icon: Icons.directions_car,
                                    label: '자동차',
                                    timeText: durationLabelFor(
                                      RouteType.driving,
                                    ),
                                    distanceText: distanceLabelFor(
                                      RouteType.driving,
                                    ),
                                    isSelected:
                                        mapProvider.routeType ==
                                            RouteType.driving,
                                    onTap: () => mapProvider
                                        .setRouteType(RouteType.driving),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: _RouteTypeButton(
                                    icon: Icons.directions_transit,
                                    label: '대중교통',
                                    timeText: durationLabelFor(
                                      RouteType.transit,
                                    ),
                                    distanceText: distanceLabelFor(
                                      RouteType.transit,
                                    ),
                                    isSelected:
                                        mapProvider.routeType ==
                                            RouteType.transit,
                                    onTap: () => mapProvider
                                        .setRouteType(RouteType.transit),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // 오른쪽: 로딩 + 닫기 버튼
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (mapProvider.isLoadingRoute) ...[
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFF6B9D),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              GestureDetector(
                                onTap: () => mapProvider.clearCourseRoute(),
                                child: Container(
                                  width: 26,
                                  height: 26,
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
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // -------- 기본 상단 아이콘/칩 --------
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24),
                    child: Row(
                      children: const [
                        _CircleChip(icon: Icons.star_border),
                        SizedBox(width: 8),
                        _CircleChip(icon: Icons.navigation),
                        SizedBox(width: 8),
                        _ScoreChip(scoreText: '10.1'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ===== 하단 드래그 시트 =====
          DraggableScrollableSheet(
            initialChildSize: 0.2,
            minChildSize: 0.2,
            maxChildSize: 1.0,
            builder: (ctx, scrollController) {
              final isPlaceTab = _currentTab == _BottomTab.place;

              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 장소/경로 탭
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            _buildTabButton(
                              label: "장소",
                              selected: isPlaceTab,
                              onTap: () => setState(() {
                                _currentTab = _BottomTab.place;
                              }),
                            ),
                            const SizedBox(width: 4),
                            _buildTabButton(
                              label: "경로",
                              selected: !isPlaceTab,
                              onTap: () => setState(() {
                                _currentTab = _BottomTab.route;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 탭 컨텐츠
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        children: [
                          if (isPlaceTab) ...[
                            const Text(
                              '장소 기능 준비 중',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '여기에 추천 장소 목록 등이 추가될 예정입니다.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ] else ...[
                            if (allCourses.isEmpty) ...[
                              const Text(
                                '저장된 코스가 없어요.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '챗봇 탭에서 코스를 저장하면 여기에도 표시됩니다.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ] else ...[
                              const Text(
                                '저장된 코스',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),

                              ...allCourses.map((course) {
                                return GestureDetector(
                                  onTap: () {
                                    mapProvider.setCourseRoute(course);
                                  },
                                  child: Container(
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7FA),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          course.template,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${course.date} · ${course.startTime} ~ ${course.endTime}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= 탭 버튼 빌더 =================
  Widget _buildTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
        ),
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
  final String timeText; // 소요 시간
  final String distanceText; // 소요 거리
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteTypeButton({
    required this.icon,
    required this.label,
    required this.timeText,
    required this.distanceText,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseTextColor =
        isSelected ? Colors.white : Colors.grey.shade800;
    final subTextColor =
        isSelected ? Colors.white.withOpacity(0.9) : Colors.grey.shade600;

    final infoText = '$timeText · $distanceText';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B9D) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: baseTextColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: baseTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              infoText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
