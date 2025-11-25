// lib/screens/diary_read_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/date_course.dart';
import '../providers/course_provider.dart';

class DiaryReadScreen extends StatelessWidget {
  final DateCourse course;

  const DiaryReadScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final diary =
        (course.id != null) ? courseProvider.getDiaryForCourse(course.id!) : null;

    final hasDiary = diary != null && diary.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('데이트 일기'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (hasDiary && course.id != null)
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('일기 삭제'),
                    content: const Text('이 코스의 일기를 모두 삭제할까요?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          '삭제',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await context
                      .read<CourseProvider>()
                      .deleteDiaryForCourse(course.id!);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('일기가 삭제되었습니다.')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      backgroundColor: const Color(0xFFFAF8F5),
      body: hasDiary
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: course.slots.length,
              itemBuilder: (context, index) {
                final slot = course.slots[index];
                final entry = (diary!.length > index) ? diary[index] : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.startTime,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${slot.emoji} ${slot.placeName}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (slot.placeAddress != null &&
                                    slot.placeAddress!.isNotEmpty)
                                  Text(
                                    slot.placeAddress!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (entry != null && entry.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.network(
                              entry.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                      if (entry != null && entry.imageUrl != null)
                        const SizedBox(height: 8),

                      if (entry != null)
                        Row(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (i) {
                                final filled = i < entry.rating;
                                return Icon(
                                  filled ? Icons.star : Icons.star_border,
                                  size: 20,
                                  color: Colors.amber,
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.rating}/5',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),

                      if (entry != null && entry.comment.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            entry.comment,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            )
          : const Center(
              child: Text(
                '아직 작성된 일기가 없어요.\n캘린더에서 일기를 먼저 작성해보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
            ),
    );
  }
}
