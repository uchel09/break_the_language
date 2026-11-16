import 'dart:math' as math;

import '../models/speaking_assessment_model.dart';

/// 100% offline/on-device evaluator for Pronunciation, Fluency, and Grammar.
/// Combines acoustic energy envelope comparison against native MP3 assets,
/// speaking pace/hesitation analysis, phonetic/Levenshtein word alignment,
/// and Indonesian-learner ESL grammar rules.
class LocalSpeakingEvaluator {
  static const Map<String, List<String>> _contractionEquivalents = {
    'hows': ['how is', 'how has', 'howz', 'howzit'],
    'thats': ['that is', 'that has'],
    'im': ['i am'],
    'wed': ['we had', 'we would'],
    'isnt': ['is not'],
    'gotta': ['got to', 'going to', 'godda'],
    'catcha': ['catch ya', 'catch you'],
    'seeya': ['see ya', 'see you'],
    'you': ['ya'],
    'ya': ['you'],
    'chloe': ['c h l o e'],
  };

  static const Set<String> _grammarFunctionWords = {
    'is',
    'are',
    'am',
    'was',
    'were',
    'do',
    'does',
    'did',
    'have',
    'has',
    'had',
    'to',
    'from',
    'on',
    'in',
    'at',
    'a',
    'an',
    'the',
    'for',
    'of',
    'my',
    'your',
    'too',
    'always',
  };

  SpeakingAssessment evaluate({
    required String stageLabel,
    required String targetText,
    required String spokenTranscript,
    required Duration recordingElapsed,
    List<double> amplitudeDbfs = const [],
    double? referenceDurationSec,
    List<int> referenceEnvelope = const [],
    bool strictTargetGrammar = true,
    bool retellPastTense = false,
    List<String> expectedKeywords = const [],
    List<String> connectors = const [],
  }) {
    final cleanTranscript = spokenTranscript.trim();
    final hasTranscript = cleanTranscript.isNotEmpty;
    final hasAcoustic = amplitudeDbfs.any((d) => d > -115.0);

    final acoustic = _analyzeAcoustics(
      elapsedSec: math.max(0.1, recordingElapsed.inMilliseconds / 1000.0),
      amplitudeDbfs: amplitudeDbfs,
      hasAcoustic: hasAcoustic,
    );

    final targetWords = _tokenize(targetText);
    final refDur = (referenceDurationSec != null && referenceDurationSec > 0)
        ? referenceDurationSec
        : math.max(1.2, targetWords.length / 2.4);

    final effectiveUserDur =
        hasAcoustic ? acoustic.activeDurationSec : recordingElapsed.inMilliseconds / 1000.0;

    final rhythmScore = _computeRhythmSimilarity(
      userEnv: acoustic.envelope12,
      refEnv: referenceEnvelope,
      hasAcoustic: hasAcoustic,
    );

    final wordResult = _alignWords(
      targetText: targetText,
      spokenTranscript: cleanTranscript,
      expectedKeywords: expectedKeywords,
      strictTarget: strictTargetGrammar,
    );

    final pronunciationScore = _computePronunciationScore(
      wordAccuracyScore: wordResult.score,
      rhythmScore: rhythmScore,
      hasTranscript: hasTranscript,
      hasAcoustic: hasAcoustic,
    );

    final fluency = _evaluateFluency(
      userDurationSec: effectiveUserDur,
      referenceDurationSec: refDur,
      pauseCount: acoustic.pauseCount,
      activeRatio: acoustic.activeRatio,
      spokenWordsCount: _tokenize(cleanTranscript).length,
      targetWordsCount: targetWords.length,
      hasAcoustic: hasAcoustic,
    );

    final grammar = _evaluateGrammar(
      targetText: targetText,
      spokenTranscript: cleanTranscript,
      strictTargetGrammar: strictTargetGrammar,
      retellPastTense: retellPastTense,
      wordEvaluations: wordResult.evaluations,
      connectors: connectors,
    );

    final overall = hasTranscript
        ? ((pronunciationScore * 0.4) +
                (fluency.score * 0.35) +
                (grammar.score * 0.25))
            .round()
        : ((pronunciationScore * 0.45) + (fluency.score * 0.55)).round();

    final tip = _buildSummaryTip(
      hasTranscript: hasTranscript,
      pronunciation: pronunciationScore,
      fluency: fluency.score,
      grammar: grammar.score,
      userDur: effectiveUserDur,
      refDur: refDur,
      pauseCount: acoustic.pauseCount,
      grammarIssues: grammar.issues,
    );

    return SpeakingAssessment(
      stageLabel: stageLabel,
      pronunciationScore: pronunciationScore.clamp(0, 100),
      fluencyScore: fluency.score.clamp(0, 100),
      grammarScore: grammar.score.clamp(0, 100),
      overallScore: overall.clamp(0, 100),
      hasTranscript: hasTranscript,
      hasAcousticSignal: hasAcoustic,
      spokenTranscript: cleanTranscript,
      targetText: targetText,
      userDurationSec: double.parse(effectiveUserDur.toStringAsFixed(2)),
      referenceDurationSec: double.parse(refDur.toStringAsFixed(2)),
      estimatedWpm: fluency.wpm,
      pauseCount: acoustic.pauseCount,
      rhythmSimilarityScore: rhythmScore,
      userEnvelope: acoustic.envelope12,
      referenceEnvelope: referenceEnvelope,
      wordEvaluations: wordResult.evaluations,
      grammarIssues: grammar.issues,
      summaryTip: tip,
    );
  }

