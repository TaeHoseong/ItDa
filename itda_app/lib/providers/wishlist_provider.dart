import 'package:flutter/foundation.dart';

import '../models/wishlist.dart';
import '../services/wishlist_api_service.dart';

/// 찜목록 상태 관리 Provider
class WishlistProvider extends ChangeNotifier {
  List<Wishlist> _wishlists = [];
  bool _isLoading = false;
  String? _error;

  List<Wishlist> get wishlists => List.unmodifiable(_wishlists);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 찜목록 로드
  Future<void> loadWishlists() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _wishlists = await WishlistApiService.getWishlists();
      debugPrint('찜목록 로드 완료: ${_wishlists.length}개');
    } catch (e) {
      _error = e.toString();
      debugPrint('찜목록 로드 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 찜 추가
  Future<bool> addWishlist({
    required String placeName,
    required double latitude,
    required double longitude,
    String? address,
    String? category,
    String? memo,
    String? link,
  }) async {
    try {
      final wishlist = await WishlistApiService.addWishlist(
        placeName: placeName,
        latitude: latitude,
        longitude: longitude,
        address: address,
        category: category,
        memo: memo,
        link: link,
      );
      _wishlists.insert(0, wishlist); // 최신순으로 맨 앞에 추가
      notifyListeners();
      debugPrint('찜 추가 완료: ${wishlist.placeName}');
      return true;
    } catch (e) {
      debugPrint('찜 추가 실패: $e');
      return false;
    }
  }

  /// 찜 삭제
  Future<bool> removeWishlist(String id) async {
    try {
      await WishlistApiService.deleteWishlist(id);
      _wishlists.removeWhere((w) => w.id == id);
      notifyListeners();
      debugPrint('찜 삭제 완료: $id');
      return true;
    } catch (e) {
      debugPrint('찜 삭제 실패: $e');
      return false;
    }
  }

  /// 좌표로 찜 여부 확인 (로컬 캐시에서)
  bool isWishlisted(double latitude, double longitude) {
    const tolerance = 0.0001; // 약 11m
    return _wishlists.any((w) =>
        (w.latitude - latitude).abs() < tolerance &&
        (w.longitude - longitude).abs() < tolerance);
  }

  /// 좌표로 찜 찾기 (로컬 캐시에서)
  Wishlist? findByCoordinates(double latitude, double longitude) {
    const tolerance = 0.0001;
    try {
      return _wishlists.firstWhere((w) =>
          (w.latitude - latitude).abs() < tolerance &&
          (w.longitude - longitude).abs() < tolerance);
    } catch (e) {
      return null;
    }
  }

  /// ID로 찜 찾기
  Wishlist? findById(String id) {
    try {
      return _wishlists.firstWhere((w) => w.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 초기화
  void clear() {
    _wishlists = [];
    _error = null;
    notifyListeners();
  }
}
