import 'package:flutter/foundation.dart';

class Schedule {
  final DateTime date;
  final String title;
  final String time;
  Schedule({required this.date, required this.title, required this.time});
}

class ScheduleProvider extends ChangeNotifier {
  final Map<DateTime, List<Schedule>> _events = {};

  List<Schedule> getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void addEvent(DateTime day, String title, String time) {
    final key = DateTime.utc(day.year, day.month, day.day);
    _events.putIfAbsent(key, () => []);
    _events[key]!.add(Schedule(date: key, title: title, time: time));
    notifyListeners();
  }
}