  _AcousticMetrics _analyzeAcoustics({
    required double elapsedSec,
    required List<double> amplitudeDbfs,
    required bool hasAcoustic,
  }) {
    if (!hasAcoustic || amplitudeDbfs.isEmpty) {
      return _AcousticMetrics(
        activeDurationSec: elapsedSec,
        activeRatio: elapsedSec > 0.4 ? 0.8 : 0.0,
        pauseCount: 0,
        envelope12: const [],
      );
    }

    const voiceThresholdDb = -42.0;
    var firstVoice = -1;
    var lastVoice = -1;
    for (var i = 0; i < amplitudeDbfs.length; i++) {
      if (amplitudeDbfs[i] > voiceThresholdDb) {
        if (firstVoice == -1) firstVoice = i;
        lastVoice = i;
      }
    }

    if (firstVoice == -1) {
      return _AcousticMetrics(
        activeDurationSec: elapsedSec,
        activeRatio: 0.1,
        pauseCount: 0,
        envelope12: List<int>.filled(12, 0),
      );
    }

    final trimmed = amplitudeDbfs.sublist(firstVoice, lastVoice + 1);
    final frameDurSec = elapsedSec / amplitudeDbfs.length;
    final activeDurationSec =
        math.max(0.25, trimmed.length * frameDurSec);

    var quietRun = 0;
    var pauseCount = 0;
    var voicedFrames = 0;
    final linear = <double>[];

    for (final db in trimmed) {
      if (db <= voiceThresholdDb) {
        quietRun++;
        if (quietRun == 4) {
          pauseCount++;
        }
      } else {
        voicedFrames++;
        quietRun = 0;
      }
      final clampedDb = db.clamp(-60.0, 0.0);
      final energy = math.pow(10.0, clampedDb / 20.0).toDouble();
      linear.add(energy);
    }

    final envelope12 = _resampleTo12(linear);
    final activeRatio = voicedFrames / math.max(1, trimmed.length);

    return _AcousticMetrics(
      activeDurationSec: activeDurationSec,
      activeRatio: activeRatio,
      pauseCount: pauseCount,
      envelope12: envelope12,
    );
  }

