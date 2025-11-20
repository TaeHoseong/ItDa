// lib/providers/user_provider.dart
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class UserProvider extends ChangeNotifier {
  AppUser? _user;

  AppUser? get user => _user;

  bool get isLoggedIn => _user != null;
  bool get surveyDone => _user?.surveyDone ?? false;
  bool get coupleMatched => _user?.coupleMatched ?? false;

  void setUser(AppUser? user) {
    _user = user;
    notifyListeners();
  }

  /// 설문 완료 후 플래그만 true로 업데이트
  void markSurveyDone() {
    if (_user == null) return;
    _user = _user!.copyWith(surveyDone: true);
    notifyListeners();
  }

  /// 매칭 완료 후 coupleId를 세팅하는 용도 (나중에 매칭 완료 API 연동 시 사용)
  void setCoupleId(String coupleId) {
    if (_user == null) return;
    _user = _user!.copyWith(coupleId: coupleId);
    notifyListeners();
  }

  void clear() {
    _user = null;
    notifyListeners();
  }
}
