import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';

import '../providers/map_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  NaverMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final size = MediaQuery.of(context).size;
    final mapProvider = context.watch<MapProvider>();

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
              for (final m in mapProvider.markers) {
                final marker = NMarker(
                  id: m.id,
                  position: m.position,
                  caption: m.caption != null
                      ? NOverlayCaption(text: m.caption!)
                      : null,
                );
                await controller.addOverlay(marker);
              }
            },

            // 📌 flutter_naver_map 공식 방식: 카메라 이벤트는 위젯 콜백으로 받는다.
            onCameraIdle: () {
              final c = _mapController;
              if (c == null) return;

              // nowCameraPosition은 현재 카메라 상태를 바로 가져올 수 있는 프로퍼티
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
