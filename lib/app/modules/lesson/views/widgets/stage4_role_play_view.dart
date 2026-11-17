import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/lesson_topic_model.dart';
import '../../../../data/models/speaking_assessment_model.dart';
import '../../controllers/lesson_controller.dart';
import 'assessment_result_card.dart';

class Stage4RolePlayView extends GetView<LessonController> {
  const Stage4RolePlayView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = controller.topic.value;
      if (data == null) return const SizedBox.shrink();

      final selectedRole = controller.selectedRoleId.value;
      final difficulty = controller.roleDifficulty.value;
      final ambienceEnabled = controller.useHeadsetAmbience.value;
      final playing = controller.audioEngine.isPlayingVoice.value;
      final activeLine = controller.audioEngine.activeLineIndex.value;
      final activeRecLine = controller.activeRoleRecordingLine.value;

      final totalMyTurns = data.dialogue
          .where((l) => l.speakerId == selectedRole)
          .length;
      final recordedMyTurns = data.dialogue
          .where(
            (l) =>
                l.speakerId == selectedRole &&
                controller.roleRecordings[l.index] != null,
          )
          .length;

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
                    'Stage 4 · Interactive Role Play Duet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih karaktermu, rekam suaramu di giliranmu, lalu putar Duet Playback bersama suara native dan latar suasana cerita.',
                    style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pilih Peran:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.characters.map((c) {
                      final isSelected = c.id == selectedRole;
                      return ChoiceChip(
                        avatar: Text(c.avatar),
                        label: Text(c.name),
                        selected: isSelected,
                        onSelected: (_) => controller.selectedRoleId.value = c.id,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<RoleDifficulty>(
                      segments: const [
                        ButtonSegment(
                          value: RoleDifficulty.fullScript,
                          label: Text('Full Script'),
                        ),
                        ButtonSegment(
                          value: RoleDifficulty.memoryGap,
                          label: Text('Memory Gap'),
                        ),
                        ButtonSegment(
                          value: RoleDifficulty.blindCue,
                          label: Text('Blind Cue ID'),
                        ),
                      ],
                      selected: {difficulty},
                      onSelectionChanged: (s) =>
                          controller.roleDifficulty.value = s.first,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: ambienceEnabled,
                    onChanged: controller.setUseHeadsetAmbience,
                    title: const Text(
                      'Suara Latar Kafe Kontinu (Headset Mode)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Ambience tetap menyala saat giliranmu berbicara agar menyatu.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  if (ambienceEnabled)
                    Row(
                      children: [
                        const Text(
                          'Vol Latar:',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                        Expanded(
                          child: Slider(
                            value: controller.audioEngine.ambienceVolume.value,
                            min: 0.05,
                            max: 0.8,
                            onChanged: controller.audioEngine.setAmbienceVolume,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: playing
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                            foregroundColor: playing
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: playing
                              ? controller.audioEngine.stopVoice
                              : controller.playRolePlayDuet,
                          icon: Icon(
                            playing
                                ? Icons.stop_rounded
                                : Icons.play_circle_filled_rounded,
                          ),
                          label: Text(
                            playing
                                ? (controller.audioEngine.isWaitingUserTurn.value
                                    ? 'Stop (Giliranmu!)'
                                    : 'Stop Role Play')
                                : 'Mulai Role Play ($recordedMyTurns/$totalMyTurns)',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    controller.audioEngine.isWaitingUserTurn.value
                        ? '🎙️ Suara karakter pilihanmu sedang dibisukan — ucapkan dialog yang tersorot!'
                        : 'Karakter pilihanmu dibisukan saat gilirannya (diganti jeda bicara live, atau putar suaramu jika sudah direkam).',
                    style: TextStyle(
                      fontSize: 11,
                      color: controller.audioEngine.isWaitingUserTurn.value
                          ? const Color(0xFF34D399)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...data.dialogue.map((line) {
            final isUserTurn = line.speakerId == selectedRole;
            final recordedPath = controller.roleRecordings[line.index];
            final assessment = controller.roleAssessments[line.index];
            final isRecordingThis = activeRecLine == line.index;
            final isPlayingThis = activeLine == line.index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoleTurnCard(
                line: line,
                character: data.findCharacter(line.speakerId),
                difficulty: difficulty,
                isUserTurn: isUserTurn,
                isRecording: isRecordingThis,
                isActive: isPlayingThis,
                hasRecordedAudio: recordedPath != null && recordedPath.isNotEmpty,
                assessment: assessment,
                onPlayReference: () => controller.playRoleReferenceLine(line),
                onToggleRecord: () => controller.toggleRoleTurnRecord(line),
                onPlayMyVoice: () => controller.playRoleUserRecording(line),
                onManualEvaluate: (text) =>
                    controller.evaluateRoleWithManualText(line, text),
              ),
            );
          }),
        ],
      );
    });
  }
}

class _RoleTurnCard extends StatelessWidget {
  const _RoleTurnCard({
    required this.line,
    required this.character,
    required this.difficulty,
    required this.isUserTurn,
    required this.isRecording,
    required this.isActive,
    required this.hasRecordedAudio,
    required this.assessment,
    required this.onPlayReference,
    required this.onToggleRecord,
    required this.onPlayMyVoice,
    required this.onManualEvaluate,
  });

  final DialogueLine line;
  final CharacterInfo? character;
  final RoleDifficulty difficulty;
  final bool isUserTurn;
  final bool isRecording;
  final bool isActive;
  final bool hasRecordedAudio;
  final SpeakingAssessment? assessment;
  final VoidCallback onPlayReference;
  final VoidCallback onToggleRecord;
  final VoidCallback onPlayMyVoice;
  final ValueChanged<String> onManualEvaluate;

  String _displayPromptText() {
    if (!isUserTurn) return line.text;
    switch (difficulty) {
      case RoleDifficulty.fullScript:
        return line.text;
      case RoleDifficulty.memoryGap:
        return line.cloze;
      case RoleDifficulty.blindCue:
        return 'Misi: ${line.cueId}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = character?.color ?? const Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUserTurn ? const Color(0xFF1E293B) : const Color(0xFF131D2F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecording
              ? const Color(0xFFEF4444)
              : isActive
                  ? const Color(0xFFF59E0B)
                  : isUserTurn
                      ? const Color(0xFF10B981)
                      : const Color(0xFF283548),
          width: (isUserTurn || isActive || isRecording) ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(character?.avatar ?? '🎙️'),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  line.speakerName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
              if (isUserTurn) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isActive
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981))
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isActive ? 'BICARA SEKARANG' : 'GILIRAN KAMU',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isActive
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF34D399),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Dengar contoh suara asli',
                onPressed: onPlayReference,
                icon: const Icon(Icons.volume_up_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _displayPromptText(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isUserTurn && difficulty == RoleDifficulty.blindCue
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFF8FAFC),
            ),
          ),
          if (isUserTurn) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isRecording
                        ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                        : const Color(0xFF0F172A),
                  ),
                  onPressed: onToggleRecord,
                  icon: Icon(
                    isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isRecording
                        ? 'Stop Rekam'
                        : hasRecordedAudio
                            ? 'Rekam Ulang'
                            : 'Rekam Giliranku',
                  ),
                ),
                if (hasRecordedAudio)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF0F172A),
                    ),
                    onPressed: onPlayMyVoice,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Dengar Suaraku'),
                  ),
              ],
            ),
            if (assessment != null) ...[
              const SizedBox(height: 10),
              AssessmentResultCard(
                assessment: assessment!,
                onManualTranscriptSubmit: onManualEvaluate,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
