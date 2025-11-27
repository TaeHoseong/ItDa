// lib/models/app_user.dart
class AppUser {
  final String userId;
  final String email;
  final String? name;
  final String? nickname;
  final String? birthday; // "YYYY-MM-DD"
  final String? gender;   // "male" / "female" (or null)
  final String? picture;  // profile image URL
  final String? coupleId; // null이면 아직 매칭 안된 상태
  final bool surveyDone;

  // 🔹 새로 추가: 우리가 만난 날
  final DateTime? firstMet;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// coupleId가 있으면 매칭된 상태라고 간주
  bool get coupleMatched => coupleId != null;

  const AppUser({
    required this.userId,
    required this.email,
    required this.surveyDone,
    this.name,
    this.nickname,
    this.birthday,
    this.gender,
    this.picture,
    this.coupleId,
    this.firstMet,   // 🔹 여기 추가
    this.createdAt,
    this.updatedAt,
  });

  /// backend `UserResponse` / `UserBase` JSON → AppUser
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      nickname: json['nickname'] as String?,
      birthday: json['birthday'] as String?,
      gender: json['gender'] as String?,
      picture: json['picture'] as String?,
      coupleId: json['couple_id'] as String?,
      surveyDone: json['survey_done'] as bool? ?? false,
      // 🔹 first_met 파싱
      firstMet: json['first_met'] != null
          ? DateTime.tryParse(json['first_met'] as String)
          : null,
      // created_at / updated_at 은 UserBase에만 있으니, 있으면 파싱하고 없으면 null
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  /// AppUser → JSON (필요하면 사용)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'name': name,
      'nickname': nickname,
      'birthday': birthday,
      'gender': gender,
      'picture': picture,
      'couple_id': coupleId,
      'survey_done': surveyDone,
      if (firstMet != null) 'first_met': firstMet!.toIso8601String(), // 🔹 추가
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? userId,
    String? email,
    String? name,
    String? nickname,
    String? birthday,
    String? gender,
    String? picture,
    String? coupleId,
    bool? surveyDone,
    DateTime? firstMet,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      picture: picture ?? this.picture,
      coupleId: coupleId ?? this.coupleId,
      surveyDone: surveyDone ?? this.surveyDone,
      firstMet: firstMet ?? this.firstMet, // 🔹 추가
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
