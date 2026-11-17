import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/lesson_topic_model.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'EngDestroying 2.0',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Obx(
              () => Chip(
                avatar: const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
                backgroundColor: const Color(0xFF1E293B),
                side: const BorderSide(color: Color(0xFF334155)),
                label: Text(
                  '${controller.readyTopicsCount}/${controller.totalTopics} Topik Aktif',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final activeLesson = controller.activeLesson;
        final featured = controller.latestReadyTopic;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (featured != null) _FeaturedHeroCard(topic: featured),
                const SizedBox(height: 20),
                const Text(
                  'Kurikulum 12 Lesson (36 Topik)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Setiap lesson berisi 3 percakapan progresif dengan 5 stage belajar lengkap.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.curriculum.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final lesson = controller.curriculum[index];
                      return Obx(() {
                        final selected =
                            controller.selectedLessonNumber.value ==
                                lesson.lessonNumber;
                        final readyCount =
                            lesson.topics.where((t) => t.isReady).length;
                        return _LessonChipCard(
                          lesson: lesson,
                          selected: selected,
                          readyCount: readyCount,
                          onTap: () =>
                              controller.selectLesson(lesson.lessonNumber),
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (activeLesson != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lesson ${activeLesson.lessonNumber.toString().padLeft(2, '0')}: ${activeLesson.title}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          activeLesson.focus,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...activeLesson.topics.map(
                    (topic) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TopicTile(
                        topic: topic,
                        onTap: () => controller.openTopic(topic),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
        if (!controller.audioEngine.hasActiveBackgroundSession) {
          return const SizedBox.shrink();
        }
        return const _HomeBackgroundPlayerBar();
      }),
    );
  }
}

class _FeaturedHeroCard extends GetView<HomeController> {
  const _FeaturedHeroCard({required this.topic});

  final CurriculumTopicMeta topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${topic.code} • SIAP DIMAINKAN',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${topic.estimatedSizeMb?.toStringAsFixed(2) ?? '-'} MB',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            topic.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            topic.subtitle,
            style: const TextStyle(fontSize: 14, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StageBadge(label: '1. Deep Listening'),
              _StageBadge(label: '2. Immersion + Mic'),
              _StageBadge(label: '3. Rapid 5s'),
              _StageBadge(label: '4. Role Play Duet'),
              _StageBadge(label: '5. Final Boss 45s'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => controller.openTopic(topic),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                'Mulai Lesson ${topic.lessonNumber.toString().padLeft(2, '0')} — Topic ${topic.topicNumber.toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0)),
      ),
    );
  }
}

class _LessonChipCard extends StatelessWidget {
  const _LessonChipCard({
    required this.lesson,
    required this.selected,
    required this.readyCount,
    required this.onTap,
  });

  final CurriculumLesson lesson;
  final bool selected;
  final int readyCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 188,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFF59E0B)
                : const Color(0xFF334155),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lesson ${lesson.lessonNumber.toString().padLeft(2, '0')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: selected
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFF8FAFC),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$readyCount/3',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: readyCount > 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              lesson.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.topic,
    required this.onTap,
  });

  final CurriculumTopicMeta topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ready = topic.isReady;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: ready
                      ? const Color(0xFF10B981).withValues(alpha: 0.16)
                      : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ready
                        ? const Color(0xFF10B981)
                        : const Color(0xFF334155),
                  ),
                ),
                child: Icon(
                  ready ? Icons.headphones_rounded : Icons.lock_clock_outlined,
                  color: ready
                      ? const Color(0xFF10B981)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          topic.code,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ready
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          topic.level,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topic.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                ready
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.photo_camera_outlined,
                size: 18,
                color: ready
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBackgroundPlayerBar extends GetView<HomeController> {
  const _HomeBackgroundPlayerBar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final engine = controller.audioEngine;
      final lineIdx = engine.activeLineIndex.value;
      final total = engine.activeTotalLines.value;
      final loopOn = engine.isLoopEnabled.value;
      final title = engine.activeTopicTitle.value.isNotEmpty
          ? engine.activeTopicTitle.value
          : 'Audio Pembelajaran';

      final statusText = lineIdx >= 0 && total > 0
          ? 'Baris ${lineIdx + 1}/$total${loopOn ? ' · Non-Stop' : ''}'
          : (engine.isAmbienceActive.value
              ? 'Suasana latar aktif${loopOn ? ' · Non-Stop' : ''}'
              : 'Sedang diputar${loopOn ? ' · Non-Stop' : ''}');

      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B1120),
          border: Border(
            top: BorderSide(color: Color(0xFFF59E0B), width: 1.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.headphones_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: controller.openActiveAudioTopic,
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFF8FAFC),
                              ),
                            ),
                            Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: loopOn
                          ? 'Matikan Non-Stop Loop'
                          : 'Aktifkan Non-Stop Loop',
                      onPressed: engine.toggleLoop,
                      icon: Icon(
                        loopOn
                            ? Icons.repeat_on_rounded
                            : Icons.repeat_rounded,
                        color: loopOn
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Buka Topik',
                      onPressed: controller.openActiveAudioTopic,
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        color: Color(0xFFCBD5E1),
                        size: 20,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hentikan Audio',
                      onPressed: engine.stopAll,
                      icon: const Icon(
                        Icons.stop_circle_rounded,
                        color: Color(0xFFEF4444),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
