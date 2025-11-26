import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUserId = 'user_id';
  final _storage = const FlutterSecureStorage();

  Future<void> save(String access, String? refresh, String? userId) async {
    await _storage.write(key: _kAccess, value: access);
    if (refresh != null) {
      await _storage.write(key: _kRefresh, value: refresh);
    }
    if (userId != null) {
      await _storage.write(key: _kUserId, value: userId);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUserId);
  }
}
