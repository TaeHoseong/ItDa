import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/persona_message.dart';
import '../services/persona_api_service.dart';

class PersonaChatProvider extends ChangeNotifier {
  final PersonaApiService _apiService;
  final List<PersonaMessage> _messages = [];
  bool _isSending = false;

  Map<String, dynamic>? _lastScheduleCreated;

  List<PersonaMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;

  /// 일정 생성 응답 (UI에서 SnackBar 띄우고 소비)
  Map<String, dynamic>? takeLastScheduleCreated() {
    final tmp = _lastScheduleCreated;
    _lastScheduleCreated = null;
    return tmp;
  }

  PersonaChatProvider._internal(this._apiService);

  factory PersonaChatProvider() {
    final sessionId = const Uuid().v4();
    final apiService = PersonaApiService(sessionId: sessionId);
    debugPrint('세션 ID: $sessionId');
    return PersonaChatProvider._internal(apiService);
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

      debugPrint('전송: $text (userId: $userId)');
      final response = await _apiService.sendMessage(text, userId: userId);

      // 기본 봇 메시지
      String botMessage = response['message'] ?? '응답을 받지 못했어요';

      // 장소 추천 처리
      if (response['action'] == 'recommend_place' &&
          response['data']?['places'] != null) {
        final places = response['data']['places'] as List<dynamic>;
        if (places.isNotEmpty) {
          final buffer = StringBuffer(botMessage);
          buffer.write('\n\n추천 장소:\n');

          for (int i = 0; i < places.length; i++) {
            final place = places[i];
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
      }

      // 일정 생성 처리 (UI에서는 SnackBar로)
      if (response['action'] == 'create_schedule' &&
          response['data']?['schedule'] != null) {
        _lastScheduleCreated = response['data']['schedule']
            as Map<String, dynamic>;
      }

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
    notifyListeners();
  }
}
