import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  final SupabaseClient _supabase;

  ChatProvider(this._supabase);

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  String? _currentUserId; // UserProvider의 AppUser에서 가져옴
  String? _coupleId;      // UserProvider의 AppUser에서 가져옴

  RealtimeChannel? _channel;

  // ===== getters =====
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  String? get coupleId => _coupleId;

  bool isMine(ChatMessage msg) => msg.senderId == _currentUserId;

  /// UserProvider(AppUser)의 정보로 ChatProvider를 설정
  /// - userId: 보낸 사람 판별용
  /// - coupleId: 어떤 커플 방인지
  ///
  /// coupleId가 바뀌면:
  /// - Realtime 구독 다시 설정
  /// - 메시지 다시 로딩
  void configure({
    required String? userId,
    required String? coupleId,
  }) {
    final hasCoupleChanged = _coupleId != coupleId;

    _currentUserId = userId;
    _coupleId = coupleId;

    if (!hasCoupleChanged) return;

    _unsubscribeRealtime();

    if (_coupleId == null) {
      _messages = [];
      notifyListeners();
      return;
    }

    // 커플이 세팅되면 메시지 로딩 + Realtime 구독
    loadMessages();
    _subscribeRealtime();
  }

  // ===== 초기 로딩: couples.chat_history 읽어오기 =====
  Future<void> loadMessages() async {
    if (_coupleId == null) {
      _error = '커플 정보가 없습니다. 매칭이 먼저 필요합니다.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _supabase
          .from('couples')
          .select('chat_history')
          .eq('couple_id', _coupleId!)
          .maybeSingle();

      if (res == null) {
        _messages = [];
      } else {
        final raw = res['chat_history'] as List<dynamic>? ?? [];
        _messages = raw
            .map(
              (e) => ChatMessage.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      }
    } catch (e) {
      _error = '채팅 불러오기 실패: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== 메시지 전송: chat_history 배열 업데이트 =====
  Future<void> send(String content) async {
    if (_coupleId == null) {
      _error = '커플 정보가 없습니다.';
      notifyListeners();
      return;
    }
    if (_currentUserId == null) {
      _error = '로그인 정보가 없습니다.';
      notifyListeners();
      return;
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    _isSending = true;
    notifyListeners();

    try {
      final now = DateTime.now().toUtc();

      final newMessage = ChatMessage(
        id: '${now.microsecondsSinceEpoch}_${_currentUserId!}',
        senderId: _currentUserId!,
        content: trimmed,
        createdAt: now,
      );

      // 1) 로컬에서 먼저 추가 (낙관적 업데이트)
      _messages = [..._messages, newMessage];
      notifyListeners();

      // 2) Supabase에 chat_history 전체 업데이트
      final payload = _messages.map((m) => m.toJson()).toList();

      await _supabase
          .from('couples')
          .update({'chat_history': payload})
          .eq('couple_id', _coupleId!);

      // 여기서는 굳이 다시 select 안 해도 됨.
      // 위 update가 성공하면 Realtime update 이벤트가 날아와서
      // _onRealtimeUpdate에서 chat_history를 다시 세팅해줄 거야.

      _error = null;
    } catch (e) {
      _error = '메시지 전송 실패: $e';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // ===== Realtime 구독 설정 =====
  void _subscribeRealtime() {
    if (_coupleId == null) return;

    // 혹시 기존 구독이 남아있으면 해제
    _unsubscribeRealtime();

    _channel = _supabase
        .channel('couple_chat_${_coupleId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'couples',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: _coupleId!,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final raw = newRecord['chat_history'] as List<dynamic>? ?? [];
            _messages = raw
                .map(
                  (e) => ChatMessage.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList();

            notifyListeners();
          },
        )
        .subscribe();
  }

  void _unsubscribeRealtime() {
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
      _channel = null;
    }
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    super.dispose();
  }
}
