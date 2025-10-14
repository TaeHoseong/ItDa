import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../services/bookmark_service.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Bookmark> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  void _loadBookmarks() {
    setState(() {
      _bookmarks = BookmarkService.getAllBookmarks();
    });
  }

  void _removeBookmark(String id) {
    BookmarkService.removeBookmark(id);
    _loadBookmarks();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('찜이 삭제되었습니다')),
    );
  }

  void _addBookmark() {
    // 테스트용 찜 추가
    final bookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '테스트 장소 ${_bookmarks.length + 1}',
      category: '카페',
      address: '서울시 강남구',
    );
    BookmarkService.addBookmark(bookmark);
    _loadBookmarks();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('찜이 추가되었습니다')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('찜한 장소'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _bookmarks.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              '찜한 장소가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = _bookmarks[index];
          return _buildBookmarkCard(bookmark);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBookmark,
        backgroundColor: const Color(0xFFFF69B4),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBookmarkCard(Bookmark bookmark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE5EC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.place,
            color: Color(0xFFFF69B4),
          ),
        ),
        title: Text(
          bookmark.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              bookmark.category,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (bookmark.address != null) ...[
              const SizedBox(height: 2),
              Text(
                bookmark.address!,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _removeBookmark(bookmark.id),
        ),
      ),
    );
  }
}