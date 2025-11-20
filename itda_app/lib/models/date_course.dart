/// 데이트 코스 모델
class DateCourse {
  final int? id;            // ⬅️ 백엔드 코스 ID (옵션)
  final String date;
  final String template;
  final String startTime;
  final String endTime;
  final double totalDistance;
  final int totalDuration;
  final List<CourseSlot> slots;

  DateCourse({
    this.id,
    required this.date,
    required this.template,
    required this.startTime,
    required this.endTime,
    required this.totalDistance,
    required this.totalDuration,
    required this.slots,
  });

  factory DateCourse.fromJson(Map<String, dynamic> json) {
    return DateCourse(
      id: json['id'] as int?,                          // ⬅️ 추가
      date: json['date'] as String,
      template: json['template'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      totalDistance: (json['total_distance'] as num).toDouble(),
      totalDuration: json['total_duration'] as int,
      slots: (json['slots'] as List)
          .map((slot) => CourseSlot.fromJson(slot as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,                        // ⬅️ 추가
      'date': date,
      'template': template,
      'start_time': startTime,
      'end_time': endTime,
      'total_distance': totalDistance,
      'total_duration': totalDuration,
      'slots': slots.map((slot) => slot.toJson()).toList(),
    };
  }
}


/// 코스 슬롯 (단일 장소)
class CourseSlot {
  final String slotType;
  final String emoji;
  final String startTime;
  final int duration;
  final String placeName;
  final String? placeAddress;
  final double latitude;
  final double longitude;
  final double? rating;
  final double score;
  final double? distanceFromPrevious;

  CourseSlot({
    required this.slotType,
    required this.emoji,
    required this.startTime,
    required this.duration,
    required this.placeName,
    this.placeAddress,
    required this.latitude,
    required this.longitude,
    this.rating,
    required this.score,
    this.distanceFromPrevious,
  });

  factory CourseSlot.fromJson(Map<String, dynamic> json) {
    return CourseSlot(
      slotType: json['slot_type'] as String,
      emoji: json['emoji'] as String,
      startTime: json['start_time'] as String,
      duration: json['duration'] as int,
      placeName: json['place_name'] as String,
      placeAddress: json['place_address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      score: (json['score'] as num).toDouble(),
      distanceFromPrevious: json['distance_from_previous'] != null
          ? (json['distance_from_previous'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slot_type': slotType,
      'emoji': emoji,
      'start_time': startTime,
      'duration': duration,
      'place_name': placeName,
      'place_address': placeAddress,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'score': score,
      'distance_from_previous': distanceFromPrevious,
    };
  }
}
