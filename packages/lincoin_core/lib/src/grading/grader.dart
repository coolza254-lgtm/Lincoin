import '../srs/card_state.dart';

/// What happened when the learner answered one question.
class AnswerEvent {
  final bool isCorrect;
  final bool usedHint;

  /// Learner pressed "ตอบแบบเดา" (answered but was guessing).
  final bool markedGuess;

  /// Learner pressed "ไม่รู้".
  final bool gaveUp;
  final int responseMs;

  const AnswerEvent({
    required this.isCorrect,
    required this.responseMs,
    this.usedHint = false,
    this.markedGuess = false,
    this.gaveUp = false,
  });
}

class GraderConfig {
  /// Correct but slower than this × the learner's median → Hard.
  final double slowFactor;

  /// Correct and faster than this × median, without a hint → Easy.
  final double fastFactor;

  /// Response times are capped here (the phone was put down).
  final int maxResponseMs;

  /// Used until enough personal data exists for a question type.
  final int defaultMedianMs;

  const GraderConfig({
    this.slowFactor = 2.0,
    this.fastFactor = 0.6,
    this.maxResponseMs = 60000,
    this.defaultMedianMs = 6000,
  });

  Map<String, Object?> toJson() => {
        'slowFactor': slowFactor,
        'fastFactor': fastFactor,
        'maxResponseMs': maxResponseMs,
        'defaultMedianMs': defaultMedianMs,
      };

  factory GraderConfig.fromJson(Map<String, Object?> json) => GraderConfig(
        slowFactor: (json['slowFactor'] as num).toDouble(),
        fastFactor: (json['fastFactor'] as num).toDouble(),
        maxResponseMs: (json['maxResponseMs'] as num).toInt(),
        defaultMedianMs: (json['defaultMedianMs'] as num).toInt(),
      );
}

/// Turns observed behaviour into a rating. The learner never rates
/// themselves, which removes self-assessment bias.
class Grader {
  final GraderConfig config;
  const Grader([this.config = const GraderConfig()]);

  Rating grade(AnswerEvent e, {int? medianMs}) {
    if (!e.isCorrect || e.gaveUp || e.markedGuess) return Rating.again;
    final ms = e.responseMs.clamp(0, config.maxResponseMs);
    final median = medianMs ?? config.defaultMedianMs;
    if (e.usedHint || ms > median * config.slowFactor) return Rating.hard;
    if (ms < median * config.fastFactor) return Rating.easy;
    return Rating.good;
  }
}

/// Rolling median response time per question type, from correct unassisted
/// answers only.
class ResponseTimeTracker {
  final int window;
  final int minSamples;
  final Map<String, List<int>> _samples = {};

  ResponseTimeTracker({this.window = 200, this.minSamples = 20});

  void add(String questionType, AnswerEvent e, {int maxResponseMs = 60000}) {
    if (!e.isCorrect || e.usedHint || e.markedGuess || e.gaveUp) return;
    final list = _samples.putIfAbsent(questionType, () => []);
    list.add(e.responseMs.clamp(0, maxResponseMs));
    if (list.length > window) list.removeAt(0);
  }

  /// Null until [minSamples] answers exist for [questionType].
  int? median(String questionType) {
    final list = _samples[questionType];
    if (list == null || list.length < minSamples) return null;
    final sorted = [...list]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }
}
