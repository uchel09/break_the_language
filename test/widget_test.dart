import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:eng_destroying_app/app/data/models/lesson_topic_model.dart';
import 'package:eng_destroying_app/app/data/repositories/lesson_repository.dart';
import 'package:eng_destroying_app/app/data/services/audio_engine_service.dart';
import 'package:eng_destroying_app/app/data/services/local_speaking_evaluator.dart';
import 'package:eng_destroying_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _SpyAudioEngineService extends AudioEngineService {
  _SpyAudioEngineService({this.deferPlayback = false});

  final bool deferPlayback;
  final List<String> playedSources = <String>[];
  final List<int> playedLineIndices = <int>[];
  final List<Completer<bool>> pendingCompletions = <Completer<bool>>[];
  bool sawWaitingTurn = false;

  void finishCurrentClip({bool result = true}) {
    if (pendingCompletions.isNotEmpty && !pendingCompletions.last.isCompleted) {
      pendingCompletions.last.complete(result);
    }
  }

  @override
  Future<void> stopVoice() async {
    await super.stopVoice();
    for (final c in pendingCompletions) {
      if (!c.isCompleted) c.complete(false);
    }
  }

  @override
  Future<void> startAmbience(String assetPath, {double? volume}) async {
    if (assetPath.isEmpty) return;
    if (volume != null) ambienceVolume.value = volume.clamp(0.0, 1.0);
    isAmbienceActive.value = true;
  }

  @override
  Future<void> stopAmbience() async {
    isAmbienceActive.value = false;
  }

  @override
  Future<void> playSfx(String assetPath, {double volume = 0.85}) async {}

  @override
  Future<bool> playAudioSource(Source source, {required int token}) async {
    if (isWaitingUserTurn.value) sawWaitingTurn = true;
    playedLineIndices.add(activeLineIndex.value);
    if (source is AssetSource) {
      playedSources.add('asset:${source.path}');
    } else if (source is DeviceFileSource) {
      playedSources.add('file:${source.path}');
    } else if (source is UrlSource) {
      playedSources.add('url:${source.url}');
    }
    if (!deferPlayback) return true;
    final completer = Completer<bool>();
    pendingCompletions.add(completer);
    return completer.future;
  }
}

