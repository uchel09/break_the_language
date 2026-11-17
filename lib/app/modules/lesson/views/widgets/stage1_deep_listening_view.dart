import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/lesson_topic_model.dart';
import '../../controllers/lesson_controller.dart';

class Stage1DeepListeningView extends GetView<LessonController> {
  const Stage1DeepListeningView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = controller.topic.value;
      if (data == null) return const SizedBox.shrink();

      final mode = controller.listeningMode.value;
      final playing = controller.audioEngine.isPlayingVoice.value;
      final ambienceOn = controller.audioEngine.isAmbienceActive.value;
      final loopOn = controller.audioEngine.isLoopEnabled.value;
      final bgPlayOn = controller.audioEngine.backgroundPlaybackEnabled.value;
      final activeLine = controller.audioEngine.activeLineIndex.value;

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
                    'Stage 1 · Deep Listening',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode == ListeningMode.slow
                        ? 'Menggunakan rekaman Native Slow asli (bukan perlambatan digital) supaya pelafalan & jeda terdengar jernih.'
                        : mode == ListeningMode.realSituation
                            ? 'Dual-Track Real Situation: dialog + suasana latar cerita kontinu + efek suara adegan.'
                            : 'Mode Normal: kecepatan percakapan native sehari-hari tanpa suara latar.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<ListeningMode>(
                      segments: const [
                        ButtonSegment(
                          value: ListeningMode.slow,
                          icon: Icon(Icons.slow_motion_video_rounded, size: 16),
                          label: Text('Native Slow'),
                        ),
                        ButtonSegment(
                          value: ListeningMode.normal,
                          icon: Icon(Icons.record_voice_over_rounded, size: 16),
                          label: Text('Normal'),
                        ),
                        ButtonSegment(
                          value: ListeningMode.realSituation,
                          icon: Icon(Icons.local_cafe_rounded, size: 16),
                          label: Text('Real Situasi'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) =>
                          controller.setListeningMode(s.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: playing
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF59E0B),
                            foregroundColor: playing
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: playing
                              ? controller.stopStage1Playback
                              : () => controller.playStage1Full(),
                          icon: Icon(
                            playing
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            playing ? 'Stop Audio' : 'Putar Percakapan',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      if (mode == ListeningMode.realSituation) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: ambienceOn
                              ? 'Matikan suasana latar'
                              : 'Tes suasana latar kontinu',
                          onPressed: controller.toggleAmbiencePreview,
                          icon: Icon(
                            ambienceOn
                                ? Icons.volume_up_rounded
                                : Icons.surround_sound_rounded,
                            color: ambienceOn
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (mode == ListeningMode.realSituation) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.graphic_eq_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ambience Latar ${(controller.audioEngine.ambienceVolume.value * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: controller.audioEngine.ambienceVolume.value,
                            min: 0.0,
                            max: 0.8,
                            onChanged: controller.audioEngine.setAmbienceVolume,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        avatar: Icon(
                          loopOn
                              ? Icons.repeat_on_rounded
                              : Icons.repeat_rounded,
                          size: 16,
                          color: loopOn
                              ? const Color(0xFF10B981)
                              : const Color(0xFF94A3B8),
                        ),
                        label: const Text('Non-Stop (Ulang Terus)'),
                        selected: loopOn,
                        onSelected: (v) =>
                            controller.audioEngine.isLoopEnabled.value = v,
                      ),
                      FilterChip(
                        avatar: Icon(
                          Icons.headphones_rounded,
                          size: 16,
                          color: bgPlayOn
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF94A3B8),
                        ),
                        label: const Text('Putar Latar Belakang'),
                        selected: bgPlayOn,
                        onSelected: (v) => controller
                            .audioEngine.backgroundPlaybackEnabled.value = v,
                      ),
                      FilterChip(
                        label: const Text('Connected Speech'),
                        selected: controller.showPhonetic.value,
                        onSelected: (v) => controller.showPhonetic.value = v,
                      ),
                      FilterChip(
                        label: const Text('Terjemahan ID'),
                        selected: controller.showIndonesian.value,
                        onSelected: (v) => controller.showIndonesian.value = v,
                      ),
                    ],
                  ),
                  if (loopOn || (playing && bgPlayOn)) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (loopOn)
                          'Non-Stop aktif: selesai baris terakhir otomatis mengulang dari baris 1.',
                        if (bgPlayOn)
                          'Tetap menyala saat kembali ke menu Home atau berpindah aplikasi.',
                      ].join(' '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...data.dialogue.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DialogueLineCard(
                line: line,
                character: data.findCharacter(line.speakerId),
                isActive: activeLine == line.index,
                showPhonetic: controller.showPhonetic.value,
                showIndonesian: controller.showIndonesian.value,
                onTap: () => controller.playSingleLine(line),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _DialogueLineCard extends StatelessWidget {
  const _DialogueLineCard({
    required this.line,
    required this.character,
    required this.isActive,
    required this.showPhonetic,
    required this.showIndonesian,
    required this.onTap,
  });

  final DialogueLine line;
  final CharacterInfo? character;
  final bool isActive;
  final bool showPhonetic;
  final bool showIndonesian;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final speakerColor = character?.color ?? const Color(0xFF94A3B8);

    return Material(
      color: isActive ? const Color(0xFF1E293B) : const Color(0xFF162033),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF283548),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: speakerColor.withValues(alpha: 0.2),
                child: Text(
                  character?.avatar ?? '🎙️',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          line.speakerName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: speakerColor,
                          ),
                        ),
                        if (line.sfxBefore != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'SFX: ${line.sfxBefore}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          isActive
                              ? Icons.graphic_eq_rounded
                              : Icons.play_circle_outline_rounded,
                          size: 18,
                          color: isActive
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      line.text,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                    if (showPhonetic && line.phonetic.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Linking: ${line.phonetic}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFBBF24),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (showIndonesian && line.meaning.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        line.meaning,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
