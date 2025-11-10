// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _TableBasicsExampleState();
}

class _TableBasicsExampleState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  // 현재 캘린더 형식 (월/2주/주). 기본은 월.

  DateTime _focusedDay = DateTime.now();
  // 현재 포커스 되어 있는 날짜 (페이지 전환 시 기준 날짜).

  DateTime? _selectedDay;
  // 사용자가 선택한 날짜.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TableCalendar - Basics'),
      ),
      body: TableCalendar(
        firstDay: kFirstDay,
        lastDay: kLastDay,
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,

        // 어떤 날이 선택 상태로 보일지 결정
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },

        // 날짜 선택 시 호출
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          }
        },

        // 포맷 변경 시 호출 (month <-> week 등)
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },

        // 페이지(월) 변경 시 호출
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }
}

/// ✅ TableCalendar에서 사용할 날짜 범위 정의
/// 공식 예제처럼 전역 상수로 두면 된다.
final DateTime kFirstDay = DateTime.utc(2010, 1, 1);
final DateTime kLastDay = DateTime.utc(2030, 12, 31);
