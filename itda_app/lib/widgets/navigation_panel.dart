import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/turn_by_turn_provider.dart' show TurnByTurnProvider, TurnByTurnMode;

/// 턴바이턴 네비게이션 안내 패널
class NavigationPanel extends StatelessWidget {
  final VoidCallback? onStop;

  const NavigationPanel({
    super.key,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TurnByTurnProvider>();
    final step = provider.currentStep;
    final nextStep = provider.nextStep;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들 바
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 현재 안내
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // 방향 아이콘 (실제 회전 방향 사용)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B9D).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getDirectionIcon(provider.getActualTurnDirection()),
                      color: const Color(0xFFFF6B9D),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 안내 텍스트
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 거리 + 방향 (실제 회전 방향 사용)
                        Row(
                          children: [
                            Text(
                              '${provider.distanceToCurrentStep}m',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B9D),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getTurnTypeKorean(provider.getActualTurnType()),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 상세 안내
                        Text(
                          step?.description ?? '경로 안내 중...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 다음 안내 미리보기
            if (nextStep != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getDirectionIcon(nextStep.turnTypeIcon),
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '다음: ${nextStep.distanceMeters}m 후 ${_getTurnTypeKorean(nextStep.turnType)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

            // 구분선
            Divider(height: 1, color: Colors.grey[200]),

            // 진행률 섹션
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  // 진행률 바
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: provider.progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF6B9D),
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        provider.progressText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6B9D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 이동 거리 / 전체 거리
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${provider.traveledDistanceText} / ${provider.totalDistanceText}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${provider.estimatedArrivalTimeText} 도착 예정',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 구분선
            Divider(height: 1, color: Colors.grey[200]),

            // 하단: 남은 거리/시간 + 종료 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 남은 거리
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    label: '남은 ${provider.remainingDistanceText}',
                  ),
                  const SizedBox(width: 12),

                  // 남은 시간
                  _InfoChip(
                    icon: Icons.access_time,
                    label: provider.remainingDurationText,
                  ),

                  const Spacer(),

                  // 종료 버튼
                  TextButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('종료'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// turnTypeIcon을 Flutter 아이콘으로 변환
  IconData _getDirectionIcon(String iconName) {
    switch (iconName) {
      case 'straight':
        return Icons.arrow_upward;
      case 'turn_left':
        return Icons.turn_left;
      case 'turn_right':
        return Icons.turn_right;
      case 'u_turn_left':
        return Icons.u_turn_left;
      case 'turn_slight_left':
        return Icons.turn_slight_left;
      case 'turn_slight_right':
        return Icons.turn_slight_right;
      case 'stairs':
        return Icons.stairs;
      case 'flag':
        return Icons.flag;
      case 'location_on':
        return Icons.location_on;
      case 'directions_walk':
        return Icons.directions_walk;
      default:
        return Icons.arrow_upward;
    }
  }

  /// turnType을 한국어로 변환
  String _getTurnTypeKorean(int turnType) {
    switch (turnType) {
      case 11:
        return '직진';
      case 12:
        return '좌회전';
      case 13:
        return '우회전';
      case 14:
        return '유턴';
      case 16:
        return '8시 방향';
      case 17:
        return '10시 방향';
      case 18:
        return '2시 방향';
      case 19:
        return '4시 방향';
      case 125:
        return '육교';
      case 126:
        return '지하보도';
      case 127:
        return '계단';
      case 200:
        return '출발';
      case 201:
        return '도착';
      case 211:
      case 212:
      case 213:
      case 214:
      case 215:
      case 216:
      case 217:
        return '횡단보도';
      default:
        return '이동';
    }
  }
}

/// 정보 칩 위젯
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// 네비게이션 상단 바 (재탐색 중, 도착 등 상태 표시)
class NavigationTopBar extends StatelessWidget {
  final VoidCallback? onStop;

  const NavigationTopBar({
    super.key,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TurnByTurnProvider>();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(provider.mode),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 상태 아이콘
          _buildStatusIcon(provider.mode),
          const SizedBox(width: 12),

          // 상태 텍스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getStatusText(provider),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // 경로 이탈 시 거리 표시
                if (provider.mode == TurnByTurnMode.offRoute)
                  Text(
                    '경로에서 ${provider.distanceFromRoute.toStringAsFixed(0)}m 벗어남',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // 닫기 버튼
          IconButton(
            onPressed: onStop,
            icon: const Icon(Icons.close, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(TurnByTurnMode mode) {
    switch (mode) {
      case TurnByTurnMode.navigating:
        return const Color(0xFFFF6B9D);
      case TurnByTurnMode.rerouting:
        return Colors.orange;
      case TurnByTurnMode.offRoute:
        return Colors.red.shade600;
      case TurnByTurnMode.arrived:
        return Colors.green;
      case TurnByTurnMode.idle:
        return Colors.grey;
    }
  }

  Widget _buildStatusIcon(TurnByTurnMode mode) {
    switch (mode) {
      case TurnByTurnMode.navigating:
        return const Icon(Icons.navigation, color: Colors.white);
      case TurnByTurnMode.rerouting:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case TurnByTurnMode.offRoute:
        return const Icon(Icons.warning_amber_rounded, color: Colors.white);
      case TurnByTurnMode.arrived:
        return const Icon(Icons.check_circle, color: Colors.white);
      case TurnByTurnMode.idle:
        return const Icon(Icons.pause, color: Colors.white);
    }
  }

  String _getStatusText(TurnByTurnProvider provider) {
    switch (provider.mode) {
      case TurnByTurnMode.navigating:
        return '도보 안내 중 • ${provider.destinationName ?? "목적지"}';
      case TurnByTurnMode.rerouting:
        return '경로 재탐색 중...';
      case TurnByTurnMode.offRoute:
        return '경로를 이탈했습니다';
      case TurnByTurnMode.arrived:
        return '목적지에 도착했습니다!';
      case TurnByTurnMode.idle:
        return '안내 대기 중';
    }
  }
}

/// 도착 다이얼로그
class ArrivalDialog extends StatelessWidget {
  final String? destinationName;
  final VoidCallback? onDismiss;

  const ArrivalDialog({
    super.key,
    this.destinationName,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 체크 아이콘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            // 타이틀
            const Text(
              '목적지 도착!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 목적지 이름
            if (destinationName != null)
              Text(
                destinationName!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),

            // 확인 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B9D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