  List<int> _resampleTo12(List<double> values) {
    if (values.isEmpty) return List<int>.filled(12, 0);
    const bins = 12;
    final out = <double>[];
    for (var b = 0; b < bins; b++) {
      final start = (b * values.length) ~/ bins;
      final end = math.max(start + 1, ((b + 1) * values.length) ~/ bins);
      var sum = 0.0;
      for (var i = start; i < math.min(end, values.length); i++) {
        sum += values[i];
      }
      out.add(sum / math.max(1, end - start));
    }
    final peak = out.reduce(math.max);
    if (peak <= 0.0001) return List<int>.filled(12, 0);
    return out.map((v) => ((v * 100) / peak).round().clamp(0, 100)).toList();
  }

  int _computeRhythmSimilarity({
    required List<int> userEnv,
    required List<int> refEnv,
    required bool hasAcoustic,
  }) {
    if (!hasAcoustic || userEnv.isEmpty || refEnv.isEmpty) return 70;
    final len = math.min(userEnv.length, refEnv.length);
    var dot = 0.0;
    var normU = 0.0;
    var normR = 0.0;
    for (var i = 0; i < len; i++) {
      final u = userEnv[i].toDouble();
      final r = refEnv[i].toDouble();
      dot += u * r;
      normU += u * u;
      normR += r * r;
    }
    if (normU <= 0.0 || normR <= 0.0) return 35;
    final cosine = dot / (math.sqrt(normU) * math.sqrt(normR));
    // Speech envelopes live in [0..100], cosine typically ranges 0.45..0.98
    final scaled = ((cosine - 0.35) / 0.63 * 100).round();
    return scaled.clamp(25, 100);
  }

  _WordAlignmentResult _alignWords({
    required String targetText,
    required String spokenTranscript,
    required List<String> expectedKeywords,
    required bool strictTarget,
  }) {
    final targetTokens = strictTarget || expectedKeywords.isEmpty
        ? _tokenize(targetText)
        : expectedKeywords.expand(_tokenize).toList();
    final spokenTokens = _tokenize(_expandSpokenText(spokenTranscript));

    if (targetTokens.isEmpty) {
      return const _WordAlignmentResult(score: 80, evaluations: []);
    }
    if (spokenTokens.isEmpty) {
      return _WordAlignmentResult(
        score: 0,
        evaluations: targetTokens
            .map(
              (w) => WordEvaluation(
                targetWord: w,
                status: WordMatchStatus.missed,
              ),
            )
            .toList(),
      );
    }

    final evaluations = <WordEvaluation>[];
    var earned = 0.0;
    var searchCursor = 0;

    for (final rawTarget in targetTokens) {
      final variants = _variantsForTarget(rawTarget);
      var bestStatus = WordMatchStatus.missed;
      String? bestSpoken;
      var bestIdx = -1;

      final windowEnd = math.min(spokenTokens.length, searchCursor + 5);
      for (var i = 0; i < windowEnd; i++) {
        final cand = spokenTokens[i];
        if (variants.contains(cand)) {
          bestStatus = WordMatchStatus.exact;
          bestSpoken = cand;
          bestIdx = i;
          break;
        }
        final sim = _bestSimilarity(variants, cand);
        if (sim >= 0.70 && bestStatus == WordMatchStatus.missed) {
          bestStatus = WordMatchStatus.close;
          bestSpoken = cand;
          bestIdx = i;
        }
      }

      if (bestIdx >= searchCursor) {
        searchCursor = bestIdx + 1;
      }

      if (bestStatus == WordMatchStatus.exact) {
        earned += 1.0;
      } else if (bestStatus == WordMatchStatus.close) {
        earned += 0.7;
      }

      evaluations.add(
        WordEvaluation(
          targetWord: rawTarget,
          status: bestStatus,
          spokenWord: bestSpoken,
        ),
      );
    }

    final pct = ((earned / targetTokens.length) * 100).round();
    return _WordAlignmentResult(score: pct, evaluations: evaluations);
  }

