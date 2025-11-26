// lib/providers/course_provider.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

import '../models/date_course.dart';
import '../services/feedback_api_service.dart';

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
/// 슬롯별 일기 모델 (서버에 저장되는 형태)
/// =====================
class DiarySlotEntry {
  final String placeName;
  final String? address;
  final int rating;      // 0~5
  final String comment;  // 한줄평
  final String? imageUrl; // Supabase Storage public URL

  const DiarySlotEntry({
    required this.placeName,
    this.address,
    this.rating = 0,
    this.comment = '',
    this.imageUrl,
  });

  DiarySlotEntry copyWith({
    String? placeName,
    String? address,
    int? rating,
    String? comment,
    String? imageUrl,
  }) {
    return DiarySlotEntry(
      placeName: placeName ?? this.placeName,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory DiarySlotEntry.fromJson(Map<String, dynamic> json) {
    return DiarySlotEntry(
      placeName: json['place_name'] ?? '',
      address: json['address'],
      rating: (json['rating'] ?? 0) as int,
      comment: json['comment'] ?? '',
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'place_name': placeName,
      'address': address,
      'rating': rating,
      'comment': comment,
      'image_url': imageUrl,
    };
  }
}

/// =====================
/// 코스 상태 + Supabase CRUD + Diary CRUD
/// =====================
class CourseProvider extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  String? _currentCoupleId;

  /// couples.schedules 에 들어있는 course_id 리스트
  List<String> _courseIds = [];

  /// course_id -> DateCourse
  final Map<String, DateCourse> _coursesById = {};

  /// course_id -> DiarySlotEntry 리스트 (슬롯 순서와 동일)
  final Map<String, List<DiarySlotEntry>> _diariesByCourseId = {};

  bool _isLoading = false;
  String? _error;

  RealtimeChannel? _coupleChannel;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get coupleId => _currentCoupleId;

  List<String> get courseIds => List.unmodifiable(_courseIds);
  List<DateCourse> get allCourses => _coursesById.values.toList();

  DateCourse? getCourseById(String id) => _coursesById[id];

  /// 특정 코스의 diary 전체 (슬롯 순서대로)
  List<DiarySlotEntry>? getDiaryForCourse(String courseId) =>
      _diariesByCourseId[courseId];

  /// 특정 코스의 특정 슬롯 diary
  DiarySlotEntry? getDiarySlot(String courseId, int slotIndex) {
    final list = _diariesByCourseId[courseId];
    if (list == null || slotIndex < 0 || slotIndex >= list.length) return null;
    return list[slotIndex];
  }

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
    _diariesByCourseId.clear();

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
      throw StateError(
        'CourseProvider: coupleId가 설정되지 않았습니다. initForCouple()를 먼저 호출하세요.',
      );
    }
  }

  Future<void> _loadCoupleCoursesOnce() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await supabase
          .from('couples')
          .select('schedules')
          .eq('couple_id', _currentCoupleId!)
          .maybeSingle();
      debugPrint('[DEBUG] couples.schedules 응답: $res');
      if (res == null) {
        _courseIds = [];
        _coursesById.clear();
        _diariesByCourseId.clear();
        _isLoading = false;
        notifyListeners();
        return;
      }

      final List<dynamic> raw = res['schedules'] ?? [];
      _courseIds = raw.cast<String>();

      await _loadCoursesForIds(_courseIds);
      await _loadDiariesForIds(_courseIds);

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
          'total_distance, total_duration, slots',
        )
        .filter('course_id', 'in', ids);
    _coursesById.clear();

    for (final row in rows as List) {
      final base = row as Map<String, dynamic>;

      // date 필드를 YYYY-MM-DD 형식으로 normalize
      String normalizedDate = base['date'];
      if (normalizedDate.contains('T')) {
        // ISO 8601 형식이면 날짜 부분만 추출
        normalizedDate = normalizedDate.split('T')[0];
      }

      // slots 필드로 DateCourse 구성
      final courseJson = {
        'course_id': base['course_id'],
        'date': normalizedDate,
        'template': base['template'],
        'start_time': base['start_time'],
        'end_time': base['end_time'],
        'total_distance': base['total_distance'],
        'total_duration': base['total_duration'],
        'slots': base['slots'] ?? [],
      };
      debugPrint('[DEBUG] courseJson: $courseJson');
      try {
        final dc = DateCourse.fromJson(courseJson);
        if (dc.id != null) {
          _coursesById[dc.id!] = dc;
        }
      } catch (e, stackTrace) {
        debugPrint('[CourseProvider] 코스 파싱 실패: $e\n$stackTrace');
      }
    }
  }

  /// diary 테이블에서 여러 course_id의 일기 로딩
  Future<void> _loadDiariesForIds(List<String> ids) async {
    if (ids.isEmpty) {
      _diariesByCourseId.clear();
      return;
    }

    final rows =
        await supabase.from('diary').select('course_id, json').filter(
              'course_id',
              'in',
              ids,
            );

    _diariesByCourseId.clear();

    for (final row in rows as List) {
      final base = row as Map<String, dynamic>;
      final courseId = base['course_id'] as String;
      final jsonData = base['json'];

      if (jsonData == null) continue;

      // json 필드가 리스트로 직접 저장됨
      final slotsList = jsonData is List ? jsonData : (jsonData['slots'] as List<dynamic>? ?? []);
      final slots = slotsList
          .map((e) => DiarySlotEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      _diariesByCourseId[courseId] = slots;
    }
  }

  Future<void> _subscribeCoupleCourses() async {
    await _coupleChannel?.unsubscribe();

    if (_currentCoupleId == null || _currentCoupleId!.isEmpty) return;

    debugPrint('[REALTIME] 구독 시작: couples:${_currentCoupleId!}');
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
            debugPrint('-----------------------------');
            debugPrint('[REALTIME] UPDATE 이벤트 도착!');
            debugPrint('[REALTIME] old record: ${payload.oldRecord}');
            debugPrint('[REALTIME] new record: ${payload.newRecord}');
            debugPrint('-----------------------------');
            try {
              final newCourses =
                  payload.newRecord['schedules'] as List<dynamic>? ?? [];
              debugPrint('[REALTIME] new schedules: $newCourses');
              final newIds = newCourses.cast<String>();

              debugPrint('[REALTIME] 기존 courseIds   → $_courseIds');
              debugPrint('[REALTIME] 새로 들어온 newIds → $newIds');

              if (!listEquals(_courseIds, newIds)) {
                debugPrint('[REALTIME] 값 변경됨 → courses + diary 다시 로드');
                _courseIds = newIds;
                await _loadCoursesForIds(_courseIds);
                await _loadDiariesForIds(_courseIds);
                notifyListeners();
              } else {
                debugPrint('[REALTIME] ⚠ 값 동일 → 업데이트 없이 종료');
              }
            } catch (e, st) {
              debugPrint('[CourseProvider] realtime payload 처리 오류: $e\n$st');
            }
          },
        )
        .subscribe();
  }

  // =====================
  // 코스 CRUD
  // =====================

  /// 코스 생성 (슬롯 포함 전체)
  Future<DateCourse> createCourse(DateCourse course) async {
    // _ensureCouple();

    try {
      final String newId = course.id ?? const Uuid().v4();

      // user_id 가져오기 (FlutterSecureStorage에서)
      const storage = FlutterSecureStorage();
      final userId = await storage.read(key: 'user_id');

      final row = {
        'course_id': newId,
        'user_id': userId,
        'couple_id': _currentCoupleId,
        'date': course.date,
        'template': course.template,
        'start_time': course.startTime,
        'end_time': course.endTime,
        'total_distance': course.totalDistance,
        'total_duration': course.totalDuration,
        'slots': course.slots.map((s) => s.toJson()).toList(),
      };

      final inserted =
          await supabase.from('courses').insert(row).select().single();

      String normalizedDate = inserted['date'];
      if (normalizedDate.contains('T')) {
        normalizedDate = normalizedDate.split('T').first;
      }

      // couples.schedules 배열에 추가
      final updatedIds = [..._courseIds, newId];

      await supabase
          .from('couples')
          .update({'schedules': updatedIds})
          .eq('couple_id', _currentCoupleId!);

      // Supabase에서 돌아온 row를 다시 DateCourse로
      final insertedJson = {
        'course_id': inserted['course_id'],
        'date': normalizedDate,
        'template': inserted['template'],
        'start_time': inserted['start_time'],
        'end_time': inserted['end_time'],
        'total_distance': inserted['total_distance'],
        'total_duration': inserted['total_duration'],
        'slots': inserted['slots'] ?? [],
      };

      final created = DateCourse.fromJson(insertedJson);

      _coursesById[newId] = created;
      _courseIds = updatedIds;
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

      final updateRow = {
        'date': course.date,
        'template': course.template,
        'start_time': course.startTime,
        'end_time': course.endTime,
        'total_distance': course.totalDistance,
        'total_duration': course.totalDuration,
        'slots': course.slots.map((s) => s.toJson()).toList(),
      };

      final updated = await supabase
          .from('courses')
          .update(updateRow)
          .eq('course_id', id)
          .select()
          .single();

      String normalizedDate = updated['date'];
      if (normalizedDate.contains('T')) {
        normalizedDate = normalizedDate.split('T').first;
      }

      final updatedJson = {
        'course_id': updated['course_id'],
        'date': normalizedDate,
        'template': updated['template'],
        'start_time': updated['start_time'],
        'end_time': updated['end_time'],
        'total_distance': updated['total_distance'],
        'total_duration': updated['total_duration'],
        'slots': updated['slots'] ?? [],
      };

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

      // 코스 삭제
      await supabase.from('courses').delete().eq('course_id', id);

      // 이 코스에 연결된 일기도 같이 삭제
      await deleteDiaryForCourse(id);

      // couples.schedules 갱신
      final updatedIds = _courseIds.where((c) => c != id).toList();
      _courseIds = updatedIds;

      await supabase
          .from('couples')
          .update({'schedules': updatedIds})
          .eq('couple_id', _currentCoupleId!);

      _coursesById.remove(id);
      // _diariesByCourseId.remove(id);  // deleteDiaryForCourse에서 이미 처리
      notifyListeners();
    } catch (e, st) {
      debugPrint('[CourseProvider] deleteCourse 실패: $e\n$st');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // =====================
  // Diary CRUD + 사진 업로드
  // =====================

  /// Supabase Storage에 일기용 사진 업로드
  /// bucket 이름은 'diary'라고 가정
  Future<String?> uploadDiaryImage({
    required String courseId,
    required int slotIndex,
    required File file,
  }) async {
    _ensureCouple();

    final ext = file.path.split('.').last;
    final path = 'diary/${_currentCoupleId}/$courseId/slot_$slotIndex.$ext';

    await supabase.storage
        .from('diary')
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    final url = supabase.storage.from('diary').getPublicUrl(path);
    return url;
  }

  /// 한 코스에 대한 diary upsert (슬롯 리스트 전체)
  Future<void> upsertDiaryForCourse({
    required DateCourse course,
    required List<DiarySlotEntry> slots,
  }) async {
    _ensureCouple();
    if (course.id == null) {
      throw Exception('Diary 저장 실패: course.id가 없습니다.');
    }

    final courseId = course.id!;
    final jsonList = slots.map((e) => e.toJson()).toList();

    await supabase.from('diary').upsert({
      'course_id': courseId,
      'couple_id': _currentCoupleId,
      'template': course.template,
      'json': jsonList,
    });

    _diariesByCourseId[courseId] = slots;
    notifyListeners();

    // 피드백 학습: 별점 기반 커플 페르소나 업데이트
    FeedbackApiService.recalculatePersona();
  }

  /// 한 코스의 diary 삭제
  Future<void> deleteDiaryForCourse(String courseId) async {
    await supabase.from('diary').delete().eq('course_id', courseId);
    _diariesByCourseId.remove(courseId);
    notifyListeners();

    // 피드백 학습: 일기 삭제 시 페르소나 재계산 (원래대로 복원)
    FeedbackApiService.recalculatePersona();
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
