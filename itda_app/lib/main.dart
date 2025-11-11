import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:intl/date_symbol_data_local.dart';


import 'secrets.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/persona_screen.dart';
import 'screens/calendar_screen.dart';

import 'providers/persona_chat_provider.dart';
import 'providers/map_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/navigation_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ko_KR', null);

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
          });

  // Hive 초기화
  await Hive.initFlutter();

  // Box 열기 (데이터 저장소)
  await Hive.openBox('bookmarks'); // 찜한 장소
  await Hive.openBox('schedules');
  await Hive.openBox('user');       // 사용자 정보

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PersonaChatProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ScheduleProvider(),
        ),
        ChangeNotifierProxyProvider<ScheduleProvider, PersonaChatProvider>(
          create: (context) => PersonaChatProvider.withScheduleProvider(
            Provider.of<ScheduleProvider>(context, listen: false),
          ),
          update: (context, scheduleProvider, previous) =>
              previous ?? PersonaChatProvider.withScheduleProvider(scheduleProvider),
        ),
        ChangeNotifierProvider(
          create: (_) => MapProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => NavigationProvider(),
        ),
        // 다른 Provider 있으면 여기에 추가
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

        // Optional: tune NavigationBar look & feel
        navigationBarTheme: NavigationBarThemeData(
          elevation: 3,
          height: 72,
          indicatorShape: const StadiumBorder(),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0x1AFF69B4), // subtle pink indicator
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

    // 백엔드에서 일정 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
      scheduleProvider.fetchSchedulesFromBackend();
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
        // Background behind the bar (same as page background)
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
                color: Color(0x22000000), // soft shadow
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
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (index) {
                  if (navigationProvider.currentIndex == index && index == 0) {
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
      )
    );
  }
}
