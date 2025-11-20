import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

import '../models/date_course.dart';

/// =====================
/// 캘린더 상태 (보기 전용)
/// =====================
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

/// =====================
/// 코스 상태 + Supabase CRUD
/// =====================
class CourseProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  String? _currentCoupleId;

  /// couples.courses 에 들어있는 course_id 리스트
  List<String> _courseIds = [];

  /// course_id -> DateCourse
  final Map<String, DateCourse> _coursesById = {};

  bool _isLoading = false;
  String? _error;

  RealtimeChannel? _coupleChannel;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get coupleId => _currentCoupleId;

  List<String> get courseIds => List.unmodifiable(_courseIds);
  List<DateCourse> get allCourses => _coursesById.values.toList();

  DateCourse? getCourseById(String id) => _coursesById[id];

  /// 특정 날짜의 코스들
  List<DateCourse> getCoursesByDate(DateTime day) {
    final key = _dateKey(day);
    return allCourses.where((c) => c.date == key).toList();
  }

  /// 특정 날짜의 모든 슬롯 (캘린더 eventLoader 용)
  List<CourseSlot> getSlotsForDay(DateTime day) {
    final key = _dateKey(day);
    return allCourses
        .where((c) => c.date == key)
        .expand((c) => c.slots)
        .toList();
  }

  /// 모든 슬롯 (지도/리스트용)
  List<CourseSlot> getAllSlots() {
    return allCourses.expand((c) => c.slots).toList();
  }

  /// 로그인 이후 커플 기준 초기화
  Future<void> initForCouple(String coupleId) async {
    // 이미 같은 커플 + 데이터가 있으면 스킵
    if (_currentCoupleId == coupleId && _coursesById.isNotEmpty) return;

    _currentCoupleId = coupleId;
    _courseIds = [];
    _coursesById.clear();

    await _subscribeCoupleCourses();
    await _loadCoupleCoursesOnce();
  }

  /// 수동 새로고침(필요할 때 호출)
  Future<void> refreshCourses() async {
    await _loadCoupleCoursesOnce();
  }

  // =====================
  // 내부 헬퍼
  // =====================

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  void _ensureCouple() {
    if (_currentCoupleId == null || _currentCoupleId!.isEmpty) {
      throw StateError('CourseProvider: coupleId가 설정되지 않았습니다. initForCouple()를 먼저 호출하세요.');
    }
  }

  Future<void> _loadCoupleCoursesOnce() async {
    // _ensureCouple();

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await supabase
          .from('couples')
          .select('courses')
          .eq('couple_id', _currentCoupleId!)
          .maybeSingle();

      if (res == null) {
        _courseIds = [];
        _coursesById.clear();
        _isLoading = false;
        notifyListeners();
        return;
      }

      final List<dynamic> raw = res['courses'] ?? [];
      _courseIds = raw.cast<String>();

      await _loadCoursesForIds(_courseIds);

      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[CourseProvider] _loadCoupleCoursesOnce 오류: $e\n$st');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCoursesForIds(List<String> ids) async {
    if (ids.isEmpty) {
      _coursesById.clear();
      return;
    }

    final rows = await supabase
    .from('courses')
    .select(
      'course_id, couple_id, date, template, start_time, end_time, '
      'total_distance, total_duration, course',
    )
    .filter('course_id', 'in', ids);

    _coursesById.clear();

    for (final row in rows as List) {
      final base = row as Map<String, dynamic>;
      final courseJson = Map<String, dynamic>.from(base['course'] ?? {});

      // meta 필드 합치기
      courseJson['course_id'] = base['course_id'];
      courseJson['date'] = base['date'];
      courseJson['template'] = base['template'];
      courseJson['start_time'] = base['start_time'];
      courseJson['end_time'] = base['end_time'];
      courseJson['total_distance'] = base['total_distance'];
      courseJson['total_duration'] = base['total_duration'];

      final dc = DateCourse.fromJson(courseJson);
      if (dc.id != null) {
        _coursesById[dc.id!] = dc;
      }
    }
  }

  Future<void> _subscribeCoupleCourses() async {
    await _coupleChannel?.unsubscribe();

    if (_currentCoupleId == null || _currentCoupleId!.isEmpty) return;

    _coupleChannel = supabase
        .channel('public:couples:${_currentCoupleId!}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'couples',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: _currentCoupleId!,
          ),
          callback: (payload) async {
            try {
              final newCourses =
                  payload.newRecord['courses'] as List<dynamic>? ?? [];
              final newIds = newCourses.cast<String>();

              if (!listEquals(_courseIds, newIds)) {
                _courseIds = newIds;
                await _loadCoursesForIds(_courseIds);
                notifyListeners();
              }
            } catch (e, st) {
              debugPrint('[CourseProvider] realtime payload 처리 오류: $e\n$st');
            }
          },
        )
        .subscribe();
  }

  // =====================
  // CRUD (Supabase 직접 호출)
  // =====================

  /// 코스 생성 (슬롯 포함 전체)
  Future<DateCourse> createCourse(DateCourse course) async {
    // _ensureCouple();

    try {
      final String newId = course.id ?? const Uuid().v4();

      // course.toJson() 안에 course_id가 들어가도록
      final courseJson = course.toJson()
        ..['course_id'] = newId;

      /*
        여기 손 볼 필요 있어보임 
        일단 course가 아니라 slots으로 들어가고, user_id도 같이 저장하게 되어있어서 추가해줘야될듯?
        (일단 지금은 nullable허용해두고 primary key도 해제해 둠) >> 근데 이래도 nullable 에러 떠서 추가가 안 됨.
        내 브랜치에 있는 코드 기준으로 추가되는거 확인됐어서 이거만 해결하면 정상 작동 될 듯 합니다. 
        -호성
      */ 
      final row = {
        'course_id': newId,
        'couple_id': _currentCoupleId,
        'date': course.date,
        'template': course.template,
        'start_time': course.startTime,
        'end_time': course.endTime,
        'total_distance': course.totalDistance,
        'total_duration': course.totalDuration,
        'course': courseJson,
      };

      final inserted = await supabase
          .from('courses')
          .insert(row)
          .select()
          .single();

      // couples.courses 배열에 추가
      final updatedIds = [..._courseIds, newId];
      _courseIds = updatedIds; // 미리 반영 (realtime payload와 맞추기)

      await supabase
          .from('couples')
          .update({'courses': updatedIds})
          .eq('couple_id', _currentCoupleId!);

      // Supabase에서 돌아온 row를 다시 DateCourse로
      final insertedJson =
          Map<String, dynamic>.from(inserted['course'] ?? {});
      insertedJson['course_id'] = inserted['course_id'];
      insertedJson['date'] = inserted['date'];
      insertedJson['template'] = inserted['template'];
      insertedJson['start_time'] = inserted['start_time'];
      insertedJson['end_time'] = inserted['end_time'];
      insertedJson['total_distance'] = inserted['total_distance'];
      insertedJson['total_duration'] = inserted['total_duration'];

      final created = DateCourse.fromJson(insertedJson);

      _coursesById[newId] = created;
      notifyListeners();

      return created;
    } catch (e, st) {
      debugPrint('[CourseProvider] createCourse 실패: $e\n$st');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 코스 전체 수정 (덮어쓰기)
  Future<DateCourse> updateCourse(DateCourse course) async {
    // _ensureCouple();

    if (course.id == null) {
      throw Exception('코스 ID가 없습니다.');
    }

    try {
      final id = course.id!;
      final courseJson = course.toJson()
        ..['course_id'] = id;

      final updateRow = {
        'date': course.date,
        'template': course.template,
        'start_time': course.startTime,
        'end_time': course.endTime,
        'total_distance': course.totalDistance,
        'total_duration': course.totalDuration,
        'course': courseJson,
      };

      final updated = await supabase
          .from('courses')
          .update(updateRow)
          .eq('course_id', id)
          .select()
          .single();

      final updatedJson =
          Map<String, dynamic>.from(updated['course'] ?? {});
      updatedJson['course_id'] = updated['course_id'];
      updatedJson['date'] = updated['date'];
      updatedJson['template'] = updated['template'];
      updatedJson['start_time'] = updated['start_time'];
      updatedJson['end_time'] = updated['end_time'];
      updatedJson['total_distance'] = updated['total_distance'];
      updatedJson['total_duration'] = updated['total_duration'];

      final dc = DateCourse.fromJson(updatedJson);
      _coursesById[id] = dc;
      notifyListeners();

      return dc;
    } catch (e, st) {
      debugPrint('[CourseProvider] updateCourse 실패: $e\n$st');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// 코스 삭제
  Future<void> deleteCourse(DateCourse course) async {
    // _ensureCouple();

    if (course.id == null) return;

    try {
      final id = course.id!;

      await supabase
          .from('courses')
          .delete()
          .eq('course_id', id);

      final updatedIds = _courseIds.where((c) => c != id).toList();
      _courseIds = updatedIds;

      await supabase
          .from('couples')
          .update({'courses': updatedIds})
          .eq('couple_id', _currentCoupleId!);

      _coursesById.remove(id);
      notifyListeners();
    } catch (e, st) {
      debugPrint('[CourseProvider] deleteCourse 실패: $e\n$st');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // =====================
  // 정리
  // =====================

  @override
  void dispose() {
    _coupleChannel?.unsubscribe();
    super.dispose();
  }
}
