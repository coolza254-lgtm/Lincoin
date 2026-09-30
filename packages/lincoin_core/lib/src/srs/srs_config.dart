import 'package:fsrs/fsrs.dart' as fsrs;

/// Version of the scheduling code path. Bump whenever a change (including a
/// dependency upgrade) could produce a different schedule for the same log.
const int schedulerAlgoVersion = 1;

/// Settings for one deck's scheduler (vocab and grammar each have their own).
class SrsConfig {
  /// FSRS-6 weights (21 values).
  final List<double> parameters;

  /// Identifies [parameters]; stored on every review log row.
  final int paramsVersion;

  /// Target probability of recall when a card comes due (0.80–0.95).
  final double desiredRetention;

  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final int maximumIntervalDays;
  final bool enableFuzz;

  /// A card whose lapse count reaches this is flagged as a leech.
  final int leechThreshold;

  static const double minRetention = 0.80;
  static const double maxRetention = 0.95;

  SrsConfig({
    List<double> parameters = fsrs.defaultParameters,
    this.paramsVersion = 0,
    this.desiredRetention = 0.90,
    this.learningSteps = const [Duration(minutes: 1), Duration(minutes: 10)],
    this.relearningSteps = const [Duration(minutes: 10)],
    this.maximumIntervalDays = 36500,
    this.enableFuzz = true,
    this.leechThreshold = 8,
  }) : parameters = List.unmodifiable(parameters) {
    if (desiredRetention < minRetention || desiredRetention > maxRetention) {
      throw ArgumentError.value(desiredRetention, 'desiredRetention',
          'must be between $minRetention and $maxRetention');
    }
  }

  SrsConfig copyWith({
    List<double>? parameters,
    int? paramsVersion,
    double? desiredRetention,
    List<Duration>? learningSteps,
    List<Duration>? relearningSteps,
    int? maximumIntervalDays,
    bool? enableFuzz,
    int? leechThreshold,
  }) =>
      SrsConfig(
        parameters: parameters ?? this.parameters,
        paramsVersion: paramsVersion ?? this.paramsVersion,
        desiredRetention: desiredRetention ?? this.desiredRetention,
        learningSteps: learningSteps ?? this.learningSteps,
        relearningSteps: relearningSteps ?? this.relearningSteps,
        maximumIntervalDays: maximumIntervalDays ?? this.maximumIntervalDays,
        enableFuzz: enableFuzz ?? this.enableFuzz,
        leechThreshold: leechThreshold ?? this.leechThreshold,
      );

  Map<String, Object?> toJson() => {
        'parameters': parameters,
        'paramsVersion': paramsVersion,
        'desiredRetention': desiredRetention,
        'learningStepsSec': learningSteps.map((d) => d.inSeconds).toList(),
        'relearningStepsSec': relearningSteps.map((d) => d.inSeconds).toList(),
        'maximumIntervalDays': maximumIntervalDays,
        'enableFuzz': enableFuzz,
        'leechThreshold': leechThreshold,
      };

  factory SrsConfig.fromJson(Map<String, Object?> json) {
    List<Duration> steps(Object? v) => (v as List<Object?>)
        .map((s) => Duration(seconds: (s as num).toInt()))
        .toList();
    return SrsConfig(
      parameters: (json['parameters'] as List<Object?>)
          .map((p) => (p as num).toDouble())
          .toList(),
      paramsVersion: (json['paramsVersion'] as num).toInt(),
      desiredRetention: (json['desiredRetention'] as num).toDouble(),
      learningSteps: steps(json['learningStepsSec']),
      relearningSteps: steps(json['relearningStepsSec']),
      maximumIntervalDays: (json['maximumIntervalDays'] as num).toInt(),
      enableFuzz: json['enableFuzz'] as bool,
      leechThreshold: (json['leechThreshold'] as num).toInt(),
    );
  }
}
