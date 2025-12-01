import './date_course.dart';
class ChatMessage {
  final String id;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateCourse? course;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    this.course,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      course: json['course'] != null
          ? DateCourse.fromJson(json['course'])
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'content': content,
      'course': course?.toJson(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
