import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../models/navigation_step.dart';
import '../services/directions_service.dart';
import '../services/location_service.dart';

/// 턴바이턴 네비게이션 모드
enum TurnByTurnMode {
  idle,       // 대기 중
  navigating, // 안내 중
  rerouting,  // 경로 재탐색 중
  arrived,    // 도착
  offRoute,   // 경로 이탈 (재탐색 전 상태)
}

/// 턴바이턴 네비게이션 상태 관리
class TurnByTurnProvider extends ChangeNotifier {
  // 상태
  TurnByTurnMode _mode = TurnByTurnMode.idle;
  Position? _currentPosition;
  double? _currentHeading;
  List<NavigationStep> _steps = [];
  int _currentStepIndex = 0;
  DetailedRouteResult? _route;
  NLatLng? _destination;
  String? _destinationName;
  int _initialTotalDistance = 0; // 시작 시 전체 거리 저장
  int _initialTotalDuration = 0; // 시작 시 전체 시간 저장 (초)
  bool _isOffRoute = false; // 경로 이탈 여부
  double _currentDistanceFromRoute = 0; // 경로로부터 현재 이격 거리
  DateTime? _navigationStartTime; // 네비게이션 시작 시간

  // 스트림 구독
  StreamSubscription<Position>? _positionSubscription;

  // 경로 이탈/도착 기준 거리 (미터)
  static const double _offRouteThreshold = 50.0;
  static const double _stepAdvanceThreshold = 30.0;
  static const double _arrivalThreshold = 20.0;

  // 도보 평균 속도 (m/s) - 약 4km/h
  static const double _walkingSpeed = 1.1;

  // Getters
  TurnByTurnMode get mode => _mode;
  Position? get currentPosition => _currentPosition;
  double? get currentHeading => _currentHeading;
  List<NavigationStep> get steps => _steps;
  int get currentStepIndex => _currentStepIndex;
  DetailedRouteResult? get route => _route;
  NLatLng? get destination => _destination;
  String? get destinationName => _destinationName;
  bool get isOffRoute => _isOffRoute;
  double get distanceFromRoute => _currentDistanceFromRoute;
  DateTime? get navigationStartTime => _navigationStartTime;

  /// 현재 위치를 NLatLng으로 반환
  NLatLng? get currentLatLng => _currentPosition != null
      ? NLatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : null;

  /// 안내 전환점 목록 (마커 표시용)
  List<NLatLng> get turnPoints {
    return _steps
        .where((step) => step.turnType != 11 && step.turnType != 200) // 직진, 출발 제외
        .map((step) => step.location)
        .toList();
  }

  /// 현재 안내 단계
  NavigationStep? get currentStep {
    if (_steps.isEmpty || _currentStepIndex >= _steps.length) return null;
    return _steps[_currentStepIndex];
  }

  /// 다음 안내 단계
  NavigationStep? get nextStep {
    if (_steps.isEmpty || _currentStepIndex + 1 >= _steps.length) return null;
    return _steps[_currentStepIndex + 1];
  }

