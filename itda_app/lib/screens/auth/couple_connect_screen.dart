import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // UpperCase formatter용
import 'package:itda_app/main.dart';

// 입력을 항상 대문자로 바꿔주는 포맷터
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class CoupleConnectScreen extends StatefulWidget {
  const CoupleConnectScreen({super.key});

  @override
  State<CoupleConnectScreen> createState() => _CoupleConnectScreenState();
}

class _CoupleConnectScreenState extends State<CoupleConnectScreen> {
  // 내 초대 코드 (예시)
  String _myInviteCode = 'AB12CD34';

  // 8칸 코드 입력용 컨트롤러 & 포커스
  final List<TextEditingController> _textControllers =
      List.generate(8, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(8, (_) => FocusNode());

  // 최종 코드 문자열
  String _finalCode = '';

  @override
  void dispose() {
    for (var c in _textControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _updateFinalCode() {
    _finalCode = _textControllers.map((e) => e.text).join();
    // debugPrint('Current code: $_finalCode');
  }

  void _connectCouple() {
    if (_finalCode.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 코드를 모두 입력해주세요')),
      );
      return;
    }

    // TODO: _finalCode 사용해서 실제 연동 처리
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color mainColor = Color(0xFFFD9180); // 메인 살구색

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5), // 크림색 배경
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '커플 연동',
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // ===== 상단 Hero 섹션 =====
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFC0AE), Color(0xFFFD9180)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: mainColor.withOpacity(0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '연인과 함께 시작하세요',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '8자리 초대 코드로\n연인과 서로 계정을 연결해요',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ===== 내 초대 코드 카드 =====
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFE1D6),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '내 초대 코드',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _myInviteCode,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: mainColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: 클립보드 복사 로직
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('코드가 복사되었습니다')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('복사하기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: mainColor,
                        side: const BorderSide(color: Color(0xFFFFC0AE)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '또는',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),

              const SizedBox(height: 24),

              // ===== 연인의 초대 코드 입력 카드 =====
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '연인의 초대 코드 입력',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '서로의 코드를 한 번만 입력하면 계속 연결돼요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ===== 코드 입력 필드 (1칸씩 8자리, 언더라인 스타일) =====
                    Row(
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          color: mainColor.withOpacity(0.9),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                              children: List.generate(8, (index) {
                                return SizedBox(
                                  width: 28,
                                  child: TextField(
                                    controller: _textControllers[index],
                                    focusNode: _focusNodes[index],
                                    textAlign: TextAlign.center,
                                    maxLength: 1,
                                    keyboardType: TextInputType.text,
                                    inputFormatters: [
                                      UpperCaseTextFormatter(),
                                    ],
                                    decoration: const InputDecoration(
                                      isCollapsed: true,
                                      counterText: '',
                                      border: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFFFFC0AE),
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color(0xFFFFC0AE),
                                          width: 2,
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: mainColor,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                    onChanged: (value) {
                                      if (value.isEmpty) {
                                        // 삭제 → 이전 칸으로
                                        if (index > 0) {
                                          FocusScope.of(context)
                                              .requestFocus(
                                                  _focusNodes[index - 1]);
                                        }
                                        _updateFinalCode();
                                        return;
                                      }

                                      // 여러 글자 들어오면 마지막 글자만 사용
                                      if (value.length > 1) {
                                        final last =
                                            value[value.length - 1].toUpperCase();
                                        _textControllers[index].text = last;
                                        _textControllers[index].selection =
                                            const TextSelection.collapsed(
                                                offset: 1);
                                      }

                                      // 다음 칸으로 이동
                                      if (index < 7) {
                                        FocusScope.of(context)
                                            .requestFocus(
                                                _focusNodes[index + 1]);
                                      } else {
                                        _focusNodes[index].unfocus();
                                      }

                                      _updateFinalCode();
                                    },
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ===== 연동하기 버튼 =====
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _connectCouple,
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
                  child: const Text('연동하기'),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
