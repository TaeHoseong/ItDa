import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:itda_app/main.dart'; // MainScreen 사용

import '../services/user_api_service.dart';
import '../services/auth_flow_helper.dart';
import '../providers/user_provider.dart';
import '../models/user_persona.dart';

/// SurveyScreen (4-page wizard + 5-star Likert)
/// - 4개 섹션(페이지): 1) mainCategory, 2) atmosphere, 3) experienceType, 4) spaceCharacteristics
/// - 각 문항은 0~5개의 별로 응답 (별 1개 = 0.2점, 총점은 1.0으로 cap)
/// - 제출 시 풀스크린 결과 페이지로 이동(확인 누르면 MainScreen으로)
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

/// 설문 결과 도출용 모델
class PersonaResult {
  final String title;        // 메인 페르소나 이름
  final String tagline;      // 한 줄 요약
  final List<String> badges; // 키워드 태그
  final String detail;       // 상세 설명
  final List<String> tips;   // 데이트 코스 추천 방향 / 해설

  const PersonaResult({
    required this.title,
    required this.tagline,
    required this.badges,
    required this.detail,
    required this.tips,
  });
}

class _SurveyScreenState extends State<SurveyScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  bool _submitting = false;

  // ====== 별 개수(0~5) 저장 ======
  // mainCategory (6)
  int foodCafe = 0,
      cultureArt = 0,
      activitySports = 0,
      natureHealing = 0,
      craftExperience = 0,
      shopping = 0;

  // atmosphere (6)
  int quiet = 0,
      romantic = 0,
      trendy = 0,
      privateVibe = 0,
      artistic = 0,
      energetic = 0;

  // experienceType (4)
  int passiveEnjoyment = 0,
      activeParticipation = 0,
      socialBonding = 0,
      relaxationFocused = 0;

  // spaceCharacteristics (4)
  int indoorRatio = 0,
      crowdednessExpected = 0,
      photoWorthiness = 0,
      scenicView = 0;

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
                color: active ? const Color(0xFFEDEDED) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? const Color(0xFFEDEDED) : Colors.grey.shade300,
                ),
              ),
              child: Text(
                '${i + 1}. ${items[i]}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? const Color(0xFFFD9180) : Colors.grey.shade700,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              icon: isLast
                  ? (_submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goTo(int page) {
    _pageCtrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
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
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      // 1) 별점 → 0.0~1.0 스코어 문자열 (기존 pretty 그대로 유지)
      String f(double v) => v.toStringAsFixed(2);
      final pretty = '''
places = np.array([[ 
    ${f(_scoreFromStars(foodCafe))}, ${f(_scoreFromStars(cultureArt))}, ${f(_scoreFromStars(activitySports))}, ${f(_scoreFromStars(natureHealing))}, ${f(_scoreFromStars(craftExperience))}, ${f(_scoreFromStars(shopping))},
    ${f(_scoreFromStars(quiet))}, ${f(_scoreFromStars(romantic))}, ${f(_scoreFromStars(trendy))}, ${f(_scoreFromStars(privateVibe))}, ${f(_scoreFromStars(artistic))}, ${f(_scoreFromStars(energetic))},
    ${f(_scoreFromStars(passiveEnjoyment))}, ${f(_scoreFromStars(activeParticipation))}, ${f(_scoreFromStars(socialBonding))}, ${f(_scoreFromStars(relaxationFocused))},
    ${f(_scoreFromStars(indoorRatio))}, ${f(_scoreFromStars(crowdednessExpected))}, ${f(_scoreFromStars(photoWorthiness))}, ${f(_scoreFromStars(scenicView))},
]])''';

      // 2) 설문 결과 → UserPersona 모델 (필드명은 너 user_persona.dart에 맞게 조정)
      final personaModel = UserPersona(
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

      // 3) 백엔드에 설문 저장
      final userProvider = context.read<UserProvider>();
      await UserApiService.submitSurvey(userProvider.user?.userId, personaModel);

      // 4) UserProvider에서 surveyDone 플래그만 true로 변경
      if (userProvider.user != null) {
        userProvider.markSurveyDone();
      }

      // 5) 로컬에서 페르소나 분석 결과 생성 (기존 로직 유지)
      final personaResult = _buildPersonaResult();

      if (!mounted) return;
      setState(() => _submitting = false);

      // 6) 결과 페이지로 이동 (MainScreen이 아니라 ResultPage → 여기서 확인 버튼으로 PostAuthNavigator 태움)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            pretty: pretty,
            persona: personaResult,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('설문 저장 중 오류가 발생했습니다: $e')),
      );

    }
  }

  // ---------- Reusable UI ----------
  Widget _pageScaffold({
    required String title,
    required String hint,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      children: [
        _sectionTitle(title),
        _hint(hint),
        const SizedBox(height: 4),
        ...children.map(
          (w) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: w,
          ),
        ),
        const SizedBox(height: 80), // 하단 버튼 공간
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(color: Colors.grey),
        ),
      );

  Widget _likertTile(
    String title,
    String emoji,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            _StarRating(
              value: value,
              onChanged: onChanged,
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_scoreFromStars(value).toStringAsFixed(2)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Persona 생성 로직 ----------
  PersonaResult _buildPersonaResult() {
    double s(int v) => _scoreFromStars(v);

    final foodie      = s(foodCafe);
    final culture     = s(cultureArt);
    final activity    = max(s(activitySports), s(activeParticipation));
    final nature      = s(natureHealing);
    final craft       = s(craftExperience);
    final shoppingLv  = s(shopping);

    final quietLv     = s(quiet);
    final romanticLv  = s(romantic);
    final trendyLv    = s(trendy);
    final privateLv   = s(privateVibe);
    final artisticLv  = s(artistic);
    final energeticLv = s(energetic);

    final passiveLv   = s(passiveEnjoyment);
    final socialLv    = s(socialBonding);
    final relaxLv     = s(relaxationFocused);

    final indoorLv    = s(indoorRatio);
    final crowdLv     = s(crowdednessExpected);
    final photoLv     = max(s(photoWorthiness), s(scenicView));
    final viewLv      = s(scenicView);

    // ===== 뱃지 후보: 점수 내림차순 정렬 후 상위 6개 선택 =====
    final badgeCandidates = <MapEntry<double, String>>[
      MapEntry(foodie,      '🍽 미식 탐험가'),
      MapEntry(culture,     '🎭 전시·공연 러버'),
      MapEntry(activity,    '🏃 액티비티 러버'),
      MapEntry(nature,      '🌿 자연 힐링러'),
      MapEntry(craft,       '🧵 공방·체험 좋아함'),
      MapEntry(shoppingLv,  '🛍 쇼핑 코스 선호'),
      MapEntry(romanticLv,  '💘 로맨틱 무드'),
      MapEntry(trendyLv,    '🔥 트렌디 스팟 선호'),
      MapEntry(privateLv,   '🤫 프라이빗 & 조용함 선호'),
      MapEntry(quietLv,     '🤫 조용한 무드 선호'),
      MapEntry(artisticLv,  '🖼 감각적인 공간 선호'),
      MapEntry(energeticLv, '⚡ 활기찬 에너지'),
      MapEntry(socialLv,    '🧑‍🤝‍🧑 소셜형 데이트'),
      MapEntry(relaxLv,     '🧘 휴식·편안함 중시'),
      MapEntry(photoLv,     '📸 인생샷 필수'),
      MapEntry(viewLv,      '🌇 뷰 맛집 선호'),
    ];

    // 점수 기준 내림차순 정렬
    badgeCandidates.sort((a, b) => b.key.compareTo(a.key));

    // 점수가 0 초과인 것만 상위 6개 추출
    final badges = badgeCandidates
        .where((e) => e.key >= 0.6)
        .take(6)
        .map((e) => e.value)
        .toList();

    final trimmedBadges =
        badges.isEmpty ? ['🔍 밸런스형 취향'] : badges;

    // 페르소나 타이틀 / 요약 / 팁
        // ----- 페르소나 타이틀 / 요약 / 팁 (다양화 버전) -----
    String title;
    String tagline;
    final tips = <String>[];
    final detailLines = <String>[];

    final result1 = (foodie + trendyLv + photoLv) / 3;
    final result2 = (nature + relaxLv + indoorLv) / 3;
    final result3 = (activity + socialLv + energeticLv) / 3;
    final result4 = (culture + artisticLv + quietLv) / 3;
    final result5 = (privateLv + romanticLv) / 2;
    final result6 = (indoorLv + relaxLv + quietLv) / 3;
    final result7 = (trendyLv + shoppingLv + crowdLv) / 3;
    final result8 = (nature + activity + photoLv) / 3;
    final result9 = (relaxLv + passiveLv + quietLv) / 3;
    final result10 = (shoppingLv + indoorLv + trendyLv) / 3;
    final result11 = (foodie + trendyLv + photoLv + nature + relaxLv + indoorLv + activity + socialLv + energeticLv + culture + artisticLv + quietLv + privateLv + romanticLv + shoppingLv + crowdLv + passiveLv) / 17;

    // 결과들을 Map으로 묶기
    final results = {
      'result1': result1,
      'result2': result2,
      'result3': result3,
      'result4': result4,
      'result5': result5,
      'result6': result6,
      'result7': result7,
      'result8': result8,
      'result9': result9,
      'result10': result10,
      'result11': result11,
    };

    // 값(value) 기준 내림차순 정렬
    final sortedResults = results.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 최고값
    final maxValue = sortedResults.first.value;

    
    // 동점 처리: 오차 없이 정확히 동일한 값만 인정
    final topEntries = sortedResults
        .where((e) => e.value == maxValue)
        .toList();

    // 동점일 때 result 번호가 큰 것 우선
    String pickBestKey(List<MapEntry<String, double>> entries) {
      entries.sort((a, b) {
        final aNum = int.parse(a.key.replaceFirst('result', ''));
        final bNum = int.parse(b.key.replaceFirst('result', ''));
        return bNum.compareTo(aNum);
      });
      return entries.first.key;
    }

    final bestKey = pickBestKey(topEntries);

    switch (bestKey) {
      // 1) 트렌디 + 미식 + 포토
      case 'result1':
        title = '트렌디 미식 & 포토 스팟형';
        tagline = '핫플과 맛집, 사진 맛집을 동시에 즐기는 타입이에요.';
        tips.add('감성 카페 → 루프탑 혹은 바 → 야경 포인트로 이어지는 코스를 추천해요.');
        tips.add('신상 디저트 숍이나 전시+카페 조합도 잘 어울려요.');
        break;

      // 2) 자연 + 휴식 (+뷰)
      case 'result2':
        title = '도심 탈출 힐링러';
        tagline = '조용한 야외와 여유를 찾는 타입이에요.';
        tips.add('강변·호수·공원 산책과 한적한 뷰 카페를 잇는 코스를 추천해요.');
        tips.add('드라이브 + 전망대 + 티타임 루트도 잘 맞아요.');
        break;

      // 3) 액티비티 + 소셜 + 에너지
      case 'result3':
        title = '에너제틱 액티브 플레이어';
        tagline = '함께 움직이고 즐기며 추억을 쌓는 활동형 타입이에요.';
        tips.add('실내 스포츠, 체험 공방, 게임/보드카페를 한 코스로 엮어보세요.');
        tips.add('시간대별로 난이도(가벼운 체험 → 활동적인 콘텐츠)를 조절하면 좋아요.');
        break;

      // 4) 문화 + 아트 + 잔잔함
      case 'result4':
        title = '아트 & 스토리텔러형';
        tagline = '전시·공연·서점에서 대화와 생각을 나누는 취향이에요.';
        tips.add('소규모 전시 → 독립서점 → 티룸/조용한 카페 루트를 추천해요.');
        tips.add('콘텐츠 중심 대화를 즐길 수 있는 공간을 골라주세요.');
        break;

      // 5) 프라이빗 + 로맨틱
      case 'result5':
        title = '프라이빗 로맨티스트';
        tagline = '둘만의 온도와 분위기를 지키는 것을 가장 중요하게 생각해요.';
        tips.add('프라이빗룸 식당, 조용한 와인바, 숨은 골목 카페를 중심으로 코스를 설계해요.');
        tips.add('사람이 덜 붐비는 시간대/동네를 골라주는 게 포인트예요.');
        break;

      // 6) 인도어 + 휴식 + 조용함
      case 'result6':
        title = '실내 아지트 러버';
        tagline = '편안한 실내 공간에서 느긋하게 보내는 걸 선호해요.';
        tips.add('편안한 카페, 북카페, 라운지 바, 영화관 등을 1~2코스로 깊게 즐기게 해주세요.');
        break;

      // 7) 트렌디 + 쇼핑 + 도심
      case 'result7':
        title = '도심 핫스팟 러버';
        tagline = '번화가와 쇼핑, 사람 많은 활기찬 분위기를 즐기는 타입이에요.';
        tips.add('핫한 상권의 쇼핑 → 인기 식당/카페 코스를 추천해요.');
        tips.add('신상 플레이스 큐레이션과 잘 어울려요.');
        break;

      // 8) 자연 + 액티비티 (아웃도어 모험)
      case 'result8':
        title = '아웃도어 어드벤처형';
        tagline = '풍경과 활동을 함께 즐기는 야외형 타입이에요.';
        tips.add('트레킹, 자전거, 액티비티 후 뷰 좋은 카페/식당으로 이어지는 동선을 추천해요.');
        break;

      // 9) 패시브 + 휴식 + 감상
      case 'result9':
        title = '슬로우 라이프 감상러';
        tagline = '과한 움직임보다 여유 있고 잔잔한 감상을 선호해요.';
        tips.add('영화관, 전시, 북카페, 티룸 등 조용히 머물 수 있는 공간 위주 코스를 추천해요.');
        break;

      // 10) 쇼핑 + 실용 + 실내
      case 'result10':
        title = '실속형 쇼핑 & 코스형';
        tagline = '실용적인 동선과 목적이 있는 데이트를 선호해요.';
        tips.add('몰/복합문화공간에서 쇼핑 + 식사 + 카페를 한 번에 해결하는 코스를 추천해요.');
        break;

      // 11) 올라운더 (혹은 기본값)
      case 'result11':
      default:
        title = '밸런스형 올라운더';
        tagline = '상황과 기분에 따라 다양한 스타일을 자연스럽게 즐기는 타입이에요.';
        tips.add('서로의 컨디션에 맞춰 테마를 바꾸는 유연한 추천과 잘 어울려요.');
        break;
    }

    // ----- 상세 설명 (detailLines) -----
    if (foodie >= 0.8) {
      detailLines.add('맛집과 카페 비중을 높게 두면 만족도가 올라가는 편이에요.');
    }
    if (nature >= 0.8) {
      detailLines.add('바람 쐴 수 있는 산책로, 공원, 뷰 스팟을 포함하면 더 잘 맞아요.');
    }
    if (activity >= 0.8) {
      detailLines.add('직접 참여하는 액티비티를 한 코스 이상 넣어두면 좋은 반응을 기대할 수 있어요.');
    }
    if (relaxLv >= 0.8 && trendyLv < 0.6) {
      detailLines.add('복잡하고 붐비는 곳보다는 여유 있고 편안한 동선을 선호하는 편이에요.');
    }
    if (photoLv >= 0.8) {
      detailLines.add('사진이 잘 나오는 포인트를 중간중간 배치하면 기록하는 재미를 느낄 수 있어요.');
    }
    if (privateLv >= 0.8 && crowdLv < 0.6) {
      detailLines.add('사람이 적고 방해받지 않는 공간에서 둘만의 시간을 보내는 것이 중요해요.');
    }
    if (socialLv >= 0.6 && energeticLv >= 0.6) {
      detailLines.add('함께 웃고 떠들 수 있는 활동과 공간에서 에너지를 많이 받는 타입이에요.');
    }

    final detail = detailLines.isEmpty
        ? '응답 결과가 고르게 분포되어 있어, 다양한 데이트 코스를 유연하게 즐길 수 있는 타입이에요.'
        : detailLines.join('\n');

    return PersonaResult(
      title: title,
      tagline: tagline,
      badges: trimmedBadges,
      detail: detail,
      tips: tips,
    );
  }
}

// ================== 별점 위젯 ==================
class _StarRating extends StatelessWidget {
  final int value; // 0~5
  final ValueChanged<int> onChanged;

  const _StarRating({
    required this.value,
    required this.onChanged,
    super.key,
  });

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
          icon: Icon(
            filled ? Icons.star : Icons.star_border,
            color: filled ? Colors.amber : Colors.grey,
          ),
          onPressed: () => onChanged(value == index ? 0 : index),
          tooltip: '$index개',
        );
      }),
    );
  }
}

