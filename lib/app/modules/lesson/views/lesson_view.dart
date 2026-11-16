import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/lesson_controller.dart';
import 'widgets/stage1_deep_listening_view.dart';
import 'widgets/stage2_immersion_view.dart';
import 'widgets/stage3_rapid_response_view.dart';
import 'widgets/stage4_role_play_view.dart';
import 'widgets/stage5_final_boss_view.dart';

class LessonView extends GetView<LessonController> {
  const LessonView({super.key});

  static const _stageLabels = <(String, IconData)>[
    ('1. Listening', Icons.headphones_rounded),
    ('2. Immersion', Icons.style_rounded),
    ('3. Rapid 5s', Icons.bolt_rounded),
    ('4. Role Play', Icons.theater_comedy_rounded),
    ('5. Final Boss', Icons.emoji_events_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final data = controller.topic.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data?.title ?? 'Memuat Topik...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (data != null)
                Text(
                  'Lesson ${data.lessonNumber.toString().padLeft(2, '0')} · Topic ${data.topicNumber.toString().padLeft(2, '0')} · ${data.level}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          );
        }),
        actions: [
          Obx(() {
            final count = controller.allCompletedAssessments.length;
            return TextButton.icon(
              onPressed: () => _showTopicReportSheet(context),
              icon: const Icon(
                Icons.assessment_rounded,
                size: 18,
                color: Color(0xFF10B981),
              ),
              label: Text(
                count > 0 ? 'Rapor ($count)' : 'Rapor',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF34D399),
                ),
              ),
            );
          }),
          Obx(() {
            final busy = controller.audioEngine.isPlayingVoice.value ||
                controller.audioEngine.isAmbienceActive.value;
            if (!busy) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Hentikan semua audio',
              onPressed: controller.audioEngine.stopAll,
              icon: const Icon(Icons.stop_circle_rounded, color: Color(0xFFF59E0B)),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null || controller.topic.value == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 42, color: Colors.amber),
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage.value ?? 'Data topik tidak ditemukan.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.loadTopicData,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                _StageSelectorBar(labels: _stageLabels),
                Obx(() {
                  final status = controller.audioEngine.playbackStatus.value;
                  if (status.isEmpty) return const SizedBox.shrink();
                  return MaterialBanner(
                    backgroundColor: const Color(0xFF7F1D1D),
                    content: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: controller.audioEngine.clearStatus,
                        child: const Text(
                          'Tutup',
                          style: TextStyle(color: Color(0xFFFDE68A)),
                        ),
                      ),
                    ],
                  );
                }),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildActiveStage(controller.currentStage.value),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActiveStage(int stageIndex) {
    switch (stageIndex) {
      case 0:
        return const Stage1DeepListeningView(key: ValueKey('stage_1'));
      case 1:
        return const Stage2ImmersionView(key: ValueKey('stage_2'));
      case 2:
        return const Stage3RapidResponseView(key: ValueKey('stage_3'));
      case 3:
        return const Stage4RolePlayView(key: ValueKey('stage_4'));
      case 4:
        return const Stage5FinalBossView(key: ValueKey('stage_5'));
      default:
        return const Stage1DeepListeningView(key: ValueKey('stage_1'));
    }
  }

  void _showTopicReportSheet(BuildContext context) {
    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF334155))),
        ),
        child: Obx(() {
          final items = controller.allCompletedAssessments;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rapor Penilaian Lokal Topik 01',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  items.isEmpty
                      ? 'Rekam suara di Stage 2, 3, 4, atau 5 untuk melihat rata-rata Pronunciation, Fluency, dan Grammar.'
                      : 'Rekap dari ${items.length} latihan berbicara yang sudah dinilai lokal di perangkat.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ReportPill(
                      label: 'Pronunciation',
                      value: items.isEmpty
                          ? '-'
                          : '${controller.topicAvgPronunciation}%',
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    _ReportPill(
                      label: 'Fluency',
                      value: items.isEmpty
                          ? '-'
                          : '${controller.topicAvgFluency}%',
                      color: const Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 8),
                    _ReportPill(
                      label: 'Grammar',
                      value: items.isEmpty
                          ? '-'
                          : '${controller.topicAvgGrammar}%',
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...items.reversed.take(6).map(
                        (a) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            a.stageLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            'Pron ${a.pronunciationScore}% · Fluency ${a.fluencyScore}% · Grammar ${a.hasTranscript ? '${a.grammarScore}%' : '-'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          trailing: Text(
                            '${a.overallScore}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Get.back<void>(),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ReportPill extends StatelessWidget {
  const _ReportPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageSelectorBar extends GetView<LessonController> {
  const _StageSelectorBar({required this.labels});

  final List<(String, IconData)> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final (title, icon) = labels[index];
          return Obx(() {
            final selected = controller.currentStage.value == index;
            return ChoiceChip(
              avatar: Icon(
                icon,
                size: 16,
                color: selected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
              ),
              label: Text(title),
              selected: selected,
              selectedColor: const Color(0xFFF59E0B),
              backgroundColor: const Color(0xFF1E293B),
              side: BorderSide(
                color: selected
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF334155),
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFE2E8F0),
              ),
              onSelected: (_) => controller.selectStage(index),
            );
          });
        },
      ),
    );
  }
}
