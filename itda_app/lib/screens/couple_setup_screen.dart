import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:itda_app/providers/user_provider.dart';
import 'package:itda_app/main.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class CoupleSetupScreen extends StatefulWidget {
  const CoupleSetupScreen({super.key});

  @override
  State<CoupleSetupScreen> createState() => _CoupleSetupScreenState();
}

class _CoupleSetupScreenState extends State<CoupleSetupScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  DateTime? _firstMet;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _firstMet ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000, 1, 1),
      lastDate: now,
      helpText: '우리가 처음 만난 날',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (picked != null) {
      setState(() {
        _firstMet = picked;
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Future<void> _saveAndGoHome() async {
    final nickname = _nicknameController.text.trim();
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;

    DateTime? firstMetToSave;

    if (user != null) {
      firstMetToSave = _firstMet ?? user.firstMet;

      final updated = user.copyWith(
        nickname: nickname.isNotEmpty ? nickname : user.nickname,
        firstMet: firstMetToSave,
      );
      userProvider.setUser(updated);

      final coupleId = user.coupleId;

      if (coupleId != null && firstMetToSave != null) {
        final supabase = Supabase.instance.client;

        try {
          // 날짜만 저장하고 싶으면 toIso8601String() 쓰거나 DateTime 그대로 넘겨도 됨
          await supabase
              .from('couples')
              .update({
                'first_met': firstMetToSave.toIso8601String(),
              })
              .eq('couple_id', coupleId);

          // 필요하면 nickname도 couples 쪽에 같이 저장 가능:
          // await supabase
          //   .from('couples')
          //   .update({
          //     'first_met': firstMetToSave.toIso8601String(),
          //     'nickname': nickname.isNotEmpty ? nickname : user.nickname,
          //   })
          //   .eq('couple_id', coupleId);

        } catch (e, st) {
          // 실패해도 앱 흐름은 막지 않고 로그만 남김
          debugPrint('[CoupleSetupScreen] couples.first_met 업데이트 실패: $e\n$st');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('서버에 커플 정보를 저장하는 데 실패했어요. 나중에 다시 시도해 주세요.'),
              ),
            );
          }
        }
      }
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  void _skip() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainColor = Color(0xFFFD9180);
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '커플 정보 설정',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(
              '나중에',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                user?.nickname != null ? '${user!.nickname}님,' : '환영해요!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '서로를 뭐라고 부를지,\n언제부터 함께였는지 남겨볼까요?',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                '서로를 뭐라고 부르나요?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  hintText: '예: 여보, 자기야, 허니, 내사랑...',
                  filled: true,
                  fillColor: const Color(0xFFFDF8F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(
                      color: mainColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 14,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                '우리가 처음 만난 날은?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF8F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEADAD2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: mainColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _firstMet != null
                            ? _formatDate(_firstMet!)
                            : '선택 안 함 (나중에 입력 가능)',
                        style: TextStyle(
                          fontSize: 14,
                          color: _firstMet != null
                              ? Colors.black87
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveAndGoHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    elevation: 0,
                  ),
                  child: const Text('저장하고 시작하기'),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: _skip,
                  child: const Text(
                    '나중에 입력할게요',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
