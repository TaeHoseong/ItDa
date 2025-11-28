import 'package:flutter/material.dart';
import '../models/date_course.dart';

/// 데이트 코스 타임라인 위젯
class DateCourseWidget extends StatelessWidget {
  final DateCourse course;
  final VoidCallback? onAddToSchedule;
  final VoidCallback? onShare;
  final bool onChat;
  final Function(int slotIndex)? onRegenerateSlot;

  const DateCourseWidget({
    Key? key,
    required this.course,
    this.onAddToSchedule,
    this.onShare,
    this.onChat = false,
    this.onRegenerateSlot,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            _buildHeader(context),
            const SizedBox(height: 16),

            // 타임라인
            ...course.slots.asMap().entries.map((entry) {
              final index = entry.key;
              final slot = entry.value;
              final isLast = index == course.slots.length - 1;

              return _buildTimelineItem(context, index, slot, isLast);
            }).toList(),

            const SizedBox(height: 16),

            // 일정에 추가 버튼
            // 일정에 추가 + 공유 버튼
            if (onAddToSchedule != null) 
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAddToSchedule,
                      icon: const Icon(Icons.add),
                      label: const Text('일정에 추가'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (!onChat) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onShare,   
                        icon: const Icon(Icons.share),
                        label: const Text('공유'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            Text(
              course.date,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${course.startTime} - ${course.endTime}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildInfoChip(
              icon: Icons.directions_walk,
              label: '${course.totalDistance}km',
            ),
            const SizedBox(width: 8),
            _buildInfoChip(
              icon: Icons.access_time,
              label: '${course.totalDuration}분',
            ),
            const SizedBox(width: 8),
            _buildInfoChip(
              icon: Icons.category,
              label: _getTemplateLabel(course.template),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, int slotIndex, CourseSlot slot, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타임라인 라인
          Column(
            children: [
              // 아이콘
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    slot.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              // 연결선
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey[300],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // 컨텐츠
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 시간
                  Text(
                    '${slot.startTime} (${slot.duration}분)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 장소명
                  Text(
                    slot.placeName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 슬롯 타입
                  Text(
                    _getSlotTypeLabel(slot.slotType),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),

                  // 평점
                  if (slot.rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          slot.rating!.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],

                  // 거리 정보
                  if (slot.distanceFromPrevious != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.directions_walk, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '이전 장소에서 ${slot.distanceFromPrevious!.toStringAsFixed(2)}km',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 재생성 버튼
                  if (!onChat) ...[
                    if (onRegenerateSlot != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: () => onRegenerateSlot!(slotIndex),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text(
                            '다른 장소',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            side: BorderSide(color: Colors.grey[400]!),
                          ),
                        ),
                      ),
                    ],
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTemplateLabel(String template) {
    const labels = {
      'full_day': '하루 코스',
      'half_day_lunch': '점심 반나절',
      'half_day_dinner': '저녁 반나절',
      'cafe_date': '카페 데이트',
      'active_date': '액티브 데이트',
      'culture_date': '문화 데이트',
      'auto': '자동 선택',
    };
    return labels[template] ?? template;
  }

  String _getSlotTypeLabel(String slotType) {
    const labels = {
      'lunch': '점심',
      'cafe': '카페',
      'activity': '액티비티',
      'dinner': '저녁',
      'night_view': '야경',
      'dessert': '디저트',
      'walk': '산책',
      'exhibition': '전시/문화',
    };
    return labels[slotType] ?? slotType;
  }
}
