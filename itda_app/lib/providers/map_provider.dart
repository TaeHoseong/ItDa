import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

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
  final List<MapMarker> _markers = [];

  bool get isInitialized => _initialized;
  NLatLng get cameraTarget => _cameraTarget;
  double get zoom => _zoom;
  List<MapMarker> get markers => List.unmodifiable(_markers);

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
}
