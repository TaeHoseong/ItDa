import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth/login_screen.dart';
import 'auth/couple_connect_screen.dart';
import 'couple_setup_screen.dart';      // 🔥 추가
import 'survey_screen.dart';         // 🔥 실제 경로에 맞게 수정
import 'package:itda_app/services/session_store.dart';
import 'package:itda_app/services/api_config.dart';
import 'package:itda_app/providers/user_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final sessionStore = SessionStore();
    final google = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: ApiConfig.googleServerClientId,
    );

    try {
      await supabase.auth.signOut();
      try {
        await google.signOut();
      } catch (_) {}
      await sessionStore.clear();

      context.read<UserProvider>().clear();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('로그아웃 중 오류 발생: $e')));
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
    final isCoupleMatched = context.watch<UserProvider>().coupleMatched;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 🔹 커플 매칭
          if (!isCoupleMatched)
            ListTile(
              leading: const Icon(Icons.favorite_border, color: Colors.pink),
              title: const Text(
                '커플 매칭하기',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('연인의 계정과 연결하고 추천을 받아요'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CoupleConnectScreen(),
                  ),
                );
              },
            ),

          if (!isCoupleMatched) const Divider(height: 24),

          // 🔹 커플 설정 페이지로 이동 (first_met 등 설정)
          ListTile(
            leading: const Icon(Icons.edit_calendar, color: Colors.blue),
            title: const Text(
              '커플 정보 설정',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('처음 만난 날짜 등 커플 정보를 수정합니다'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CoupleSetupScreen(),
                ),
              );
            },
          ),

          const Divider(height: 24),

          // 🔹 설문 페이지
          ListTile(
            leading: const Icon(Icons.list_alt_outlined, color: Colors.orange),
            title: const Text(
              '취향 설문 다시하기',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('커플 취향을 다시 설정하고 추천을 새로 받아요'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SurveyScreen(),  // 경로 맞게 수정
                ),
              );
            },
          ),

          const Divider(height: 24),

          // 🔹 로그아웃
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
