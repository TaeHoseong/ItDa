import 'package:flutter/material.dart';
import 'signup_screen.dart';
import '../../services/api_config.dart';
import 'package:itda_app/services/auth_flow_helper.dart';
import 'package:provider/provider.dart';
import 'package:itda_app/providers/user_provider.dart';
import 'package:itda_app/models/app_user.dart';
import 'package:itda_app/services/session_store.dart';

// ▼ 추가: Supabase
import 'package:supabase_flutter/supabase_flutter.dart';

// ▼ 추가: 구글/HTTP/보안 저장소
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    serverClientId:
        '545845229063-okupe6in5bos5lkb9n4apc18t62hpqj1.apps.googleusercontent.com',
  );
  final _session = SessionStore();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ===========================
  // 🔹 Supabase에서 유저 정보 로드
  // ===========================
  Future<AppUser> _loadUserFromSupabase(String userId) async {
    final supabase = Supabase.instance.client;

    final data = await supabase
        .from('users')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) {
      throw Exception('유저 정보를 찾을 수 없습니다. (user_id: $userId)');
    }

    // Supabase users 테이블 구조가 AppUser.fromJson과 동일하다고 가정
    return AppUser.fromJson(Map<String, dynamic>.from(data));
  }

  // ==========================================
  // 🔹 이메일/비밀번호 로그인 → user_id만 반환
  // ==========================================
  Future<String> _performLoginRequest({
    required String email,
    required String password,
  }) async {
    final resp = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (resp.statusCode != 200) {
      throw Exception('로그인 실패: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;

    // access token + user_id 저장
    final accessToken = decoded['access_token'] as String;
    final userJson = decoded['user'] as Map<String, dynamic>;
    final userId = userJson['user_id'] as String?;

    if (userId == null) {
      throw Exception('로그인 응답에 user_id가 없습니다.');
    }

    await _session.save(accessToken, null, userId);

    // 이 함수는 이제 user_id만 넘겨준다
    return userId;
  }

  // =====================
  // 🔹 이메일/비밀번호 로그인
  // =====================
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요')),
      );
      return;
    }

    try {
      // 1) 백엔드 로그인 → user_id 획득
      final userId = await _performLoginRequest(
        email: email,
        password: password,
      );

      // 2) Supabase users 테이블에서 실제 유저 정보 가져오기
      final appUser = await _loadUserFromSupabase(userId);

      if (!mounted) return;

      // 3) UserProvider에 저장
      context.read<UserProvider>().setUser(appUser);

      // 4) 설문/커플 매칭 상태에 따라 라우팅
      PostAuthNavigator.routeWithUser(
        context,
        user: appUser,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $error')),
      );
    }
  }

  // =====================
  // 🔹 Google Sign-In
  // =====================
  Future<void> _handleGoogleSignIn() async {
    setState(() => _googleLoading = true);
    try {
      print('🔵 Google Sign-In 시작...');
      final account = await _google.signIn();
      print('🔵 Account: ${account?.email}');
      if (account == null) throw Exception('로그인이 취소되었습니다.');

      print('🔵 인증 정보 가져오는 중...');
      final auth = await account.authentication;
      final idToken = auth.idToken;
      print('🔵 idToken 길이: ${idToken?.length}');
      if (idToken == null) throw Exception('idToken을 가져오지 못했습니다.');

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
      if (userId == null) throw Exception('user_id 누락');

      print('✅ 로그인 성공!');
      print('📝 Access Token: $access');
      print('👤 User ID: $userId');
      print('📧 Email: ${user?['email']}');

      // 세션 저장
      await _session.save(access, refresh, userId);

      // 🔹 Supabase에서 실제 유저 정보 가져오기
      final appUser = await _loadUserFromSupabase(userId);

      if (mounted) {
        context.read<UserProvider>().setUser(appUser);
        print('routing with user (from Supabase)');
        print(appUser.surveyDone);
        print(appUser.coupleMatched);

        PostAuthNavigator.routeWithUser(
          context,
          user: appUser,
        );
      }
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
    const themePink = Color(0xFFFD9180);
    const backgroundCream = Color(0xFFFAF8F5);

    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

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
                          colors: [Color(0xFFFFC0AE), themePink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: themePink.withOpacity(0.25),
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
                      '잇다',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: themePink,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI가 추천하는 특별한 데이트',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF7A6C66), //Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ===== 로그인 카드 =====
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: '이메일',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: const Color(0xFFFDF8F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.transparent),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.transparent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: themePink, width: 1.6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                        filled: true,
                        fillColor: const Color(0xFFFDF8F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.transparent),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.transparent),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: themePink,
                            width: 1.6,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ===== 로그인 버튼 =====
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themePink,
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
                  child: const Text('로그인'),
                ),
              ),

              const SizedBox(height: 12),

              // ===== 회원가입 링크 =====
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
                child: Text(
                  '계정이 없으신가요? 회원가입',
                  style: TextStyle(
                    color: Color(0xFF6B4A3C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '또는',
                      style: TextStyle(
                        color: Color(0xFFBDB6B2),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),

              const SizedBox(height: 16),

              // ===== Google 로그인 버튼 =====
              OutlinedButton.icon(
                onPressed: _googleLoading ? null : _handleGoogleSignIn,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: Text(
                  _googleLoading ? '로그인 중…' : 'Google로 계속하기',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B4A3C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  foregroundColor: const Color(0xFF6B4A3C),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
