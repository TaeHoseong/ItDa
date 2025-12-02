// persona_chat_provider.dart
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/persona_message.dart';
import '../models/date_course.dart';
import '../services/persona_api_service.dart';
import '../services/location_service.dart';
import 'course_provider.dart';

class PersonaChatProvider extends ChangeNotifier {
  final PersonaApiService _apiService;
  final CourseProvider? _courseProvider;
  final List<PersonaMessage> _messages = [];
  bool _isSending = false;

  Map<String, dynamic>? _lastScheduleCreated;

  /// 추천받은 장소 목록 저장 (UI에서 접근용)
  List<Map<String, dynamic>>? _lastRecommendedPlaces;

  /// 마지막 메시지가 추천 의도였는지 플래그
  bool _lastMessageWasRecommendation = false;

  /// 생성된 데이트 코스
  DateCourse? _lastGeneratedCourse;

  List<PersonaMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  List<Map<String, dynamic>>? get lastRecommendedPlaces =>
      _lastRecommendedPlaces;
  bool get shouldShowPlaceCards =>
      _lastMessageWasRecommendation &&
      _lastRecommendedPlaces != null &&
      _lastRecommendedPlaces!.isNotEmpty;
  DateCourse? get lastGeneratedCourse => _lastGeneratedCourse;

  /// 일정 생성 응답 (UI에서 SnackBar 띄우고 소비)
  Map<String, dynamic>? takeLastScheduleCreated() {
    final tmp = _lastScheduleCreated;
    _lastScheduleCreated = null;
    return tmp;
  }

  PersonaChatProvider._internal(this._apiService, this._courseProvider);

  factory PersonaChatProvider() {
    final sessionId = const Uuid().v4();
    final apiService = PersonaApiService(sessionId: sessionId);
    debugPrint('세션 ID: $sessionId');
    return PersonaChatProvider._internal(apiService, null);
  }

  factory PersonaChatProvider.withCourseProvider(CourseProvider courseProvider) {
    final sessionId = const Uuid().v4();
    final apiService = PersonaApiService(sessionId: sessionId);
    debugPrint('세션 ID: $sessionId (with CourseProvider)');
    return PersonaChatProvider._internal(apiService, courseProvider);
  }

