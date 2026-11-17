import 'dart:ui';

/// Metadata for a single topic inside one of the 12 lessons (3 topics/lesson).
class CurriculumTopicMeta {
  const CurriculumTopicMeta({
    required this.lessonNumber,
    required this.topicNumber,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.isReady,
    this.jsonAssetPath,
    this.estimatedSizeMb,
  });

  final int lessonNumber;
  final int topicNumber;
  final String title;
  final String subtitle;
  final String level;
  final bool isReady;
  final String? jsonAssetPath;
  final double? estimatedSizeMb;

  String get code =>
      'L${lessonNumber.toString().padLeft(2, '0')}·T${topicNumber.toString().padLeft(2, '0')}';
}

/// Curriculum container representing one Lesson with 3 Topics.
class CurriculumLesson {
  const CurriculumLesson({
    required this.lessonNumber,
    required this.title,
    required this.focus,
    required this.topics,
  });

  final int lessonNumber;
  final String title;
  final String focus;
  final List<CurriculumTopicMeta> topics;
}

class CharacterInfo {
  const CharacterInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
    required this.colorHex,
    required this.voiceLabel,
  });

  final String id;
  final String name;
  final String role;
  final String avatar;
  final String colorHex;
  final String voiceLabel;

  Color get color {
    final cleaned = colorHex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return const Color(0xFFF59E0B);
    return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
  }

  factory CharacterInfo.fromJson(Map<String, dynamic> json) {
    return CharacterInfo(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      avatar: (json['avatar'] ?? '🗣️').toString(),
      colorHex: (json['color'] ?? '#f59e0b').toString(),
      voiceLabel: (json['voiceLabel'] ?? '').toString(),
    );
  }
}

class AudioAssetsInfo {
  const AudioAssetsInfo({
    required this.ambienceLoop,
    this.sfxDoorChime = '',
    this.sfxBookPat = '',
    this.cues = const {},
  });

  final String ambienceLoop;
  final String sfxDoorChime;
  final String sfxBookPat;
  final Map<String, String> cues;

  String? resolveCue(String cue) {
    final mapped = cues[cue];
    if (mapped != null && mapped.isNotEmpty) return mapped;
    if (cue == 'door_chime' && sfxDoorChime.isNotEmpty) return sfxDoorChime;
    if (cue == 'book_pat' && sfxBookPat.isNotEmpty) return sfxBookPat;
    return null;
  }

  List<String> get allSfxPaths => {
        if (ambienceLoop.isNotEmpty) ambienceLoop,
        if (sfxDoorChime.isNotEmpty) sfxDoorChime,
        if (sfxBookPat.isNotEmpty) sfxBookPat,
        for (final path in cues.values)
          if (path.isNotEmpty) path,
      }.toList();

  factory AudioAssetsInfo.fromJson(Map<String, dynamic> json) {
    final rawCues = json['cues'] as Map<String, dynamic>? ?? const {};
    return AudioAssetsInfo(
      ambienceLoop: (json['ambienceLoop'] ?? '').toString(),
      sfxDoorChime: (json['sfxDoorChime'] ?? '').toString(),
      sfxBookPat: (json['sfxBookPat'] ?? '').toString(),
      cues: rawCues.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }
}

class DialogueLine {
  const DialogueLine({
    required this.index,
    required this.speakerId,
    required this.speakerName,
    required this.audio,
    required this.audioSlow,
    required this.text,
    required this.cloze,
    required this.cueId,
    required this.phonetic,
    required this.meaning,
    this.sfxBefore,
    this.durationSec,
    this.durationSlowSec,
    this.envelope = const [],
    this.envelopeSlow = const [],
  });

  final int index;
  final String speakerId;
  final String speakerName;
  final String audio;
  final String audioSlow;
  final String text;
  final String cloze;
  final String cueId;
  final String phonetic;
  final String meaning;
  final String? sfxBefore;
  final double? durationSec;
  final double? durationSlowSec;
  final List<int> envelope;
  final List<int> envelopeSlow;

