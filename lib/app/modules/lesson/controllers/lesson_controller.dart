import 'dart:async';

import 'package:get/get.dart';

import '../../../data/models/lesson_topic_model.dart';
import '../../../data/models/speaking_assessment_model.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../data/services/audio_engine_service.dart';
import '../../../data/services/local_speaking_evaluator.dart';
import '../../../data/services/speech_tools_service.dart';

enum ListeningMode { slow, normal, realSituation }

enum ImmersionFilter { all, vocabulary, expressions }

enum RapidMode { story, personal }

enum RoleDifficulty { fullScript, memoryGap, blindCue }

class LessonController extends GetxController {
  LessonController({CurriculumTopicMeta? initialTopicMeta})
      : _initialTopicMeta = initialTopicMeta;

  final CurriculumTopicMeta? _initialTopicMeta;

  late final LessonRepository _repository =
      Get.isRegistered<LessonRepository>()
          ? Get.find<LessonRepository>()
          : Get.put(LessonRepository());

  late final AudioEngineService audioEngine =
      Get.isRegistered<AudioEngineService>()
          ? Get.find<AudioEngineService>()
          : Get.put(AudioEngineService());

  late final SpeechToolsService speechTools =
      Get.isRegistered<SpeechToolsService>()
          ? Get.find<SpeechToolsService>()
          : Get.put(SpeechToolsService());

  late final LocalSpeakingEvaluator evaluator =
      Get.isRegistered<LocalSpeakingEvaluator>()
          ? Get.find<LocalSpeakingEvaluator>()
          : Get.put(LocalSpeakingEvaluator());

  static const String _defaultTopicJson =
      'assets/data/lessons/lesson_01/topic_01.json';

  final isLoading = true.obs;
  final errorMessage = RxnString();
  final topic = Rxn<TopicData>();
  final currentStage = 0.obs;

  // Stage 1: Deep Listening
  final listeningMode = ListeningMode.realSituation.obs;
  final showPhonetic = true.obs;
  final showIndonesian = false.obs;

  // Stage 2: Immersion & Shadowing
  final immersionFilter = ImmersionFilter.all.obs;
  final immersionIndex = 0.obs;
  final shadowUseSlow = false.obs;
  final shadowRecordings = <String, String>{}.obs;
  final shadowTranscripts = <String, String>{}.obs;
  final shadowAssessments = <String, SpeakingAssessment>{}.obs;
  final Map<String, RecordingCapture> _shadowCaptures = {};
  final isRecordingShadow = false.obs;

  // Stage 3: Rapid Response
  final rapidIndex = 0.obs;
  final rapidMode = RapidMode.story.obs;
  final rapidCountdown = 5.0.obs;
  final rapidTimerActive = false.obs;
  final rapidHintUnlocked = false.obs;
  final rapidAnswerRevealed = false.obs;
  final rapidScore = 0.obs;
  final rapidSpokenFeedback = ''.obs;
  final rapidAssessments = <int, SpeakingAssessment>{}.obs;
  final Map<int, RecordingCapture> _rapidCaptures = {};
  final isRecordingRapid = false.obs;
  Timer? _rapidTimer;

  // Stage 4: Role Play
  final selectedRoleId = 'maya'.obs;
  final roleDifficulty = RoleDifficulty.fullScript.obs;
  final useHeadsetAmbience = true.obs;
  final roleRecordings = <int, String>{}.obs;
  final roleAssessments = <int, SpeakingAssessment>{}.obs;
  final Map<int, RecordingCapture> _roleCaptures = {};
  final activeRoleRecordingLine = (-1).obs;

  // Stage 5: Final Boss
  final bossModeIndex = 0.obs;
  final bossSecondsLeft = 45.obs;
  final bossRunning = false.obs;
  final activeBeatIndex = 0.obs;
  final bossHitKeywords = <String>{}.obs;
  final bossTranscript = ''.obs;
  final bossRecordingPath = RxnString();
  final bossAssessment = Rxn<SpeakingAssessment>();
  RecordingCapture? _bossCapture;
  Timer? _bossTimer;

  List<SpeakingAssessment> get allCompletedAssessments => [
        ...shadowAssessments.values,
        ...rapidAssessments.values,
        ...roleAssessments.values,
        if (bossAssessment.value != null) bossAssessment.value!,
      ];

  int _averageScore(int Function(SpeakingAssessment a) pick) {
    final list = allCompletedAssessments;
    if (list.isEmpty) return 0;
    final sum = list.fold<int>(0, (acc, item) => acc + pick(item));
    return (sum / list.length).round();
  }

