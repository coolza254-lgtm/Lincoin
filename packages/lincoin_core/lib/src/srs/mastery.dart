import 'card_state.dart';

/// Fixed, config-driven definition of "mastered". Evaluated on current state,
/// so a mastered card that is later forgotten stops counting.
class MasteryRule {
  final double minStabilityDays;
  final int minReps;

  const MasteryRule({this.minStabilityDays = 21, this.minReps = 3});

  bool isMastered(CardState s) =>
      s.status == CardStatus.review &&
      (s.stability ?? 0) >= minStabilityDays &&
      s.reps >= minReps &&
      s.lastRating != Rating.again;

  Map<String, Object?> toJson() =>
      {'minStabilityDays': minStabilityDays, 'minReps': minReps};

  factory MasteryRule.fromJson(Map<String, Object?> json) => MasteryRule(
        minStabilityDays: (json['minStabilityDays'] as num).toDouble(),
        minReps: (json['minReps'] as num).toInt(),
      );
}
