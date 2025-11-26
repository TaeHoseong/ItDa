import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/user_provider.dart';
import '../models/chat_message.dart';
import 'settings_screen.dart'; // ✅ 설정 화면 import

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(ChatProvider chat) async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    await chat.send(text);
    _textController.clear();

    await Future.delayed(const Duration(milliseconds: 80));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const mainColor = Color(0xFFFD9180);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          '커플 채팅',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        // ✅ 여기: 우상단 빨간 동그라미 위치에 설정 아이콘
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ===== 메시지 리스트 =====
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chat, _) {
                  if (chat.coupleId == null) {
                    return Center(
                      child: Text(
                        '아직 커플 매칭이 되지 않았어요 🥲',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    );
                  }

                  if (chat.isLoading && chat.messages.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (chat.error != null && chat.messages.isEmpty) {
                    return Center(
                      child: Text(
                        chat.error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  final msgs = chat.messages;

                  if (msgs.isEmpty) {
                    return Center(
                      child: Text(
                        '처음 메시지를 보내보세요 💬',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: msgs.length,
                    itemBuilder: (context, index) {
                      final msg = msgs[index];
                      final isMine = chat.isMine(msg);
                      return _ChatBubble(
                        message: msg,
                        isMine: isMine,
                      );
                    },
                  );
                },
              ),
            ),

            // ===== 입력창 =====
            Consumer<ChatProvider>(
              builder: (_, chat, __) {
                final canChat = chat.coupleId != null;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, -1),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            enabled: canChat,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: canChat
                                  ? '메시지를 입력하세요'
                                  : '커플 매칭 후 채팅을 사용할 수 있어요',
                              filled: true,
                              fillColor: const Color(0xFFF5F3F0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: (!canChat || chat.isSending)
                              ? null
                              : () => _send(chat),
                          icon: chat.isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          color: mainColor,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _ChatBubble({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMine ? const Color(0xFFFD9180) : Colors.white;
    final textColor = isMine ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
              bottomRight: isMine ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: Text(
            message.content,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
