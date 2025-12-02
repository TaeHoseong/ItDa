import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// GPS 위치 관련 공통 서비스
class LocationService {
  static Position? _cachedPosition;
  static DateTime? _lastFetchTime;

  // 캐시 유효 시간 (10초 - 실시간에 가깝게)
  static const Duration _cacheValidDuration = Duration(seconds: 10);

  // 위치 스트림 (싱글톤)
  static StreamSubscription<Position>? _positionStreamSubscription;
  static final _positionStreamController = StreamController<Position>.broadcast();

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

  /// 실시간 위치 스트림 시작 (네비게이션용)
  /// [distanceFilter]: 이 거리(미터) 이상 이동할 때만 업데이트
  static Stream<Position> startPositionStream({
    int distanceFilter = 5,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    // 이미 스트림이 활성화되어 있으면 기존 스트림 반환
    if (_positionStreamSubscription != null) {
      debugPrint('📍 기존 위치 스트림 재사용');
      return _positionStreamController.stream;
    }

    debugPrint('📍 위치 스트림 시작 (distanceFilter: ${distanceFilter}m)');

    // Geolocator 스트림 구독
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).listen(
      (Position position) {
        // 캐시 업데이트
        _cachedPosition = position;
        _lastFetchTime = DateTime.now();

        // 브로드캐스트 스트림으로 전달
        _positionStreamController.add(position);

        debugPrint(
          '📍 위치 업데이트: ${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)} '
          '(heading: ${position.heading.toStringAsFixed(1)}°)',
        );
      },
      onError: (error) {
        debugPrint('📍 위치 스트림 오류: $error');
        _positionStreamController.addError(error);
      },
    );

    return _positionStreamController.stream;
  }

  /// 위치 스트림 중지
  static void stopPositionStream() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      debugPrint('📍 위치 스트림 중지');
    }
  }

  /// 위치 스트림 활성화 여부
  static bool get isStreamActive => _positionStreamSubscription != null;

  /// 두 좌표 간 거리 계산 (미터)
  static double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// 두 좌표 간 방향 계산 (도)
  static double bearingBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.bearingBetween(startLat, startLng, endLat, endLng);
  }
}
