import 'package:flutter/foundation.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// 지도 탭으로 이동 (인덱스 1)
  void navigateToMap() {
    setIndex(1);
  }

  /// 추천 탭으로 이동 (인덱스 0)
  void navigateToHome() {
    setIndex(0);
  }

  /// 캘린더 탭으로 이동 (인덱스 2)
  void navigateToCalendar() {
    setIndex(2);
  }

  /// 채팅 탭으로 이동 (인덱스 3)
  void navigateToChat() {
    setIndex(3);
  }
}
