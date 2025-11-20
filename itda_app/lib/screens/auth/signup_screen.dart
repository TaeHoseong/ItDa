import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_config.dart';
import 'package:itda_app/services/auth_flow_helper.dart';
import 'package:itda_app/providers/user_provider.dart';
import 'package:itda_app/models/app_user.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 이름
  final _nameController = TextEditingController();

  // 이메일: 로컬 + 도메인 분리
  final _emailLocalController = TextEditingController();   // 아이디 부분
  final _emailDomainController = TextEditingController();  // 도메인 부분

  // 비밀번호
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isPasswordConfirmVisible = false;

  bool _loading = false;

  // 자주 쓰는 이메일 도메인 리스트
  final List<String> _domainSuggestions = const [
    'gmail.com',
    'naver.com',
    'daum.net',
    'hanmail.net',
    'kakao.com',
    'outlook.com',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailLocalController.dispose();
    _emailDomainController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<AppUser> _performCreateUserRequest({
    required String name,
    required String email,
    required String password,
  }) async {
    final resp = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/create_user'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('회원가입 실패: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final userJson = decoded['user'] as Map<String, dynamic>;

    return AppUser.fromJson(userJson);
  }

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final local = _emailLocalController.text.trim();
    final domain = _emailDomainController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    if (name.isEmpty || local.isEmpty || domain.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요')),
      );
      return;
    }

    if (password != passwordConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다')),
      );
      return;
    }

    // 최종 이메일 조합
    final email = '$local@$domain';

    setState(() => _loading = true);

    try {
      final appUser = await _performCreateUserRequest(
        name: name,
        email: email,
        password: password,
      );

      if (!mounted) return;

      context.read<UserProvider>().setUser(appUser);

      PostAuthNavigator.routeWithUser(
        context,
        user: appUser,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const themePink = Color(0xFFFD9180);
    const backgroundCream = Color(0xFFFAF8F5);

    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: const Text(
          '회원가입',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // ===== 입력 카드 =====
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 이름
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: '이름',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
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
                    const SizedBox(height: 16),

                    // 이메일 라벨
                    const Text(
                      '이메일',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 이메일 분리 입력: [local] @ [domain + dropdown]
                    Row(
                      children: [
                        // 아이디 부분
                        Expanded(
                          flex: 7,
                          child: TextField(
                            controller: _emailLocalController,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: '아이디',
                              prefixIcon:
                                  const Icon(Icons.email_outlined, size: 20),
                              filled: true,
                              fillColor: const Color(0xFFFDF8F6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.transparent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.transparent),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(
                                  color: themePink,
                                  width: 1.6,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 12),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),

                        const SizedBox(width: 4),
                        const Text('@',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(width: 4),

                        // 도메인 + 드롭다운
                        Expanded(
                          flex: 6,
                          child: TextField(
                            controller: _emailDomainController,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: '도메인',
                              filled: true,
                              fillColor: const Color(0xFFFDF8F6),
                              suffixIcon: PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: Colors.grey[600],
                                ),
                                onSelected: (value) {
                                  _emailDomainController.text = value;
                                },
                                itemBuilder: (context) => _domainSuggestions
                                    .map(
                                      (domain) => PopupMenuItem<String>(
                                        value: domain,
                                        child: Text(domain),
                                      ),
                                    )
                                    .toList(),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.transparent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.transparent),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(
                                  color: themePink,
                                  width: 1.6,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 8),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 비밀번호
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        prefixIcon:
                            const Icon(Icons.lock_outline_rounded, size: 20),
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
                    const SizedBox(height: 16),

                    // 비밀번호 확인
                    TextField(
                      controller: _passwordConfirmController,
                      obscureText: !_isPasswordConfirmVisible,
                      decoration: InputDecoration(
                        labelText: '비밀번호 확인',
                        prefixIcon:
                            const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordConfirmVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordConfirmVisible =
                                  !_isPasswordConfirmVisible;
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

              const SizedBox(height: 28),

              // ===== 가입하기 버튼 =====
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signup,
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
                  child: Text(_loading ? '가입 중…' : '가입하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
