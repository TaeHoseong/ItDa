class Bookmark {
  final String id;
  final String title;
  final String category;
  final String? address;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.title,
    required this.category,
    this.address,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Map으로 변환 (저장용)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Map에서 생성 (불러오기용)
  factory Bookmark.fromMap(Map<dynamic, dynamic> map) {
    return Bookmark(
      id: map['id'],
      title: map['title'],
      category: map['category'],
      address: map['address'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}