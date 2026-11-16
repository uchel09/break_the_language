import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/lesson_topic_model.dart';

/// Loads lesson topic JSON payloads and provides the 12-Lesson x 3-Topic catalog.
class LessonRepository {
  Future<TopicData> loadTopic(String assetJsonPath) async {
    final rawJson = await rootBundle.loadString(assetJsonPath);
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    return TopicData.fromJson(decoded);
  }

  /// Returns all 12 lessons with 3 topics each (36 topics total).
  List<CurriculumLesson> getCurriculum() {
    const lessonTitles = <String>[
      'Greetings & First Impressions',
      'Daily Routines & Habits',
      'Cafe, Food & Ordering',
      'Getting Around & Directions',
      'Shopping & Bargaining',
      'Making Plans & Invitations',
      'Work, Study & Deadlines',
      'Hobbies & Weekend Stories',
      'Health, Emergencies & Help',
      'Travel & Airport Situations',
      'Opinions & Friendly Debates',
      'Storytelling & Natural Fluency',
    ];

    return List<CurriculumLesson>.generate(12, (lessonIdx) {
      final lessonNum = lessonIdx + 1;
      final level = lessonNum <= 4
          ? 'A2 Foundation'
          : (lessonNum <= 8 ? 'B1 Intermediate' : 'B1+ Fluency');

      final topics = List<CurriculumTopicMeta>.generate(3, (topicIdx) {
        final topicNum = topicIdx + 1;
        if (lessonNum == 1 && topicNum == 1) {
          return const CurriculumTopicMeta(
            lessonNumber: 1,
            topicNumber: 1,
            title: 'Meeting Someone New',
            subtitle: 'Maya, Chloe & Ryan — Keluar dari Kedai Kopi',
            level: 'A2 → B1 Starter',
            isReady: true,
            jsonAssetPath: 'assets/data/lessons/lesson_01/topic_01.json',
            estimatedSizeMb: 2.97,
          );
        }

        return CurriculumTopicMeta(
          lessonNumber: lessonNum,
          topicNumber: topicNum,
          title: 'Topic ${topicNum.toString().padLeft(2, '0')} — Pending Photo',
          subtitle: 'Menunggu foto percakapan Lesson $lessonNum Topic $topicNum',
          level: level,
          isReady: false,
        );
      });

      return CurriculumLesson(
        lessonNumber: lessonNum,
        title: lessonTitles[lessonIdx],
        focus: level,
        topics: topics,
      );
    });
  }
}
