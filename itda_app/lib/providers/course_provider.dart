// course_provider.dart
import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/course_api_service.dart';
import '../models/date_course.dart';

class CalendarProvider extends ChangeNotifier {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  CalendarFormat get calendarFormat => _calendarFormat;
  DateTime get focusedDay => _focusedDay;
  DateTime? get selectedDay => _selectedDay;

  void selectDay(DateTime selected, DateTime focused) {
    if (!isSameDay(_selectedDay, selected)) {
      _selectedDay = selected;
      _focusedDay = focused;
      notifyListeners();
    }
  }

  void changeFormat(CalendarFormat format) {
    if (_calendarFormat != format) {
      _calendarFormat = format;
      notifyListeners();
    }
  }

  void updateFocusedDay(DateTime day) {
    _focusedDay = day;
  }
}

class CourseProvider extends ChangeNotifier {
  final Map<DateTime, DateCourse> _coursesByDate = {};
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  DateTime _key(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// 특정 날짜 코스
  DateCourse? getCourseForDay(DateTime day) {
    return _coursesByDate[_key(day)];
  }

  /// 특정 날짜의 슬롯 리스트 (캘린더 eventLoader용)
  List<CourseSlot> getSlotsForDay(DateTime day) {
    return getCourseForDay(day)?.slots ?? [];
  }

  /// 모든 슬롯 (지도/리스트용)
  List<CourseSlot> getAllSlots() {
    final slots = <CourseSlot>[];
    for (final course in _coursesByDate.values) {
      slots.addAll(course.slots);
    }
    return slots;
  }

  List<DateCourse> getAllCourses() {
    return _coursesByDate.values.toList();
  }

  /// 백엔드에서 모든 코스 가져오기
  Future<void> fetchCoursesFromBackend() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final courses = await CourseApiService.getAllCourses();
      _coursesByDate.clear();
      for (final course in courses) {
        // DateCourse.date는 String이니까 DateTime으로 파싱 (YYYY-MM-DD or ISO 기준)
        final date = DateTime.parse(course.date);
        _coursesByDate[_key(date)] = course;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[CourseProvider] 코스 불러오기 실패: $e');
    }
  }

  /// 코스 생성 (하루 코스 전체)
  Future<void> createCourse(DateCourse course) async {
    try {
      final created = await CourseApiService.createCourse(course);
      final date = DateTime.parse(created.date);
      _coursesByDate[_key(date)] = created;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('[CourseProvider] 코스 생성 실패: $e');
      rethrow;
    }
  }

  /// 코스 수정 (전체 덮어쓰기)
  Future<void> updateCourse(DateCourse course) async {
    if (course.id == null) {
      throw Exception('코스 ID가 없습니다.');
    }
    try {
      final updated = await CourseApiService.updateCourse(course);
      final date = DateTime.parse(updated.date);
      _coursesByDate[_key(date)] = updated;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('[CourseProvider] 코스 수정 실패: $e');
      rethrow;
    }
  }

  /// 코스 삭제
  Future<void> deleteCourse(DateCourse course) async {
    if (course.id == null) return;
    try {
      await CourseApiService.deleteCourse(course.id!);
      final date = DateTime.parse(course.date);
      _coursesByDate.remove(_key(date));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('[CourseProvider] 코스 삭제 실패: $e');
      rethrow;
    }
  }
}
