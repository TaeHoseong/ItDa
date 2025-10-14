import 'package:flutter/material.dart';
import 'package:itda_app/main.dart';

class CoupleConnectScreen extends StatefulWidget {
  const CoupleConnectScreen({super.key});

  @override
  State<CoupleConnectScreen> createState() => _CoupleConnectScreenState();
}

class _CoupleConnectScreenState extends State<CoupleConnectScreen> {
  final _codeController = TextEditingController();
  String _myInviteCode = 'AB12CD34';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _connectCouple() {
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 코드를 입력해주세요')),
      );
      return;
    }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('커플 연동'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _skip,
            child: const Text('나중에'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 60,
                  color: Color(0xFFFF69B4),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                '연인과 함께 시작하세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                '8자리 초대 코드로 연인과 연동하세요',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      '내 초대 코드',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _myInviteCode,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF69B4),
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('코드가 복사되었습니다')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('복사하기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF69B4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('또는', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 32),

              const Text(
                '연인의 초대 코드 입력',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  hintText: '8자리 코드를 입력하세요',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  letterSpacing: 4,
                ),
                maxLength: 8,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _connectCouple,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF69B4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '연동하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}