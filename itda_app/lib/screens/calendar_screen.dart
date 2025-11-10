import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/schedule_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = context.watch<ScheduleProvider>();
    final selectedEvents = scheduleProvider.getEventsForDay(_selectedDay!);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F5),
        elevation: 0,
        title: const Text('달력'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildCalendar(),
          const SizedBox(height: 8),
          _buildSelectedDateSection(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  ...selectedEvents.map((e) => _EventTile(e.title, e.time)),
                  const SizedBox(height: 8),
                  _AddEventButton(
                    onTap: () {
                      scheduleProvider.addEvent(
                        _selectedDay!,
                        "새로운 나들이",
                        "3:00 PM",
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TableCalendar(
        locale: 'ko_KR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        headerVisible: true,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextFormatter: (date, locale) =>
              '${date.month}월 ${date.year}',
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          rightChevronIcon: const Icon(Icons.arrow_right),
          leftChevronIcon: const Icon(Icons.arrow_left),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Colors.black54),
          weekendStyle: TextStyle(color: Color(0xFFFF6B6B)),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            border: Border.all(color: Colors.black54),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: Color(0xFFFFB6B6),
            shape: BoxShape.circle,
          ),
          outsideDaysVisible: false,
        ),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
      ),
    );
  }

  Widget _buildSelectedDateSection() {
    final day = _selectedDay!;
    final weekdayName = ['월', '화', '수', '목', '금', '토', '일'][day.weekday - 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${day.year}년 ${day.month}월 ${day.day}일 ($weekdayName)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E1E1E),
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final String title;
  final String time;
  const _EventTile(this.title, this.time);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            time,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.send_rounded, size: 20, color: Colors.black87),
        ],
      ),
    );
  }
}

class _AddEventButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddEventButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.black54),
            SizedBox(width: 6),
            Text(
              '새로운 나들이',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
