import 'package:audioplayers/audioplayers.dart';
import 'package:eng_destroying_app/app/data/models/lesson_topic_model.dart';
import 'package:eng_destroying_app/app/data/repositories/lesson_repository.dart';
import 'package:eng_destroying_app/app/data/services/audio_engine_service.dart';
import 'package:eng_destroying_app/app/data/services/local_speaking_evaluator.dart';
import 'package:eng_destroying_app/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _SpyAudioEngineService extends AudioEngineService {
  final List<String> playedSources = <String>[];
  bool sawWaitingTurn = false;

  @override
  Future<bool> playAudioSource(Source source, {required int token}) async {
    if (isWaitingUserTurn.value) sawWaitingTurn = true;
    if (source is AssetSource) {
      playedSources.add('asset:${source.path}');
    } else if (source is DeviceFileSource) {
      playedSources.add('file:${source.path}');
    } else if (source is UrlSource) {
      playedSources.add('url:${source.url}');
    }
    return true;
  }
}

void main() {
  tearDown(Get.reset);

  test('Curriculum maps 12 lessons x 3 topics (36 total) with L01 T01 ready',
      () {
    final repo = LessonRepository();
    final curriculum = repo.getCurriculum();

    expect(curriculum.length, 12);
    final totalTopics = curriculum.fold<int>(
      0,
      (sum, lesson) => sum + lesson.topics.length,
    );
    expect(totalTopics, 36);
    expect(curriculum.first.topics.first.isReady, isTrue);
    expect(
      curriculum.first.topics.first.jsonAssetPath,
      'assets/data/lessons/lesson_01/topic_01.json',
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

  testWidgets(
      'Home launches Topic 01, scores Stage 2 locally, opens Rapor, switches stages',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const EngDestroyingApp());
    await tester.pumpAndSettle();

    expect(find.text('EngDestroying 2.0'), findsOneWidget);
    await tester.tap(find.text('Mulai Lesson 01 — Topic 01'));
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
    expect(find.text('Rapor Penilaian Lokal Topik 01'), findsOneWidget);
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
  });
}
