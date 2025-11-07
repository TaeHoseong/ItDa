import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/persona_api_service.dart';
import 'dart:async';


/// PersonaScreen (single stateful page)
/// ------------------------------------
/// Shows the original mascot PNG first, then swaps to the scrollable chat
/// view after the first user message.
class PersonaScreen extends StatefulWidget {
  const PersonaScreen({
    super.key,
    this.initialText = '안녕! 무엇을 도와줄까? 😊',
  });

  final String initialText;

  @override
  State<PersonaScreen> createState() => _PersonaScreenState();
}

class _PersonaScreenState extends State<PersonaScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _sending = false;

  // API 서비스
  late final PersonaApiService _apiService;

  @override
  void initState() {
    super.initState();

    // 세션 ID 생성
    final sessionId = const Uuid().v4();
    _apiService = PersonaApiService(sessionId: sessionId);

    print('세션 ID: $sessionId');
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messages.add({'text': text, 'sender': 'user'});
    });

    _controller.clear();
    _scrollToBottomSoon();

    try {
      // 실제 API 호출
      print('전송: $text');
      final response = await _apiService.sendMessage(text);

      if (!mounted) return;

      final botMessage = response['message'] ?? '응답을 받지 못했어요';
      print('📥 응답: $botMessage');

      ///setState(() => _messages.add({'text': botMessage, 'sender': 'bot'}));
      // 장소 추천인 경우 추천 목록 추가
      String displayMessage = botMessage;
      if (response['action'] == 'recommend_place' &&
          response['data']?['places'] != null) {
        final places = response['data']['places'] as List<dynamic>;

        if (places.isNotEmpty) {
          displayMessage += '\n\n📍 추천 장소:\n';
          for (int i = 0; i < places.length; i++) {
            final place = places[i];
            final name = place['name'] ?? '이름 없음';
            final score = place['score'] ?? 0.0;
            final address = place['address'] ?? '';

            displayMessage += '\n${i + 1}. $name';
            if (address.isNotEmpty) {
              displayMessage += '\n   📌 $address';
            }
            displayMessage += '\n   ⭐ 추천도: ${(score * 100).toStringAsFixed(0)}%\n';
          }
        }
      }

      setState(() => _messages.add({'text': displayMessage, 'sender': 'bot'}));

      // 일정 생성 성공 시 스낵바
      if (response['action'] == 'create_schedule' &&
          response['data']?['schedule'] != null) {
        final schedule = response['data']['schedule'];
        _showScheduleCreatedSnackbar(schedule);
      }

    } catch (e) {
      print('❌ 오류: $e');
      if (!mounted) return;
      setState(() {
        _messages.add({
          'text': '죄송해요, 오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
          'sender': 'bot',
        });
      });

      // 에러 스낵바
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('네트워크 오류: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _scrollToBottomSoon();
      if (mounted) setState(() => _sending = false);
    }
  }

  // 일정 생성 스낵바
  void _showScheduleCreatedSnackbar(Map<String, dynamic> schedule) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ 일정 생성: ${schedule['title']}\n'
              '📅 ${schedule['date']} ${schedule['time'] ?? ''}',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showEmpty = _messages.isEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8F5),
        // 🔥 AppBar 추가 (세션 초기화 버튼)
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF8F5),
          elevation: 0,
          title: const Text('일정 챗봇'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                // await _apiService.clearSession();
                setState(() {
                  _messages.clear();
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔄 새로운 대화를 시작해요!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              tooltip: '대화 초기화',
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: showEmpty
                        ? _EmptyState(
                      key: const ValueKey('empty'),
                      initialText: widget.initialText,
                    )
                        : _ChatList(
                      key: const ValueKey('chat'),
                      messages: _messages,
                      scroll: _scroll,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 32,
                ),
                child: _InputPill(
                  controller: _controller,
                  hint: '페르소나에게 말하기 · · ·',
                  sending: _sending,
                  onSend: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.initialText});
  final String initialText;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bubbleMaxWidth = size.width * 0.82;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // MODIFIED: Replaced SizedBox(height: 200) with a Spacer
        const Spacer(flex: 2), // 'flex' allows you to weigh the spacing
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
            child: _SpeechBubble(text: initialText),
          ),
        ),
        const Spacer(flex: 1), // Added a Spacer
        Center(
          child: Image.asset(
            'assets/images/mascot.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
        // MODIFIED: Replaced SizedBox(height: 200) with a Spacer
        const Spacer(flex: 3), // 'flex' allows you to weigh the spacing
      ],
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({super.key, required this.messages, required this.scroll});
  final List<Map<String, String>> messages;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return ListView.separated(
      controller: scroll,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemBuilder: (context, i) {
        final m = messages[i];
        final isUser = m['sender'] == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: size.width * 0.8),
            child: _ChatBubble(text: m['text'] ?? '', isUser: isUser),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: messages.length,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});
  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final bg = isUser ? const Color(0xFFFD9180) : Colors.white;
    final fg = isUser ? Colors.white : const Color(0xFF1E1E1E);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
          bottomLeft: Radius.circular(isUser ? 22 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 22),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(text, style: TextStyle(fontSize: 16, height: 1.35, color: fg)),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, height: 1.4, color: Color(0xFF1E1E1E)),
          ),
        ),
        const Positioned(left: 40, bottom: -20, child: _TailShadowAndFill()),
      ],
    );
  }
}

class _TailShadowAndFill extends StatelessWidget {
  const _TailShadowAndFill();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 28,
      child: Stack(
        children: const [
          Positioned(left: 0, top: 2, child: _TailPainterWidget(color: Color(0x1F000000))),
          _TailPainterWidget(color: Colors.white),
        ],
      ),
    );
  }
}

class _TailPainterWidget extends StatelessWidget {
  const _TailPainterWidget({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(36, 28), painter: _TailPainter(color: color));
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.40, size.height * 0.25, size.width * 0.55, size.height * 0.02)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.35, size.width * 0.98, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.70, size.width * 0.22, size.height * 0.98)
      ..close();
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InputPill extends StatelessWidget {
  const _InputPill({required this.controller, required this.hint, required this.sending, required this.onSend});

  final TextEditingController controller;
  final String hint;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: hint, border: InputBorder.none),
              // MODIFIED: The following line has been removed
              // onSubmitted: (_) => onSend(), 
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: SizedBox(
              width: 44,
              height: 44,
              child: InkWell(
                onTap: sending ? null : onSend,
                borderRadius: BorderRadius.circular(24),
                child: Center(
                  child: sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : const Icon(Icons.send_rounded, color: Colors.black87),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}