import 'package:flutter/foundation.dart';

class Schedule {
  final DateTime date;
  final String title;
  final String time;

  // 장소 정보 (옵션)
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final String? address;

  Schedule({
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
}

class ScheduleProvider extends ChangeNotifier {
  final Map<DateTime, List<Schedule>> _events = {};

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
}
