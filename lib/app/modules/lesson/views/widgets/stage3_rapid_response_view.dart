import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/lesson_controller.dart';
import 'assessment_result_card.dart';

class Stage3RapidResponseView extends GetView<LessonController> {
  const Stage3RapidResponseView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = controller.topic.value;
      final q = controller.currentRapidQuestion;
      if (data == null || q == null) return const SizedBox.shrink();

      final total = data.rapidResponse.length;
      final idx = controller.rapidIndex.value;
      final mode = controller.rapidMode.value;
      final seconds = controller.rapidCountdown.value;
      final active = controller.rapidTimerActive.value;
      final hintUnlocked = controller.rapidHintUnlocked.value;
      final revealed = controller.rapidAnswerRevealed.value;
      final recording = controller.isRecordingRapid.value;
      final assessment = controller.rapidAssessments[q.id];
      final speechNote = controller.speechTools.statusNote.value;

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
                          'Stage 3 · Rapid Response 5s',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('Skor: ${controller.rapidScore.value}'),
                        backgroundColor: const Color(0xFF0F172A),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<RapidMode>(
                      segments: const [
                        ButtonSegment(
                          value: RapidMode.story,
                          label: Text('Refleks Cerita'),
                        ),
                        ButtonSegment(
                          value: RapidMode.personal,
                          label: Text('Refleks Pribadi'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) =>
                          controller.rapidMode.value = s.first,
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
                      Text(
                        'Pertanyaan ${idx + 1} / $total',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: seconds <= 2.5
                              ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                              : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${seconds.toStringAsFixed(1)}s',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: seconds <= 2.5
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (seconds / 5.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFF0F172A),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        seconds <= 2.5
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    mode == RapidMode.story ? q.question : q.personalQuestion,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF0F172A),
                        ),
                        onPressed: controller.startRapidTimer,
                        icon: Icon(
                          active ? Icons.refresh_rounded : Icons.timer_rounded,
                        ),
                        label: Text(
                          active ? 'Ulang Timer 5s' : 'Mulai 5s + Suara',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.speakRapidQuestion,
                        icon: const Icon(Icons.volume_up_rounded),
                        label: const Text('Dengar Soal'),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: recording
                              ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                              : const Color(0xFF0F172A),
                        ),
                        onPressed: controller.toggleRapidMic,
                        icon: Icon(
                          recording ? Icons.stop_rounded : Icons.mic_rounded,
                        ),
                        label: Text(recording ? 'Stop Jawab' : 'Jawab Pakai Mic'),
                      ),
                    ],
                  ),
                  if (hintUnlocked && mode == RapidMode.story) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'Pola Bantu (2.5s Hint): ${q.hint}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFDE68A),
                        ),
                      ),
                    ),
                  ],
                  if (controller.rapidSpokenFeedback.value.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Tangkapan suara: "${controller.rapidSpokenFeedback.value}"',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                  if (speechNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      speechNote,
                      style: const TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ],
                  if (assessment != null) ...[
                    const SizedBox(height: 12),
                    AssessmentResultCard(
                      assessment: assessment,
                      onManualTranscriptSubmit:
                          controller.evaluateRapidWithManualText,
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (!revealed)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed: controller.revealRapidAnswer,
                          child: const Text('Lihat Kunci Jawaban'),
                        ),
                        FilledButton.tonal(
                          onPressed: controller.markRapidSelfCorrect,
                          child: const Text('Saya Jawab Benar (+1)'),
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Natural Short: ${q.shortAnswer}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF34D399),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Full Sentence: ${q.fullAnswer}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFF8FAFC),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: controller.prevRapidQuestion,
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
                          onPressed: controller.nextRapidQuestion,
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text(
                            'Soal Berikutnya',
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
