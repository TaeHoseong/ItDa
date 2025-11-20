import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:itda_app/models/date_course.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';

import '../providers/course_provider.dart';
import '../providers/map_provider.dart';
import '../providers/navigation_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  // ===== 코스 옵션 BottomSheet =====
  void _showCourseOptions(DateTime day, DateCourse course) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.black87),
                title: const Text(
                  '코스 수정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  // TODO: 코스 편집 화면으로 이동
                  // _openEditCourseScreen(day, course);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFFD9180),
                ),
                title: const Text(
                  '코스 삭제',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFD9180),
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDeleteCourse(day, course);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final selectedDay = _selectedDay ?? _focusedDay;

    // ✅ 여러 코스 받을 수 있도록
    final selectedCourses = courseProvider.getCoursesByDate(selectedDay);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFD9180),
        onPressed: () => _openAddCourseSheet(selectedDay),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            children: [
              // ===== 캘린더 =====
              TableCalendar<CourseSlot>(
                firstDay: kFirstDay,
                lastDay: kLastDay,
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                startingDayOfWeek: StartingDayOfWeek.sunday,

                // 🔗 코스 슬롯 연결 (여러 코스의 슬롯 합쳐서 표시)
                eventLoader: courseProvider.getSlotsForDay,

                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },

                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },

                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },

                headerVisible: true,

                // 커스텀 셀 + 하트 마커
                calendarBuilders: CalendarBuilders<CourseSlot>(
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildDayCell(
                      day: day,
                      backgroundColor: Colors.transparent,
                      textColor: Colors.black87,
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildDayCell(
                      day: day,
                      textColor: Colors.white,
                      backgroundColor: const Color(0xFF111111),
                    );
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return _buildDayCell(
                      day: day,
                      textColor: Colors.black87,
                      backgroundColor: const Color(0xFFFFD5C2),
                    );
                  },
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return const SizedBox.shrink();

                    final count = events.length > 4 ? 4 : events.length;

                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            count,
                            (index) => const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 1.2),
                              child: Icon(
                                Icons.favorite,
                                size: 9,
                                color: Color(0xFFFD9180),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ===== 선택한 날짜 텍스트 =====
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatSelectedDate(selectedDay),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // ===== 코스 리스트 (코스 단위 카드, 각 카드 안에 슬롯들) =====
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: selectedCourses.length + 1,
                  itemBuilder: (context, index) {
                    // 맨 위: "새로운 코스 만들기"
                    if (index == 0) {
                      return GestureDetector(
                        onTap: () => _openAddCourseSheet(selectedDay),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 22,
                                color: Colors.black87,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '새로운 데이트 코스 만들기',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final course = selectedCourses[index - 1];

                    return GestureDetector(
                      onTap: () {
                        _showCourseOptions(selectedDay, course);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 코스 헤더: 시간 범위 + 템플릿 이름 등
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${course.startTime}  -  ${course.endTime}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    course.template,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.more_vert,
                                  size: 20,
                                  color: Colors.black45,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 슬롯들 리스트
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: course.slots.map((slot) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 6.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.startTime,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${slot.emoji} ${slot.placeName}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (slot.placeAddress != null &&
                                                slot.placeAddress!.isNotEmpty)
                                              Text(
                                                slot.placeAddress!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 8),

                            // ✅ 길 안내 버튼 (지도에 이 코스를 띄우기)
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  final mapProvider =
                                      context.read<MapProvider>();
                                  final navProvider =
                                      context.read<NavigationProvider>();

                                  // 선택한 코스를 지도에 세팅
                                  mapProvider.setCourseRoute(course);

                                  // 지도 탭으로 이동 (0: 추천, 1: 지도, 2: 달력, 3: 채팅)
                                  navProvider.setIndex(1);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFFD9180),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.directions_walk,
                                        size: 16,
                                        color: Color(0xFFFD9180),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '길 안내',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFD9180),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 코스 삭제 확인 =====
  void _confirmDeleteCourse(DateTime day, DateCourse course) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '코스 삭제',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '정말 "${course.template}" 코스를 삭제하시겠습니까?',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                final courseProvider = context.read<CourseProvider>();
                try {
                  await courseProvider.deleteCourse(course);
                  Navigator.of(ctx).pop();
                } catch (_) {
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('코스 삭제에 실패했습니다. 다시 시도해주세요.'),
                    ),
                  );
                }
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Color(0xFFFD9180),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===== iOS 스타일 타임 피커 =====
  Future<TimeOfDay?> _pickCupertinoTime({TimeOfDay? initial}) async {
    final now = DateTime.now();
    final initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      initial?.hour ?? now.hour,
      initial?.minute ?? now.minute,
    );

    TimeOfDay tempTime = initial ?? TimeOfDay.fromDateTime(initialDateTime);

    return showCupertinoModalPopup<TimeOfDay>(
      context: context,
      builder: (ctx) {
        return Container(
          height: 260,
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.of(ctx).pop(tempTime),
                      child: const Text(
                        '완료',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  initialDateTime: initialDateTime,
                  onDateTimeChanged: (DateTime dt) {
                    tempTime = TimeOfDay(
                      hour: dt.hour,
                      minute: dt.minute,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== BottomSheet: 새 코스(슬롯 1개) 추가 =====
  void _openAddCourseSheet(DateTime day) {
    final normalized = _normalize(day);
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> pickStart() async {
                final picked = await _pickCupertinoTime(
                  initial: startTime,
                );
                if (picked != null) {
                  setSheetState(() => startTime = picked);
                }
              }

              Future<void> pickEnd() async {
                final picked = await _pickCupertinoTime(
                  initial: endTime ?? startTime,
                );
                if (picked != null) {
                  setSheetState(() => endTime = picked);
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    _formatSelectedDate(normalized),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      hintText: '장소 / 코스 이름',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: pickStart,
                          child: _TimeChip(
                            label: startTime == null
                                ? '시작 시간'
                                : _formatTime(startTime!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: pickEnd,
                          child: _TimeChip(
                            label: endTime == null
                                ? '종료 시간'
                                : _formatTime(endTime!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            hintText: '위치 (주소 또는 메모)',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(14),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final placeName = titleController.text.trim();
                        if (placeName.isEmpty) {
                          Navigator.of(ctx).pop();
                          return;
                        }
                        final placeAddress = locationController.text.trim();

                        String startTimeStr = '';
                        String endTimeStr = '';
                        if (startTime != null) {
                          startTimeStr = _formatTime(startTime!);
                        }
                        if (endTime != null) {
                          endTimeStr = _formatTime(endTime!);
                        } else {
                          endTimeStr = startTimeStr;
                        }

                        const defaultDuration = 60;

                        final newSlot = CourseSlot(
                          slotType: 'manual',
                          emoji: '📍',
                          startTime: startTimeStr,
                          duration: defaultDuration,
                          placeName: placeName,
                          placeAddress:
                              placeAddress.isEmpty ? null : placeAddress,
                          latitude: 0.0,
                          longitude: 0.0,
                          rating: null,
                          score: 0,
                          distanceFromPrevious: null,
                        );

                        final courseProvider =
                            context.read<CourseProvider>();

                        final dateString =
                            '${normalized.year.toString().padLeft(4, '0')}-'
                            '${normalized.month.toString().padLeft(2, '0')}-'
                            '${normalized.day.toString().padLeft(2, '0')}';

                        final newCourse = DateCourse(
                          date: dateString,
                          template: 'manual_course',
                          startTime: startTimeStr,
                          endTime: endTimeStr,
                          totalDistance: 0,
                          totalDuration: defaultDuration,
                          slots: [newSlot],
                        );

                        try {
                          await courseProvider.createCourse(newCourse);

                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ 새로운 코스가 추가되었습니다'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ 코스 추가 실패: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Icon(Icons.check, size: 22),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ===== Day 셀 =====
  Widget _buildDayCell({
    required DateTime day,
    required Color textColor,
    Color? backgroundColor,
  }) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatSelectedDate(DateTime day) {
    const w = ['일', '월', '화', '수', '목', '금', '토'];
    return '${day.year}년 ${day.month}월 ${day.day}일 (${w[day.weekday % 7]})';
  }
}

// 시간 Chip
class _TimeChip extends StatelessWidget {
  final String label;
  const _TimeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
        ),
      ),
    );
  }
}

// 캘린더 범위
final DateTime kFirstDay = DateTime.utc(2010, 1, 1);
final DateTime kLastDay = DateTime.utc(2030, 12, 31);

// 시간 포맷
String _formatTime(TimeOfDay t) {
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  final h12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final mm = t.minute.toString().padLeft(2, '0');
  return '$period $h12:$mm';
}
