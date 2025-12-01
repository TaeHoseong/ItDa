import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// GPS 위치 관련 공통 서비스
class LocationService {
  static Position? _cachedPosition;
  static DateTime? _lastFetchTime;

  // 캐시 유효 시간 (5분)
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// 현재 GPS 위치 가져오기
  /// 캐시된 위치가 있고 유효하면 캐시 반환, 아니면 새로 가져옴
  static Future<Position?> getCurrentPosition({bool forceRefresh = false}) async {
    // 캐시가 유효하면 캐시된 위치 반환
    if (!forceRefresh && _cachedPosition != null && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < _cacheValidDuration) {
        debugPrint('📍 캐시된 GPS 위치 사용: ${_cachedPosition!.latitude}, ${_cachedPosition!.longitude}');
        return _cachedPosition;
      }
    }

    try {
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 위치 서비스가 비활성화됨');
        return _cachedPosition; // 캐시라도 반환
      }

      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('📍 위치 권한이 거부됨');
          return _cachedPosition;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('📍 위치 권한이 영구적으로 거부됨');
        return _cachedPosition;
      }

      // 현재 위치 가져오기
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 캐시 업데이트
      _cachedPosition = position;
      _lastFetchTime = DateTime.now();

      debugPrint('📍 GPS 위치 획득: ${position.latitude}, ${position.longitude}');
      return position;

    } catch (e) {
      debugPrint('📍 위치 가져오기 실패: $e');
      return _cachedPosition; // 에러 시 캐시라도 반환
    }
  }

  /// 캐시된 위치 반환 (비동기 호출 없이)
  static Position? get cachedPosition => _cachedPosition;

  /// 위치 권한 상태 확인
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  /// 위치 권한 요청
  static Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  /// 캐시 초기화
  static void clearCache() {
    _cachedPosition = null;
    _lastFetchTime = null;
  }
}
