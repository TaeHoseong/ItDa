import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// 📅 CalendarProvider
/// TableCalendar의 상태(선택 날짜, 포커스 날짜, 형식)를 Provider로 분리한 버전.
/// 다른 위젯에서도 손쉽게 접근/변경 가능.
class CalendarProvider extends ChangeNotifier {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // ========== Getter ==========
  CalendarFormat get calendarFormat => _calendarFormat;
  DateTime get focusedDay => _focusedDay;
  DateTime? get selectedDay => _selectedDay;

  // ========== Setter ==========

  /// 선택된 날짜를 변경
  void selectDay(DateTime selected, DateTime focused) {
    if (!isSameDay(_selectedDay, selected)) {
      _selectedDay = selected;
      _focusedDay = focused;
      notifyListeners();
    }
  }

  /// 달력 형식 변경 (month/week/2weeks)
  void changeFormat(CalendarFormat format) {
    if (_calendarFormat != format) {
      _calendarFormat = format;
      notifyListeners();
    }
  }

  /// 페이지 변경 시 포커스 날짜 갱신
  void updateFocusedDay(DateTime day) {
    _focusedDay = day;
    // setState 불필요 → notifyListeners() 호출 안 해도 무방하지만
    // 다른 위젯에서 이 값이 필요하다면 notifyListeners() 해도 됨.
  }
}