// ================== 제출 결과 페이지 ==================
class ResultPage extends StatelessWidget {
  final String pretty;
  final PersonaResult persona;

  const ResultPage({
    super.key,
    required this.pretty,
    required this.persona,
  });

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                persona.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                persona.tagline,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: persona.badges
                    .map(
                      (b) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          b,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),

              Text(
                persona.detail,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),

              if (persona.tips.isNotEmpty) ...[
                const Text(
                  '이런 코스를 추천해요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                ...persona.tips.map(
                  (t) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(
                        child: Text(
                          t,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  '세부 응답 데이터 보기',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                children: [
                  Card(
                    color: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        pretty,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '# 컬럼 순서\n'
                    '- main: [food_cafe, culture_art, activity_sports, nature_healing, craft_experience, shopping]\n'
                    '- atmos: [quiet, romantic, trendy, private, artistic, energetic]\n'
                    '- exp: [passive_enjoyment, active_participation, social_bonding, relaxation_focused]\n'
                    '- space: [indoor_ratio, crowdedness_expected, photo_worthiness, scenic_view]',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ],
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final userProvider = context.read<UserProvider>();
                    final user = userProvider.user;

                    if (user != null) {
                      PostAuthNavigator.routeWithUser(
                        context,
                        user: user,
                      );
                    } else {
                      // 혹시 모를 예외 상황: 유저 정보가 없으면 그냥 메인으로 fallback
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const MainScreen(),
                        ),
                        (route) => false,
                      );
                    }
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
