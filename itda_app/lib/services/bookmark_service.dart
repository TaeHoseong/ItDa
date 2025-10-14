import 'package:hive/hive.dart';
import '../models/bookmark.dart';

class BookmarkService {
  static final Box _box = Hive.box('bookmarks');

  // 찜 추가
  static Future<void> addBookmark(Bookmark bookmark) async {
    await _box.put(bookmark.id, bookmark.toMap());
  }

  // 찜 삭제
  static Future<void> removeBookmark(String id) async {
    await _box.delete(id);
  }

  // 모든 찜 가져오기
  static List<Bookmark> getAllBookmarks() {
    return _box.values
        .map((item) => Bookmark.fromMap(item))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 최신순
  }

  // 특정 찜이 있는지 확인
  static bool isBookmarked(String id) {
    return _box.containsKey(id);
  }

  // 카테고리별 찜 가져오기
  static List<Bookmark> getBookmarksByCategory(String category) {
    return getAllBookmarks()
        .where((bookmark) => bookmark.category == category)
        .toList();
  }
}