import 'dart:math';
import 'package:flutter/material.dart';
import 'package:itda_app/main.dart'; // MainScreen 사용

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
    final items = ['카테고리', '분위기', '경험', '공간'];
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
      title: '1) 메인 카테고리 선호도',
      hint: '별을 눌러 선호도를 선택하세요. (⭐ 1개 = 0.2점, 최대 1.0)',
      children: [
        _likertTile('카페/음식 (food_cafe)', '☕️', foodCafe, (v) => setState(() => foodCafe = v)),
        _likertTile('문화/예술 (culture_art)', '🎭', cultureArt, (v) => setState(() => cultureArt = v)),
        _likertTile('액티비티/스포츠 (activity_sports)', '🏃', activitySports, (v) => setState(() => activitySports = v)),
        _likertTile('자연/힐링 (nature_healing)', '🌿', natureHealing, (v) => setState(() => natureHealing = v)),
        _likertTile('공방/체험 (craft_experience)', '🧵', craftExperience, (v) => setState(() => craftExperience = v)),
        _likertTile('쇼핑 (shopping)', '🛍️', shopping, (v) => setState(() => shopping = v)),
      ],
    );
  }

  Widget _pageAtmosphere() {
    return _pageScaffold(
      title: '2) 장소 분위기',
      hint: '끌림 정도를 별로 선택하세요. (0~5개, 0.2점씩, 최대 1.0)',
      children: [
        _likertTile('조용하고 담담한 분위기 (quiet)', '🤫', quiet, (v) => setState(() => quiet = v)),
        _likertTile('로맨틱한 분위기 (romantic)', '💘', romantic, (v) => setState(() => romantic = v)),
        _likertTile('트렌디/힙한 감성 (trendy)', '🔥', trendy, (v) => setState(() => trendy = v)),
        _likertTile('프라이빗/아늑함 (private)', '🛋️', privateVibe, (v) => setState(() => privateVibe = v)),
        _likertTile('예술적/감각적 (artistic)', '🖼️', artistic, (v) => setState(() => artistic = v)),
        _likertTile('에너지/활기 (energetic)', '⚡️', energetic, (v) => setState(() => energetic = v)),
      ],
    );
  }

  Widget _pageExperience() {
    return _pageScaffold(
      title: '3) 경험 성격',
      hint: '선호하는 경험 방식을 선택하세요. (⭐ 1개 = 0.2점)',
      children: [
        _likertTile('감상형/편안히 즐김 (passive_enjoyment)', '🍿', passiveEnjoyment,
            (v) => setState(() => passiveEnjoyment = v)),
        _likertTile('직접 참여/체험 (active_participation)', '🛠️', activeParticipation,
            (v) => setState(() => activeParticipation = v)),
        _likertTile('소셜/교류 중심 (social_bonding)', '🧑‍🤝‍🧑', socialBonding,
            (v) => setState(() => socialBonding = v)),
        _likertTile('휴식 중심 (relaxation_focused)', '🧘', relaxationFocused,
            (v) => setState(() => relaxationFocused = v)),
      ],
    );
  }

  Widget _pageSpace() {
    return _pageScaffold(
      title: '4) 공간 특성',
      hint: '공간에 대한 선호를 별로 표현하세요. (0~5개)',
      children: [
        _likertTile('실내 선호 비율 (indoor_ratio)', '🏠', indoorRatio, (v) => setState(() => indoorRatio = v)),
        _likertTile('혼잡 예상 허용도 (crowdedness_expected)', '👥', crowdednessExpected,
            (v) => setState(() => crowdednessExpected = v)),
        _likertTile('사진 스팟 가치 (photo_worthiness)', '📸', photoWorthiness,
            (v) => setState(() => photoWorthiness = v)),
        _likertTile('뷰/풍경 선호 (scenic_view)', '🌇', scenicView, (v) => setState(() => scenicView = v)),
      ],
    );
  }

  // ---------- Submit (→ ResultPage) ----------
  Future<void> _submit() async {
    setState(() => _submitting = true);

    String f(double v) => v.toStringAsFixed(2);
    final pretty = '''
places = np.array([[ 
    ${f(_scoreFromStars(foodCafe))}, ${f(_scoreFromStars(cultureArt))}, ${f(_scoreFromStars(activitySports))}, ${f(_scoreFromStars(natureHealing))}, ${f(_scoreFromStars(craftExperience))}, ${f(_scoreFromStars(shopping))},               # main category
    ${f(_scoreFromStars(quiet))}, ${f(_scoreFromStars(romantic))}, ${f(_scoreFromStars(trendy))}, ${f(_scoreFromStars(privateVibe))}, ${f(_scoreFromStars(artistic))}, ${f(_scoreFromStars(energetic))},   # atmosphere
    ${f(_scoreFromStars(passiveEnjoyment))}, ${f(_scoreFromStars(activeParticipation))}, ${f(_scoreFromStars(socialBonding))}, ${f(_scoreFromStars(relaxationFocused))},             # experienceType
    ${f(_scoreFromStars(indoorRatio))}, ${f(_scoreFromStars(crowdednessExpected))}, ${f(_scoreFromStars(photoWorthiness))}, ${f(_scoreFromStars(scenicView))},            # spaceCharacteristics
]])''';

    if (!mounted) return;
    setState(() => _submitting = false);

    // 풀스크린 결과 페이지로 이동 (현재 설문 페이지 대체)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultPage(pretty: pretty)),
    );
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
