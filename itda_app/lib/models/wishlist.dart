/// 찜목록 모델
class Wishlist {
  final String id;
  final String coupleId;
  final String userId;
  final String placeName;
  final String? address;
  final String? category;
  final double latitude;
  final double longitude;
  final String? memo;
  final String? link;
  final DateTime createdAt;

  Wishlist({
    required this.id,
    required this.coupleId,
    required this.userId,
    required this.placeName,
    this.address,
    this.category,
    required this.latitude,
    required this.longitude,
    this.memo,
    this.link,
    required this.createdAt,
  });

  factory Wishlist.fromJson(Map<String, dynamic> json) {
    return Wishlist(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      userId: json['user_id'] as String,
      placeName: json['place_name'] as String,
      address: json['address'] as String?,
      category: json['category'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      memo: json['memo'] as String?,
      link: json['link'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'user_id': userId,
      'place_name': placeName,
      'address': address,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'memo': memo,
      'link': link,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
