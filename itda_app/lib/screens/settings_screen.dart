import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth/login_screen.dart';
import 'auth/couple_connect_screen.dart'; // 커플 매칭 화면 import
import 'package:itda_app/services/session_store.dart';
import 'package:itda_app/providers/user_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final sessionStore = SessionStore();
    final google = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId:
          '545845229063-okupe6in5bos5lkb9n4apc18t62hpqj1.apps.googleusercontent.com',
    );

    try {
      // 1) Supabase 세션 종료
      await supabase.auth.signOut();

      // 2) 구글 로그인 세션 종료
      try {
        await google.signOut();
      } catch (_) {}

      // 3) SecureStorage 에서 토큰/유저ID 삭제
      await sessionStore.clear();

      // 4) UserProvider 에서 유저 정보 초기화
      try {
        context.read<UserProvider>().clear();
      } catch (_) {}

      // 5) 로그인 화면으로 이동
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
    // 현재 유저의 커플 매칭 여부
    final isCoupleMatched =
        context.watch<UserProvider>().coupleMatched; // (coupleId != null)

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 아직 커플 매칭이 안 되어 있을 때만 보이는 메뉴
          if (!isCoupleMatched)
            ListTile(
              leading: const Icon(Icons.favorite_border, color: Colors.pink),
              title: const Text(
                '커플 매칭하기',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('연인의 계정과 연결하고 데이트 추천을 받아요'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CoupleConnectScreen(),
                  ),
                );
              },
            ),

          if (!isCoupleMatched)
            const Divider(height: 24),

          // 로그아웃
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
