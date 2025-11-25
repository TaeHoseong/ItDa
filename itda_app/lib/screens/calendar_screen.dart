// lib/screens/calendar_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:itda_app/models/date_course.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/course_provider.dart';
import '../providers/map_provider.dart';
import '../providers/navigation_provider.dart';
import 'diary_read_screen.dart';

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
    final courseProvider = context.read<CourseProvider>();
    final hasDiary = course.id != null &&
        courseProvider.getDiaryForCourse(course.id!) != null;
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
              if (hasDiary)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Color(0xFFE53935),
                  ),
                  title: const Text(
                    '일기만 삭제',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE53935),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmDeleteDiary(course);
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

              // ===== 코스 리스트 =====
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: selectedCourses.length + 1,
                  itemBuilder: (context, index) {
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
                    final courseId = course.id;
                    final hasDiary = courseId != null &&
                        courseProvider.getDiaryForCourse(courseId) != null;

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
                            // 코스 헤더
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

                            // 슬롯들
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: course.slots.map((slot) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
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

                            // 버튼들
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasDiary)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                DiaryReadScreen(course: course),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        margin:
                                            const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: const Color(0xFFFD9180),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.visibility_rounded,
                                              size: 16,
                                              color: Color(0xFFFD9180),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '일기 보기',
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
                                  GestureDetector(
                                    onTap: () {
                                      _openDiarySheet(selectedDay, course);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xFF111111),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_note_rounded,
                                            size: 16,
                                            color: Color(0xFF111111),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            '일기 쓰기',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF111111),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      final mapProvider =
                                          context.read<MapProvider>();
                                      final navProvider =
                                          context.read<NavigationProvider>();

                                      mapProvider.setCourseRoute(course);
                                      navProvider.setIndex(1);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(999),
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
                                ],
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

  void _confirmDeleteDiary(DateCourse course) {
    if (course.id == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '일기 삭제',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            '이 코스에 작성된 일기를 모두 삭제할까요?',
            style: TextStyle(fontSize: 15),
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
                  await courseProvider.deleteDiaryForCourse(course.id!);
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('일기가 삭제되었습니다.'),
                    ),
                  );
                } catch (_) {
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('일기 삭제에 실패했습니다. 다시 시도해주세요.'),
                    ),
                  );
                }
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Color(0xFFE53935),
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

  /// ====== 코스 일기 작성 BottomSheet ======
  void _openDiarySheet(DateTime day, DateCourse course) {
    final normalized = _normalize(day);
    final courseProvider = context.read<CourseProvider>();

    if (course.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코스 ID가 없어 일기를 저장할 수 없습니다.')),
      );
      return;
    }

    final existing = courseProvider.getDiaryForCourse(course.id!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // 기존 저장된 일기를 UI용으로 변환
        final List<_SlotDiaryEntry> entries = List.generate(
          course.slots.length,
          (index) {
            final slot = course.slots[index];
            final e = (existing != null && index < existing.length)
                ? existing[index]
                : null;

            return _SlotDiaryEntry(
              imagePath: e?.imageUrl, // URL일 수도, null일 수도
              rating: e?.rating ?? 0,
              comment: e?.comment ?? '',
            );
          },
        );

        final List<TextEditingController> controllers = [
          for (int i = 0; i < course.slots.length; i++)
            TextEditingController(text: entries[i].comment),
        ];

        DecorationImage? buildImage(_SlotDiaryEntry entry) {
          if (entry.imagePath == null) return null;
          if (entry.imagePath!.startsWith('http')) {
            return DecorationImage(
              image: NetworkImage(entry.imagePath!),
              fit: BoxFit.cover,
            );
          } else {
            return DecorationImage(
              image: FileImage(File(entry.imagePath!)),
              fit: BoxFit.cover,
            );
          }
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImage(int index) async {
              final picker = ImagePicker();
              final picked =
                  await picker.pickImage(source: ImageSource.gallery);

              if (picked != null) {
                setSheetState(() {
                  entries[index] =
                      entries[index].copyWith(imagePath: picked.path);
                });
              }
            }

            void setRating(int index, int rating) {
              setSheetState(() {
                entries[index] = entries[index].copyWith(rating: rating);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      '${_formatSelectedDate(normalized)} · ${course.startTime} ~ ${course.endTime}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '데이트 일기 (장소별)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 🔸 각 장소(slot)별 일기 UI
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: course.slots.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final slot = course.slots[index];
                        final entry = entries[index];
                        final controller = controllers[index];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${slot.emoji} ${slot.placeName}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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
                            const SizedBox(height: 8),

                            // 사진 + 한줄평
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => pickImage(index),
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F7),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      image: buildImage(entry),
                                    ),
                                    child: entry.imagePath == null
                                        ? const Icon(
                                            Icons.add_a_photo_outlined,
                                            size: 20,
                                            color: Colors.black54,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      hintText: '이 장소에 대한 한줄평을 남겨보세요',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // 별점 ★★★★★
                            Row(
                              children: List.generate(5, (starIndex) {
                                final starValue = starIndex + 1;
                                final isFilled =
                                    starValue <= entry.rating;
                                return IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  iconSize: 22,
                                  onPressed: () =>
                                      setRating(index, starValue),
                                  icon: Icon(
                                    isFilled
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                  ),
                                );
                              }),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text(
                            '닫기',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111111),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () async {
                            if (course.id == null) return;

                            final List<DiarySlotEntry> slotsToSave = [];

                            for (int i = 0; i < course.slots.length; i++) {
                              final slot = course.slots[i];
                              final localEntry = entries[i].copyWith(
                                comment: controllers[i].text.trim(),
                              );

                              String? imageUrl;

                              // 기존 diary가 있다면 그 url 유지
                              if (existing != null &&
                                  i < existing.length &&
                                  existing[i].imageUrl != null) {
                                imageUrl = existing[i].imageUrl;
                              }

                              // 로컬 파일로 새로 선택했으면 업로드
                              if (localEntry.imagePath != null &&
                                  !localEntry.imagePath!
                                      .startsWith('http')) {
                                imageUrl =
                                    await courseProvider.uploadDiaryImage(
                                  courseId: course.id!,
                                  slotIndex: i,
                                  file: File(localEntry.imagePath!),
                                );
                              }

                              slotsToSave.add(
                                DiarySlotEntry(
                                  placeName: slot.placeName,
                                  address: slot.placeAddress,
                                  rating: localEntry.rating,
                                  comment: localEntry.comment,
                                  imageUrl: imageUrl,
                                ),
                              );
                            }

                            await courseProvider.upsertDiaryForCourse(
                              course: course,
                              slots: slotsToSave,
                            );

                            if (!mounted) return;
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('📝 장소별 데이트 일기가 저장되었습니다'),
                              ),
                            );
                          },
                          child: const Text(
                            '저장',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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

// ====== 각 장소(slot)별 일기 entry (UI용, 로컬 파일 path 포함) ======
class _SlotDiaryEntry {
  final String? imagePath;   // 로컬 or URL
  final int rating;          // 0~5점
  final String comment;      // 한줄평

  const _SlotDiaryEntry({
    this.imagePath,
    this.rating = 0,
    this.comment = '',
  });

  _SlotDiaryEntry copyWith({
    String? imagePath,
    int? rating,
    String? comment,
  }) {
    return _SlotDiaryEntry(
      imagePath: imagePath ?? this.imagePath,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
    );
  }
}