  /// 현재 단계까지 남은 거리 (미터)
  int get distanceToCurrentStep {
    if (currentStep == null || _currentPosition == null) return 0;
    return LocationService.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      currentStep!.location.latitude,
      currentStep!.location.longitude,
    ).round();
  }

  /// 목적지까지 남은 총 거리 (미터)
  int get remainingDistance {
    if (_route == null || _currentPosition == null) {
      return _initialTotalDistance; // 초기값은 전체 거리
    }

    // 현재 위치에서 가장 가까운 경로 지점을 찾고, 그 지점부터 끝까지의 거리 계산
    final path = _route!.path;
    if (path.length < 2) return 0;

    // 현재 위치에서 가장 가까운 경로 지점 인덱스 찾기
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < path.length; i++) {
      final dist = LocationService.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        path[i].latitude,
        path[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // 현재 위치 → 가장 가까운 지점 거리 + 그 지점부터 끝까지 폴리라인 거리
    double total = minDistance;
    for (int i = closestIndex; i < path.length - 1; i++) {
      total += LocationService.distanceBetween(
        path[i].latitude,
        path[i].longitude,
        path[i + 1].latitude,
        path[i + 1].longitude,
      );
    }

    return total.round();
  }

  /// 목적지까지 남은 총 시간 (초)
  int get remainingDuration {
    final remaining = remainingDistance;
    if (remaining == 0) return 0;

    // 현재 속도가 유효하면 (0.5m/s 이상) 속도 기반, 아니면 평균 도보 속도
    final speed = (_currentPosition != null && _currentPosition!.speed > 0.5)
        ? _currentPosition!.speed
        : _walkingSpeed;

    return (remaining / speed).round();
  }

  /// 거리를 텍스트로 변환 (공통 헬퍼)
  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters}m';
  }

  /// 남은 거리 텍스트
  String get remainingDistanceText => _formatDistance(remainingDistance);

  /// 남은 시간 텍스트
  String get remainingDurationText {
    final minutes = (remainingDuration / 60).round();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '약 $hours시간 $mins분' : '약 $hours시간';
    }
    return '약 $minutes분';
  }

  /// 전체 거리 (미터) - 네비게이션 시작 시 저장된 값
  int get totalDistance => _initialTotalDistance;

  /// 폴리라인 좌표들의 실제 거리 계산 (미터)
  static int _calculatePathDistance(List<NLatLng> path) {
    if (path.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < path.length - 1; i++) {
      total += LocationService.distanceBetween(
        path[i].latitude,
        path[i].longitude,
        path[i + 1].latitude,
        path[i + 1].longitude,
      );
    }
    return total.round();
  }

  /// 전체 거리 텍스트
  String get totalDistanceText => _formatDistance(totalDistance);

  /// 이동한 거리 (미터)
  int get traveledDistance {
    final total = totalDistance;
    final remaining = remainingDistance;
    return (total - remaining).clamp(0, total);
  }

  /// 이동한 거리 텍스트
  String get traveledDistanceText => _formatDistance(traveledDistance);

  /// 진행률 (0.0 ~ 1.0)
  double get progress {
    final total = totalDistance;
    if (total == 0) return 0.0;
    return (traveledDistance / total).clamp(0.0, 1.0);
  }

  /// 진행률 퍼센트 텍스트
  String get progressText {
    return '${(progress * 100).round()}%';
  }

  /// 예상 도착 시간 (DateTime)
  DateTime get estimatedArrivalTime {
    return DateTime.now().add(Duration(seconds: remainingDuration));
  }

  /// 예상 도착 시간 텍스트 (HH:mm 형식)
  String get estimatedArrivalTimeText {
    final eta = estimatedArrivalTime;
    final hour = eta.hour.toString().padLeft(2, '0');
    final minute = eta.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 네비게이션 시작
  Future<bool> startNavigation(
    NLatLng destination, {
    String? destinationName,
  }) async {
    try {
      _mode = TurnByTurnMode.rerouting;
      _destination = destination;
      _destinationName = destinationName;
      notifyListeners();

      // 1. 현재 위치 가져오기
      final position = await LocationService.getCurrentPosition(forceRefresh: true);
      if (position == null) {
        debugPrint('❌ 현재 위치를 가져올 수 없음');
        _mode = TurnByTurnMode.idle;
        notifyListeners();
        return false;
      }

      _currentPosition = position;
      _currentHeading = position.heading;

      final start = NLatLng(position.latitude, position.longitude);

      // 2. 상세 경로 조회
      final route = await DirectionsService.getDetailedWalkingRoute(start, destination);
      if (route == null) {
        debugPrint('❌ 경로를 가져올 수 없음');
        _mode = TurnByTurnMode.idle;
        notifyListeners();
        return false;
      }

      _route = route;
      _steps = route.steps;
      _currentStepIndex = 0;
      _isOffRoute = false;
      _currentDistanceFromRoute = 0;

      // 전체 거리/시간 저장 (폴리라인 좌표로 실제 거리 계산)
      _initialTotalDistance = _calculatePathDistance(route.path);
      _initialTotalDuration = (_initialTotalDistance / _walkingSpeed).round(); // 도보 속도 기반

      // 네비게이션 시작 시간 기록
      _navigationStartTime = DateTime.now();

      // 3. GPS 스트림 시작
      _startPositionStream();

      _mode = TurnByTurnMode.navigating;
      notifyListeners();

      debugPrint('✅ 네비게이션 시작: ${_steps.length}개 안내 단계');
      return true;
    } catch (e) {
      debugPrint('❌ 네비게이션 시작 실패: $e');
      _mode = TurnByTurnMode.idle;
      notifyListeners();
      return false;
    }
  }

  /// 네비게이션 종료
  void stopNavigation() {
    _stopPositionStream();
    _mode = TurnByTurnMode.idle;
    _route = null;
    _steps = [];
    _currentStepIndex = 0;
    _destination = null;
    _destinationName = null;
    _initialTotalDistance = 0;
    _initialTotalDuration = 0;
    _isOffRoute = false;
    _currentDistanceFromRoute = 0;
    _navigationStartTime = null;
    notifyListeners();

    debugPrint('🛑 네비게이션 종료');
  }

  /// GPS 스트림 시작
  void _startPositionStream() {
    _stopPositionStream(); // 기존 스트림 정리

    final stream = LocationService.startPositionStream(distanceFilter: 5);
    _positionSubscription = stream.listen(
      _onPositionUpdate,
      onError: (error) {
        debugPrint('❌ 위치 스트림 오류: $error');
      },
    );
  }

  /// GPS 스트림 중지
  void _stopPositionStream() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    LocationService.stopPositionStream();
  }

  /// GPS 업데이트 콜백
  void _onPositionUpdate(Position position) {
    if (_mode != TurnByTurnMode.navigating && _mode != TurnByTurnMode.offRoute) return;

    _currentPosition = position;
    _currentHeading = position.heading;

    // 도착 체크
    if (_checkArrival(position)) {
      _onArrived();
      return;
    }

    // 경로 이탈 체크 (이탈 상태 업데이트)
    final isOff = _checkOffRoute(position);

    if (isOff && _mode != TurnByTurnMode.offRoute && _mode != TurnByTurnMode.rerouting) {
      // 경로 이탈 감지 → offRoute 모드로 전환 후 재탐색
      _mode = TurnByTurnMode.offRoute;
      notifyListeners();

      // 1초 후 재탐색 시작 (사용자에게 이탈 알림 시간 제공)
      Future.delayed(const Duration(seconds: 1), () {
        if (_mode == TurnByTurnMode.offRoute) {
          _reroute();
        }
      });
      return;
    }

    // Step 전환 체크
    _checkStepAdvancement(position);

    notifyListeners();
  }

  /// 도착 여부 확인
  bool _checkArrival(Position position) {
    if (_destination == null) return false;

    final distance = LocationService.distanceBetween(
      position.latitude,
      position.longitude,
      _destination!.latitude,
      _destination!.longitude,
    );

    return distance <= _arrivalThreshold;
  }

  /// 도착 처리
  void _onArrived() {
    _mode = TurnByTurnMode.arrived;
    _stopPositionStream();
    notifyListeners();

    debugPrint('🎉 목적지 도착!');
  }

  /// 경로 이탈 감지 및 상태 업데이트
  bool _checkOffRoute(Position position) {
    if (_route == null || _route!.path.isEmpty) return false;

    // 현재 위치에서 경로상 가장 가까운 점까지의 거리 계산
    double minDistance = double.infinity;

    for (final point in _route!.path) {
      final distance = LocationService.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    // 경로로부터의 거리 업데이트
    _currentDistanceFromRoute = minDistance;

    // 이탈 여부 업데이트
    final wasOffRoute = _isOffRoute;
    _isOffRoute = minDistance > _offRouteThreshold;

    // 이탈 상태가 변경되었으면 로그 출력
    if (_isOffRoute && !wasOffRoute) {
      debugPrint('⚠️ 경로 이탈 감지: ${minDistance.toStringAsFixed(1)}m 벗어남');
    } else if (!_isOffRoute && wasOffRoute) {
      debugPrint('✅ 경로 복귀: ${minDistance.toStringAsFixed(1)}m');
    }

    return _isOffRoute;
  }

  /// Step 전환 체크
  void _checkStepAdvancement(Position position) {
    if (currentStep == null) return;

    final distanceToStep = LocationService.distanceBetween(
      position.latitude,
      position.longitude,
      currentStep!.location.latitude,
      currentStep!.location.longitude,
    );

    // 현재 step에 도달하면 다음 step으로
    if (distanceToStep <= _stepAdvanceThreshold) {
      if (_currentStepIndex < _steps.length - 1) {
        _currentStepIndex++;
        debugPrint('➡️ 다음 안내 단계로 전환: ${currentStep?.description}');
      }
    }
  }

  /// 다음 안내 지점까지의 실제 회전 방향 계산
  /// GPS 방위각과 다음 지점 방향을 비교하여 좌/우회전 판단
  String getActualTurnDirection() {
    if (currentStep == null || _currentPosition == null || _currentHeading == null) {
      return currentStep?.turnTypeIcon ?? 'straight';
    }

    // API에서 제공한 turnType이 직진(11)이 아니면 API 결과 사용
    if (currentStep!.turnType != 11) {
      return currentStep!.turnTypeIcon;
    }

    // 직진인 경우, 실제 필요한 방향 전환 계산
    final bearingToNext = LocationService.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      currentStep!.location.latitude,
      currentStep!.location.longitude,
    );

    // 현재 진행 방향과 목표 방향의 차이 계산
    double angleDiff = bearingToNext - _currentHeading!;

    // -180 ~ 180 범위로 정규화
    while (angleDiff > 180) angleDiff -= 360;
    while (angleDiff < -180) angleDiff += 360;

    // 각도 차이에 따른 방향 판단
    // - 양수: 오른쪽으로 회전 필요
    // - 음수: 왼쪽으로 회전 필요
    if (angleDiff.abs() < 20) {
      return 'straight';
    } else if (angleDiff >= 20 && angleDiff < 60) {
      return 'turn_slight_right';
    } else if (angleDiff >= 60) {
      return 'turn_right';
    } else if (angleDiff <= -20 && angleDiff > -60) {
      return 'turn_slight_left';
    } else {
      return 'turn_left';
    }
  }

  /// 실제 회전 방향에 따른 turnType 반환
  int getActualTurnType() {
    final direction = getActualTurnDirection();
    switch (direction) {
      case 'straight':
        return 11;
      case 'turn_left':
        return 12;
      case 'turn_right':
        return 13;
      case 'turn_slight_left':
        return 17; // 10시 방향
      case 'turn_slight_right':
        return 18; // 2시 방향
      default:
        return currentStep?.turnType ?? 11;
    }
  }

  /// 경로 재탐색
  Future<void> _reroute() async {
    if (_destination == null || _currentPosition == null) return;

    debugPrint('🔄 경로 재탐색 중...');
    _mode = TurnByTurnMode.rerouting;
    notifyListeners();

    try {
      final start = NLatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      final route = await DirectionsService.getDetailedWalkingRoute(
        start,
        _destination!,
      );

      if (route == null) {
        debugPrint('❌ 경로 재탐색 실패');
        _mode = TurnByTurnMode.navigating; // 기존 경로 유지
        notifyListeners();
        return;
      }

      _route = route;
      _steps = route.steps;
      _currentStepIndex = 0;
      _mode = TurnByTurnMode.navigating;
      notifyListeners();

      debugPrint('✅ 경로 재탐색 완료: ${_steps.length}개 안내 단계');
    } catch (e) {
      debugPrint('❌ 경로 재탐색 오류: $e');
      _mode = TurnByTurnMode.navigating;
      notifyListeners();
    }
  }

  /// 도착 상태 확인 후 idle로 전환
  void dismissArrival() {
    if (_mode == TurnByTurnMode.arrived) {
      stopNavigation();
    }
  }

  @override
  void dispose() {
    _stopPositionStream();
    super.dispose();
  }
}
