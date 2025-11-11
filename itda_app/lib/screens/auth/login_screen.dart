import 'package:flutter/material.dart';
import 'package:itda_app/main.dart';
import 'signup_screen.dart';
import '../survey_screen.dart';
import '../../services/api_config.dart';

// ▼ 추가: 구글/HTTP/보안 저장소
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 간단 세션 저장 유틸
class _SessionStore {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUserId = 'user_id';
  final _storage = const FlutterSecureStorage();

  Future<void> save(String access, String? refresh, String? userId) async {
    await _storage.write(key: _kAccess, value: access);
    if (refresh != null) {
      await _storage.write(key: _kRefresh, value: refresh);
    }
    if (userId != null) {
      await _storage.write(key: _kUserId, value: userId);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUserId);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  // ▼ 추가: 구글 로그인 상태 & 유틸
  bool _googleLoading = false;
  final _google = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '545845229063-okupe6in5bos5lkb9n4apc18t62hpqj1.apps.googleusercontent.com',
  );
  final _session = _SessionStore();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SurveyScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요')),
      );
    }
  }

  // ▼ 추가: Route A – Google Sign-In → idToken 서버 전송 → 세션 저장 → 메인 이동
  Future<void> _handleGoogleSignIn() async {
    setState(() => _googleLoading = true);
    try {
      print('🔵 Google Sign-In 시작...');
      final account = await _google.signIn();
      print('🔵 Account: ${account?.email}');
      if (account == null) throw Exception('로그인이 취소되었습니다.');

      print('🔵 인증 정보 가져오는 중...');
      final auth = await account.authentication;
      final idToken = auth.idToken; // 서버에서 검증할 핵심 토큰
      print('🔵 idToken 길이: ${idToken?.length}');
      if (idToken == null) throw Exception('idToken을 가져오지 못했습니다.');

      // 백엔드 API 호출
      print('🔵 백엔드 API 호출: ${ApiConfig.baseUrl}/auth/google');
      final resp = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
          'client_type': 'flutter-mobile',
        }),
      );

      print('🔵 서버 응답: ${resp.statusCode}');
      if (resp.statusCode != 200) {
        print('❌ 서버 에러: ${resp.body}');
        throw Exception('서버 인증 실패 (${resp.statusCode}) ${resp.body}');
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final access = body['access_token'] as String?;
      final refresh = body['refresh_token'] as String?;
      final user = body['user'] as Map<String, dynamic>?;
      final userId = user?['user_id'] as String?;

      if (access == null) throw Exception('access_token 누락');

      // 🔍 디버그: 토큰 출력
      print('✅ 로그인 성공!');
      print('📝 Access Token: $access');
      print('👤 User ID: $userId');
      print('📧 Email: ${user?['email']}');

      await _session.save(access, refresh, userId);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SurveyScreen()),
      );
    } catch (e, stackTrace) {
      print('❌ Google Sign-In 에러: $e');
      print('❌ Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('구글 로그인 실패: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePink = const Color(0xFFFD9180);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDEDED),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite,
                  size: 60,
                  color: themePink,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                '잇다',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: themePink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'AI가 추천하는 특별한 데이트',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '이메일',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themePink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '로그인',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
                child: const Text('계정이 없으신가요? 회원가입'),
              ),
              const SizedBox(height: 24),

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
              const SizedBox(height: 24),

              // ▼ 여기 변경: 실제 구글 로그인 호출
              OutlinedButton.icon(
                onPressed: _googleLoading ? null : _handleGoogleSignIn,
                icon: const Icon(Icons.g_mobiledata, size: 32),
                label: Text(_googleLoading ? '로그인 중…' : 'Google로 계속하기'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
