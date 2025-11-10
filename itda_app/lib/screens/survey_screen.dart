import 'dart:math';
import 'package:flutter/material.dart';
import 'package:itda_app/main.dart'; // MainScreen 사용
import '../models/user_persona.dart';
import '../services/user_api_service.dart';

/// SurveyScreen (4-page wizard + 5-star Likert)
/// - 4개 섹션(페이지): 1) mainCategory, 2) atmosphere, 3) experienceType, 4) spaceCharacteristics
/// - 각 문항은 0~5개의 별로 응답 (별 1개 = 0.2점, 총점은 1.0으로 cap)
/// - 제출 시 풀스크린 결과 페이지로 이동(확인 누르면 MainScreen으로)
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});
  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  bool _submitting = false;

  // ====== 별 개수(0~5) 저장 ======
  // mainCategory (6)
  int foodCafe = 0, cultureArt = 0, activitySports = 0, natureHealing = 0, craftExperience = 0, shopping = 0;
  // atmosphere (6)
  int quiet = 0, romantic = 0, trendy = 0, privateVibe = 0, artistic = 0, energetic = 0;
  // experienceType (4)
  int passiveEnjoyment = 0, activeParticipation = 0, socialBonding = 0, relaxationFocused = 0;
  // spaceCharacteristics (4)
  int indoorRatio = 0, crowdednessExpected = 0, photoWorthiness = 0, scenicView = 0;

  double _scoreFromStars(int stars) => min(stars * 0.2, 1.0); // ⭐ 1개 = 0.2점, 최대 1.0

  @override
  Widget build(BuildContext context) {
    final pink = const Color(0xFFFD9180);

    return Scaffold(
      appBar: AppBar(title: const Text('장소 취향 설문'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            _headerStepper(),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _pageMainCategory(),
                  _pageAtmosphere(),
                  _pageExperience(),
                  _pageSpace(),
                ],
              ),
            ),
            _bottomNav(pink),
          ],
        ),
      ),
    );
  }

  // ---------- Step header ----------
  Widget _headerStepper() {
    final items = ['테마', '분위기', '경험', '공간'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = i == _page;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active ? Color(0xFFEDEDED) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? Color(0xFFEDEDED) : Colors.grey.shade300),
              ),
              child: Text(
                '${i + 1}. ${items[i]}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Color(0xFFFD9180) : Colors.grey.shade700,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------- Bottom nav ----------
  Widget _bottomNav(Color pink) {
    final isFirst = _page == 0;
    final isLast = _page == 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isFirst ? null : () => _goTo(_page - 1),
              icon: const Icon(Icons.chevron_left),
              label: const Text('이전'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              icon: isLast
                  ? (_submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check))
                  : const Icon(Icons.chevron_right),
              label: Text(isLast ? (_submitting ? '제출 중…' : '제출') : '다음'),
              onPressed: _submitting
                  ? null
                  : () {
                      if (isLast) {
                        _submit();
                      } else {
                        _goTo(_page + 1);
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goTo(int page) {
    _pageCtrl.animateToPage(page, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  // ---------- Pages ----------
  Widget _pageMainCategory() {
    return _pageScaffold(
      title: '1) 데이트 테마 선호도',
      hint: '별을 눌러 선호도를 선택하세요',
      children: [
        _likertTile('카페/음식', '☕️', foodCafe, (v) => setState(() => foodCafe = v)),
        _likertTile('문화/예술', '🎭', cultureArt, (v) => setState(() => cultureArt = v)),
        _likertTile('액티비티/스포츠', '🏃', activitySports, (v) => setState(() => activitySports = v)),
        _likertTile('자연/힐링', '🌿', natureHealing, (v) => setState(() => natureHealing = v)),
        _likertTile('공방/체험', '🧵', craftExperience, (v) => setState(() => craftExperience = v)),
        _likertTile('쇼핑', '🛍️', shopping, (v) => setState(() => shopping = v)),
      ],
    );
  }

  Widget _pageAtmosphere() {
    return _pageScaffold(
      title: '2) 장소 분위기',
      hint: '별을 눌러 선호도를 선택하세요',
      children: [
        _likertTile('조용한   분위기', '🤫', quiet, (v) => setState(() => quiet = v)),
        _likertTile('로맨틱한 분위기', '💘', romantic, (v) => setState(() => romantic = v)),
        _likertTile('트렌디/  힙한 감성', '🔥', trendy, (v) => setState(() => trendy = v)),
        _likertTile('프라이빗/아늑함', '🛋️', privateVibe, (v) => setState(() => privateVibe = v)),
        _likertTile('예술적/  감각적', '🖼️', artistic, (v) => setState(() => artistic = v)),
        _likertTile('에너지/  활기', '⚡️', energetic, (v) => setState(() => energetic = v)),
      ],
    );
  }

  Widget _pageExperience() {
    return _pageScaffold(
      title: '3) 경험 성격',
      hint: '별을 눌러 선호도를 선택하세요.',
      children: [
        _likertTile('감상형/  관람 중심', '🍿', passiveEnjoyment,
            (v) => setState(() => passiveEnjoyment = v)),
        _likertTile('직접 참여/체험 중심', '🛠️', activeParticipation,
            (v) => setState(() => activeParticipation = v)),
        _likertTile('소셜/     교류 중심', '🧑‍🤝‍🧑', socialBonding,
            (v) => setState(() => socialBonding = v)),
        _likertTile('휴식 중심', '🧘', relaxationFocused,
            (v) => setState(() => relaxationFocused = v)),
      ],
    );
  }

  Widget _pageSpace() {
    return _pageScaffold(
      title: '4) 공간 특성',
      hint: '별을 눌러 선호도를 선택하세요.',
      children: [
        _likertTile('실내 선호', '🏠', indoorRatio, (v) => setState(() => indoorRatio = v)),
        _likertTile('인구 밀도', '👥', crowdednessExpected,
            (v) => setState(() => crowdednessExpected = v)),
        _likertTile('포토 스팟', '📸', photoWorthiness,
            (v) => setState(() => photoWorthiness = v)),
        _likertTile('뷰/풍경', '🌇', scenicView, (v) => setState(() => scenicView = v)),
      ],
    );
  }

  // ---------- Submit (→ ResultPage) ----------
  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      // Create UserPersona object from survey results
      final persona = UserPersona(
        foodCafe: _scoreFromStars(foodCafe),
        cultureArt: _scoreFromStars(cultureArt),
        activitySports: _scoreFromStars(activitySports),
        natureHealing: _scoreFromStars(natureHealing),
        craftExperience: _scoreFromStars(craftExperience),
        shopping: _scoreFromStars(shopping),
        quiet: _scoreFromStars(quiet),
        romantic: _scoreFromStars(romantic),
        trendy: _scoreFromStars(trendy),
        privateVibe: _scoreFromStars(privateVibe),
        artistic: _scoreFromStars(artistic),
        energetic: _scoreFromStars(energetic),
        passiveEnjoyment: _scoreFromStars(passiveEnjoyment),
        activeParticipation: _scoreFromStars(activeParticipation),
        socialBonding: _scoreFromStars(socialBonding),
        relaxationFocused: _scoreFromStars(relaxationFocused),
        indoorRatio: _scoreFromStars(indoorRatio),
        crowdednessExpected: _scoreFromStars(crowdednessExpected),
        photoWorthiness: _scoreFromStars(photoWorthiness),
        scenicView: _scoreFromStars(scenicView),
      );

      // Send to backend API
      await UserApiService.updatePersona(persona);

      // Generate pretty format for display
      String f(double v) => v.toStringAsFixed(2);
      final pretty = '''
places = np.array([[
    ${f(persona.foodCafe)}, ${f(persona.cultureArt)}, ${f(persona.activitySports)}, ${f(persona.natureHealing)}, ${f(persona.craftExperience)}, ${f(persona.shopping)},               # main category
    ${f(persona.quiet)}, ${f(persona.romantic)}, ${f(persona.trendy)}, ${f(persona.privateVibe)}, ${f(persona.artistic)}, ${f(persona.energetic)},   # atmosphere
    ${f(persona.passiveEnjoyment)}, ${f(persona.activeParticipation)}, ${f(persona.socialBonding)}, ${f(persona.relaxationFocused)},             # experienceType
    ${f(persona.indoorRatio)}, ${f(persona.crowdednessExpected)}, ${f(persona.photoWorthiness)}, ${f(persona.scenicView)},            # spaceCharacteristics
]])''';

      if (!mounted) return;
      setState(() => _submitting = false);

      // 풀스크린 결과 페이지로 이동 (현재 설문 페이지 대체)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultPage(pretty: pretty)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('설문 제출 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------- Reusable UI ----------
  Widget _pageScaffold({required String title, required String hint, required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      children: [
        _sectionTitle(title),
        _hint(hint),
        const SizedBox(height: 4),
        ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)),
        const SizedBox(height: 80), // 하단 버튼 공간
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      );

  Widget _hint(String text) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(color: Colors.grey)));

  Widget _likertTile(String title, String emoji, int value, ValueChanged<int> onChanged) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            _StarRating(
              value: value,
              onChanged: onChanged,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Text('${_scoreFromStars(value).toStringAsFixed(2)}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 별(0~5) 위젯
/// - 토글: 현재 선택된 별(= value)을 다시 누르면 0으로 초기화
class _StarRating extends StatelessWidget {
  final int value; // 0~5
  final ValueChanged<int> onChanged;
  const _StarRating({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final index = i + 1;
        final filled = index <= value;
        return IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: Icon(filled ? Icons.star : Icons.star_border, color: filled ? Colors.amber : Colors.grey),
          // 토글 규칙: 현재 값과 동일한 별을 누르면 0으로(모두 비우기).
          // 그 외에는 그 별의 개수(index)로 설정.
          onPressed: () => onChanged(value == index ? 0 : index),
          tooltip: '$index개',
        );
      }),
    );
  }
}

/// 제출 결과 풀스크린 페이지
class ResultPage extends StatelessWidget {
  final String pretty;
  const ResultPage({super.key, required this.pretty});

  @override
  Widget build(BuildContext context) {
    final pink = const Color(0xFFFD9180);
    return Scaffold(
      appBar: AppBar(
        title: const Text('설문 결과'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Card(
                color: Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    pretty,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '# 컬럼 순서\n'
                  '- main: [food_cafe, culture_art, activity_sports, nature_healing, craft_experience, shopping]\n'
                  '- atmos: [quiet, romantic, trendy, private, artistic, energetic]\n'
                  '- exp: [passive_enjoyment, active_participation, social_bonding, relaxation_focused]\n'
                  '- space: [indoor_ratio, crowdedness_expected, photo_worthiness, scenic_view]',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('확인'),
                  style: FilledButton.styleFrom(
                    backgroundColor: pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // 메인으로 이동 (스택 비우고 교체)
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                      (route) => false,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