  int _computePronunciationScore({
    required int wordAccuracyScore,
    required int rhythmScore,
    required bool hasTranscript,
    required bool hasAcoustic,
  }) {
    if (hasTranscript && hasAcoustic) {
      return ((wordAccuracyScore * 0.72) + (rhythmScore * 0.28)).round();
    }
    if (hasTranscript) return wordAccuracyScore;
    if (hasAcoustic) return rhythmScore;
    return 0;
  }

  _FluencyResult _evaluateFluency({
    required double userDurationSec,
    required double referenceDurationSec,
    required int pauseCount,
    required double activeRatio,
    required int spokenWordsCount,
    required int targetWordsCount,
    required bool hasAcoustic,
  }) {
    final ratio = userDurationSec / math.max(0.4, referenceDurationSec);
    int paceScore;
    if (ratio >= 0.75 && ratio <= 1.35) {
      paceScore = 96;
    } else if (ratio >= 0.55 && ratio <= 1.65) {
      paceScore = 80;
    } else if (ratio >= 0.40 && ratio <= 2.10) {
      paceScore = 62;
    } else {
      paceScore = 40;
    }

    var continuityScore = hasAcoustic ? (activeRatio * 100).round() : 78;
    continuityScore = (continuityScore - (pauseCount * 9)).clamp(25, 100);

    final effectiveWords = spokenWordsCount > 0 ? spokenWordsCount : targetWordsCount;
    final minutes = math.max(0.02, userDurationSec / 60.0);
    final wpm = (effectiveWords / minutes).round().clamp(0, 260);

    final score = hasAcoustic
        ? ((paceScore * 0.55) + (continuityScore * 0.45)).round()
        : paceScore;

    return _FluencyResult(score: score, wpm: wpm);
  }