  factory DialogueLine.fromJson(Map<String, dynamic> json) {
    return DialogueLine(
      index: (json['index'] as num?)?.toInt() ?? 0,
      speakerId: (json['speakerId'] ?? '').toString(),
      speakerName: (json['speakerName'] ?? '').toString(),
      audio: (json['audio'] ?? '').toString(),
      audioSlow: (json['audioSlow'] ?? json['audio'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      cloze: (json['cloze'] ?? '').toString(),
      cueId: (json['cueId'] ?? '').toString(),
      phonetic: (json['phonetic'] ?? '').toString(),
      meaning: (json['meaning'] ?? '').toString(),
      sfxBefore: json['sfxBefore']?.toString(),
      durationSec: (json['durationSec'] as num?)?.toDouble(),
      durationSlowSec: (json['durationSlowSec'] as num?)?.toDouble(),
      envelope: (json['envelope'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      envelopeSlow: (json['envelopeSlow'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

class ImmersionItem {
  const ImmersionItem({
    required this.term,
    required this.meaning,
    required this.example,
    required this.phonetic,
    required this.audio,
    required this.audioSlow,
    required this.category,
    this.durationSec,
    this.durationSlowSec,
    this.envelope = const [],
    this.envelopeSlow = const [],
  });

  final String term;
  final String meaning;
  final String example;
  final String phonetic;
  final String audio;
  final String audioSlow;
  final String category;
  final double? durationSec;
  final double? durationSlowSec;
  final List<int> envelope;
  final List<int> envelopeSlow;

  factory ImmersionItem.fromJson(
    Map<String, dynamic> json, {
    required String category,
  }) {
    return ImmersionItem(
      term: (json['term'] ?? '').toString(),
      meaning: (json['meaning'] ?? '').toString(),
      example: (json['example'] ?? '').toString(),
      phonetic: (json['phonetic'] ?? '').toString(),
      audio: (json['audio'] ?? '').toString(),
      audioSlow: (json['audioSlow'] ?? json['audio'] ?? '').toString(),
      category: category,
      durationSec: (json['durationSec'] as num?)?.toDouble(),
      durationSlowSec: (json['durationSlowSec'] as num?)?.toDouble(),
      envelope: (json['envelope'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      envelopeSlow: (json['envelopeSlow'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

class ImmersionData {
  const ImmersionData({
    required this.vocabulary,
    required this.expressions,
  });

  final List<ImmersionItem> vocabulary;
  final List<ImmersionItem> expressions;

  List<ImmersionItem> get all => [...vocabulary, ...expressions];

  factory ImmersionData.fromJson(Map<String, dynamic> json) {
    final vocabRaw = (json['vocabulary'] as List<dynamic>? ?? []);
    final exprRaw = (json['expressions'] as List<dynamic>? ?? []);
    return ImmersionData(
      vocabulary: vocabRaw
          .map(
            (e) => ImmersionItem.fromJson(
              e as Map<String, dynamic>,
              category: 'Vocabulary',
            ),
          )
          .toList(),
      expressions: exprRaw
          .map(
            (e) => ImmersionItem.fromJson(
              e as Map<String, dynamic>,
              category: 'Expression',
            ),
          )
          .toList(),
    );
  }
}

class RapidQuestion {
  const RapidQuestion({
    required this.id,
    required this.question,
    required this.shortAnswer,
    required this.fullAnswer,
    required this.hint,
    required this.keywords,
    required this.personalQuestion,
  });

  final int id;
  final String question;
  final String shortAnswer;
  final String fullAnswer;
  final String hint;
  final List<String> keywords;
  final String personalQuestion;

  factory RapidQuestion.fromJson(Map<String, dynamic> json) {
    return RapidQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: (json['question'] ?? '').toString(),
      shortAnswer: (json['shortAnswer'] ?? '').toString(),
      fullAnswer: (json['fullAnswer'] ?? '').toString(),
      hint: (json['hint'] ?? '').toString(),
      keywords: (json['keywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      personalQuestion: (json['personalQuestion'] ?? '').toString(),
    );
  }
}

class StoryModeOption {
  const StoryModeOption({
    required this.id,
    required this.title,
    required this.instruction,
  });

  final String id;
  final String title;
  final String instruction;

  factory StoryModeOption.fromJson(Map<String, dynamic> json) {
    return StoryModeOption(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      instruction: (json['instruction'] ?? '').toString(),
    );
  }
}

class StoryBeat {
  const StoryBeat({
    required this.step,
    required this.title,
    required this.image,
    required this.starter,
    required this.keywords,
    required this.connectors,
  });

  final int step;
  final String title;
  final String image;
  final String starter;
  final List<String> keywords;
  final List<String> connectors;

  factory StoryBeat.fromJson(Map<String, dynamic> json) {
    return StoryBeat(
      step: (json['step'] as num?)?.toInt() ?? 1,
      title: (json['title'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      starter: (json['starter'] ?? '').toString(),
      keywords: (json['keywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      connectors: (json['connectors'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class FinalBossData {
  const FinalBossData({
    required this.durationSeconds,
    required this.storyModes,
    required this.storyBeats,
  });

  final int durationSeconds;
  final List<StoryModeOption> storyModes;
  final List<StoryBeat> storyBeats;

  factory FinalBossData.fromJson(Map<String, dynamic> json) {
    return FinalBossData(
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 45,
      storyModes: (json['storyModes'] as List<dynamic>? ?? [])
          .map((e) => StoryModeOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      storyBeats: (json['storyBeats'] as List<dynamic>? ?? [])
          .map((e) => StoryBeat.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TopicData {
  const TopicData({
    required this.lessonNumber,
    required this.topicNumber,
    required this.topicId,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.durationMinutes,
    required this.characters,
    required this.audioAssets,
    required this.dialogue,
    required this.immersion,
    required this.rapidResponse,
    required this.finalBoss,
  });

  final int lessonNumber;
  final int topicNumber;
  final String topicId;
  final String title;
  final String subtitle;
  final String level;
  final int durationMinutes;
  final List<CharacterInfo> characters;
  final AudioAssetsInfo audioAssets;
  final List<DialogueLine> dialogue;
  final ImmersionData immersion;
  final List<RapidQuestion> rapidResponse;
  final FinalBossData finalBoss;

  CharacterInfo? findCharacter(String id) {
    for (final c in characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  factory TopicData.fromJson(Map<String, dynamic> json) {
    return TopicData(
      lessonNumber: (json['lessonNumber'] as num?)?.toInt() ?? 1,
      topicNumber: (json['topicNumber'] as num?)?.toInt() ?? 1,
      topicId: (json['topicId'] ?? 'lesson-01-topic-01').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      level: (json['level'] ?? 'A2 → B1').toString(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 12,
      characters: (json['characters'] as List<dynamic>? ?? [])
          .map((e) => CharacterInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      audioAssets: AudioAssetsInfo.fromJson(
        (json['audioAssets'] as Map<String, dynamic>? ?? {}),
      ),
      dialogue: (json['dialogue'] as List<dynamic>? ?? [])
          .map((e) => DialogueLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      immersion: ImmersionData.fromJson(
        (json['immersion'] as Map<String, dynamic>? ?? {}),
      ),
      rapidResponse: (json['rapidResponse'] as List<dynamic>? ?? [])
          .map((e) => RapidQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      finalBoss: FinalBossData.fromJson(
        (json['finalBoss'] as Map<String, dynamic>? ?? {}),
      ),
    );
  }
}
