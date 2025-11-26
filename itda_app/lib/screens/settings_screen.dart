import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth/login_screen.dart';
import 'package:itda_app/services/session_store.dart';
import 'package:itda_app/providers/user_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final sessionStore = SessionStore();
    final google = GoogleSignIn(
      scopes: ['email', 'profile'],
      // serverClientId 는 꼭 같을 필요는 없지만,
      // LoginScreen 이랑 동일하게 맞춰줘도 됨
      serverClientId:
          '545845229063-okupe6in5bos5lkb9n4apc18t62hpqj1.apps.googleusercontent.com',
    );

    try {
      // 1) Supabase 세션 종료
      await supabase.auth.signOut();

      // 2) 구글 로그인 세션 종료 (구글로 로그인한 경우)
      try {
        await google.signOut();
      } catch (_) {
        // 이미 로그아웃 되어 있거나, 구글 로그인이 아니어도 여기서 에러 나도 치명적이지 않으니까 무시
      }

      // 3) SecureStorage 에서 토큰/유저ID 삭제
      await sessionStore.clear();

      // 4) UserProvider 에서 유저 정보 초기화
      // clearUser() 메서드가 없으면 UserProvider 에 하나 만들어주면 좋음
      try {
        context.read<UserProvider>().clear();
      } catch (_) {
        // 일단 앱이 죽지는 않도록 방어
      }

      // 5) 네비게이션 스택 날리고 로그인 화면으로 이동
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: $e')),
      );
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _logout(context);
              },
              child: const Text(
                '로그아웃',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              '로그아웃',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('현재 계정에서 로그아웃합니다'),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}
