import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/lesson_topic_model.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../routes/app_pages.dart';

class HomeController extends GetxController {
  final LessonRepository _repository = Get.isRegistered<LessonRepository>()
      ? Get.find<LessonRepository>()
      : Get.put(LessonRepository());

  final curriculum = <CurriculumLesson>[].obs;
  final selectedLessonNumber = 1.obs;

  int get totalTopics =>
      curriculum.fold(0, (sum, lesson) => sum + lesson.topics.length);

  int get readyTopicsCount => curriculum.fold(
        0,
        (sum, lesson) =>
            sum + lesson.topics.where((t) => t.isReady).length,
      );

  CurriculumLesson? get activeLesson {
    if (curriculum.isEmpty) return null;
    for (final lesson in curriculum) {
      if (lesson.lessonNumber == selectedLessonNumber.value) return lesson;
    }
    return curriculum.first;
  }

  CurriculumTopicMeta? get firstReadyTopic {
    for (final lesson in curriculum) {
      for (final topic in lesson.topics) {
        if (topic.isReady) return topic;
      }
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    curriculum.assignAll(_repository.getCurriculum());
  }

  void selectLesson(int lessonNumber) {
    selectedLessonNumber.value = lessonNumber;
  }

  void openTopic(CurriculumTopicMeta topic) {
    if (topic.isReady && topic.jsonAssetPath != null) {
      Get.toNamed(Routes.LESSON, arguments: topic);
      return;
    }
    Get.snackbar(
      '${topic.code} Belum Aktif',
      'Kirim foto teks percakapan buku untuk ${topic.code} agar audio & 5 stage-nya dibuatkan.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF1E293B),
      colorText: const Color(0xFFF8FAFC),
      margin: const EdgeInsets.all(16),
    );
  }
}
