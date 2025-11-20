import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'secrets.dart';
import 'screens/auth/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/persona_screen.dart';
import 'screens/calendar_screen.dart';

import 'providers/persona_chat_provider.dart';
import 'providers/map_provider.dart';
import 'providers/course_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 날짜 포맷 (ko_KR)
  await initializeDateFormatting('ko_KR', null);

  // 네이버 지도 초기화
  await FlutterNaverMap().init(
    clientId: NAVER_MAP_CLIENT_ID,
    onAuthFailed: (ex) {
      switch (ex) {
        case NQuotaExceededException(:final message):
          print("사용량 초과 (message: $message)");
          break;
        case NUnauthorizedClientException() ||
              NClientUnspecifiedException() ||
              NAnotherAuthFailedException():
          print("인증 실패: $ex");
          break;
      }
    },
  );

  // Supabase 초기화
  await Supabase.initialize(
    url: 'https://mzvrpbrwmtmgxtjbdbik.supabase.co',
    anonKey: SUPABASE_KEY,
  );

  // Hive 초기화
  await Hive.initFlutter();

  // Box 열기 (데이터 저장소)
  await Hive.openBox('bookmarks'); // 찜한 장소
  await Hive.openBox('schedules'); // 필요 없으면 나중에 제거해도 됨
  await Hive.openBox('user');      // 사용자 정보

  runApp(
    MultiProvider(
      providers: [
        // 1) 유저 정보
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),

        // 2) 코스/캘린더 상태 (Supabase 연동)
        ChangeNotifierProvider(
          create: (_) => CourseProvider(),
        ),

        // 3) PersonaChatProvider ← CourseProvider 주입
        ChangeNotifierProxyProvider<CourseProvider, PersonaChatProvider>(
          create: (context) => PersonaChatProvider.withCourseProvider(
            Provider.of<CourseProvider>(context, listen: false),
          ),
          update: (context, courseProvider, previous) =>
              previous ?? PersonaChatProvider.withCourseProvider(courseProvider),
        ),

        // 4) 지도/네비
        ChangeNotifierProvider(
          create: (_) => MapProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => NavigationProvider(),
        ),
        ChangeNotifierProxyProvider<UserProvider, ChatProvider>(
          create: (_) => ChatProvider(Supabase.instance.client),
          update: (_, userProvider, chatProvider) {
            chatProvider ??= ChatProvider(Supabase.instance.client);

            final user = userProvider.user;
            final userId = user?.userId;
            final coupleId = user?.coupleId;

            chatProvider.configure(
              userId: userId,
              coupleId: coupleId,
            );

            return chatProvider;
          },
        ),
      ],
      child: const ItdaApp(),
    ),
  );
}

class ItdaApp extends StatelessWidget {
  const ItdaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '잇다',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB6C1),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF8F5),

        // NavigationBar 스타일
        navigationBarTheme: NavigationBarThemeData(
          elevation: 3,
          height: 72,
          indicatorShape: const StadiumBorder(),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0x1AFF69B4),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            );
          }),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 초기 문구들
  final List<String> personaSentences = [
    '오늘 하루는 어땠나요?',
    '요즘 즐겨 먹는 음식이 있나요?',
    '태희 님은 잘 못 먹는 음식이 있나요?',
    '최근에 가고 싶은 카페가 있나요?',
  ];

  int _personaIdx = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // 처음 한 번만 생성해서 계속 재사용
    _pages = [
      PersonaScreen(
        initialText: personaSentences[_personaIdx],
      ),
      const MapScreen(),
      const CalendarScreen(),
      const ChatScreen(),
    ];

    // ✅ 로그인 후(MainScreen 진입 후) 커플 기준 Supabase 연동 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final courseProvider = Provider.of<CourseProvider>(context, listen: false);
      final userProvider   = Provider.of<UserProvider>(context, listen: false);
      
      final coupleId = userProvider.user?.coupleId;

      if (coupleId != null) {
        try {
          await courseProvider.initForCouple(coupleId);
        } catch (e) {
          debugPrint('initForCouple 실패: $e');
        }
      } else {
        debugPrint('⚠ coupleId가 null 입니다. 로그인 후 UserProvider에 coupleId를 세팅했는지 확인하세요.');
      }
    });
  }

  void _nextPersonaSentence() {
    setState(() {
      _personaIdx = (_personaIdx + 1) % personaSentences.length;

      // 탭 다시 눌렀을 때, 첫 화면 문구만 교체 (채팅 기록은 Provider가 들고 있어서 안 날아감)
      _pages[0] = PersonaScreen(
        initialText: personaSentences[_personaIdx],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();

    return Scaffold(
      body: IndexedStack(
        index: navigationProvider.currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFFFAF8F5),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 20,
                offset: Offset(0, 0),
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            child: NavigationBarTheme(
              data: const NavigationBarThemeData(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent, // no pill behind icons
                elevation: 0,
              ),
              child: NavigationBar(
                height: 72,
                selectedIndex: navigationProvider.currentIndex,
                labelBehavior:
                    NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (index) {
                  if (navigationProvider.currentIndex == index &&
                      index == 0) {
                    _nextPersonaSentence();
                  }
                  navigationProvider.setIndex(index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.favorite_border_rounded),
                    selectedIcon: Icon(Icons.favorite_rounded),
                    label: '추천',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.location_on_outlined),
                    selectedIcon: Icon(Icons.location_on_rounded),
                    label: '지도',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: '달력',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline_rounded),
                    selectedIcon: Icon(Icons.chat_bubble_rounded),
                    label: '채팅',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
