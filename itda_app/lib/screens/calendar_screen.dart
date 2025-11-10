import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// 날짜별 일정 목록 (메모리)
  final Map<DateTime, List<Schedule>> _events = {};

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Schedule> _getEventsForDay(DateTime day) {
    return _events[_normalize(day)] ?? const [];
  }

  void _addEvent(DateTime day, Schedule schedule) {
    final key = _normalize(day);
    final list = _events[key] ?? [];
    setState(() {
      _events[key] = [...list, schedule];
    });
  }

  void _removeEvent(DateTime day, int index) {
    final key = _normalize(day);
    final list = [...?_events[key]];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    setState(() {
      if (list.isEmpty) {
        _events.remove(key);
      } else {
        _events[key] = list;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _selectedDay ?? _focusedDay;
    final selectedEvents = _getEventsForDay(selectedDay);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFD9180),
        onPressed: () => _openAddScheduleSheet(selectedDay),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea( // 화면 상단 여백 확보
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
          children: [
          // ===== 캘린더 =====
          TableCalendar<Schedule>(
            firstDay: kFirstDay,
            lastDay: kLastDay,
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.sunday,

            // 🔗 일정 연결 (여기가 핵심)
            eventLoader: _getEventsForDay,

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

            /*
            calendarStyle: CalendarStyle(
              defaultDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              defaultTextStyle: const TextStyle(
                color: Colors.black87,
              ),
              selectedDecoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(8),
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              todayDecoration: BoxDecoration(
                color: const Color(0xFFFFD5C2),
                borderRadius: BorderRadius.circular(8),
              ),
              todayTextStyle: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              cellMargin: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 0,
              ),
            ),*/

            // 커스텀 셀 + 하트 마커
            calendarBuilders: CalendarBuilders<Schedule>(
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
                // 일정 있는 날짜에 하트 표시 (개수/위치는 나중에 조정)
                if (events.isEmpty) return const SizedBox.shrink();

                // 최대 4개까지만 하트 표시
                final count = events.length > 4 ? 4 : events.length;

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8), // 마커 4픽셀 올림
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        count,
                        (index) => const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 1.2), // 하트 간 간격
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

          // ===== 일정 리스트 =====
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: selectedEvents.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "새로운 이벤트" 행
                  return GestureDetector(
                    onTap: () => _openAddScheduleSheet(selectedDay),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded,
                              size: 22, color: Colors.black87),
                          SizedBox(width: 8),
                          Text(
                            '새로운 이벤트',
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

                final schedule = selectedEvents[index - 1];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 시간
                      if (schedule.startTime != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTime(schedule.startTime!),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (schedule.endTime != null)
                              Text(
                                _formatTime(schedule.endTime!),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        )
                      else
                        const Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: Colors.black54,
                        ),
                      const SizedBox(width: 12),

                      // 제목 + 위치
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (schedule.location != null &&
                                schedule.location!.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  schedule.location!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.black45,
                        ),
                        onPressed: () =>
                            _removeEvent(selectedDay, index - 1),
                      ),
                    ],
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

  // ===== iOS 스타일 타임 피커 =====
  Future<TimeOfDay?> _pickCupertinoTime({
    TimeOfDay? initial,
  }) async {
    final now = DateTime.now();
    final initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      initial?.hour ?? now.hour,
      initial?.minute ?? now.minute,
    );

    TimeOfDay tempTime =
        initial ?? TimeOfDay.fromDateTime(initialDateTime);

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
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () =>
                          Navigator.of(ctx).pop(),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    CupertinoButton(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () =>
                          Navigator.of(ctx).pop(tempTime),
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

  // ===== BottomSheet: 새 일정 추가 =====
  void _openAddScheduleSheet(DateTime day) {
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
                      margin:
                          const EdgeInsets.only(bottom: 16),
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
                      hintText: '제목',
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
                            hintText: '위치',
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
                      onPressed: () {
                        final title =
                            titleController.text.trim();
                        if (title.isEmpty) {
                          Navigator.of(ctx).pop();
                          return;
                        }
                        final loc =
                            locationController.text.trim();
                        final schedule = Schedule(
                          title: title,
                          startTime: startTime,
                          endTime: endTime,
                          location:
                              loc.isEmpty ? null : loc,
                        );
                        _addEvent(normalized, schedule);
                        Navigator.of(ctx).pop();
                      },
                      child:
                          const Icon(Icons.check, size: 22),
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
      alignment: Alignment.topCenter, // 숫자를 박스 위쪽 중앙에
      padding: const EdgeInsets.only(top: 6), // 살짝 아래로 내림 (가독성)
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
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

// 일정 모델
class Schedule {
  final String title;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? location;

  Schedule({
    required this.title,
    this.startTime,
    this.endTime,
    this.location,
  });
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
