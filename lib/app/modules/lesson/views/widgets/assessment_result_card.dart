import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/speaking_assessment_model.dart';

/// Displays complete local speaking scores: Pronunciation, Fluency, Grammar,
/// duration/rhythm comparison against the native audio, word highlights, and tips.
class AssessmentResultCard extends StatelessWidget {
  const AssessmentResultCard({
    super.key,
    required this.assessment,
    this.onManualTranscriptSubmit,
  });

  final SpeakingAssessment assessment;
  final ValueChanged<String>? onManualTranscriptSubmit;

  Color _scoreColor(int score, {bool active = true}) {
    if (!active) return const Color(0xFF64748B);
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _scoreColor(assessment.overallScore).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_rounded,
                size: 16,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Penilaian Lokal · ${assessment.gradeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _scoreColor(assessment.overallScore)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Total ${assessment.overallScore}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _scoreColor(assessment.overallScore),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Pronunciation',
                  valueText: '${assessment.pronunciationScore}%',
                  subText: assessment.hasTranscript
                      ? 'Kata & ritme'
                      : 'Ritme suara',
                  color: _scoreColor(assessment.pronunciationScore),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Fluency',
                  valueText: '${assessment.fluencyScore}%',
                  subText:
                      '${assessment.estimatedWpm} WPM · ${assessment.pauseCount} jeda',
                  color: _scoreColor(assessment.fluencyScore),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Grammar',
                  valueText: assessment.hasTranscript
                      ? '${assessment.grammarScore}%'
                      : '-',
                  subText: assessment.hasTranscript
                      ? (assessment.grammarIssues.isEmpty
                          ? 'Struktur rapi'
                          : '${assessment.grammarIssues.length} catatan')
                      : 'Perlu STT/teks',
                  color: _scoreColor(
                    assessment.grammarScore,
                    active: assessment.hasTranscript,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(
                icon: Icons.timer_outlined,
                text:
                    'Kamu ${assessment.userDurationSec}s vs Asli ${assessment.referenceDurationSec}s',
              ),
              if (assessment.referenceEnvelope.isNotEmpty)
                _InfoChip(
                  icon: Icons.graphic_eq_rounded,
                  text: 'Kecocokan ritme ${assessment.rhythmSimilarityScore}%',
                ),
            ],
          ),
          if (assessment.referenceEnvelope.isNotEmpty) ...[
            const SizedBox(height: 10),
            _EnvelopeComparisonBar(
              reference: assessment.referenceEnvelope,
              user: assessment.userEnvelope,
            ),
          ],
          if (assessment.hasTranscript &&
              assessment.wordEvaluations.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Perbandingan Kata:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: assessment.wordEvaluations.map((w) {
                final Color fg;
                final Color bg;
                final String label;
                switch (w.status) {
                  case WordMatchStatus.exact:
                    fg = const Color(0xFF34D399);
                    bg = const Color(0xFF10B981).withValues(alpha: 0.16);
                    label = w.targetWord;
                  case WordMatchStatus.close:
                    fg = const Color(0xFFFBBF24);
                    bg = const Color(0xFFF59E0B).withValues(alpha: 0.16);
                    label = '${w.targetWord} (~${w.spokenWord ?? ""})';
                  case WordMatchStatus.missed:
                    fg = const Color(0xFFF87171);
                    bg = const Color(0xFFEF4444).withValues(alpha: 0.16);
                    label = w.targetWord;
                }
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: fg.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (assessment.hasTranscript && assessment.grammarIssues.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...assessment.grammarIssues.take(3).map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.rule_rounded,
                          size: 14,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${issue.ruleTitle}: ${issue.explanation}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 8),
          Text(
            assessment.summaryTip,
            style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
          ),
          if (onManualTranscriptSubmit != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openManualTranscriptDialog(context),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: Text(
                  assessment.hasTranscript
                      ? 'Ubah/Uji Teks Ucapan'
                      : 'Input Teks Ucapan untuk Cek Kata & Grammar',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openManualTranscriptDialog(BuildContext context) async {
    final textCtrl = TextEditingController(text: assessment.spokenTranscript);
    final submitted = await Get.dialog<String>(
      AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Evaluasi Teks Ucapan Lokal',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: textCtrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ketik kalimat Inggris yang barusan kamu ucapkan...',
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<String>(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Get.back<String>(result: textCtrl.text),
            child: const Text('Nilai Sekarang'),
          ),
        ],
      ),
    );
    textCtrl.dispose();
    if (submitted != null && submitted.trim().isNotEmpty) {
      onManualTranscriptSubmit?.call(submitted.trim());
    }
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.valueText,
    required this.subText,
    required this.color,
  });

  final String label;
  final String valueText;
  final String subText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valueText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            subText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Color(0xFFCBD5E1)),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF38BDF8)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
          ),
        ],
      ),
    );
  }
}

class _EnvelopeComparisonBar extends StatelessWidget {
  const _EnvelopeComparisonBar({
    required this.reference,
    required this.user,
  });

  final List<int> reference;
  final List<int> user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pola Penekanan Suara:',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const _LegendDot(color: Color(0xFFF59E0B), label: 'Asli'),
              const SizedBox(width: 8),
              const _LegendDot(color: Color(0xFF10B981), label: 'Kamu'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(reference.length, (i) {
                final refHeight =
                    (reference[i].clamp(8, 100) / 100.0) * 32.0;
                final userVal = i < user.length ? user[i] : 0;
                final userHeight = (userVal.clamp(4, 100) / 100.0) * 32.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            height: refHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 1),
                        Expanded(
                          child: Container(
                            height: user.isEmpty ? 3 : userHeight,
                            decoration: BoxDecoration(
                              color: user.isEmpty
                                  ? const Color(0xFF334155)
                                  : const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5E1)),
        ),
      ],
    );
  }
}