  int get topicAvgPronunciation =>
      _averageScore((a) => a.pronunciationScore);

  int get topicAvgFluency => _averageScore((a) => a.fluencyScore);

  int get topicAvgGrammar => _averageScore((a) => a.grammarScore);

  int get topicAvgOverall => _averageScore((a) => a.overallScore);

  CurriculumTopicMeta? get _resolvedMeta {
    final arg = Get.arguments;
    if (arg is CurriculumTopicMeta) return arg;
    return _initialTopicMeta;
  }

  List<ImmersionItem> get filteredImmersionItems {
    final data = topic.value;
    if (data == null) return const [];
    switch (immersionFilter.value) {
      case ImmersionFilter.all:
        return data.immersion.all;
      case ImmersionFilter.vocabulary:
        return data.immersion.vocabulary;
      case ImmersionFilter.expressions:
        return data.immersion.expressions;
    }
  }

  ImmersionItem? get currentImmersionItem {
    final items = filteredImmersionItems;
    if (items.isEmpty) return null;
    final idx = immersionIndex.value.clamp(0, items.length - 1);
    return items[idx];
  }

  RapidQuestion? get currentRapidQuestion {
    final data = topic.value;
    if (data == null || data.rapidResponse.isEmpty) return null;
    final idx = rapidIndex.value.clamp(0, data.rapidResponse.length - 1);
    return data.rapidResponse[idx];
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(loadTopicData());
  }

