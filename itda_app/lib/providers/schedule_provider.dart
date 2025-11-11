import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/schedule_api_service.dart';

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

class Schedule {
  final int? id; // 백엔드 DB ID (null이면 로컬 전용)
  final DateTime date;
  final String title;
  final String time;

  // 장소 정보 (옵션)
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final String? address;

  Schedule({
    this.id,
    required this.date,
    required this.title,
    required this.time,
    this.placeName,
    this.latitude,
    this.longitude,
    this.address,
  });

  /// 장소 정보가 있는지 확인
  bool get hasPlace => latitude != null && longitude != null;

  /// JSON → Schedule 변환 (백엔드 응답용)
  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'],
      date: DateTime.parse(json['date']),
      title: json['title'],
      time: json['time'] ?? '',
      placeName: json['place_name'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      address: json['address'],
    );
  }

  /// Schedule → JSON 변환 (백엔드 전송용)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'time': time,
      if (placeName != null) 'place_name': placeName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null) 'address': address,
    };
  }
}

class ScheduleProvider extends ChangeNotifier {
  final Map<DateTime, List<Schedule>> _events = {};
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Schedule> getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  /// 모든 일정 반환 (지도 마커용)
  List<Schedule> getAllEvents() {
    final allEvents = <Schedule>[];
    for (final events in _events.values) {
      allEvents.addAll(events);
    }
    return allEvents;
  }

  /// 장소 정보가 있는 일정만 반환 (지도 마커용)
  List<Schedule> getEventsWithPlace() {
    return getAllEvents().where((e) => e.hasPlace).toList();
  }

  void addEvent(
    DateTime day,
    String title,
    String time, {
    String? placeName,
    double? latitude,
    double? longitude,
    String? address,
  }) {
    final key = DateTime.utc(day.year, day.month, day.day);
    _events.putIfAbsent(key, () => []);
    _events[key]!.add(Schedule(
      date: key,
      title: title,
      time: time,
      placeName: placeName,
      latitude: latitude,
      longitude: longitude,
      address: address,
    ));
    notifyListeners();
  }

  /// 백엔드에서 모든 일정 가져오기 (앱 시작 시 호출)
  Future<void> fetchSchedulesFromBackend() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final schedules = await ScheduleApiService.getAllSchedules();

      // 기존 일정 초기화
      _events.clear();

      // 백엔드 일정을 로컬에 추가
      for (final scheduleJson in schedules) {
        final schedule = Schedule.fromJson(scheduleJson);
        final key = DateTime.utc(
          schedule.date.year,
          schedule.date.month,
          schedule.date.day,
        );
        _events.putIfAbsent(key, () => []);
        _events[key]!.add(schedule);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[ScheduleProvider] 일정 불러오기 실패: $e');
    }
  }

  /// 백엔드에 일정 생성 + 로컬 추가
  Future<void> createScheduleWithBackend({
    required DateTime day,
    required String title,
    required String time,
    String? placeName,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      // 백엔드에 생성
      final createdSchedule = await ScheduleApiService.createSchedule(
        title: title,
        date: day,
        time: time,
        placeName: placeName,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      // 로컬에 추가 (백엔드 ID 포함)
      final schedule = Schedule.fromJson(createdSchedule);
      final key = DateTime.utc(day.year, day.month, day.day);
      _events.putIfAbsent(key, () => []);
      _events[key]!.add(schedule);
      notifyListeners();

      debugPrint('[ScheduleProvider] 일정 생성 성공: ${schedule.title}');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('[ScheduleProvider] 일정 생성 실패: $e');
      rethrow;
    }
  }

  /// 백엔드 일정 삭제 + 로컬 제거
  Future<void> deleteScheduleWithBackend(DateTime day, int index) async {
    final key = DateTime.utc(day.year, day.month, day.day);
    if (_events[key] == null || index < 0 || index >= _events[key]!.length) {
      return;
    }

    final schedule = _events[key]![index];

    // 백엔드 ID가 있으면 백엔드에서 삭제
    if (schedule.id != null) {
      try {
        await ScheduleApiService.deleteSchedule(schedule.id!);
        debugPrint('[ScheduleProvider] 백엔드 일정 삭제 성공: ${schedule.title}');
      } catch (e) {
        _error = e.toString();
        notifyListeners();
        debugPrint('[ScheduleProvider] 백엔드 삭제 실패: $e');
        rethrow;
      }
    }

    // 로컬에서 제거
    _events[key]!.removeAt(index);
    if (_events[key]!.isEmpty) {
      _events.remove(key);
    }
    notifyListeners();
  }

  /// 백엔드 일정 수정 + 로컬 업데이트
  Future<void> updateScheduleWithBackend({
    required DateTime day,
    required int index,
    required String title,
    required String time,
    String? placeName,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final key = DateTime.utc(day.year, day.month, day.day);
    if (_events[key] == null || index < 0 || index >= _events[key]!.length) {
      return;
    }

    final oldSchedule = _events[key]![index];

    // 백엔드 ID가 있으면 백엔드에서 수정
    if (oldSchedule.id != null) {
      try {
        final updatedSchedule = await ScheduleApiService.updateSchedule(
          scheduleId: oldSchedule.id!,
          title: title,
          date: day,
          time: time,
          placeName: placeName,
          latitude: latitude,
          longitude: longitude,
          address: address,
        );

        // 로컬 업데이트 (백엔드 응답 사용)
        _events[key]![index] = Schedule.fromJson(updatedSchedule);
        notifyListeners();

        debugPrint('[ScheduleProvider] 백엔드 일정 수정 성공: $title');
      } catch (e) {
        _error = e.toString();
        notifyListeners();
        debugPrint('[ScheduleProvider] 백엔드 수정 실패: $e');
        rethrow;
      }
    } else {
      // 백엔드 ID가 없으면 로컬만 수정
      _events[key]![index] = Schedule(
        date: key,
        title: title,
        time: time,
        placeName: placeName,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      notifyListeners();
    }
  }

  /// 특정 날짜의 특정 인덱스 일정 삭제
  void removeEvent(DateTime day, int index) {
    final key = DateTime.utc(day.year, day.month, day.day);
    if (_events[key] != null && index >= 0 && index < _events[key]!.length) {
      _events[key]!.removeAt(index);
      if (_events[key]!.isEmpty) {
        _events.remove(key);
      }
      notifyListeners();
    }
  }

  /// 특정 날짜의 특정 인덱스 일정 수정
  void updateEvent(
    DateTime day,
    int index,
    String title,
    String time, {
    String? placeName,
    double? latitude,
    double? longitude,
    String? address,
  }) {
    final key = DateTime.utc(day.year, day.month, day.day);
    if (_events[key] != null && index >= 0 && index < _events[key]!.length) {
      _events[key]![index] = Schedule(
        date: key,
        title: title,
        time: time,
        placeName: placeName,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      notifyListeners();
    }
  }
}
