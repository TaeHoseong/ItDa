import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/persona_message.dart';
import '../providers/persona_chat_provider.dart';
import '../providers/schedule_provider.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend(PersonaChatProvider chat) async {
    final text = _controller.text.trim();
    if (text.isEmpty || chat.isSending) return;

    _controller.clear();
    await chat.sendUserMessage(text);
    _scrollToBottomSoon();
  }

  void _showScheduleCreatedSnackbar(Map<String, dynamic> schedule) {
    if (!mounted) return;
    final title = schedule['title'] ?? '일정';
    final date = schedule['date'] ?? '';
    final time = schedule['time'] ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ 일정 생성: $title\n📅 $date $time'),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF8F5),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '대화 초기화',
              onPressed: () {
                context.read<PersonaChatProvider>().clearChat();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔄 새로운 대화를 시작해요!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Consumer<PersonaChatProvider>(
            builder: (context, chat, _) {
              // 일정 생성 SnackBar 처리
              final schedule = chat.takeLastScheduleCreated();
              if (schedule != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showScheduleCreatedSnackbar(schedule);
                });
              }

              final messages = chat.messages;
              final showEmpty = messages.isEmpty;

              // 기존 메시지 있을 경우 첫 빌드 때 스크롤 맨 아래로
              if (messages.isNotEmpty) {
                _scrollToBottomSoon();
              }

              return Column(
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
                                messages: messages,
                                scroll: _scroll,
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom > 0
                          ? 16
                          : 32,
                    ),
                    child: _InputPill(
                      controller: _controller,
                      hint: '페르소나에게 말하기 · · ·',
                      sending: chat.isSending,
                      onSend: () => _handleSend(chat),
                    ),
                  ),
                ],
              );
            },
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
        const Spacer(flex: 2),
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
            child: _SpeechBubble(text: initialText),
          ),
        ),
        const Spacer(flex: 1),
        Center(
          child: Image.asset(
            'assets/images/mascot.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({
    super.key,
    required this.messages,
    required this.scroll,
  });

  final List<PersonaMessage> messages;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final chatProvider = context.watch<PersonaChatProvider>();

    return ListView.separated(
      controller: scroll,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final isUser = m.sender == PersonaSender.user;
        final isLastBotMessage = !isUser && i == messages.length - 1;
        final showPlaceCards = isLastBotMessage &&
                                chatProvider.lastRecommendedPlaces != null &&
                                chatProvider.lastRecommendedPlaces!.isNotEmpty;

        return Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Align(
              alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: size.width * 0.8),
                child: _ChatBubble(
                  text: m.text,
                  isUser: isUser,
                ),
              ),
            ),
            if (showPlaceCards) ...[
              const SizedBox(height: 12),
              _PlaceRecommendationCards(
                places: chatProvider.lastRecommendedPlaces!,
              ),
            ],
          ],
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            height: 1.35,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// 아래 _SpeechBubble, _TailShadowAndFill, _TailPainterWidget, _TailPainter, _InputPill 은 기존 코드 그대로 사용

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: const ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            shadows: [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 4,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              height: 1.4,
              color: Color(0xFF1E1E1E),
            ),
          ),
        ),
        const Positioned(
          left: 30,
          bottom: -42,
          child: _TailShadowAndFill(),
        ),
      ],
    );
  }
}

class _TailShadowAndFill extends StatelessWidget {
  const _TailShadowAndFill();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: const [
          // Shadow tail (same tone as bubble shadow)
          Positioned(
            left: 0,
            top: 4,
            child: _TailPainterWidget(
              color: Color(0x22000000),
              blurSigma: 4, // <- soft shadow
            ),
          ),
          // Main white tail
          _TailPainterWidget(
            color: Colors.white,
            blurSigma: 0,
          ),
        ],
      ),
    );
  }
}

class _TailPainterWidget extends StatelessWidget {
  const _TailPainterWidget({
    required this.color,
    this.blurSigma = 0,
  });

  final Color color;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(40, 44),
      painter: _TailPainter(
        color: color,
        blurSigma: blurSigma,
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({
    required this.color,
    this.blurSigma = 0,
  });

  final Color color;
  final double blurSigma;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(
        size.width * 0.15, size.height * 0.7,
        size.width * 0.7, size.height,
      )
      ..quadraticBezierTo(
        size.width * 0.4, size.height * 0.65,
        size.width, 0,
      )
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // blurSigma > 0이면 말풍선 꼬리도 BoxShadow처럼 부드럽게
    if (blurSigma > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.blurSigma != blurSigma;
}


class _InputPill extends StatelessWidget {
  const _InputPill({
    required this.controller,
    required this.hint,
    required this.sending,
    required this.onSend,
  });

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
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: SizedBox(
              width: 44,
              height: 44,
              child: InkWell(
                onTap: sending ? null : onSend,
                borderRadius: BorderRadius.circular(24),
                child: Center(
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.black87,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceRecommendationCards extends StatelessWidget {
  const _PlaceRecommendationCards({required this.places});
  final List<Map<String, dynamic>> places;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: places.map((place) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              place['name'] ?? '이름 없음',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (place['address'] != null && place['address'] != '')
                  Text(
                    place['address'],
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                const SizedBox(height: 4),
                Text(
                  '⭐ 추천도: ${((place['score'] ?? 0.0) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF6B6B)),
              onPressed: () => _showAddScheduleDialog(context, place),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showAddScheduleDialog(
    BuildContext context,
    Map<String, dynamic> place,
  ) async {
    final scheduleProvider = context.read<ScheduleProvider>();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${place['name']} 일정 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  selectedDate == null
                      ? '날짜 선택'
                      : '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedTime = picked;
                    });
                  }
                },
                icon: const Icon(Icons.access_time),
                label: Text(
                  selectedTime == null
                      ? '시간 선택'
                      : '${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
              ),
              onPressed: () {
                if (selectedDate != null && selectedTime != null) {
                  scheduleProvider.addEvent(
                    selectedDate!,
                    place['name'] ?? '장소',
                    '${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                    placeName: place['name'],
                    latitude: place['latitude'],
                    longitude: place['longitude'],
                    address: place['address'],
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('✅ 일정에 추가되었습니다'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('날짜와 시간을 모두 선택해주세요'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }
}