  _GrammarResult _evaluateGrammar({
    required String targetText,
    required String spokenTranscript,
    required bool strictTargetGrammar,
    required bool retellPastTense,
    required List<WordEvaluation> wordEvaluations,
    required List<String> connectors,
  }) {
    if (spokenTranscript.isEmpty) {
      return const _GrammarResult(
        score: 0,
        issues: [
          GrammarFeedbackItem(
            ruleTitle: 'Belum ada transkrip suara',
            explanation:
                'Aktifkan STT mikrofon atau uji dengan teks ucapanmu untuk menilai Grammar.',
          ),
        ],
      );
    }

    final issues = <GrammarFeedbackItem>[];
    var score = 100;
    final lowerSpoken = _expandSpokenText(spokenTranscript.toLowerCase());

    if (strictTargetGrammar) {
      for (final w in wordEvaluations) {
        if (w.status == WordMatchStatus.missed &&
            _grammarFunctionWords.contains(w.targetWord)) {
          score -= 12;
          issues.add(
            GrammarFeedbackItem(
              ruleTitle: 'Kata struktur terlewat: "${w.targetWord}"',
              explanation:
                  'Kata bantu/penghubung "${w.targetWord}" penting untuk tata bahasa kalimat ini.',
              suggestion: 'Target: "$targetText"',
            ),
          );
        } else if (w.status == WordMatchStatus.missed &&
            (w.targetWord.endsWith('s') || w.targetWord.endsWith('ed'))) {
          score -= 10;
          issues.add(
            GrammarFeedbackItem(
              ruleTitle: 'Akhiran gramatikal: "${w.targetWord}"',
              explanation:
                  'Pastikan akhiran -s/-ed pada "${w.targetWord}" terdengar jelas.',
            ),
          );
        }
      }

      if (issues.isEmpty) {
        final missedRatio = wordEvaluations
                .where((w) => w.status == WordMatchStatus.missed)
                .length /
            math.max(1, wordEvaluations.length);
        if (missedRatio > 0.35) {
          score -= 22;
          issues.add(
            GrammarFeedbackItem(
              ruleTitle: 'Struktur kalimat belum lengkap',
              explanation:
                  'Sebagian frasa inti belum terucap lengkap sesuai pola kalimat target.',
              suggestion: targetText,
            ),
          );
        }
      }
    } else {
      // Free-speech ESL grammar checks (Stage 3 Personal & Stage 5 Storytelling)
      if (retellPastTense) {
        final hasBasePastMistake = RegExp(
          r'\b(yesterday|then|suddenly|finally)\b.*\b(walk|bump|ask|tell|introduce|say|have)\b',
        ).hasMatch(lowerSpoken);
        if (hasBasePastMistake) {
          score -= 15;
          issues.add(
            const GrammarFeedbackItem(
              ruleTitle: 'Gunakan Past Tense saat Retell',
              explanation:
                  'Kejadian di masa lalu memakai Verb-2: walked, bumped, asked, introduced, told.',
              suggestion: 'Contoh: "Yesterday, Maya walked out and bumped into Ryan."',
            ),
          );
        }
      }

      if (RegExp(r'\b(i|you|we|they)\s+is\b|\b(he|she|it|maya|chloe|ryan)\s+are\b')
          .hasMatch(lowerSpoken)) {
        score -= 18;
        issues.add(
          const GrammarFeedbackItem(
            ruleTitle: 'Kesesuaian Subject + To Be',
            explanation:
                'Gunakan "I am", "you/we/they are", dan "he/she/nama orang is".',
          ),
        );
      }

      if (RegExp(r'\b(he|she|maya|chloe|ryan)\s+(come|say|tell|ask|have|go|forget|spell)\b')
          .hasMatch(lowerSpoken)) {
        score -= 14;
        issues.add(
          const GrammarFeedbackItem(
            ruleTitle: 'Akhiran -s / has untuk Orang Ketiga Tunggal',
            explanation:
                'Untuk he/she/Maya/Chloe/Ryan di masa kini, gunakan comes, says, has, asks, goes.',
          ),
        );
      }

      if (RegExp(r'\b(i|she|he|chloe|maya)\s+from\b').hasMatch(lowerSpoken)) {
        score -= 15;
        issues.add(
          const GrammarFeedbackItem(
            ruleTitle: 'Tambahkan "to be" sebelum "from"',
            explanation: 'Katanya jangan langsung "I from...", melainkan "I am from..." / "She is from...".',
          ),
        );
      }

      if (connectors.isNotEmpty) {
        final usedConnector = connectors.any(
          (c) => lowerSpoken.contains(c.toLowerCase()),
        );
        if (!usedConnector) {
          score -= 8;
          issues.add(
            GrammarFeedbackItem(
              ruleTitle: 'Tambahkan kata penghubung cerita',
              explanation:
                  'Pakai connector seperti ${connectors.take(3).join(", ")} agar alur cerita lebih runtut.',
            ),
          );
        }
      }

      final wordCount = _tokenize(lowerSpoken).length;
      if (wordCount < 4) {
        score -= 15;
        issues.add(
          const GrammarFeedbackItem(
            ruleTitle: 'Kalimat masih terlalu singkat',
            explanation: 'Coba jawab dengan klausa lengkap (Subjek + Kata Kerja + Keterangan).',
          ),
        );
      }
    }

    return _GrammarResult(
      score: score.clamp(20, 100),
      issues: issues,
    );
  }

