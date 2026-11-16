import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/lesson_controller.dart';
import 'assessment_result_card.dart';

class Stage2ImmersionView extends GetView<LessonController> {
  const Stage2ImmersionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.filteredImmersionItems;
      final item = controller.currentImmersionItem;
      final currentIdx = controller.immersionIndex.value;
      final recording = controller.isRecordingShadow.value;
      final note = controller.speechTools.statusNote.value;

      if (item == null) {
        return const Center(child: Text('Belum ada materi immersion.'));
      }

      final recordedPath = controller.shadowRecordings[item.term];
      final transcript = controller.shadowTranscripts[item.term];
      final assessment = controller.shadowAssessments[item.term];

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stage 2 · Immersion & Shadowing',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Dengarkan Native atau Native Slow, lalu rekam suaramu untuk membandingkan pelafalan.',
                    style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<ImmersionFilter>(
                      segments: const [
                        ButtonSegment(
                          value: ImmersionFilter.all,
                          label: Text('Semua (14)'),
                        ),
                        ButtonSegment(
                          value: ImmersionFilter.vocabulary,
                          label: Text('Kosakata (6)'),
                        ),
                        ButtonSegment(
                          value: ImmersionFilter.expressions,
                          label: Text('Ekspresi (8)'),
                        ),
                      ],
                      selected: {controller.immersionFilter.value},
                      onSelectionChanged: (s) =>
                          controller.setImmersionFilter(s.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Kartu ${currentIdx + 1} / ${items.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item.term,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.meaning,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"${item.example}"',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF8FAFC),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Connected speech: ${item.phonetic}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFBBF24),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF0F172A),
                          ),
                          onPressed: () => controller.playCurrentImmersionAudio(
                            slowOverride: false,
                          ),
                          icon: const Icon(Icons.volume_up_rounded),
                          label: const Text('Native'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => controller.playCurrentImmersionAudio(
                            slowOverride: true,
                          ),
                          icon: const Icon(Icons.slow_motion_video_rounded),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Native Slow'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: recording
                                ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                                : const Color(0xFF0F172A),
                            foregroundColor: recording
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFE2E8F0),
                          ),
                          onPressed: controller.toggleShadowRecord,
                          icon: Icon(
                            recording ? Icons.stop_rounded : Icons.mic_rounded,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              recording ? 'Stop Rekam' : 'Rekam Suara Saya',
                            ),
                          ),
                        ),
                      ),
                      if (recordedPath != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: const Color(0xFF0F172A),
                            ),
                            onPressed: controller.playCurrentShadowRecording,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Putar Suaraku'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (transcript != null && transcript.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Transkrip STT: "$transcript"',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6EE7B7),
                        ),
                      ),
                    ),
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      note,
                      style: const TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ],
                  if (assessment != null) ...[
                    const SizedBox(height: 12),
                    AssessmentResultCard(
                      assessment: assessment,
                      onManualTranscriptSubmit:
                          controller.evaluateShadowWithManualText,
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            controller.evaluateShadowWithManualText(item.example),
                        icon: const Icon(Icons.analytics_outlined, size: 16),
                        label: const Text(
                          'Simulasi Cek Nilai Tanpa Mic',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: currentIdx > 0
                              ? () =>
                                  controller.setImmersionIndex(currentIdx - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text(
                            'Sebelumnya',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: currentIdx < items.length - 1
                              ? () =>
                                  controller.setImmersionIndex(currentIdx + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text(
                            'Berikutnya',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