  Future<void> loadTopicData() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final path = _resolvedMeta?.jsonAssetPath ?? _defaultTopicJson;
      final loaded = await _repository.loadTopic(path);
      topic.value = loaded;
      bossSecondsLeft.value = loaded.finalBoss.durationSeconds;
      if (loaded.characters.isNotEmpty) {
        selectedRoleId.value = loaded.characters.first.id;
      }
      if (audioEngine.hasActiveBackgroundSession &&
          audioEngine.activeTopicTitle.value == loaded.title) {
        listeningMode.value = audioEngine.activeRealSituation.value
            ? ListeningMode.realSituation
            : (audioEngine.activeSlowMode.value
                ? ListeningMode.slow
                : ListeningMode.normal);
      }
      unawaited(audioEngine.preloadTopicAssets(loaded));
    } catch (e) {
      errorMessage.value = 'Gagal memuat materi topik: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> selectStage(int index) async {
    if (index == currentStage.value) return;
    await _stopActiveActivities(keepAmbience: index == 3 && useHeadsetAmbience.value);
    currentStage.value = index;
  }

  Future<void> _stopActiveActivities({bool keepAmbience = false}) async {
    _rapidTimer?.cancel();
    rapidTimerActive.value = false;
    if (bossRunning.value) {
      await stopBossChallenge();
    }
    if (speechTools.isRecording.value) {
      await speechTools.stopRecording();
    }
    isRecordingShadow.value = false;
    isRecordingRapid.value = false;
    activeRoleRecordingLine.value = -1;
    await speechTools.stopTts();
    if (keepAmbience) {
      await audioEngine.stopVoice();
    } else {
      await audioEngine.stopAll();
    }
  }

  // -------------------- STAGE 1: DEEP LISTENING --------------------

  Future<void> setListeningMode(ListeningMode mode) async {
    listeningMode.value = mode;
    if (audioEngine.isSequencePlaying.value) {
      final currentLine = audioEngine.activeLineIndex.value;
      final idx = topic.value?.dialogue.indexWhere((l) => l.index == currentLine) ?? -1;
      await playStage1Full(startFromIndex: idx >= 0 ? idx : 0);
    } else if (audioEngine.isPlayingVoice.value) {
      await playStage1Full(startFromIndex: 0);
    } else if (mode != ListeningMode.realSituation) {
      await audioEngine.stopAmbience();
    }
  }

  Future<void> playStage1Full({int startFromIndex = 0}) async {
    final data = topic.value;
    if (data == null) return;
    audioEngine.setActiveTopicContext(
      meta: _resolvedMeta,
      title: data.title,
      totalLines: data.dialogue.length,
    );
    await audioEngine.playDialogueSequence(
      lines: data.dialogue,
      slow: listeningMode.value == ListeningMode.slow,
      withRealSituation: listeningMode.value == ListeningMode.realSituation,
      assetsInfo: data.audioAssets,
      startFromIndex: startFromIndex,
    );
  }

  Future<void> playSingleLine(DialogueLine line) async {
    final data = topic.value;
    if (data == null) return;
    if (audioEngine.isSequencePlaying.value) {
      final idx = data.dialogue.indexWhere((l) => l.index == line.index);
      await playStage1Full(startFromIndex: idx >= 0 ? idx : 0);
      return;
    }
    audioEngine.setActiveTopicContext(
      meta: _resolvedMeta,
      title: data.title,
      totalLines: data.dialogue.length,
    );
    final useSlow = listeningMode.value == ListeningMode.slow;
    final path = useSlow ? line.audioSlow : line.audio;
    if (listeningMode.value == ListeningMode.realSituation &&
        !audioEngine.isAmbienceActive.value) {
      await audioEngine.startAmbience(data.audioAssets.ambienceLoop);
    }
    if (listeningMode.value == ListeningMode.realSituation &&
        line.sfxBefore != null) {
      final sfx = data.audioAssets.resolveCue(line.sfxBefore!);
      if (sfx != null && sfx.isNotEmpty) {
        await audioEngine.playSfx(sfx);
      }
    }
    await audioEngine.playSingleAsset(path, lineIndex: line.index);
  }

  Future<void> stopStage1Playback() async {
    await audioEngine.stopAll();
  }

  Future<void> toggleAmbiencePreview() async {
    final data = topic.value;
    if (data == null) return;
    audioEngine.setActiveTopicContext(
      meta: _resolvedMeta,
      title: data.title,
      totalLines: data.dialogue.length,
    );
    if (audioEngine.isAmbienceActive.value) {
      await audioEngine.stopAmbience();
    } else {
      await audioEngine.startAmbience(data.audioAssets.ambienceLoop);
    }
  }

  // ---------------- STAGE 2: IMMERSION & SHADOWING ----------------

  void setImmersionFilter(ImmersionFilter filter) {
    immersionFilter.value = filter;
    immersionIndex.value = 0;
  }

  void setImmersionIndex(int index) {
    final items = filteredImmersionItems;
    if (items.isEmpty) return;
    immersionIndex.value = index.clamp(0, items.length - 1);
  }

  Future<void> playCurrentImmersionAudio({bool? slowOverride}) async {
    final item = currentImmersionItem;
    if (item == null) return;
    final useSlow = slowOverride ?? shadowUseSlow.value;
    await audioEngine.playSingleAsset(useSlow ? item.audioSlow : item.audio);
  }

  Future<void> toggleShadowRecord() async {
    final item = currentImmersionItem;
    if (item == null) return;

    if (isRecordingShadow.value) {
      final capture = await speechTools.stopRecordingWithCapture();
      isRecordingShadow.value = false;
      if (capture.filePath != null && capture.filePath!.isNotEmpty) {
        shadowRecordings[item.term] = capture.filePath!;
      }
      if (capture.transcript.isNotEmpty) {
        shadowTranscripts[item.term] = capture.transcript;
      }
      _shadowCaptures[item.term] = capture;
      _runShadowEvaluation(item, capture);
      return;
    }

    await audioEngine.stopVoice();
    final started = await speechTools.startRecording(
      tag: 'shadow_${item.term}',
      enableStt: true,
      onTranscript: (text) {
        if (text.isNotEmpty) {
          shadowTranscripts[item.term] = text;
        }
      },
    );
    isRecordingShadow.value = started;
  }

  Future<void> playCurrentShadowRecording() async {
    final item = currentImmersionItem;
    if (item == null) return;
    final path = shadowRecordings[item.term];
    if (path == null || path.isEmpty) return;
    await audioEngine.playRecordedAudio(path);
  }

  void _runShadowEvaluation(ImmersionItem item, RecordingCapture capture) {
    final slow = shadowUseSlow.value;
    final refDur = slow ? item.durationSlowSec : item.durationSec;
    final refEnv = slow && item.envelopeSlow.isNotEmpty
        ? item.envelopeSlow
        : item.envelope;
    final result = evaluator.evaluate(
      stageLabel: 'Immersion · ${item.term}',
      targetText: item.example,
      spokenTranscript: capture.transcript,
      recordingElapsed: capture.elapsed,
      amplitudeDbfs: capture.amplitudeDbfs,
      referenceDurationSec: refDur,
      referenceEnvelope: refEnv,
      strictTargetGrammar: true,
    );
    shadowAssessments[item.term] = result;
  }

  void evaluateShadowWithManualText(String spokenText) {
    final item = currentImmersionItem;
    if (item == null) return;
    final clean = spokenText.trim();
    shadowTranscripts[item.term] = clean;
    final prev = _shadowCaptures[item.term] ??
        RecordingCapture(
          elapsed: Duration(
            milliseconds: ((item.durationSec ?? 2.0) * 1000).round(),
          ),
        );
    final updated = RecordingCapture(
      filePath: prev.filePath,
      transcript: clean,
      elapsed: prev.elapsed,
      amplitudeDbfs: prev.amplitudeDbfs,
    );
    _shadowCaptures[item.term] = updated;
    _runShadowEvaluation(item, updated);
  }

  // -------------------- STAGE 3: RAPID RESPONSE --------------------

  Future<void> speakRapidQuestion() async {
    final q = currentRapidQuestion;
    if (q == null) return;
    final prompt =
        rapidMode.value == RapidMode.story ? q.question : q.personalQuestion;
    await speechTools.speakPrompt(prompt);
  }

  void startRapidTimer() {
    _rapidTimer?.cancel();
    rapidCountdown.value = 5.0;
    rapidHintUnlocked.value = false;
    rapidAnswerRevealed.value = false;
    rapidSpokenFeedback.value = '';
    rapidTimerActive.value = true;
    unawaited(speakRapidQuestion());

    _rapidTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final next = (rapidCountdown.value - 0.1).clamp(0.0, 5.0);
      rapidCountdown.value = double.parse(next.toStringAsFixed(1));
      if (rapidCountdown.value <= 2.5) {
        rapidHintUnlocked.value = true;
      }
      if (rapidCountdown.value <= 0.0) {
        timer.cancel();
        rapidTimerActive.value = false;
        rapidAnswerRevealed.value = true;
      }
    });
  }

  void revealRapidAnswer() {
    _rapidTimer?.cancel();
    rapidTimerActive.value = false;
    rapidHintUnlocked.value = true;
    rapidAnswerRevealed.value = true;
  }

  Future<void> toggleRapidMic() async {
    final q = currentRapidQuestion;
    if (q == null) return;
    if (isRecordingRapid.value) {
      final capture = await speechTools.stopRecordingWithCapture();
      isRecordingRapid.value = false;
      final spoken = capture.transcript.toLowerCase();
      rapidSpokenFeedback.value = capture.transcript;
      _rapidCaptures[q.id] = capture;
      _runRapidEvaluation(q, capture);
      if (spoken.isNotEmpty &&
          q.keywords.any((kw) => spoken.contains(kw.toLowerCase()))) {
        rapidScore.value++;
        revealRapidAnswer();
      }
      return;
    }

    await speechTools.stopTts();
    final ok = await speechTools.startRecording(
      tag: 'rapid_${q.id}',
      enableStt: true,
      onTranscript: (text) {
        rapidSpokenFeedback.value = text;
        final lower = text.toLowerCase();
        if (rapidMode.value == RapidMode.story &&
            q.keywords.any((kw) => lower.contains(kw.toLowerCase()))) {
          if (!rapidAnswerRevealed.value) {
            rapidScore.value++;
            revealRapidAnswer();
          }
        }
      },
    );
    isRecordingRapid.value = ok;
  }

  void markRapidSelfCorrect() {
    rapidScore.value++;
    revealRapidAnswer();
  }

  void _runRapidEvaluation(RapidQuestion q, RecordingCapture capture) {
    final isStory = rapidMode.value == RapidMode.story;
    final result = evaluator.evaluate(
      stageLabel: 'Rapid #${q.id}',
      targetText: isStory ? q.fullAnswer : q.personalQuestion,
      spokenTranscript: capture.transcript,
      recordingElapsed: capture.elapsed,
      amplitudeDbfs: capture.amplitudeDbfs,
      referenceDurationSec: isStory ? 2.5 : 3.5,
      strictTargetGrammar: false,
      expectedKeywords: isStory ? q.keywords : const [],
    );
    rapidAssessments[q.id] = result;
  }

  void evaluateRapidWithManualText(String spokenText) {
    final q = currentRapidQuestion;
    if (q == null) return;
    final clean = spokenText.trim();
    rapidSpokenFeedback.value = clean;
    final prev = _rapidCaptures[q.id] ??
        const RecordingCapture(elapsed: Duration(seconds: 2));
    final updated = RecordingCapture(
      filePath: prev.filePath,
      transcript: clean,
      elapsed: prev.elapsed,
      amplitudeDbfs: prev.amplitudeDbfs,
    );
    _rapidCaptures[q.id] = updated;
    _runRapidEvaluation(q, updated);
    if (rapidMode.value == RapidMode.story &&
        q.keywords.any((kw) => clean.toLowerCase().contains(kw.toLowerCase()))) {
      revealRapidAnswer();
    }
  }

  void nextRapidQuestion() {
    final total = topic.value?.rapidResponse.length ?? 0;
    if (total == 0) return;
    _rapidTimer?.cancel();
    rapidTimerActive.value = false;
    rapidCountdown.value = 5.0;
    rapidHintUnlocked.value = false;
    rapidAnswerRevealed.value = false;
    rapidSpokenFeedback.value = '';
    rapidIndex.value = (rapidIndex.value + 1) % total;
  }

  void prevRapidQuestion() {
    final total = topic.value?.rapidResponse.length ?? 0;
    if (total == 0) return;
    _rapidTimer?.cancel();
    rapidTimerActive.value = false;
    rapidCountdown.value = 5.0;
    rapidHintUnlocked.value = false;
    rapidAnswerRevealed.value = false;
    rapidSpokenFeedback.value = '';
    rapidIndex.value = (rapidIndex.value - 1 + total) % total;
  }

  // -------------------- STAGE 4: ROLE PLAY --------------------

  Future<void> setUseHeadsetAmbience(bool enabled) async {
    useHeadsetAmbience.value = enabled;
    final data = topic.value;
    if (data == null) return;
    if (enabled) {
      await audioEngine.startAmbience(data.audioAssets.ambienceLoop);
    } else {
      await audioEngine.stopAmbience();
    }
  }

  Future<void> playRoleReferenceLine(DialogueLine line) async {
    await audioEngine.playSingleAsset(line.audio, lineIndex: line.index);
  }

  Future<void> toggleRoleTurnRecord(DialogueLine line) async {
    if (activeRoleRecordingLine.value == line.index) {
      final capture = await speechTools.stopRecordingWithCapture();
      activeRoleRecordingLine.value = -1;
      if (capture.filePath != null && capture.filePath!.isNotEmpty) {
        roleRecordings[line.index] = capture.filePath!;
      }
      _roleCaptures[line.index] = capture;
      _runRoleEvaluation(line, capture);
      return;
    }

    if (activeRoleRecordingLine.value != -1) {
      await speechTools.stopRecording();
    }

    await audioEngine.stopVoice();
    // Keep continuous ambience running cleanly if headset mode is enabled!
    if (useHeadsetAmbience.value && !audioEngine.isAmbienceActive.value) {
      final loopPath = topic.value?.audioAssets.ambienceLoop ?? '';
      await audioEngine.startAmbience(loopPath);
    }

    final started = await speechTools.startRecording(
      tag: 'role_${line.speakerId}_${line.index}',
      enableStt: true,
    );
    activeRoleRecordingLine.value = started ? line.index : -1;
  }

  void _runRoleEvaluation(DialogueLine line, RecordingCapture capture) {
    final result = evaluator.evaluate(
      stageLabel: 'Role Play · ${line.speakerName} #${line.index + 1}',
      targetText: line.text,
      spokenTranscript: capture.transcript,
      recordingElapsed: capture.elapsed,
      amplitudeDbfs: capture.amplitudeDbfs,
      referenceDurationSec: line.durationSec,
      referenceEnvelope: line.envelope,
      strictTargetGrammar: true,
    );
    roleAssessments[line.index] = result;
  }

  void evaluateRoleWithManualText(DialogueLine line, String spokenText) {
    final prev = _roleCaptures[line.index] ??
        RecordingCapture(
          elapsed: Duration(
            milliseconds: ((line.durationSec ?? 2.2) * 1000).round(),
          ),
        );
    final updated = RecordingCapture(
      filePath: prev.filePath,
      transcript: spokenText.trim(),
      elapsed: prev.elapsed,
      amplitudeDbfs: prev.amplitudeDbfs,
    );
    _roleCaptures[line.index] = updated;
    _runRoleEvaluation(line, updated);
  }

  Future<void> playRoleUserRecording(DialogueLine line) async {
    final path = roleRecordings[line.index];
    if (path == null || path.isEmpty) return;
    await audioEngine.playRecordedAudio(path, lineIndex: line.index);
  }

  Future<void> playRolePlayDuet() async {
    final data = topic.value;
    if (data == null) return;
    await audioEngine.playRolePlayDuet(
      lines: data.dialogue,
      userRoleId: selectedRoleId.value,
      userRecordings: roleRecordings,
      assetsInfo: data.audioAssets,
      useAmbience: useHeadsetAmbience.value,
    );
  }

  // -------------------- STAGE 5: FINAL BOSS --------------------

  Future<void> toggleBossChallenge() async {
    if (bossRunning.value) {
      await stopBossChallenge();
      return;
    }

    final data = topic.value;
    final duration = data?.finalBoss.durationSeconds ?? 45;
    final totalBeats = data?.finalBoss.storyBeats.length ?? 4;

    await audioEngine.stopVoice();
    bossSecondsLeft.value = duration;
    activeBeatIndex.value = 0;
    bossHitKeywords.clear();
    bossTranscript.value = '';

    final micOk = await speechTools.startRecording(
      tag: 'final_boss',
      enableStt: true,
      onTranscript: _handleBossTranscript,
    );
    if (!micOk) return;

    bossRunning.value = true;
    _bossTimer?.cancel();
    _bossTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (bossSecondsLeft.value <= 1) {
        bossSecondsLeft.value = 0;
        unawaited(stopBossChallenge());
        return;
      }
      bossSecondsLeft.value--;
      final elapsed = duration - bossSecondsLeft.value;
      final beatSpan = (duration / totalBeats).ceil().clamp(1, duration);
      activeBeatIndex.value = (elapsed ~/ beatSpan).clamp(0, totalBeats - 1);
    });
  }

  Future<void> stopBossChallenge() async {
    _bossTimer?.cancel();
    bossRunning.value = false;
    final capture = await speechTools.stopRecordingWithCapture();
    if (capture.filePath != null && capture.filePath!.isNotEmpty) {
      bossRecordingPath.value = capture.filePath;
    }
    _bossCapture = capture;
    _runBossEvaluation(capture);
  }

  void _runBossEvaluation(RecordingCapture capture) {
    final boss = topic.value?.finalBoss;
    if (boss == null) return;
    final allKeywords = [
      for (final beat in boss.storyBeats) ...beat.keywords,
    ];
    final allConnectors = [
      for (final beat in boss.storyBeats) ...beat.connectors,
    ];
    final targetSummary = boss.storyBeats.map((b) => b.starter).join(' ');
    final result = evaluator.evaluate(
      stageLabel: 'Final Boss 45s',
      targetText: targetSummary,
      spokenTranscript: capture.transcript,
      recordingElapsed: capture.elapsed,
      amplitudeDbfs: capture.amplitudeDbfs,
      referenceDurationSec: boss.durationSeconds * 0.75,
      strictTargetGrammar: false,
      retellPastTense: bossModeIndex.value == 0,
      expectedKeywords: allKeywords,
      connectors: allConnectors,
    );
    bossAssessment.value = result;
  }

  void evaluateBossWithManualText(String spokenText) {
    final clean = spokenText.trim();
    _handleBossTranscript(clean);
    final prev = _bossCapture ?? const RecordingCapture(elapsed: Duration(seconds: 35));
    final updated = RecordingCapture(
      filePath: prev.filePath,
      transcript: clean,
      elapsed: prev.elapsed,
      amplitudeDbfs: prev.amplitudeDbfs,
    );
    _bossCapture = updated;
    _runBossEvaluation(updated);
  }

  void _handleBossTranscript(String transcript) {
    bossTranscript.value = transcript;
    final beats = topic.value?.finalBoss.storyBeats ?? const [];
    final lower = transcript.toLowerCase();
    for (final beat in beats) {
      for (final kw in beat.keywords) {
        if (lower.contains(kw.toLowerCase())) {
          bossHitKeywords.add(kw);
        }
      }
    }
  }

  void toggleManualKeywordHit(String keyword) {
    if (bossHitKeywords.contains(keyword)) {
      bossHitKeywords.remove(keyword);
    } else {
      bossHitKeywords.add(keyword);
    }
  }

  Future<void> playBossRecording() async {
    final path = bossRecordingPath.value;
    if (path == null || path.isEmpty) return;
    await audioEngine.playRecordedAudio(path);
  }

  @override
  void onClose() {
    _rapidTimer?.cancel();
    _bossTimer?.cancel();
    final keepBackgroundAudio = audioEngine.backgroundPlaybackEnabled.value &&
        audioEngine.hasActiveBackgroundSession;
    if (!keepBackgroundAudio) {
      unawaited(audioEngine.stopAll());
    }
    unawaited(speechTools.stopRecording());
    unawaited(speechTools.stopTts());
    super.onClose();
  }
}