  void _addMessage({
    required String text,
    required PersonaSender sender,
  }) {
    _messages.add(
      PersonaMessage(
        id: const Uuid().v4(),
        text: text,
        sender: sender,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> sendUserMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _isSending) return;

    // 유저 메시지 추가
    _addMessage(text: text, sender: PersonaSender.user);

    _isSending = true;
    notifyListeners();

    try {
      // 저장된 user_id 가져오기 (사용자별 맞춤 추천용)
      const storage = FlutterSecureStorage();
      final userId = await storage.read(key: 'user_id');

      // GPS 위치 가져오기 (공통 서비스 사용)
      final position = await LocationService.getCurrentPosition();

      debugPrint('전송: $text (userId: $userId, lat: ${position?.latitude}, lng: ${position?.longitude})');
      final response = await _apiService.sendMessage(
        text,
        userId: userId,
        userLat: position?.latitude,
        userLng: position?.longitude,
      );

      debugPrint(
          '📥 백엔드 응답: action=${response['action']}, message=${response['message']}');
      if (response['data'] != null) {
        debugPrint('   data keys: ${response['data'].keys}');
      }

      // 기본 봇 메시지
      String botMessage = response['message'] ?? '응답을 받지 못했어요';

      // ===== 장소 추천 처리 =====
      if ((response['action'] == 'recommend_place' ||
              response['action'] == "re_recommend_place") &&
          response['data']?['places'] != null) {
        final places = response['data']['places'] as List<dynamic>;
        if (places.isNotEmpty) {
          // 장소 목록 저장 (UI에서 버튼 표시용)
          _lastRecommendedPlaces =
              List<Map<String, dynamic>>.from(places as List);
          _lastMessageWasRecommendation = true; // 추천 의도 플래그 설정

          final buffer = StringBuffer(botMessage);
          buffer.write('\n\n추천 장소:\n');

          for (int i = 0; i < places.length; i++) {
            final place = places[i] as Map<String, dynamic>;
            final name = place['name'] ?? '이름 없음';
            final score = (place['score'] ?? 0.0) as num;
            final address = place['address'] ?? '';

            buffer.write('\n${i + 1}. $name');
            if (address.isNotEmpty) {
              buffer.write('\n$address');
            }
            buffer.write(
                '\n   ⭐ 추천도: ${(score * 100).toStringAsFixed(0)}%\n');
          }

          botMessage = buffer.toString();
        }
      } else {
        // 추천이 아닌 다른 액션이면 플래그 초기화
        _lastMessageWasRecommendation = false;
      }

      // ===== 데이트 코스 생성 처리 =====
      if (response['action'] == 'generate_course' &&
          response['data']?['course'] != null) {
        try {
          final courseData =
              response['data']['course'] as Map<String, dynamic>;
          _lastGeneratedCourse = DateCourse.fromJson(courseData);
          debugPrint(
              '✅ 데이트 코스 생성됨: ${_lastGeneratedCourse!.slots.length}개 슬롯');
        } catch (e) {
          debugPrint('❌ 코스 파싱 오류: $e');
        }
      } else if (response['action'] == 'regenerate_course_slot' &&
          response['data']?['course'] != null) {
        // 슬롯 재생성 처리
        try {
          final courseData =
              response['data']['course'] as Map<String, dynamic>;
          _lastGeneratedCourse = DateCourse.fromJson(courseData);
          debugPrint(
              '✅ 슬롯 재생성됨: ${response['data']?['slot_index']}번');
        } catch (e) {
          debugPrint('❌ 슬롯 재생성 파싱 오류: $e');
        }
      } else if (response['action'] != 'recommend_place' &&
          response['action'] != 're_recommend_place' &&
          response['action'] != 'select_place') {
        // 코스/장소 관련 액션이 아니면 초기화
        _lastGeneratedCourse = null;
      }

      // ===== 일정 생성 처리 → 이제 DateCourse로 저장 =====
      final actionTaken = response['data']?['action_taken'];
      if (actionTaken == 'schedule_ready' &&
          response['data']?['schedule_data'] != null &&
          _courseProvider != null) {
        final scheduleData =
            response['data']['schedule_data'] as Map<String, dynamic>;

        try {
          // 날짜 파싱 (YYYY-MM-DD 형식 가정)
          final dateStr = scheduleData['date'] as String;
          final date = DateTime.parse(dateStr);

          final normalizedDateString =
              '${date.year.toString().padLeft(4, '0')}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}';

          final title = scheduleData['title'] as String? ?? '일정';
          final timeStr = scheduleData['time'] as String? ?? '';

          // 하나의 슬롯으로 이루어진 코스로 저장
          final lat = scheduleData['latitude'] as num?;
          final lng = scheduleData['longitude'] as num?;

          if (lat == null || lng == null) {
            debugPrint(
                '⚠️ schedule_data에 latitude/longitude가 없어 코스로 저장하지 않습니다.');
          } else {
            final slot = CourseSlot(
              slotType: 'persona',
              emoji: '💌',
              startTime: timeStr,
              duration: 60, // 기본 60분
              placeName:
                  scheduleData['place_name'] as String? ?? title,
              placeAddress: scheduleData['address'] as String?,
              latitude: lat.toDouble(),
              longitude: lng.toDouble(),
              rating: null,
              score: 0,
              distanceFromPrevious: null,
            );

            final course = DateCourse(
              // id 는 백엔드에서 생성되므로 여기선 생략
              date: normalizedDateString,
              template: 'persona_schedule',
              startTime: timeStr,
              endTime: timeStr,
              totalDistance: 0,
              totalDuration: slot.duration,
              slots: [slot],
            );

            await _courseProvider!.createCourse(course);

            debugPrint('✅ 일정이 코스로 저장되고 CourseProvider에 추가됨');
            _lastScheduleCreated = scheduleData;
          }
        } catch (e) {
          debugPrint('⚠️ 코스 생성/저장 중 오류: $e');
          _addMessage(
            text: '일정을 저장하는 중 문제가 발생했어요. 다시 시도해주세요.',
            sender: PersonaSender.bot,
          );
        }
      }

      // 최종 봇 메시지 추가
      _addMessage(text: botMessage, sender: PersonaSender.bot);
    } catch (e, st) {
      debugPrint('PersonaChatProvider 오류: $e');
      debugPrint('$st');

      _addMessage(
        text: '죄송해요, 오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
        sender: PersonaSender.bot,
      );
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    _lastScheduleCreated = null;
    _lastRecommendedPlaces = null;
    _lastMessageWasRecommendation = false;
    _lastGeneratedCourse = null;
    notifyListeners();
  }
}