void main() {
  tearDown(Get.reset);

  test('Curriculum maps 12 lessons x 3 topics (36 total) with L01 T01 & T02 ready',
      () {
    final repo = LessonRepository();
    final curriculum = repo.getCurriculum();

    expect(curriculum.length, 12);
    final totalTopics = curriculum.fold<int>(
      0,
      (sum, lesson) => sum + lesson.topics.length,
    );
    expect(totalTopics, 36);
    expect(curriculum.first.topics[0].isReady, isTrue);
    expect(
      curriculum.first.topics[0].jsonAssetPath,
      'assets/data/lessons/lesson_01/topic_01.json',
    );
    expect(curriculum.first.topics[1].isReady, isTrue);
    expect(
      curriculum.first.topics[1].jsonAssetPath,
      'assets/data/lessons/lesson_01/topic_02.json',
    );
  });

  test('Lesson 01 Topic 01 JSON maps audio durations and envelopes cleanly',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = LessonRepository();
    final data = await repo.loadTopic(
      'assets/data/lessons/lesson_01/topic_01.json',
    );

    expect(data.lessonNumber, 1);
    expect(data.topicNumber, 1);
    expect(data.characters.length, 3);
    expect(data.dialogue.length, 16);
    expect(data.dialogue[1].durationSec, isNotNull);
    expect(data.dialogue[1].durationSec!, greaterThan(1.0));
    expect(data.dialogue[1].envelope.length, 12);
    expect(data.dialogue[1].envelopeSlow.length, 12);
    expect(data.immersion.vocabulary.first.envelope.length, 12);
    expect(data.immersion.vocabulary.length, 6);
    expect(data.immersion.expressions.length, 8);
    expect(data.rapidResponse.length, 12);
    expect(data.finalBoss.storyBeats.length, 4);
  });

  test('Lesson 01 Topic 02 JSON maps audio durations, envelopes, and SFX cues',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = LessonRepository();
    final data = await repo.loadTopic(
      'assets/data/lessons/lesson_01/topic_02.json',
    );

    expect(data.lessonNumber, 1);
    expect(data.topicNumber, 2);
    expect(data.characters.length, 2);
    expect(data.characters.map((c) => c.id), ['hannah', 'kenji']);
    expect(
      data.audioAssets.resolveCue('lounge_door'),
      'audio/sfx/lounge_door.mp3',
    );
    expect(
      data.audioAssets.resolveCue('phone_ping'),
      'audio/sfx/phone_ping.mp3',
    );
    expect(data.dialogue.length, 16);
    for (final line in data.dialogue) {
      expect(line.durationSec, isNotNull);
      expect(line.durationSlowSec, isNotNull);
      expect(line.durationSec!, greaterThan(1.0));
      expect(line.envelope.length, 12);
      expect(line.envelopeSlow.length, 12);
      expect((await rootBundle.load('assets/${line.audio}')).lengthInBytes, greaterThan(1000));
      expect((await rootBundle.load('assets/${line.audioSlow}')).lengthInBytes, greaterThan(1000));
    }
    for (final sfxPath in data.audioAssets.allSfxPaths) {
      expect((await rootBundle.load('assets/$sfxPath')).lengthInBytes, greaterThan(1000));
    }
    expect(data.immersion.vocabulary.length, 6);
    expect(data.immersion.expressions.length, 8);
    expect(data.rapidResponse.length, 12);
    expect(data.finalBoss.storyBeats.length, 4);
    for (final beat in data.finalBoss.storyBeats) {
      expect((await rootBundle.load(beat.image)).lengthInBytes, greaterThan(1000));
    }
  });

  test('LocalSpeakingEvaluator scores Pronunciation, Fluency, and Grammar',
      () {
    final evaluator = LocalSpeakingEvaluator();

    final highResult = evaluator.evaluate(
      stageLabel: 'Immersion · Meet',
      targetText: 'Nice to meet you, Ryan.',
      spokenTranscript: 'Nice to meet you Ryan',
      recordingElapsed: const Duration(milliseconds: 1200),
      amplitudeDbfs: List<double>.generate(
        15,
        (i) => i == 4 ? -12.0 : -18.0,
      ),
      referenceDurationSec: 1.18,
      referenceEnvelope: const [100, 46, 2, 59, 54, 52, 71, 33, 28, 34, 22, 4],
      strictTargetGrammar: true,
    );

    expect(highResult.hasTranscript, isTrue);
    expect(highResult.hasAcousticSignal, isTrue);
    expect(highResult.pronunciationScore, greaterThanOrEqualTo(80));
    expect(highResult.fluencyScore, greaterThanOrEqualTo(85));
    expect(highResult.grammarScore, 100);

    final grammarIssuesResult = evaluator.evaluate(
      stageLabel: 'Final Boss 45s',
      targetText: 'Yesterday, my friend Chloe and I walked out of a coffee shop.',
      spokenTranscript: 'Yesterday Maya walk out and she come from New Zealand',
      recordingElapsed: const Duration(seconds: 6),
      amplitudeDbfs: const [
        -18, -16, -50, -50, -50, -50, -14, -18, -50, -50, -50, -50, -15,
      ],
      referenceDurationSec: 4.0,
      strictTargetGrammar: false,
      retellPastTense: true,
      connectors: const ['First', 'Suddenly'],
    );

    expect(grammarIssuesResult.grammarIssues, isNotEmpty);
    expect(grammarIssuesResult.pauseCount, 2);
    expect(grammarIssuesResult.grammarScore, lessThan(85));

    final acousticOnly = evaluator.evaluate(
      stageLabel: 'Role Play',
      targetText: "Hey, Ryan! How's it going?",
      spokenTranscript: '',
      recordingElapsed: const Duration(milliseconds: 1700),
      amplitudeDbfs: const [-18, -15, -20, -25, -45, -18, -22, -28],
      referenceDurationSec: 1.69,
      referenceEnvelope: const [88, 100, 87, 61, 38, 3, 71, 41, 51, 71, 38, 15],
    );
    expect(acousticOnly.hasTranscript, isFalse);
    expect(acousticOnly.hasAcousticSignal, isTrue);
    expect(acousticOnly.fluencyScore, greaterThanOrEqualTo(75));
  });

  test('Role Play mutes chosen character unrecorded turns instead of playing AI',
      () async {
    final spy = _SpyAudioEngineService();
    const lines = [
      DialogueLine(
        index: 0,
        speakerId: 'narrator',
        speakerName: 'Narrator',
        audio: 'lines/line_00.mp3',
        audioSlow: 'lines_slow/line_00.mp3',
        text: 'Intro',
        cloze: 'Intro',
        cueId: 'Intro',
        phonetic: '',
        meaning: '',
        durationSec: 0.1,
      ),
      DialogueLine(
        index: 1,
        speakerId: 'maya',
        speakerName: 'Maya',
        audio: 'lines/line_01_maya.mp3',
        audioSlow: 'lines_slow/line_01_maya.mp3',
        text: 'Hey Ryan!',
        cloze: 'Hey ____!',
        cueId: 'Sapa Ryan',
        phonetic: '',
        meaning: '',
        durationSec: 0.1,
      ),
      DialogueLine(
        index: 2,
        speakerId: 'ryan',
        speakerName: 'Ryan',
        audio: 'lines/line_02_ryan.mp3',
        audioSlow: 'lines_slow/line_02_ryan.mp3',
        text: 'Hey Maya!',
        cloze: 'Hey ____!',
        cueId: 'Balas Maya',
        phonetic: '',
        meaning: '',
        durationSec: 0.1,
      ),
    ];

    final waitingStates = <bool>[];
    final sub = spy.isWaitingUserTurn.listen(waitingStates.add);

    await spy.playRolePlayDuet(
      lines: lines,
      userRoleId: 'maya',
      userRecordings: const {},
      assetsInfo: const AudioAssetsInfo(
        ambienceLoop: '',
        sfxDoorChime: '',
        sfxBookPat: '',
      ),
      useAmbience: false,
    );
    await sub.cancel();

    expect(spy.playedSources, ['asset:lines/line_00.mp3', 'asset:lines/line_02_ryan.mp3']);
    expect(waitingStates, contains(true));
  });

  test('Non-Stop Loop automatically restarts conversation from index 0 until stopped',
      () async {
    final spy = _SpyAudioEngineService();
    const lines = [
      DialogueLine(
        index: 0,
        speakerId: 'narrator',
        speakerName: 'Narrator',
        audio: 'lines/0.mp3',
        audioSlow: 'lines_slow/0.mp3',
        text: 'Zero',
        cloze: 'Zero',
        cueId: '',
        phonetic: '',
        meaning: '',
      ),
      DialogueLine(
        index: 1,
        speakerId: 'hannah',
        speakerName: 'Hannah',
        audio: 'lines/1.mp3',
        audioSlow: 'lines_slow/1.mp3',
        text: 'One',
        cloze: 'One',
        cueId: '',
        phonetic: '',
        meaning: '',
      ),
      DialogueLine(
        index: 2,
        speakerId: 'kenji',
        speakerName: 'Kenji',
        audio: 'lines/2.mp3',
        audioSlow: 'lines_slow/2.mp3',
        text: 'Two',
        cloze: 'Two',
        cueId: '',
        phonetic: '',
        meaning: '',
      ),
    ];

    spy.isLoopEnabled.value = true;
    var calls = 0;
    await spy.playDialogueSequence(
      lines: lines,
      slow: false,
      withRealSituation: false,
      assetsInfo: const AudioAssetsInfo(ambienceLoop: ''),
      interLinePause: Duration.zero,
      loopPause: Duration.zero,
      onLineChanged: (_) {
        calls++;
        if (calls >= 5) {
          spy.stopVoice();
        }
      },
    );

    expect(spy.playedLineIndices, [0, 1, 2, 0]);
    expect(spy.isPlayingVoice.value, isFalse);
    expect(spy.isSequencePlaying.value, isFalse);
    expect(spy.activeLineIndex.value, -1);
  });

  testWidgets(
      'Home shows 2/36 active, launches Topic 02, scores Stage 2 locally, opens Rapor, switches stages',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const EngDestroyingApp());
    await tester.pumpAndSettle();

    expect(find.text('EngDestroying 2.0'), findsOneWidget);
    expect(find.text('2/36 Topik Aktif'), findsOneWidget);
    expect(find.text('Meeting Someone New'), findsOneWidget);
    expect(find.text('Where Do You Live?'), findsWidgets);

    await tester.tap(find.text('Mulai Lesson 01 — Topic 02'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stage 1 · Deep Listening'), findsOneWidget);

    await tester.tap(find.text('2. Immersion'));
    await tester.pumpAndSettle();
    expect(find.text('Stage 2 · Immersion & Shadowing'), findsOneWidget);

    await tester.ensureVisible(find.text('Simulasi Cek Nilai Tanpa Mic'));
    await tester.tap(find.text('Simulasi Cek Nilai Tanpa Mic'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Penilaian Lokal'), findsOneWidget);
    expect(find.text('Pronunciation'), findsOneWidget);
    expect(find.text('Fluency'), findsOneWidget);
    expect(find.text('Grammar'), findsOneWidget);
    expect(find.text('Rapor (1)'), findsOneWidget);

    await tester.tap(find.text('Rapor (1)'));
    await tester.pumpAndSettle();
    expect(
      find.text('Rapor Penilaian Lokal · Topic 02: Where Do You Live?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    final tabs = <(String, String)>[
      ('3. Rapid 5s', 'Stage 3 · Rapid Response 5s'),
      ('4. Role Play', 'Stage 4 · Interactive Role Play Duet'),
      ('5. Final Boss', 'Stage 5 · Final Boss Storytelling (45s)'),
    ];

    for (final (tabLabel, heading) in tabs) {
      final tabFinder = find.text(tabLabel);
      await tester.dragUntilVisible(
        tabFinder,
        find.byType(ListView).first,
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(tabFinder);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pumpAndSettle();
      expect(find.text(heading), findsOneWidget);
    }
    expect(find.text('Retell Story'), findsOneWidget);
  });

  testWidgets(
      'Stage 1 Non-Stop & Background Play stay alive on Home menu with Mini-Player controls',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final spy = _SpyAudioEngineService();
    Get.put<AudioEngineService>(spy, permanent: true);

    await tester.pumpWidget(const EngDestroyingApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai Lesson 01 — Topic 02'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Non-Stop (Ulang Terus)'), findsOneWidget);
    expect(find.text('Putar Latar Belakang'), findsOneWidget);
    expect(spy.backgroundPlaybackEnabled.value, isTrue);

    await tester.tap(find.byIcon(Icons.surround_sound_rounded));
    await tester.pumpAndSettle();
    expect(spy.isAmbienceActive.value, isTrue);

    await tester.ensureVisible(find.text('Non-Stop (Ulang Terus)'));
    await tester.tap(find.text('Non-Stop (Ulang Terus)'));
    await tester.pumpAndSettle();
    expect(spy.isLoopEnabled.value, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Audio remains active when navigating back to Home menu.
    expect(spy.hasActiveBackgroundSession, isTrue);
    expect(find.text('Topic 02: Where Do You Live?'), findsOneWidget);
    expect(find.text('Suasana latar aktif · Non-Stop'), findsOneWidget);

    await tester.tap(find.byTooltip('Hentikan Audio'));
    await tester.pumpAndSettle();
    expect(spy.hasActiveBackgroundSession, isFalse);
    expect(find.text('Suasana latar aktif · Non-Stop'), findsNothing);
  });

  testWidgets(
      'Tapping an earlier line while Putar Percakapan is active jumps and continues sequentially',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final spy = _SpyAudioEngineService(deferPlayback: true);
    Get.put<AudioEngineService>(spy, permanent: true);

    await tester.pumpWidget(const EngDestroyingApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai Lesson 01 — Topic 02'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pumpAndSettle();

    // Start full sequence playback; advances from line 0 up to line 5.
    await tester.tap(find.text('Putar Percakapan'));
    await tester.pump();
    for (var step = 0; step < 5; step++) {
      spy.finishCurrentClip();
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(spy.isSequencePlaying.value, isTrue);
    expect(spy.activeLineIndex.value, 5);

    // Tap line 2 while still playing; must jump to 2 and continue 2 -> 3 -> 4.
    final line2Finder = find.text("Oh, yes! Good morning. I'm Kenjiro, by the way.");
    await tester.dragUntilVisible(
      line2Finder,
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.pump();
    await tester.tap(line2Finder);
    await tester.pump();
    expect(spy.activeLineIndex.value, 2);
    expect(spy.isSequencePlaying.value, isTrue);

    spy.finishCurrentClip();
    await tester.pump(const Duration(milliseconds: 600));
    expect(spy.activeLineIndex.value, 3);
    expect(spy.isSequencePlaying.value, isTrue);

    spy.finishCurrentClip();
    await tester.pump(const Duration(milliseconds: 600));
    expect(spy.activeLineIndex.value, 4);
    expect(spy.isSequencePlaying.value, isTrue);

    // After Stop Audio, tapping line 2 plays only line 2 without starting sequence.
    await tester.dragUntilVisible(
      find.text('Stop Audio'),
      find.byType(ListView).last,
      const Offset(0, 200),
    );
    await tester.pump();
    await tester.tap(find.text('Stop Audio'));
    await tester.pump();
    expect(spy.isSequencePlaying.value, isFalse);

    await tester.dragUntilVisible(
      line2Finder,
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.pump();
    await tester.tap(line2Finder);
    await tester.pump();
    expect(spy.activeLineIndex.value, 2);
    expect(spy.isSequencePlaying.value, isFalse);

    spy.finishCurrentClip();
    await tester.pump();
    expect(spy.activeLineIndex.value, -1);
    expect(spy.isPlayingVoice.value, isFalse);
  });
}
