enum WordMatchStatus { exact, close, missed }

class WordEvaluation {
  const WordEvaluation({
    required this.targetWord,
    required this.status,
    this.spokenWord,
  });

  final String targetWord;
  final WordMatchStatus status;
  final String? spokenWord;
}

class GrammarFeedbackItem {
  const GrammarFeedbackItem({
    required this.ruleTitle,
    required this.explanation,
    this.suggestion,
  });

  final String ruleTitle;
  final String explanation;
  final String? suggestion;
}

/// Raw capture returned when stopping a microphone recording session.
class RecordingCapture {
  const RecordingCapture({
    this.filePath,
    this.transcript = '',
    this.elapsed = Duration.zero,
    this.amplitudeDbfs = const [],
  });

  final String? filePath;
  final String transcript;
  final Duration elapsed;
  final List<double> amplitudeDbfs;
}

/// Complete on-device evaluation comparing Pronunciation, Fluency, and Grammar.
class SpeakingAssessment {
  const SpeakingAssessment({
    required this.stageLabel,
    required this.pronunciationScore,
    required this.fluencyScore,
    required this.grammarScore,
    required this.overallScore,
    required this.hasTranscript,
    required this.hasAcousticSignal,
    required this.spokenTranscript,
    required this.targetText,
    required this.userDurationSec,
    required this.referenceDurationSec,
    required this.estimatedWpm,
    required this.pauseCount,
    required this.rhythmSimilarityScore,
    required this.userEnvelope,
    required this.referenceEnvelope,
    required this.wordEvaluations,
    required this.grammarIssues,
    required this.summaryTip,
  });

  final String stageLabel;
  final int pronunciationScore;
  final int fluencyScore;
  final int grammarScore;
  final int overallScore;
  final bool hasTranscript;
  final bool hasAcousticSignal;
  final String spokenTranscript;
  final String targetText;
  final double userDurationSec;
  final double referenceDurationSec;
  final int estimatedWpm;
  final int pauseCount;
  final int rhythmSimilarityScore;
  final List<int> userEnvelope;
  final List<int> referenceEnvelope;
  final List<WordEvaluation> wordEvaluations;
  final List<GrammarFeedbackItem> grammarIssues;
  final String summaryTip;

  String get gradeLabel {
    if (overallScore >= 85) return 'Mantap (Natural)';
    if (overallScore >= 70) return 'Bagus (Terus Latih)';
    if (overallScore >= 50) return 'Cukup (Perlu Poles)';
    return 'Perlu Latihan Lagi';
  }
}
