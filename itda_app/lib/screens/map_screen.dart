import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../models/date_course.dart'; // CourseSlot
import '../providers/map_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/course_provider.dart';
import '../services/directions_service.dart'; // RouteType, RouteSummary

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

  // 🔹 검색 모드 플래그
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // 예시용 최근 검색어
  final List<String> _recentKeywords = [
    '국제캠',
    '연세대학교 신촌캠퍼스',
    '홍대입구역',
    '카페',
  ];

  // 🔹 경로 타입별 캐시
  final Map<RouteType, String> _cachedDuration = {};
  final Map<RouteType, String> _cachedDistance = {};

  // 🔹 MapProvider 상태 변화 감지용
  bool _prevIsLoadingRoute = false;
  RouteSummary? _prevRouteSummary;

  static const List<Color> _segmentColors = [
    Color(0xFFD4654F),
    Color(0xFFFFA78F),
    Color(0xFFFD9180), // themePink (기본)
    Color(0xFFE36E58),
    Color(0xFFFFC8B4), // 매우 라이트 (부드러운 느낌)
  ];
/*
  static const List<Color> _segmentColors = [
    Color(0xFFFF6B9D),
    Color(0xFFE91E63),
    Color(0xFFFF4081),
    Color(0xFFF50057),
    Color(0xFFFF80AB),
  ];
*/
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapProvider = context.read<MapProvider>();
      mapProvider.addListener(_onMapProviderChanged);
      _prevIsLoadingRoute = mapProvider.isLoadingRoute;
      _prevRouteSummary = mapProvider.routeSummary;
    });
  }

  @override
  void dispose() {
    try {
      context.read<MapProvider>().removeListener(_onMapProviderChanged);
    } catch (_) {}
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// MapProvider 변경 시 호출 → 경로 계산 끝났을 때 캐시 갱신
  void _onMapProviderChanged() {
    if (!mounted) return;
    final mapProvider = context.read<MapProvider>();

    final bool isLoading = mapProvider.isLoadingRoute;
    final RouteSummary? summary = mapProvider.routeSummary;
    final RouteType type = mapProvider.routeType;

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

      // 대중교통 fallback 알림 표시
      if (mapProvider.hasTransitFallback && type == RouteType.transit) {
        _showTransitFallbackSnackBar();
      }
    }

    _prevIsLoadingRoute = isLoading;
    _prevRouteSummary = summary;
  }

  /// 대중교통 미지원 알림 SnackBar 표시
  void _showTransitFallbackSnackBar() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('현재 운행하는 대중교통 경로가 없어 도보 경로로 안내합니다'),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {
            context.read<MapProvider>().clearTransitFallbackNotice();
          },
        ),
      ),
    );

    // 알림 표시 후 상태 초기화
    context.read<MapProvider>().clearTransitFallbackNotice();
  }

  // ================= 마커 및 폴리라인 =================

  Future<void> _addMarkersToMap(
      NaverMapController controller, List<MapMarker> markers) async {
    for (final m in markers) {
      final marker = NMarker(
        id: m.id,
        position: m.position,
        caption: m.caption != null ? NOverlayCaption(text: m.caption!) : null,
      );

      marker.setOnTapListener((overlay) {
        _showMarkerInfoSheet(m);
      });

      await controller.addOverlay(marker);
    }
  }

  void _showMarkerInfoSheet(MapMarker marker) {
    final data = marker.data;
    String title = marker.caption ?? '장소 정보';
    String address = '';
    String category = '';
    String? telephone;
    String? link;
    double? score;

    if (data is Map<String, dynamic>) {
      // 검색 결과
      title = (data['title'] as String?)?.replaceAll(RegExp(r'<[^>]*>'), '') ?? title;
      address = data['address'] ?? data['roadAddress'] ?? '';
      category = data['category'] ?? '';
      telephone = data['telephone'];
      link = data['link'];
    } else if (data is CourseSlot) {
      // 코스 슬롯
      title = data.placeName;
      address = data.placeAddress ?? '';
      category = data.slotType;
      score = data.score;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 타이틀 및 카테고리
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 2. 주소
              if (address.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              
              // 3. 전화번호 (검색 결과인 경우)
              if (telephone != null && telephone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      telephone,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],

              // 4. 평점 (코스 슬롯인 경우)
              if (score != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '추천 점수: ${score.toStringAsFixed(1)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // 5. 액션 버튼
              Row(
                children: [
                  // 찜하기 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: 위시리스트 추가 기능 구현
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('위시리스트 기능 준비 중입니다.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6F61),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('찜하기'),
                    ),
                  ),
                  // 상세보기 버튼 (link가 있을 때만)
                  if (link != null && link.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // URL 열기
                          launchUrlString(link!);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6F61),
                          side: const BorderSide(color: Color(0xFFFF6F61)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('상세보기'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
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
          color: const Color(0xFFFD9180),
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

  // ================= Search overlay =================

  Widget _buildSearchOverlay(EdgeInsets padding, MapProvider mapProvider) {
    return Positioned.fill(
      child: Material(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 지도 모드 검색바와 동일한 위치
            SizedBox(height: padding.top + 16),

            // 검색 입력창 + 뒤로가기
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(26),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() => _isSearchMode = false);
                        FocusScope.of(context).unfocus();
                      },
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 22,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '장소, 버스, 지하철, 주소 검색',
                          hintStyle: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 16,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (v) {
                          debugPrint('검색: $v');
                          context.read<MapProvider>().searchPlaces(v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.mic_none,
                      size: 22,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 카테고리 칩들
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildSearchChip("최근검색", true),
                  const SizedBox(width: 8),
                  _buildSearchChip("예약", false),
                  _buildSearchChip("장소", false),
                  _buildSearchChip("버스", false),
                  _buildSearchChip("경로", false),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                "최근 검색",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 최근 검색 리스트 OR 검색 결과 리스트
            Expanded(
              child: mapProvider.isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : mapProvider.searchResults.isNotEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: mapProvider.searchResults.length,
                          itemBuilder: (_, i) {
                            final item = mapProvider.searchResults[i];
                            // Naver API response structure: title, address, etc.
                            // item['title'] might contain HTML tags like <b>...</b>
                            String title = item['title'] ?? '';
                            title = title.replaceAll('<b>', '').replaceAll('</b>', '');
                            final address = item['address'] ?? item['roadAddress'] ?? '';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.location_on_outlined, size: 22),
                              title: Text(title),
                              subtitle: Text(
                                address,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              onTap: () {
                                // 1. 마커 추가 및 상태 업데이트 (카메라 이동 포함)
                                mapProvider.addSearchMarker(item);
                                
                                // 2. 검색 모드 종료 및 키보드 닫기
                                setState(() {
                                  _isSearchMode = false;
                                });
                                FocusScope.of(context).unfocus();
                              },
                            );
                          },
                        )
                      : ListView.builder(
                          itemCount: _recentKeywords.length,
                          itemBuilder: (_, i) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.history, size: 22),
                              title: Text(_recentKeywords[i]),
                              trailing: const Icon(Icons.close, size: 20),
                              onTap: () {
                                _searchController.text = _recentKeywords[i];
                                context.read<MapProvider>().searchPlaces(_recentKeywords[i]);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Colors.black : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  // ================= build =================

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final mapProvider = context.watch<MapProvider>();
    final navigationProvider = context.watch<NavigationProvider>();
    final courseProvider = context.watch<CourseProvider>();

    final allCourses = courseProvider.allCourses;

    String durationLabelFor(RouteType type) {
      final cached = _cachedDuration[type];
      if (cached != null && cached.isNotEmpty) return cached;

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
      if (cached != null && cached.isNotEmpty) return cached;

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
      backgroundColor: const Color(0xFFFAF8F5),
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

          // ===== 상단 UI (지도 모드 검색바) =====
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: padding.top + 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // 지도 모드에서의 검색바 (네이버지도 스타일, 클릭 시 전체 검색 모드로 전환)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _isSearchMode = true);
                            Future.delayed(
                              const Duration(milliseconds: 100),
                              () {
                                if (mounted) {
                                  FocusScope.of(context)
                                      .requestFocus(_searchFocusNode);
                                }
                              },
                            );
                          },
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
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _RouteTypeButton(
                                    icon: Icons.directions_walk,
                                    label: '도보',
                                    timeText:
                                        durationLabelFor(RouteType.walking),
                                    distanceText:
                                        distanceLabelFor(RouteType.walking),
                                    isSelected: mapProvider.routeType ==
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
                                    timeText:
                                        durationLabelFor(RouteType.driving),
                                    distanceText:
                                        distanceLabelFor(RouteType.driving),
                                    isSelected: mapProvider.routeType ==
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
                                    timeText:
                                        durationLabelFor(RouteType.transit),
                                    distanceText:
                                        distanceLabelFor(RouteType.transit),
                                    isSelected: mapProvider.routeType ==
                                        RouteType.transit,
                                    onTap: () => mapProvider
                                        .setRouteType(RouteType.transit),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                    color: Color(0xFFFD9180),
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
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
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

          // ===== 검색 모드 오버레이 =====
          if (_isSearchMode) _buildSearchOverlay(padding, mapProvider),
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
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
    final baseTextColor = isSelected ? Colors.white : Colors.grey.shade800;
    final subTextColor =
        isSelected ? Colors.white.withOpacity(0.9) : Colors.grey.shade600;

    final infoText = '$timeText · $distanceText';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFD9180) : Colors.grey.shade100,
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