  String _buildSummaryTip({
    required bool hasTranscript,
    required int pronunciation,
    required int fluency,
    required int grammar,
    required double userDur,
    required double refDur,
    required int pauseCount,
    required List<GrammarFeedbackItem> grammarIssues,
  }) {
    if (!hasTranscript) {
      return 'STT tidak menangkap teks di perangkat ini, jadi Fluency & Ritme tetap dihitung dari sinyal audio. Gunakan tombol uji teks jika ingin skor Pronunciation & Grammar berbasis kata.';
    }
    if (pronunciation < 70) {
      return 'Fokus pada kata berwarna kuning/merah dan tiru pola connected speech di mode Native Slow.';
    }
    if (pauseCount >= 2 || userDur > refDur * 1.6) {
      return 'Pelafalan sudah bagus; percepat transisi antar kata agar tidak berhenti lama ($pauseCount jeda terdeteksi).';
    }
    if (grammar < 80 && grammarIssues.isNotEmpty) {
      return grammarIssues.first.explanation;
    }
    if (fluency >= 85 && pronunciation >= 85 && grammar >= 85) {
      return 'Keren! Ritme, pelafalan kata, dan struktur kalimatmu sudah sangat mendekati audio asli.';
    }
    return 'Sudah bagus — ulang 1–2 kali lagi sambil menyamakan tempo dengan audio asli.';
  }

  String _expandSpokenText(String raw) {
    var text = raw.toLowerCase();
    for (final entry in _contractionEquivalents.entries) {
      for (final alt in entry.value) {
        if (alt == 'ya' || alt == 'you') continue;
        final escaped = RegExp.escape(alt);
        text = text.replaceAll(
          RegExp('\\b$escaped\\b'),
          entry.key,
        );
      }
    }
    return text;
  }

  Set<String> _variantsForTarget(String target) {
    final base = target.toLowerCase().replaceAll("'", '');
    final out = <String>{base};
    for (final entry in _contractionEquivalents.entries) {
      if (entry.key == base) {
        out.addAll(entry.value.expand(_tokenize));
      } else if (entry.value.contains(base)) {
        out.add(entry.key);
      }
    }
    return out;
  }

  double _bestSimilarity(Set<String> variants, String candidate) {
    var best = 0.0;
    for (final v in variants) {
      if (v == candidate) return 1.0;
      final pkV = _phoneticSkeleton(v);
      final pkC = _phoneticSkeleton(candidate);
      final lev = _normalizedEditSimilarity(v, candidate);
      final pkSim = _normalizedEditSimilarity(pkV, pkC);
      best = math.max(best, math.max(lev, pkSim * 0.95));
    }
    return best;
  }

  String _phoneticSkeleton(String word) {
    return word
        .toLowerCase()
        .replaceAll('ph', 'f')
        .replaceAll('ck', 'k')
        .replaceAll('ch', 'c')
        .replaceAll('sh', 's')
        .replaceAll('th', 't')
        .replaceAll('tt', 'd')
        .replaceAll('dd', 'd')
        .replaceAll('oo', 'u')
        .replaceAll('ee', 'i')
        .replaceAll(RegExp(r'[aeiou]+'), 'a');
  }

  double _normalizedEditSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final maxLen = math.max(a.length, b.length);
    if (maxLen == 0) return 1.0;
    final dist = _levenshtein(a, b);
    return 1.0 - (dist / maxLen);
  }

  int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = math.min(
          math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }
    return dp[m][n];
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll('—', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.replaceAll("'", ''))
        .where((w) => w.isNotEmpty)
        .toList();
  }
}

class _AcousticMetrics {
  const _AcousticMetrics({
    required this.activeDurationSec,
    required this.activeRatio,
    required this.pauseCount,
    required this.envelope12,
  });

  final double activeDurationSec;
  final double activeRatio;
  final int pauseCount;
  final List<int> envelope12;
}

class _WordAlignmentResult {
  const _WordAlignmentResult({
    required this.score,
    required this.evaluations,
  });

  final int score;
  final List<WordEvaluation> evaluations;
}

class _FluencyResult {
  const _FluencyResult({required this.score, required this.wpm});

  final int score;
  final int wpm;
}

class _GrammarResult {
  const _GrammarResult({required this.score, required this.issues});

  final int score;
  final List<GrammarFeedbackItem> issues;
}
