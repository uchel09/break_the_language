import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/lesson_topic_model.dart';
import '../../controllers/lesson_controller.dart';
import 'assessment_result_card.dart';

class Stage5FinalBossView extends GetView<LessonController> {
  const Stage5FinalBossView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = controller.topic.value;
      if (data == null) return const SizedBox.shrink();

      final boss = data.finalBoss;
      final modes = boss.storyModes;
      final activeMode = modes.isNotEmpty
          ? modes[controller.bossModeIndex.value.clamp(0, modes.length - 1)]
          : null;
      final running = controller.bossRunning.value;
      final secs = controller.bossSecondsLeft.value;
      final activeBeat = controller.activeBeatIndex.value;
      final totalKeywords = boss.storyBeats.fold<int>(
        0,
        (sum, beat) => sum + beat.keywords.length,
      );
      final hitCount = controller.bossHitKeywords.length;
      final recorded = controller.bossRecordingPath.value;
      final assessment = controller.bossAssessment.value;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Stage 5 · Final Boss Storytelling (45s)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: running
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Text(
                          '${secs}s',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: running
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (modes.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<int>(
                        segments: [
                          for (var i = 0; i < modes.length; i++)
                            ButtonSegment(
                              value: i,
                              label: Text(
                                i == 0 ? 'Retell (Maya)' : 'My Own Story',
                              ),
                            ),
                        ],
                        selected: {controller.bossModeIndex.value},
                        onSelectionChanged: (s) =>
                            controller.bossModeIndex.value = s.first,
                      ),
                    ),
                  if (activeMode != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      activeMode.instruction,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: running
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF59E0B),
                            foregroundColor: running
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: controller.toggleBossChallenge,
                          icon: Icon(
                            running ? Icons.stop_rounded : Icons.mic_rounded,
                          ),
                          label: Text(
                            running
                                ? 'Selesai & Simpan'
                                : 'Mulai Tantangan ${boss.durationSeconds}s',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      if (recorded != null) ...[
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                          ),
                          onPressed: controller.playBossRecording,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Dengarkan'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Target Keyword Tercapai: $hitCount / $totalKeywords (Otomatis via STT atau ketuk chip di kartu)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  if (controller.bossTranscript.value.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Live STT: ${controller.bossTranscript.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ],
                  if (assessment != null) ...[
                    const SizedBox(height: 12),
                    AssessmentResultCard(
                      assessment: assessment,
                      onManualTranscriptSubmit:
                          controller.evaluateBossWithManualText,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 640;
              if (twoCols) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: boss.storyBeats.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 390,
                  ),
                  itemBuilder: (_, index) => _StoryBeatCard(
                    beat: boss.storyBeats[index],
                    isActive: activeBeat == index,
                    hitKeywords: controller.bossHitKeywords,
                    onTapCard: () => controller.activeBeatIndex.value = index,
                    onToggleKeyword: controller.toggleManualKeywordHit,
                  ),
                );
              }

              return Column(
                children: [
                  for (var index = 0;
                      index < boss.storyBeats.length;
                      index++) ...[
                    _StoryBeatCard(
                      beat: boss.storyBeats[index],
                      isActive: activeBeat == index,
                      hitKeywords: controller.bossHitKeywords,
                      onTapCard: () =>
                          controller.activeBeatIndex.value = index,
                      onToggleKeyword: controller.toggleManualKeywordHit,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      );
    });
  }
}

class _StoryBeatCard extends StatelessWidget {
  const _StoryBeatCard({
    required this.beat,
    required this.isActive,
    required this.hitKeywords,
    required this.onTapCard,
    required this.onToggleKeyword,
  });

  final StoryBeat beat;
  final bool isActive;
  final Set<String> hitKeywords;
  final VoidCallback onTapCard;
  final ValueChanged<String> onToggleKeyword;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapCard,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? const Color(0xFFF59E0B)
                : const Color(0xFF334155),
            width: isActive ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                beat.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFF0F172A),
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Panel ${beat.step}: ${beat.title}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isActive
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    beat.starter,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...beat.connectors.map(
                        (c) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            c,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      ...beat.keywords.map((kw) {
                        final hit = hitKeywords.contains(kw);
                        return InkWell(
                          onTap: () => onToggleKeyword(kw),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: hit
                                  ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.25)
                                  : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: hit
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF475569),
                              ),
                            ),
                            child: Text(
                              hit ? '✓ $kw' : kw,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: hit
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
