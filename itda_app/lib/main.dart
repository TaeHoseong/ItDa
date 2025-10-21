import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/recommend_screen.dart';
import 'screens/map_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/char_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 초기화
  await Hive.initFlutter();

  // Box 열기 (데이터 저장소)
  await Hive.openBox('bookmarks'); // 찜한 장소
  await Hive.openBox('schedules');  // 일정
  await Hive.openBox('user');       // 사용자 정보

  runApp(const ItdaApp());
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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 1) Define your persona sentences here
  final List<String> personaSentences = [
    '오늘 하루는 어땠나요?',
    '요즘 즐겨 먹는 음식이 있나요?',
    '태희 님은 잘 못 먹는 음식이 있나요?',
    '최근에 가고 싶은 카페가 있나요?',
  ];

  int _personaIdx = 0;

  String get _currentPersonaSentence => personaSentences[_personaIdx];

  // 2) Cycle to the next sentence
  void _nextPersonaSentence() {
    setState(() {
      _personaIdx = (_personaIdx + 1) % personaSentences.length;
    });
  }

  // 3) Build screens with the current dynamic sentence + callback
  List<Widget> _buildScreens() {
    return [
      const HomeScreen(),
      const MapScreen(),
      PersonaScreen(
        initialText: _currentPersonaSentence,
      ),
      const ChatScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();

    return Scaffold(
      body: screens[_currentIndex],
      // 4) Material 3 NavigationBar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          // if Persona tab (index 2) is tapped again, cycle sentence
          if (_currentIndex == index && index == 2) {
            _nextPersonaSentence();
          }
          setState(() => _currentIndex = index);
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '달력',
          ),
          NavigationDestination
          (
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on_rounded),
            label: '지도',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: '추천',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: '채팅',
          ),
        ],
      ),
    );
  }
}